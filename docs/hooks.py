"""MkDocs hooks: llms.txt, sitemap.xml, and llms.txt-style markdown mirrors (index.html.md)."""

from __future__ import annotations

import shutil
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Any

# Optional short blurbs for llms.txt links (path keys match nav paths without leading ./)
_BLURBS: dict[str, str] = {
    "index.md": "Project overview and local LLM inference APIs.",
    "llm-basics.md": "Core LLM concepts needed to use Quaynor effectively.",
    "model-selection.md": "Choose and run GGUF models with the library.",
    "python/index.md": "Install and configure the Python bindings.",
    "python/chat.md": "Synchronous and chat session APIs in Python.",
    "python/tool-calling.md": "Grammar-based tool calling from Python.",
    "python/vision.md": "Vision and audio modalities in Python.",
    "python/sampling.md": "Temperature, top-p, and sampler settings.",
    "python/streaming-and-async-api.md": "Streaming tokens and async chat.",
    "python/embeddings-and-rag.md": "Embeddings and retrieval workflows.",
    "python/logging-and-troubleshooting.md": "Logging and debugging.",
    "react-native/index.md": "Install and use the React Native package.",
    "react-native/chat.md": "Chat APIs on React Native.",
    "react-native/tool-calling.md": "Tool calling from React Native.",
    "react-native/vision.md": "Vision inputs on React Native.",
    "react-native/sampling.md": "Sampling configuration.",
    "react-native/embeddings-and-rag.md": "Embeddings and RAG.",
    "flutter/index.md": "Flutter app integration and FFI setup.",
    "flutter/chat.md": "Chat API from Flutter.",
    "flutter/tool-calling.md": "Tool calling in Flutter.",
    "flutter/vision.md": "Vision and audio in Flutter.",
    "flutter/sampling.md": "Sampler options.",
    "flutter/embeddings-and-rag.md": "Embeddings and RAG in Flutter.",
}


def _norm_nav_path(raw: str) -> str:
    return raw.removeprefix("./").lstrip("/")


def _walk_nav(
    nav: list[Any], section: str | None = None
) -> list[tuple[str | None, str, str]]:
    """Yield (section_title, page_title, doc_path) from MkDocs nav."""
    out: list[tuple[str | None, str, str]] = []
    for item in nav:
        if not isinstance(item, dict):
            continue
        for title, val in item.items():
            if isinstance(val, str):
                out.append((section, title, _norm_nav_path(val)))
            elif isinstance(val, list):
                out.extend(_walk_nav(val, title))
    return out


def _mirror_relpath(doc_path: str) -> str:
    """Path under site_dir for the llms.txt companion file (…/index.html.md)."""
    if doc_path == "index.md":
        return "index.html.md"
    if doc_path.endswith("/index.md"):
        folder = doc_path[: -len("/index.md")]
        return f"{folder}/index.html.md"
    if doc_path.endswith(".md"):
        stem = doc_path[: -len(".md")]
        return f"{stem}/index.html.md"
    raise ValueError(f"unsupported doc path: {doc_path}")


def _source_md_for_index(index_html: Path, site_dir: Path) -> Path | None:
    d = index_html.parent
    rel_site = d.relative_to(site_dir)
    cand = d / "index.md"
    if cand.exists():
        return cand
    name = rel_site.as_posix()
    if name == ".":
        return site_dir / "index.md" if (site_dir / "index.md").exists() else None
    leaf = rel_site.name
    sibling = d.parent / f"{leaf}.md"
    if sibling.exists():
        return sibling
    return None


def _pretty_url(site_url: str, index_html: Path, site_dir: Path) -> str:
    rel = index_html.parent.relative_to(site_dir)
    base = site_url.rstrip("/")
    if rel == Path("."):
        return f"{base}/"
    return f"{base}/{rel.as_posix().strip('/')}/"


def _sitemap_sort_key(index_html: Path, site_dir: Path) -> tuple:
    rel = index_html.parent.relative_to(site_dir)
    if rel == Path("."):
        return (0,)
    return (1,) + tuple(rel.parts)


def on_post_build(config: Any, **kwargs: Any) -> None:
    site_dir = Path(config["site_dir"]).resolve()
    site_url: str = (config.get("site_url") or "").strip() or "https://www.quaynor.site/"
    nav: list[Any] = config.get("nav") or []

    # 1) llms.txt companion files next to each HTML page (index.html.md)
    for index_html in site_dir.rglob("index.html"):
        if "pygments" in index_html.parts:
            continue
        src = _source_md_for_index(index_html, site_dir)
        if src is None or not src.is_file():
            continue
        dest = index_html.parent / "index.html.md"
        shutil.copyfile(src, dest)

    # 2) sitemap.xml (canonical HTML URLs)
    urlset = ET.Element(
        "urlset", xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
    )
    for index_html in sorted(
        site_dir.rglob("index.html"),
        key=lambda p: _sitemap_sort_key(p, site_dir),
    ):
        if "pygments" in index_html.parts:
            continue
        loc = _pretty_url(site_url, index_html, site_dir)
        url_el = ET.SubElement(urlset, "url")
        ET.SubElement(url_el, "loc").text = loc

    sitemap_path = site_dir / "sitemap.xml"
    tree = ET.ElementTree(urlset)
    ET.indent(tree, space="  ")
    tree.write(sitemap_path, encoding="utf-8", xml_declaration=True)

    robots = (
        "User-agent: *\n"
        "Allow: /\n\n"
        f"Sitemap: {site_url.rstrip('/')}/sitemap.xml\n"
    )
    (site_dir / "robots.txt").write_text(robots, encoding="utf-8")

    # 3) llms.txt (curated markdown links; mirrors follow /index.html.md convention)
    base = site_url.rstrip("/")

    grouped: dict[str | None, list[tuple[str, str]]] = defaultdict(list)
    for section, title, doc_path in _walk_nav(nav):
        grouped[section].append((title, doc_path))

    nav_section_order: list[str | None] = []
    for section, _, _ in _walk_nav(nav):
        if section not in nav_section_order:
            nav_section_order.append(section)

    lines = [
        "# Quaynor",
        "",
        "> Local, offline LLM inference with streaming, tool calling, and embeddings.",
        "> Python, Flutter, and React Native bindings over Llama.cpp.",
        "",
    ]

    for section in nav_section_order:
        heading = "Docs" if section is None else section
        lines.append(f"## {heading}")
        lines.append("")
        for title, doc_path in grouped[section]:
            mirror = _mirror_relpath(doc_path)
            md_url = f"{base}/{mirror}"
            blurb = _BLURBS.get(doc_path, f"{title} — Quaynor documentation.")
            lines.append(f"- [{title}]({md_url}): {blurb}")
        lines.append("")

    lines.extend(
        [
            "## Optional",
            "",
            f"- [{getattr(config, 'repo_name', None) or 'Source'}]({getattr(config, 'repo_url', None) or 'https://github.com/iBz-04/quaynor'}): Quaynor source and issues.",
            "",
            "## Sitemaps",
            "",
            f"- [sitemap.xml]({base}/sitemap.xml): Documentation URLs for search engines.",
            "",
        ]
    )

    (site_dir / "llms.txt").write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")
