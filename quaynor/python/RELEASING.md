# Publishing `quaynor` on PyPI

## Before you publish

1. **Version** — Bump the **same version** in both:

   - `pyproject.toml` → `[project].version`
   - `Cargo.toml` → `[package].version`

2. **Quality gate** — From this directory (`quaynor/python`):

   ```bash
   uv run pytest
   ```

3. **Smoke build** — Produces ABI3 wheels locally:

   ```bash
   uvx maturin build --release
   uvx maturin sdist
   ```

4. **Dry run metadata** (optional) — Pass the `.whl` and `.tar.gz` paths that `maturin build` / `maturin sdist` prints:

   ```bash
   uvx twine check path/to/quaynor-*.whl path/to/quaynor-*.tar.gz
   ```

## Publish

1. **[PyPI](https://pypi.org)** — Create or use an API token with upload scope (`pypi.org` legacy token or Trusted Publisher).

2. **Upload**:

   ```bash
   uvx maturin publish \
     --username __token__ \
     --password "pypi-YOURTOKEN"
   ```

   Prefer **Trusted Publishing** from CI (OIDC to PyPI) for routine releases instead of embedding tokens locally.

3. **Tag the repo** (optional but recommended):

   ```bash
   git tag -a python-v1.2.3 -m "quaynor PyPI v1.2.3"
   git push origin python-v1.2.3
   ```

   Use whatever tag naming matches your repo’s convention (`v…` vs `python-v…`).

## Wheels note

Rust native extensions publish **per-platform** wheels from machines or CI matrices that match your users (linux/macos/windows, appropriate CPU arches). ABI3 reduces the Python version matrix (`abi3`/CPython ≥ minimum). Add Linux CI builders if Linux users matter for your roadmap.
