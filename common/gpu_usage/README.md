# GPU Process Report

A simple Bash script that uses `nvidia-smi` and standard Linux tools to generate a report showing:

- which NVIDIA GPUs are present
- current GPU utilization and memory usage
- which processes are using each GPU
- the owner of each process
- useful process details such as CPU usage, RSS memory, elapsed time, start time, and command
- a per-user GPU memory summary

## Requirements

- bash
- nvidia-smi
- ps
- awk
- sed
- sort
- date
- hostname
- tput

## Usage

Make the script executable:

```bash
chmod +x gpu_usage.sh
```

Run it:

```bash
./gpu_usage.sh
```

Disable colors if needed:

```bash
NO_COLOR=1 ./gpu_usage.sh
```

Live view with watch:

```bash
watch -c -n 5 ./gpu_usage.sh
```
