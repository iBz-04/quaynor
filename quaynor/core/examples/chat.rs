//! Minimal streaming chat example.
//!
//! Run with:
//!   cargo run --example chat -- /path/to/model.gguf
//!   cargo run --example chat -- hf://bartowski/Qwen_Qwen3-0.6B-GGUF/Qwen_Qwen3-0.6B-Q4_K_M.gguf

use quaynor::chat::ChatBuilder;
use quaynor::llm::get_model;
use std::io::Write;
use std::sync::Arc;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let model_path = std::env::args()
        .nth(1)
        .ok_or("usage: chat <model path, URL, or hf://owner/repo/file.gguf>")?;

    let model = Arc::new(get_model(&model_path, true, None)?);

    let chat = ChatBuilder::new(model)
        .with_context_size(4096)
        .with_system_prompt(Some("You are a helpful assistant."))
        .build();

    let mut stream = chat.ask("Is a zebra black or white?");
    while let Some(token) = stream.next_token() {
        print!("{token}");
        std::io::stdout().flush()?;
    }
    println!();
    Ok(())
}
