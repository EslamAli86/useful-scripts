# useful-scripts

Reusable Python/Bash utilities for research workflows, HPC/Slurm tasks (ARC), web scraping, and day-to-day automation.

This repo is intentionally **practical**: small scripts that solve real problems, with clear usage examples and minimal dependencies.

## What’s inside

| Directory | What you’ll find |
|---|---|
| `ARC/` | Utilities for ARC/HPC workflows (Slurm, GPUs, monitoring, helper scripts). |
| `research/` *(planned)* | Research workflow helpers (data prep, experiments, evaluation, reproducible runs). |
| `scraping/` *(planned)* | Scraping + parsing scripts with reliability helpers (rate limits, retries, resume support). |
| `common/` *(planned)* | Shared helpers used across scripts (logging, CLI args, IO, small utilities). |

Each directory should include its own `README.md` with requirements and runnable examples.

## Featured scripts

- `ARC/gpu_dashboard.sh` — terminal dashboard for Slurm GPU availability + job activity (partition summary, per-user usage, node view).

## Getting started

```bash
git clone https://github.com/EslamAli86/useful-scripts.git
cd useful-scripts
```

Most scripts are self-contained. If a script requires a specific environment (e.g., Python packages), it will be documented in the nearest `README.md`.

## Notes on responsible use

- **No secrets:** keep tokens/keys in `.env` (ignored) and provide `.env.example` templates when needed.
- **Scraping:** use responsibly (respect site terms/robots where applicable, rate-limit requests, avoid collecting sensitive data).
- **ARC:** scripts here are meant to be generic and do not include proprietary/internal ARC content.

## License

MIT — see `LICENSE`.
