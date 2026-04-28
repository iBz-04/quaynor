# Publishing `quaynor` on PyPI

## Manual publish (your machine only)

You do **not** need CI. From **`quaynor/python`** everything can be driven with `maturin` and a **PyPI API token**.

### 1. Create a PyPI API token

- **Production:** https://pypi.org/manage/account/token/ → create a token (project-scoped token for `quaynor` is fine).
- Starts with **`pypi-`** (keep it secret; never commit it).

(Optional **dry run** on TestPyPI — separate account at https://test.pypi.org/ and a token from there.)

### 2. Build and upload

```bash
cd quaynor/python

uv run pytest                                   # optional but recommended

export MATURIN_PYPI_TOKEN='pypi-xxxxxREPLACE'   # or paste once interactively instead of exporting

uvx maturin publish \
  --non-interactive \
  --release
```

`publish` rebuilds optimized wheels + source dist and uploads them. Omit `--release` only if you deliberately want debug builds (do not publish those to PyPI).

**Safer credential handling:** omit `export`; run `unset MATURIN_PYPI_TOKEN` afterward; rely on `-p`/`MATURIN_PASSWORD` only if you prefer, but exports in shell profiles are risky.

### 3. Optionally try TestPyPI first

Same command, plus:

```bash
export MATURIN_REPOSITORY=testpypi
export MATURIN_PYPI_TOKEN='pypi-xxxx-from-testpypi'
uvx maturin publish --non-interactive --release
```

Unset `MATURIN_REPOSITORY` when publishing to production.

---

## Before you publish (checklist reference)

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

## Publish (alternate: username/password)

If you prefer not to use `MATURIN_PYPI_TOKEN`:

```bash
uvx maturin publish \
  --non-interactive \
  --username __token__ \
  --password "pypi-xxxxxREPLACE"
```

## Tag after release (recommended)

```bash
git tag -a python-v1.2.3 -m "quaynor PyPI v1.2.3"
git push origin python-v1.2.3
```

Use whatever tag naming matches your repo’s convention (`v…` vs `python-v…`).

## Wheels note

Rust native extensions publish **per-platform** wheels from machines or CI matrices that match your users (linux/macos/windows, appropriate CPU arches). ABI3 reduces the Python version matrix (`abi3`/CPython ≥ minimum). Add Linux CI builders if Linux users matter for your roadmap.
