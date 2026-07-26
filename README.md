# Vexriscv Debug Support

A catalogue of Vexriscv debug tasks — JTAG/SWD DTM & DMI, debug module, CSRs, triggers, system integration, and verification.

Published site: https://disdi.github.io/standard-debug-vexriscv/

## Prerequisites

Install [mdBook](https://rust-lang.github.io/mdBook/):

```sh
# via cargo (requires Rust toolchain)
cargo install mdbook

# or download a release binary from
# https://github.com/rust-lang/mdBook/releases
```

Confirm:

```sh
mdbook --version
```

## Build

From the repository root:

```sh
mdbook build
```

Output is written to `book/`. Open `book/index.html` in a browser, or serve it with any static file server.

For a live-reload preview while editing:

```sh
mdbook serve --open
```

This builds the book and serves it at http://localhost:3000.

## Test

mdBook runs rustdoc on fenced code blocks (untagged or `rust` blocks). Non-Rust samples must use an explicit language tag such as `text`, `sh`, or `gdb`.

```sh
mdbook test
```

CI runs `mdbook build` then `mdbook test` on every pull request and every push to `main`.

## Deploy

Deployment is automatic via GitHub Actions (`.github/workflows/ci.yaml`):

| Event | What runs |
| --- | --- |
| Pull request | Build + test |
| Push to `main` | Build + test + deploy to `gh-pages` |

The deploy step publishes `./book` to the `gh-pages` branch with [`peaceiris/actions-gh-pages`](https://github.com/peaceiris/actions-gh-pages). The site is served at the path configured in `book.toml`:

```toml
[output.html]
site-url = "https://disdi.github.io/standard-debug-vexriscv/"
```

### Manual deploy (optional)

If you need to publish from a local machine:

```sh
mdbook build
# publish contents of book/ to the gh-pages branch
# e.g. with the gh-pages CLI, or by pushing book/ to gh-pages
```

Prefer the CI path on `main` so PR checks stay the source of truth.

## Repository layout

| Path | Role |
| --- | --- |
| `book.toml` | mdBook config (title, HTML output, site URL) |
| `src/` | Markdown chapters (`SUMMARY.md` is the table of contents) |
| `src/images/` | Figures used by the chapters |
| `.github/workflows/ci.yaml` | Build, test, and GitHub Pages deploy |
| `specification/` | Reference PDFs (not part of the book build) |

## License

See [LICENSE](LICENSE).
