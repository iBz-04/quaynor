use crate::errors::{InitWorkerError, LoadModelError, ReadError};
use crate::memory;
use crate::tokenizer::{ProjectionModel, Tokenizer, TokenizerChunk, TokenizerChunks};
use lazy_static::lazy_static;
use llama_cpp_2::context::kv_cache::KvCacheConversionError;
use llama_cpp_2::context::params::{LlamaContextParams, LlamaPoolingType};
use llama_cpp_2::context::LlamaContext;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::AddBos;
use llama_cpp_2::model::LlamaModel;
use llama_cpp_2::mtmd::MtmdInputChunks;
use llama_cpp_2::token::LlamaToken;
use std::io::{Read, Write};
use std::pin::pin;
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, LazyLock, Mutex, MutexGuard, RwLock};
use tracing::{debug, debug_span, error, info, info_span, warn};

#[derive(Debug)]
pub(crate) struct GlobalInferenceLockToken;
lazy_static! {
    pub(crate) static ref GLOBAL_INFERENCE_LOCK: Mutex<GlobalInferenceLockToken> =
        Mutex::new(GlobalInferenceLockToken);
}

static LLAMA_BACKEND: LazyLock<LlamaBackend> =
    LazyLock::new(|| LlamaBackend::init().expect("Failed to initialize llama backend"));
static LOADED_CACHE_MODELS: LazyLock<Mutex<std::collections::HashMap<std::path::PathBuf, usize>>> =
    LazyLock::new(|| Mutex::new(std::collections::HashMap::new()));
static MODEL_CACHE_OPERATION_LOCK: LazyLock<RwLock<()>> = LazyLock::new(|| RwLock::new(()));

#[derive(Debug)]
pub struct Model {
    pub(crate) language_model: LlamaModel,
    pub(crate) projection_model: Option<ProjectionModel>,
    loaded_cache_keys: Vec<std::path::PathBuf>,
}

impl Model {
    pub fn max_ctx(&self) -> u32 {
        self.language_model.n_ctx_train()
    }
}

impl Drop for Model {
    fn drop(&mut self) {
        if self.loaded_cache_keys.is_empty() {
            return;
        }

        let mut loaded_cache_models = LOADED_CACHE_MODELS
            .lock()
            .expect("Loaded model registry lock was poisoned while dropping a model");
        for cache_key in &self.loaded_cache_keys {
            match loaded_cache_models.get_mut(cache_key) {
                Some(count) if *count > 1 => *count -= 1,
                Some(_) => {
                    loaded_cache_models.remove(cache_key);
                }
                None => panic!(
                    "Loaded model registry did not contain cache key while dropping model: {}",
                    cache_key.display()
                ),
            }
        }
    }
}

pub fn has_gpu_backend() -> bool {
    #[cfg(any(
        all(target_os = "ios", target_arch = "aarch64", target_abi = "sim"),
        all(target_os = "ios", target_arch = "x86_64")
    ))]
    {
        // GPU-acceleration not working on ios simulators seems to be a known issue in llama.cpp:
        // https://github.com/ggml-org/llama.cpp/blob/017eceed61e885b79f6cf3542e0879be68c6e922/examples/llama.swiftui/llama.cpp.swift/LibLlama.swift#L66
        warn!("Running on iOS simulator. Disabling GPU support.");
        return false;
    }

    for backend_device in llama_cpp_2::list_llama_ggml_backend_devices() {
        // TODO: account for memory available on backend device - .memory_total and .memory free
        //       we might use these with GGUF model metadata, to decide on a number of layers to offload
        match backend_device.device_type {
            llama_cpp_2::LlamaBackendDeviceType::Unknown => {
                continue;
            }
            llama_cpp_2::LlamaBackendDeviceType::Cpu => {
                continue;
            }
            llama_cpp_2::LlamaBackendDeviceType::Accelerator => {
                // Accelerator devices (e.g. NPUs) are auto-initialized by llama.cpp during
                // context creation regardless of n_gpu_layers — no explicit handling needed.
                continue;
            }
            llama_cpp_2::LlamaBackendDeviceType::IntegratedGpu => {
                return true;
            }
            llama_cpp_2::LlamaBackendDeviceType::Gpu => {
                return true;
            }
        }
    }

    false
}

#[derive(Clone)]
enum ParsedModelPath {
    HuggingFaceUrl(String, String, String), // e.g. hf://owner/repo/model.gguf -> (owner, repo, filename)
    HttpUrl(String),                        // e.g. https://example.com/lol/qwen3.gguf
    FilesystemPath(std::path::PathBuf),     // e.g. ./qwen3.gguf
}

pub struct CachedModel {
    pub path: String,
    pub size: u64,
}

fn parse_model_path(
    model_path: &str,
) -> Result<ParsedModelPath, nom::Err<nom::error::Error<String>>> {
    use nom::branch::alt;
    use nom::bytes::complete::{tag, tag_no_case, take_until};
    use nom::combinator::{cut, map, rest, verify};
    use nom::sequence::{preceded, terminated};
    use nom::Parser;

    let mut parser = alt((
        // hf://owner/repo/filename.gguf (also hf:, huggingface:, huggingface://)
        map(
            preceded(
                alt((
                    tag_no_case("huggingface://"),
                    tag_no_case("huggingface:"),
                    tag_no_case("hf://"),
                    tag_no_case("hf:"),
                )),
                cut((
                    terminated(take_until("/"), tag("/")),
                    terminated(take_until("/"), tag("/")),
                    verify(rest, |s: &str| !s.is_empty()),
                )),
            ),
            |(owner, repo, filename): (&str, &str, &str)| {
                ParsedModelPath::HuggingFaceUrl(owner.into(), repo.into(), filename.into())
            },
        ),
        // https://... or http://...
        map(
            (alt((tag_no_case("https://"), tag_no_case("http://"))), rest),
            |(scheme, path): (&str, &str)| ParsedModelPath::HttpUrl(format!("{}{}", scheme, path)),
        ),
        // Anything else is a filesystem path
        map(rest, |p: &str| {
            ParsedModelPath::FilesystemPath(std::path::PathBuf::from(p))
        }),
    ));
    let result: nom::IResult<&str, ParsedModelPath> = parser.parse(model_path);
    result
        .map(|(_, parsed)| parsed)
        .map_err(|e| e.map(|e| e.cloned()))
}

/// takes a fancy path (possibly with hf: or https:// in front), and resolve it to a realized path
/// on the filesystem
fn resolve_fancy_path_to_fs(
    parsed_path: ParsedModelPath,
    headers: Option<&std::collections::HashMap<String, String>>,
    progress: Option<&(dyn Fn(u64, u64) + Send + Sync)>,
) -> Result<std::path::PathBuf, LoadModelError> {
    let fs_model_path = match parsed_path {
        ParsedModelPath::HuggingFaceUrl(owner, repo, filename) => {
            download_model_from_hf_with_options(&owner, &repo, &filename, headers, progress)?
        }
        ParsedModelPath::FilesystemPath(path) => path,
        ParsedModelPath::HttpUrl(url) => download_model_from_url_with_options(&url, headers, progress)?,
    };

    if !fs_model_path.exists() {
        let e = LoadModelError::ModelNotFound(fs_model_path.to_string_lossy().into());
        error!(error = %e, "Model file not found");
        return Err(e);
    }

    Ok(fs_model_path)
}

pub fn resolve_model_path(
    model_path: &str,
    headers: Option<&std::collections::HashMap<String, String>>,
    progress: Option<&(dyn Fn(u64, u64) + Send + Sync)>,
) -> Result<std::path::PathBuf, LoadModelError> {
    resolve_fancy_path_to_fs(parse_model_path(model_path)?, headers, progress)
}

fn cache_tracking_key_for_existing_path(
    path: &std::path::Path,
) -> Result<Option<std::path::PathBuf>, LoadModelError> {
    let cache_dir = get_cache_dir()?;

    if !cache_dir.exists() {
        return Ok(None);
    }

    let canonical_cache_dir = cache_dir.canonicalize().map_err(|e| {
        LoadModelError::DownloadError(format!(
            "Failed to read cache directory {}: {e}",
            cache_dir.display()
        ))
    })?;
    let canonical_path = path
        .canonicalize()
        .map_err(|_| LoadModelError::ModelNotFound(path.to_string_lossy().into_owned()))?;

    if canonical_path.starts_with(&canonical_cache_dir) {
        Ok(Some(canonical_path))
    } else {
        Ok(None)
    }
}

fn register_loaded_cache_models(cache_keys: &[std::path::PathBuf]) -> Result<(), LoadModelError> {
    if cache_keys.is_empty() {
        return Ok(());
    }

    let mut loaded_cache_models = LOADED_CACHE_MODELS
        .lock()
        .map_err(|_| LoadModelError::LoadedModelRegistryLockPoisoned)?;
    for cache_key in cache_keys {
        *loaded_cache_models.entry(cache_key.clone()).or_insert(0) += 1;
    }
    Ok(())
}

fn cached_model_is_loaded(cache_key: &std::path::Path) -> Result<bool, LoadModelError> {
    let loaded_cache_models = LOADED_CACHE_MODELS
        .lock()
        .map_err(|_| LoadModelError::LoadedModelRegistryLockPoisoned)?;
    Ok(loaded_cache_models
        .get(cache_key)
        .is_some_and(|count| *count > 0))
}

#[tracing::instrument(level = "info")]
pub fn get_model(
    model_path: &str,
    use_gpu_if_available: bool,
    mmproj_path: Option<&str>,
) -> Result<Model, LoadModelError> {
    let _cache_operation_guard = MODEL_CACHE_OPERATION_LOCK
        .read()
        .map_err(|_| LoadModelError::ModelCacheOperationLockPoisoned)?;
    let parsed_model_path = parse_model_path(model_path)?;
    let real_model_path = resolve_fancy_path_to_fs(parsed_model_path, None, None)?;
    let parsed_mmproj_path = mmproj_path.map(parse_model_path).transpose()?;
    let real_mmproj_path = parsed_mmproj_path
        .map(|path| resolve_fancy_path_to_fs(path, None, None))
        .transpose()?;
    let mut loaded_cache_keys = Vec::new();
    if let Some(cache_key) = cache_tracking_key_for_existing_path(&real_model_path)? {
        loaded_cache_keys.push(cache_key);
    }
    if let Some(real_mmproj_path) = real_mmproj_path.as_deref() {
        if let Some(cache_key) = cache_tracking_key_for_existing_path(real_mmproj_path)? {
            loaded_cache_keys.push(cache_key);
        }
    }

    // TODO: `LlamaModelParams` uses all devices by default. Set it to an empty list once an upstream device API is available.
    let use_gpu = use_gpu_if_available && has_gpu_backend();
    let loading_plan =
        memory::plan_model_loading(&real_model_path, real_mmproj_path.as_deref(), use_gpu);
    let gpu_layers = loading_plan.gpu_layers;
    for warning in &loading_plan.warnings {
        warn!("{}", warning);
    }

    info!(use_gpu = use_gpu, gpu_layers = gpu_layers, "Loading model");

    let model_params = LlamaModelParams::default().with_n_gpu_layers(gpu_layers);

    let model_params = pin!(model_params);
    let load_span = info_span!("model_load", path = %real_model_path.display());
    let _guard = load_span.enter();

    let language_model =
        LlamaModel::load_from_file(&LLAMA_BACKEND, &real_model_path, &model_params).map_err(
            |e| {
                let error_msg = format!(
                    "Bad model path: {} - Llama.cpp error: {}",
                    real_model_path.display(),
                    e
                );
                error!(error = %error_msg, "Failed to load model");
                LoadModelError::InvalidModel(error_msg)
            },
        )?;

    info!("Model loaded successfully");
    let projection_model = real_mmproj_path
        .as_ref()
        .map(|path| ProjectionModel::from_path(path, &language_model, use_gpu))
        .transpose()?;
    register_loaded_cache_models(&loaded_cache_keys)?;

    Ok(Model {
        language_model,
        projection_model,
        loaded_cache_keys,
    })
}

/// Asynchronously loads a GGUF model from disk.
///
/// This function offloads the blocking model load operation to a background thread,
/// allowing the async runtime to remain responsive. This is particularly useful when
/// loading large models that can take several seconds to initialize.
///
/// # Arguments
///
/// * `model_path` - Path to the GGUF model file
/// * `use_gpu_if_available` - Whether to attempt GPU acceleration if a discrete GPU is available
///
/// # Returns
///
/// Returns a `Model` on success, or a `LoadModelError` on failure.
///
/// # Errors
///
/// This function will return an error if:
/// * The model file is not found (`LoadModelError::ModelNotFound`)
/// * The model file is invalid or unsupported (`LoadModelError::InvalidModel`)
/// * The communication channel closes unexpectedly (`LoadModelError::ModelChannelError`)
#[tracing::instrument(level = "info")]
pub async fn get_model_async(
    model_path: String,
    use_gpu_if_available: bool,
    mmproj_path: Option<String>,
) -> Result<Model, LoadModelError> {
    let (output_tx, mut output_rx) = tokio::sync::mpsc::channel(4096);
    std::thread::spawn(move || {
        output_tx.blocking_send(get_model(
            &model_path,
            use_gpu_if_available,
            mmproj_path.as_deref(),
        ))
    });

    match output_rx.recv().await {
        Some(model) => return model,
        None => Err(LoadModelError::ModelChannelError),
    }
}

pub async fn get_model_async_with_progress(
    model_path: String,
    use_gpu_if_available: bool,
    mmproj_path: Option<String>,
    progress: Option<Arc<dyn Fn(u64, u64) + Send + Sync>>,
) -> Result<Model, LoadModelError> {
    let (output_tx, mut output_rx) = tokio::sync::mpsc::channel(4096);
    std::thread::spawn(move || {
        let progress_ref = progress.as_deref();
        let real_model_path = resolve_model_path(&model_path, None, progress_ref);
        let result = real_model_path.and_then(|_| {
            get_model(&model_path, use_gpu_if_available, mmproj_path.as_deref())
        });
        output_tx.blocking_send(result)
    });

    match output_rx.recv().await {
        Some(model) => return model,
        None => Err(LoadModelError::ModelChannelError),
    }
}

/// Get the cache directory for downloaded models.
///
/// On Android, the package name is read from `/proc/self/cmdline` and the user ID
/// is derived from the UID (`uid / 100000`). This avoids needing JNI or an Android
/// Context object, which isn't reliably available — Flutter loads native libraries
/// via `dlopen` (not `System.loadLibrary`), so `JNI_OnLoad` is never called.
///
/// On other platforms, uses the `dirs` crate to find the standard cache directory.
pub fn get_cache_dir() -> Result<std::path::PathBuf, crate::errors::LoadModelError> {
    let base = get_platform_cache_dir()?;
    Ok(base.join("quaynor").join("models"))
}

#[cfg(target_os = "android")]
fn get_platform_cache_dir() -> Result<std::path::PathBuf, crate::errors::LoadModelError> {
    // Read the package name from /proc/self/cmdline. This file contains the process
    // name as a null-terminated string. On Android this is the package name
    // (e.g. "com.example.app"), possibly with a colon suffix for multi-process apps
    // (e.g. "com.example.app:remote").
    let cmdline = std::fs::read("/proc/self/cmdline").map_err(|e| {
        crate::errors::LoadModelError::DownloadError(format!(
            "Failed to read /proc/self/cmdline: {e}"
        ))
    })?;

    let package_name = cmdline
        .split(|&b| b == 0)
        .next()
        .and_then(|bytes| std::str::from_utf8(bytes).ok())
        .map(|s| s.split(':').next().unwrap_or(s))
        .ok_or_else(|| {
            crate::errors::LoadModelError::DownloadError(
                "Could not determine Android package name from /proc/self/cmdline".into(),
            )
        })?;

    // Derive the Android user ID from the Unix UID. Android assigns UIDs as:
    //   uid = user_id * 100000 + app_id
    // This gives the correct path on multi-user devices (e.g. GrapheneOS work
    // profiles), where /data/data/ is a symlink only valid for user 0.
    let uid = unsafe { libc::getuid() };
    let user_id = uid / 100000;

    Ok(std::path::PathBuf::from(format!(
        "/data/user/{user_id}/{package_name}/cache"
    )))
}

#[cfg(not(target_os = "android"))]
fn get_platform_cache_dir() -> Result<std::path::PathBuf, crate::errors::LoadModelError> {
    dirs::cache_dir().ok_or_else(|| {
        crate::errors::LoadModelError::DownloadError("Could not determine cache directory".into())
    })
}

/// Download a file from a URL to a local path, streaming to disk with progress logging.
///
/// Returns early if the file already exists at the target path.
/// Rejects paths containing `..` to prevent path traversal attacks.
fn download_file(
    url: &str,
    target_path: &std::path::Path,
    headers: Option<&std::collections::HashMap<String, String>>,
    progress: Option<&(dyn Fn(u64, u64) + Send + Sync)>,
) -> Result<(), crate::errors::LoadModelError> {
    for component in target_path.components() {
        if component == std::path::Component::ParentDir {
            return Err(crate::errors::LoadModelError::DownloadError(
                "Path traversal detected: '..' is not allowed in model paths".into(),
            ));
        }
    }

    if target_path.exists() {
        info!("Using cached file: {}", target_path.display());
        return Ok(());
    }

    // Create parent directories
    if let Some(parent) = target_path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| {
            crate::errors::LoadModelError::DownloadError(format!(
                "Failed to create cache directory {}: {e}",
                parent.display()
            ))
        })?;
    }

    info!("Downloading {} -> {}", url, target_path.display());

    let mut request = ureq::get(url);
    if let Some(headers) = headers {
        for (name, value) in headers {
            request = request.header(name.as_str(), value.as_str());
        }
    }

    let response = request.call().map_err(|e| {
        crate::errors::LoadModelError::DownloadError(format!("HTTP request failed: {e}"))
    })?;

    let content_length: std::num::NonZeroU64 = response
        .headers()
        .get("content-length")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<std::num::NonZeroU64>().ok())
        .ok_or_else(|| {
            crate::errors::LoadModelError::DownloadError(format!(
                "Server returned missing or zero Content-Length for {url}"
            ))
        })?;

    info!(
        "Download size: {:.1} GB",
        content_length.get() as f64 / 1_073_741_824.0
    );

    // Write to a temp file first, then rename — avoids partial files on failure.
    let tmp_path = target_path.with_file_name(format!(
        "{}.{:x}.part",
        target_path
            .file_name()
            .unwrap_or_default()
            .to_string_lossy(),
        rand::random::<u32>(),
    ));

    let download_result: Result<(), crate::errors::LoadModelError> = (|| {
        let mut file = std::fs::File::create(&tmp_path).map_err(|e| {
            crate::errors::LoadModelError::DownloadError(format!(
                "Failed to create temp file {}: {e}",
                tmp_path.display()
            ))
        })?;

        let body = response.into_body();
        let mut reader = body.into_reader();
        let mut downloaded: u64 = 0;
        let mut last_logged_pct: u64 = 0;
        let mut buf = vec![0u8; 256 * 1024]; // 256 KB chunks
        if let Some(progress) = progress {
            progress(0, content_length.get());
        }

        loop {
            let n = reader.read(&mut buf).map_err(|e| {
                crate::errors::LoadModelError::DownloadError(format!(
                    "Read error during download: {e}"
                ))
            })?;
            if n == 0 {
                break;
            }
            file.write_all(&buf[..n]).map_err(|e| {
                crate::errors::LoadModelError::DownloadError(format!(
                    "Write error during download: {e}"
                ))
            })?;
            downloaded += n as u64;
            if let Some(progress) = progress {
                progress(downloaded, content_length.get());
            }

            let pct = (downloaded * 100) / content_length;
            if pct >= last_logged_pct + 5 {
                info!(
                    "Download progress: {pct}% ({downloaded}/{} bytes)",
                    content_length
                );
                last_logged_pct = pct;
            }
        }
        if downloaded != content_length.get() {
            return Err(crate::errors::LoadModelError::DownloadError(format!(
                "Download incomplete: got {downloaded}/{} bytes",
                content_length
            )));
        }
        Ok(())
    })();

    if download_result.is_err() {
        if let Err(e) = std::fs::remove_file(&tmp_path) {
            warn!("Failed to clean up temp file {}: {e}", tmp_path.display());
        }
        return download_result;
    }

    // Rename temp file to final path
    std::fs::rename(&tmp_path, target_path).map_err(|e| {
        crate::errors::LoadModelError::DownloadError(format!(
            "Failed to rename temp file to {}: {e}",
            target_path.display()
        ))
    })?;

    info!("Download complete: {}", target_path.display());
    Ok(())
}

/// Download a GGUF model from HuggingFace Hub and return the local path to it.
///
/// If the model is already cached locally, the cached path is returned without downloading.
fn download_model_from_hf_with_options(
    owner: &str,
    repo: &str,
    filename: &str,
    headers: Option<&std::collections::HashMap<String, String>>,
    progress: Option<&(dyn Fn(u64, u64) + Send + Sync)>,
) -> Result<std::path::PathBuf, crate::errors::LoadModelError> {
    let cache_dir = get_cache_dir()?;
    let target_path = cache_dir.join(owner).join(repo).join(filename);
    let url = format!("https://huggingface.co/{owner}/{repo}/resolve/main/{filename}");
    download_file(&url, &target_path, headers, progress)?;
    Ok(target_path)
}

/// Download a model from a generic HTTP(S) URL and return the local path to it.
///
/// The file is cached by its URL path components under the cache directory.
fn download_model_from_url_with_options(
    url: &str,
    headers: Option<&std::collections::HashMap<String, String>>,
    progress: Option<&(dyn Fn(u64, u64) + Send + Sync)>,
) -> Result<std::path::PathBuf, crate::errors::LoadModelError> {
    let cache_dir = get_cache_dir()?;
    // Derive a cache path from the URL: strip scheme, use the rest as path components
    let path_part = url
        .trim_start_matches("https://")
        .trim_start_matches("http://");
    let target_path = cache_dir.join("http").join(path_part);
    download_file(url, &target_path, headers, progress)?;
    Ok(target_path)
}

fn cached_model_path_for(
    parsed_path: ParsedModelPath,
) -> Result<std::path::PathBuf, LoadModelError> {
    let cache_dir = get_cache_dir()?;
    let path = match parsed_path {
        ParsedModelPath::HuggingFaceUrl(owner, repo, filename) => {
            cache_dir.join(owner).join(repo).join(filename)
        }
        ParsedModelPath::HttpUrl(url) => {
            let path_part = url
                .trim_start_matches("https://")
                .trim_start_matches("http://");
            cache_dir.join("http").join(path_part)
        }
        ParsedModelPath::FilesystemPath(path) => path,
    };
    Ok(path)
}

fn ensure_cached_gguf_path(
    path: &std::path::Path,
) -> Result<(std::path::PathBuf, std::path::PathBuf), LoadModelError> {
    let cache_dir = get_cache_dir()?;
    ensure_cached_gguf_path_in_cache(path, &cache_dir)
}

fn ensure_cached_gguf_path_in_cache(
    path: &std::path::Path,
    cache_dir: &std::path::Path,
) -> Result<(std::path::PathBuf, std::path::PathBuf), LoadModelError> {
    let canonical_cache_dir = cache_dir.canonicalize().map_err(|e| {
        LoadModelError::DownloadError(format!(
            "Failed to read cache directory {}: {e}",
            cache_dir.display()
        ))
    })?;
    let canonical_path = path
        .canonicalize()
        .map_err(|_| LoadModelError::ModelNotFound(path.to_string_lossy().into_owned()))?;

    if !canonical_path.starts_with(&canonical_cache_dir) {
        return Err(LoadModelError::ModelOutsideCache(
            path.to_string_lossy().into_owned(),
        ));
    }

    let metadata = std::fs::symlink_metadata(&canonical_path).map_err(|e| {
        LoadModelError::DownloadError(format!(
            "Failed to read metadata for {}: {e}",
            canonical_path.display()
        ))
    })?;
    if !metadata.is_file() {
        return Err(LoadModelError::DownloadError(format!(
            "Cached model is not a file: {}",
            canonical_path.display()
        )));
    }

    if canonical_path.extension().and_then(|ext| ext.to_str()) != Some("gguf") {
        return Err(LoadModelError::CachedModelNotGguf(
            canonical_path.to_string_lossy().into_owned(),
        ));
    }

    Ok((canonical_path, canonical_cache_dir))
}

fn cleanup_empty_cache_dirs(
    mut dir: std::path::PathBuf,
    cache_dir: &std::path::Path,
) -> Result<(), LoadModelError> {
    while dir.starts_with(cache_dir) && dir != cache_dir {
        match std::fs::remove_dir(&dir) {
            Ok(()) => {
                if let Some(parent) = dir.parent() {
                    dir = parent.to_path_buf();
                } else {
                    break;
                }
            }
            Err(error)
                if matches!(
                    error.kind(),
                    std::io::ErrorKind::DirectoryNotEmpty | std::io::ErrorKind::NotFound
                ) =>
            {
                return Ok(());
            }
            Err(source) => {
                return Err(LoadModelError::CleanupCachedModelDirectory {
                    path: dir.to_string_lossy().into_owned(),
                    source,
                });
            }
        }
    }
    Ok(())
}

pub fn download_model(
    model_path: &str,
    headers: Option<&std::collections::HashMap<String, String>>,
    progress: Option<&(dyn Fn(u64, u64) + Send + Sync)>,
) -> Result<std::path::PathBuf, crate::errors::LoadModelError> {
    resolve_model_path(model_path, headers, progress)
}

pub fn delete_cached_model(model_path: &str) -> Result<u64, crate::errors::LoadModelError> {
    let _cache_operation_guard = MODEL_CACHE_OPERATION_LOCK
        .write()
        .map_err(|_| LoadModelError::ModelCacheOperationLockPoisoned)?;
    let target_path = cached_model_path_for(parse_model_path(model_path)?)?;
    let (canonical_path, cache_dir) = ensure_cached_gguf_path(&target_path)?;
    delete_cached_model_at_path(canonical_path, cache_dir)
}

fn delete_cached_model_at_path(
    canonical_path: std::path::PathBuf,
    cache_dir: std::path::PathBuf,
) -> Result<u64, crate::errors::LoadModelError> {
    let size = std::fs::metadata(&canonical_path)
        .map_err(|e| {
            LoadModelError::DownloadError(format!(
                "Failed to read metadata for {}: {e}",
                canonical_path.display()
            ))
        })?
        .len();
    if cached_model_is_loaded(&canonical_path)? {
        return Err(LoadModelError::CachedModelInUse(
            canonical_path.to_string_lossy().into_owned(),
        ));
    }

    std::fs::remove_file(&canonical_path).map_err(|source| LoadModelError::DeleteCachedModel {
        path: canonical_path.to_string_lossy().into_owned(),
        source,
    })?;

    if let Some(parent) = canonical_path.parent() {
        cleanup_empty_cache_dirs(parent.to_path_buf(), &cache_dir)?;
    }

    Ok(size)
}

pub fn get_cached_models() -> Result<Vec<CachedModel>, crate::errors::LoadModelError> {
    let cache_dir = get_cache_dir()?;
    if !cache_dir.exists() {
        return Ok(Vec::new());
    }

    let mut models = Vec::new();
    collect_cached_models(&cache_dir, &mut models)?;
    models.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(models)
}

fn collect_cached_models(
    dir: &std::path::Path,
    models: &mut Vec<CachedModel>,
) -> Result<(), crate::errors::LoadModelError> {
    for entry in std::fs::read_dir(dir).map_err(|e| {
        crate::errors::LoadModelError::DownloadError(format!(
            "Failed to read cache directory {}: {e}",
            dir.display()
        ))
    })? {
        let entry = entry.map_err(|e| {
            crate::errors::LoadModelError::DownloadError(format!(
                "Failed to read cache entry in {}: {e}",
                dir.display()
            ))
        })?;
        let path = entry.path();
        let metadata = entry.metadata().map_err(|e| {
            crate::errors::LoadModelError::DownloadError(format!(
                "Failed to read metadata for {}: {e}",
                path.display()
            ))
        })?;
        if metadata.is_dir() {
            collect_cached_models(&path, models)?;
        } else if metadata.is_file()
            && path.extension().and_then(|ext| ext.to_str()) == Some("gguf")
        {
            models.push(CachedModel {
                path: path.to_string_lossy().into_owned(),
                size: metadata.len(),
            });
        }
    }
    Ok(())
}

fn read_add_bos_metadata(model: &LlamaModel) -> Result<AddBos, InitWorkerError> {
    match model.meta_val_str("tokenizer.ggml.add_bos_token") {
        Ok(val) => match val.as_str() {
            "true" => Ok(AddBos::Always),
            "false" => Ok(AddBos::Never),
            _ => Err(InitWorkerError::InvalidAddBosData(format!(
                "Invalid boolean value for tokenizer.ggml.add_bos_token: '{}'",
                val,
            ))),
        },
        Err(_) => {
            // Defaulting to true seems to be "safer" than defaulting to false
            // the GGUF files for the gpt-oss models (at least ones that I have seen in the wild)
            // don't have the add_bos metadata field, and have a massive aneurysm if they don't
            // get the bos.
            // could it be that omitting bos generally does more damage than including it?
            warn!("tokenizer.ggml.add_bos_token not found in GGUF metadata, defaulting to true");
            Ok(AddBos::Always)
        }
    }
}

#[derive(Debug)]
pub(crate) struct Worker<'a, S> {
    pub(crate) n_past: i32,
    pub(crate) ctx: LlamaContext<'a>,
    pub(crate) big_batch: LlamaBatch<'a>,
    pub(crate) small_batch: LlamaBatch<'a>,
    pub(crate) projection_model: Option<&'a ProjectionModel>,
    pub(crate) tokenizer: Tokenizer<'a>,
    pub(crate) use_embeddings: bool,

    pub(crate) extra: S,
}

pub trait PoolingType {
    fn pooling_type(&self) -> LlamaPoolingType;
}

impl<'a, T> PoolingType for Worker<'a, T> {
    fn pooling_type(&self) -> LlamaPoolingType {
        LlamaPoolingType::Unspecified
    }
}

#[derive(Debug)]
pub enum WriteOutput {
    Token(String),
    Done(String),
}

// Common methods for any workstate type
impl<'a, T> Worker<'a, T>
where
    T: PoolingType,
{
    pub(crate) fn new_with_type(
        model: &'a Model,
        n_ctx: u32,
        use_embeddings: bool,
        extra: T,
    ) -> Result<Worker<'a, T>, InitWorkerError> {
        info!("Initializing worker");

        let projection_model = model.projection_model.as_ref();

        // Set up context parameters using available parallelism
        let ctx = {
            let n_threads = std::thread::available_parallelism()?.get() as i32;
            let ctx_plan = memory::plan_context(
                std::cmp::min(n_ctx, model.language_model.n_ctx_train()),
                projection_model.is_some(),
                memory::ModelArchitecture {
                    n_layers: model.language_model.n_layer(),
                    n_embd: model.language_model.n_embd() as u32,
                    n_head: model.language_model.n_head(),
                    n_head_kv: model.language_model.n_head_kv(),
                },
            )?;
            let n_ctx = ctx_plan.n_ctx;
            let n_ubatch = ctx_plan.n_ubatch;
            for w in &ctx_plan.warnings {
                warn!("{}", w);
            }

            let ctx_params = LlamaContextParams::default()
                .with_n_ctx(std::num::NonZero::new(n_ctx))
                .with_n_batch(n_ctx) // n_batch sets the max size of a batch (i.e. max prompt size)
                .with_n_ubatch(n_ubatch)
                .with_n_threads(n_threads)
                .with_n_threads_batch(n_threads)
                .with_embeddings(use_embeddings)
                .with_pooling_type(extra.pooling_type());

            // Create inference context and sampler
            model
                .language_model
                .new_context(&LLAMA_BACKEND, ctx_params)?
        };

        let big_batch = LlamaBatch::new(ctx.n_ctx() as usize, 1);
        let small_batch = LlamaBatch::new(1, 1);

        let add_bos = read_add_bos_metadata(&model.language_model)?;
        debug!(?add_bos, "Read add_bos from GGUF metadata:");

        let tokenizer = Tokenizer::new(&model.language_model, projection_model, add_bos);

        let state = Worker {
            n_past: 0,
            ctx,
            big_batch,
            small_batch,
            projection_model,
            extra,
            tokenizer,
            use_embeddings,
        };
        Ok(state)
    }

    #[tracing::instrument(level = "trace", skip(self))]
    pub fn reset_context(&mut self) -> &mut Self {
        self.ctx.clear_kv_cache();
        self.n_past = 0;
        self
    }

    #[tracing::instrument(level = "trace", skip(self))]
    pub fn read_string(&mut self, text: String) -> Result<&mut Self, ReadError> {
        let _gil_guard = GLOBAL_INFERENCE_LOCK.lock();
        let inference_lock_token = _gil_guard.unwrap();
        let chunks = self.tokenizer.tokenize(text, vec![])?;
        self.read_chunks(chunks, &inference_lock_token)
    }

    pub fn read_chunks(
        &mut self,
        chunks: TokenizerChunks,
        inference_lock_token: &MutexGuard<'_, GlobalInferenceLockToken>,
    ) -> Result<&mut Self, ReadError> {
        for chunk in chunks.into_iter() {
            match chunk {
                TokenizerChunk::Text(tokens, _) => {
                    self.read_text_tokens(tokens, inference_lock_token)?;
                }
                TokenizerChunk::Image(embeddings, _) | TokenizerChunk::Audio(embeddings, _) => {
                    self.read_media_embeddings(embeddings, inference_lock_token)?;
                }
            }
        }

        Ok(self)
    }

    #[tracing::instrument(level = "trace", skip(self))]
    fn read_media_embeddings(
        &mut self,
        embeddings: Rc<MtmdInputChunks>,
        inference_lock_token: &MutexGuard<'_, GlobalInferenceLockToken>,
    ) -> Result<&mut Self, ReadError> {
        let projection_model = self
            .projection_model
            .as_ref()
            .ok_or(ReadError::ProjectionModelNotInitialized)?;

        let n_tokens = embeddings.as_ref().total_tokens();
        debug!(n_tokens, "Reading media embeddings:");

        let decode_span = debug_span!("read media embeddings", n_tokens = n_tokens);
        let decode_guard = decode_span.enter();
        let n_ctx = self.ctx.n_ctx() as i32;
        self.n_past = embeddings.eval_chunks(
            &projection_model.ctx,
            &self.ctx,
            self.n_past,
            0,
            n_ctx,
            true,
        )?;

        drop(decode_guard);
        debug!(
            "Completed read media embeddings operation, n_past: {}",
            self.n_past
        );

        Ok(self)
    }

    // ---------- IMPORTANT ----------
    // Should only be used under a global inference lock
    // This is a safety meassure to prevent bugs from multiple
    // contexts with the same model. It might not be necessary
    // but assume it is.
    #[tracing::instrument(level = "trace", skip(self))]
    fn read_text_tokens(
        &mut self,
        tokens: Vec<LlamaToken>,
        inference_lock_token: &MutexGuard<'_, GlobalInferenceLockToken>,
    ) -> Result<&mut Self, ReadError> {
        let n_tokens = tokens.len();
        debug!(n_tokens, "Reading tokens:");

        // can't read nothing
        debug_assert!(!tokens.is_empty());
        // can't read more than the context size
        debug_assert!(tokens.len() < self.ctx.n_ctx() as usize);

        {
            debug!("Populating batch");
            // make batch
            self.big_batch.clear();
            let seq_ids = &[0];
            for (i, token) in (0..).zip(tokens.iter()) {
                // For LLM workers only the last token's logits are needed (sampling).
                // For encoder workers every token must be marked as an output so the
                // pooling layer has hidden states to work with — otherwise llama.cpp
                // logs "embeddings required but some input tokens were not marked as
                // outputs -> overriding" and silently flips them on for us.
                let output_logits = self.use_embeddings || i == n_tokens - 1;
                self.big_batch
                    .add(*token, self.n_past + i as i32, seq_ids, output_logits)?;
            }
        }

        // llm go brr
        let decode_span = debug_span!("read decode", n_tokens = n_tokens);
        let decode_guard = decode_span.enter();
        self.ctx.decode(&mut self.big_batch)?;
        drop(decode_guard);
        // brrr

        self.n_past += tokens.len() as i32;

        debug!("Completed read tokens operation, n_past: {}", self.n_past);

        Ok(self)
    }

    #[tracing::instrument(level = "trace", skip(self))]
    pub fn remove_all_tokens_from_index_from_ctx(
        &mut self,
        index: usize,
    ) -> Result<(), KvCacheConversionError> {
        if self.n_past <= index as i32 {
            return Ok(());
        }

        let seq_rm_success = self
            .ctx
            .clear_kv_cache_seq(Some(0), Some(index as u32), None)?;

        if seq_rm_success {
            self.n_past = index as i32;
        } else {
            // Partial sequence removal is not supported by this model's memory type
            // (e.g. hybrid models with recurrent components). Fall back to full reset.
            warn!(
                index,
                n_past = self.n_past,
                "Partial KV cache removal not supported, falling back to full context reset"
            );
            self.reset_context();
        }

        Ok(())
    }
}

/// Owns a background worker thread's resources and ensures clean shutdown.
///
/// When dropped: sets the optional stop flag, closes the message channel (causing the
/// worker's `recv()` to return `Err`), then joins the thread. This ordering guarantees
/// the worker has fully exited before any statics (e.g. `LLAMA_BACKEND`) are destroyed.
pub(crate) struct WorkerGuard<T> {
    pub(crate) msg_tx: Option<std::sync::mpsc::Sender<T>>,
    join_handle: Option<std::thread::JoinHandle<()>>,
    should_stop: Option<Arc<AtomicBool>>,
}

impl<T> WorkerGuard<T> {
    pub(crate) fn new(
        msg_tx: std::sync::mpsc::Sender<T>,
        join_handle: std::thread::JoinHandle<()>,
        should_stop: Option<Arc<AtomicBool>>,
    ) -> Self {
        Self {
            msg_tx: Some(msg_tx),
            join_handle: Some(join_handle),
            should_stop,
        }
    }

    /// Send a message to the worker. Returns false if the worker is gone.
    pub(crate) fn send(&self, msg: T) -> bool {
        self.msg_tx.as_ref().is_some_and(|tx| tx.send(msg).is_ok())
    }

    /// Signal the worker to stop mid-generation (no-op if no stop flag).
    pub(crate) fn stop(&self) {
        if let Some(ref flag) = self.should_stop {
            flag.store(true, Ordering::Relaxed);
        }
    }
}

impl<T> Drop for WorkerGuard<T> {
    fn drop(&mut self) {
        if let Some(ref stop) = self.should_stop {
            stop.store(true, Ordering::Relaxed);
        }
        drop(self.msg_tx.take());
        if let Some(handle) = self.join_handle.take() {
            if let Err(e) = handle.join() {
                error!("Worker panicked: {:?}", e);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_root(name: &str) -> std::path::PathBuf {
        std::env::temp_dir().join(format!(
            "quaynor-{name}-{}-{:x}",
            std::process::id(),
            rand::random::<u64>()
        ))
    }

    #[test]
    fn delete_cached_model_at_path_removes_file_and_empty_parent_dirs() {
        let root = test_root("delete-cached-model");
        let cache_dir = root.join("cache");
        let model_path = cache_dir.join("owner").join("repo").join("model.gguf");
        std::fs::create_dir_all(model_path.parent().unwrap()).unwrap();
        std::fs::write(&model_path, [1, 2, 3, 4]).unwrap();

        let (canonical_path, canonical_cache_dir) =
            ensure_cached_gguf_path_in_cache(&model_path, &cache_dir).unwrap();
        let deleted_bytes =
            delete_cached_model_at_path(canonical_path, canonical_cache_dir).unwrap();

        assert_eq!(deleted_bytes, 4);
        assert!(!model_path.exists());
        assert!(!cache_dir.join("owner").exists());
        assert!(cache_dir.exists());

        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn ensure_cached_gguf_path_rejects_paths_outside_cache() {
        let root = test_root("outside-cache");
        let cache_dir = root.join("cache");
        let outside_path = root.join("outside.gguf");
        std::fs::create_dir_all(&cache_dir).unwrap();
        std::fs::write(&outside_path, [1]).unwrap();

        let error = ensure_cached_gguf_path_in_cache(&outside_path, &cache_dir).unwrap_err();
        assert!(matches!(error, LoadModelError::ModelOutsideCache(_)));

        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn ensure_cached_gguf_path_rejects_non_gguf_files() {
        let root = test_root("non-gguf");
        let cache_dir = root.join("cache");
        let model_path = cache_dir.join("owner").join("repo").join("model.bin");
        std::fs::create_dir_all(model_path.parent().unwrap()).unwrap();
        std::fs::write(&model_path, [1]).unwrap();

        let error = ensure_cached_gguf_path_in_cache(&model_path, &cache_dir).unwrap_err();
        assert!(matches!(error, LoadModelError::CachedModelNotGguf(_)));

        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn delete_cached_model_at_path_rejects_loaded_models() {
        let root = test_root("loaded-model");
        let cache_dir = root.join("cache");
        let model_path = cache_dir.join("owner").join("repo").join("model.gguf");
        std::fs::create_dir_all(model_path.parent().unwrap()).unwrap();
        std::fs::write(&model_path, [1]).unwrap();

        let (canonical_path, canonical_cache_dir) =
            ensure_cached_gguf_path_in_cache(&model_path, &cache_dir).unwrap();
        register_loaded_cache_models(&[canonical_path.clone()]).unwrap();

        let error =
            delete_cached_model_at_path(canonical_path.clone(), canonical_cache_dir).unwrap_err();
        assert!(matches!(error, LoadModelError::CachedModelInUse(_)));
        assert!(model_path.exists());

        LOADED_CACHE_MODELS
            .lock()
            .unwrap()
            .remove(&canonical_path)
            .unwrap();
        std::fs::remove_dir_all(root).unwrap();
    }
}
