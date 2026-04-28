import os
from pathlib import Path

MODEL_SYMLINK = Path("./model.gguf")
EMBEDDING_SYMLINK = Path("./embedding-model.gguf")
RERANKER_SYMLINK = Path("./reranker-model.gguf")
VISION_MODEL_SYMLINK = Path("./vision-model.gguf")
PROJECTION_MODEL_SYMLINK = Path("./projection_model.gguf")
DOG_IMAGE_SYMLINK = Path("./dog.png")
PENGUIN_IMAGE_SYMLINK = Path("./penguin.png")
SOUND_SYMLINK = Path("./sound.mp3")

# Cache symlinks for huggingface: paths used in doc examples.
# These let doctests use huggingface: paths without network access,
# by placing symlinks where the download cache would expect the files.
HF_CACHE_DIR = Path(
    os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache"))
) / "quaynor" / "models"

HF_CACHE_SYMLINKS: list[Path] = []


def _setup_hf_cache_symlink(owner: str, repo: str, filename: str, target: str):
    """Create a symlink in the huggingface download cache directory."""
    cache_path = HF_CACHE_DIR / owner / repo / filename
    if not cache_path.exists():
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        os.symlink(target, cache_path)
    HF_CACHE_SYMLINKS.append(cache_path)


def pytest_markdown_docs_globals():
    import quaynor

    # make symlink to TEST_MODEL, so we can use "./model.gguf" literal in docs
    model_path = os.environ.get("TEST_MODEL")
    assert isinstance(model_path, str)

    if not MODEL_SYMLINK.exists():
        os.symlink(model_path, MODEL_SYMLINK)

    # populate the download cache so huggingface: paths in docs work offline
    _setup_hf_cache_symlink(
        "bartowski", "Qwen_Qwen3-0.6B-GGUF", "Qwen_Qwen3-0.6B-Q4_K_M.gguf",
        model_path,
    )

    # make symlink to TEST_EMBEDDING_MODEL, so we can use "./embedding-model.gguf" literal in docs
    embedding_model_path = os.environ.get("TEST_EMBEDDINGS_MODEL")
    if embedding_model_path and not EMBEDDING_SYMLINK.exists():
        os.symlink(embedding_model_path, EMBEDDING_SYMLINK)

    # make symlink to TEST_RERANKER_MODEL, so we can use "./reranker-model.gguf" literal in docs
    reranker_model_path = os.environ.get("TEST_CROSSENCODER_MODEL")
    if reranker_model_path and not RERANKER_SYMLINK.exists():
        os.symlink(reranker_model_path, RERANKER_SYMLINK)

    # make symlink to TEST_VISION_MODEL, so we can use "./vision-model.gguf" literal in docs
    vision_model_path = os.environ.get("TEST_VISION_MODEL")
    if vision_model_path and not VISION_MODEL_SYMLINK.exists():
        os.symlink(vision_model_path, VISION_MODEL_SYMLINK)

    # make symlink to TEST_MMPROJ_MODEL, so we can use "./projection_model.gguf" literal in docs
    mmproj_path = os.environ.get("TEST_MMPROJ_MODEL")
    if mmproj_path and not PROJECTION_MODEL_SYMLINK.exists():
        os.symlink(mmproj_path, PROJECTION_MODEL_SYMLINK)

    # make symlinks for test images used in vision docs
    tests_img_dir = Path(__file__).parent.parent / "quaynor" / "python" / "tests" / "img"
    if (tests_img_dir / "dog.png").exists() and not DOG_IMAGE_SYMLINK.exists():
        os.symlink(tests_img_dir / "dog.png", DOG_IMAGE_SYMLINK)
    if (tests_img_dir / "penguin.png").exists() and not PENGUIN_IMAGE_SYMLINK.exists():
        os.symlink(tests_img_dir / "penguin.png", PENGUIN_IMAGE_SYMLINK)

    # make symlink for test audio used in vision docs
    tests_audio_dir = Path(__file__).parent.parent / "quaynor" / "python" / "tests" / "audio"
    if (tests_audio_dir / "sound.mp3").exists() and not SOUND_SYMLINK.exists():
        os.symlink(tests_audio_dir / "sound.mp3", SOUND_SYMLINK)

    return {
        "quaynor": quaynor,
        "Chat": quaynor.Chat,
        "Model": quaynor.Model,
        "SamplerPresets": quaynor.SamplerPresets,
        "SamplerConfig": quaynor.SamplerConfig,
        "Encoder": quaynor.Encoder,
        "EncoderAsync": quaynor.EncoderAsync,
        "CrossEncoder": quaynor.CrossEncoder,
        "CrossEncoderAsync": quaynor.CrossEncoderAsync,
        "cosine_similarity": quaynor.cosine_similarity,
        "tool": quaynor.tool,
        "Text": quaynor.Text,
        "Image": quaynor.Image,
        "Audio": quaynor.Audio,
        "Prompt": quaynor.Prompt,
    }


def pytest_sessionfinish(session, exitstatus):
    """Clean up symlinks after test session."""
    for symlink in [
        MODEL_SYMLINK,
        EMBEDDING_SYMLINK,
        RERANKER_SYMLINK,
        VISION_MODEL_SYMLINK,
        PROJECTION_MODEL_SYMLINK,
        DOG_IMAGE_SYMLINK,
        PENGUIN_IMAGE_SYMLINK,
        SOUND_SYMLINK,
        *HF_CACHE_SYMLINKS,
    ]:
        if os.path.islink(symlink):
            os.unlink(symlink)
