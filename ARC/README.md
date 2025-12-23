# ARC Utilities

This directory contains scripts and helpers I use for ARC/HPC workflows.

## My ARC roles and contributions

I work with **Advanced Research Computing (ARC)** at Virginia Tech, supporting researchers and students who run computational workloads on ARC clusters.

**Responsibilities**
- Provide day-to-day HPC user support by responding to helpdesk tickets and troubleshooting issues with batch jobs, Slurm usage, GPU access, storage, and software environments.
- Help users install, configure, and debug scientific/ML software stacks (conda/pip, CUDA tooling, MPI-dependent software, etc.).
- Develop and maintain small automation utilities (shell/Python) that reduce manual work for both users and support staff.
- Build and support **containerized workflows** (e.g., Docker/Singularity/Apptainer) to improve reproducibility and portability across ARC systems.
- Contribute to internal documentation and “how-to” guides to help users self-serve common tasks.

**Selected achievements**
- Assisted **5,400+** ARC users with running computational jobs and resolving system/software issues (Aug 2019–present).
- Developed containerized solutions and reusable scripts that streamline environment setup and reduce support overhead.
- Produced practical documentation and templates that help users adopt best practices for Slurm, GPUs, and reproducible environments.

---

## Slurm GPU Dashboard

`gpu_dashboard.sh` is a terminal-friendly dashboard for monitoring GPU availability and job activity in a Slurm **GPU partition** on ARC (and similar Slurm clusters).

It summarizes:
- GPU type + total/used/free GPUs in the partition
- Running & pending job counts
- Per-user GPU usage (running jobs)
- Pending jobs per user (count + GPUs requested)
- Per-job GPU usage (running + pending)
- Node-level views, including nodes with free GPUs (using `AllocTRES`)

### Requirements
- Slurm CLI tools available: `sinfo`, `squeue`, `scontrol`
- Optional (for nicer output): a real terminal (TTY) with `tput` available for colors

### Usage

```bash
./gpu_dashboard.sh [partition] [--user USER] [--brief]
```

- `partition` (optional): Slurm partition name (overrides the script default)
- `--user USER` or `--user=USER`: filter job/accounting sections to a specific user (partition totals are still shown)
- `--brief`: stop after the summary + per-user sections (skips per-job and node tables)

### Examples

```bash
# Use the default partition configured inside the script
./gpu_dashboard.sh

# Specify a partition
./gpu_dashboard.sh a100_normal_q

# Filter to a single user
./gpu_dashboard.sh --user ehussein

# Partition + user filter + brief mode
./gpu_dashboard.sh h200_normal_q --user=ehussein --brief
```

### Notes
- The script infers GPU type and counts from Slurm GRES strings (e.g., `gpu:h200:8`).
- If your cluster uses different GRES conventions, you may need small parsing tweaks.
- Output is colorized when running in a TTY; otherwise it prints plain text.

### Install

```bash
chmod +x gpu_dashboard.sh
```
