#!/usr/bin/env bash

# GPU dashboard for Slurm partitions on ARC
# Usage examples:
#   gpu_dashboard.sh
#   gpu_dashboard.sh a100_normal_q
#   gpu_dashboard.sh --user ehussein
#   gpu_dashboard.sh a100_normal_q --user ehussein --brief

PARTITION="h200_normal_q"
USER_FILTER=""
BRIEF=0

########################
# Parse CLI arguments  #
########################
while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)
      USER_FILTER="$2"
      shift 2
      ;;
    --user=*)
      USER_FILTER="${1#--user=}"
      shift
      ;;
    --brief)
      BRIEF=1
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      echo "Usage: $0 [partition] [--user USER] [--brief]" >&2
      exit 1
      ;;
    *)
      PARTITION="$1"
      shift
      ;;
  esac
done

if [ -n "${USER_FILTER}" ]; then
  SQ_USER_OP="-u ${USER_FILTER}"
else
  SQ_USER_OP=""
fi

#################################
# Formatting (bold + colors)    #
#################################
if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
  BOLD=$(tput bold)
  DIM=$(tput dim)
  RESET=$(tput sgr0)
  RED="\033[31m"
  GREEN="\033[32m"
  YELLOW="\033[33m"
else
  BOLD=""
  DIM=""
  RESET=""
  RED=""
  GREEN=""
  YELLOW=""
fi

# Colorize node state (idle/mixed/allocated/etc.)
color_state() {
  local state="$1"
  case "$state" in
    idle)
      printf "%b%s%b" "${GREEN}" "${state}" "${RESET}"
      ;;
    mix*|mixed)
      printf "%b%s%b" "${YELLOW}" "${state}" "${RESET}"
      ;;
    alloc*|allocated|drain*|down)
      printf "%b%s%b" "${RED}" "${state}" "${RESET}"
      ;;
    *)
      printf "%s" "${state}"
      ;;
  esac
}

# Colorize FREE GPUs (0=red, low=yellow, enough=green)
color_free() {
  local free="$1"
  local tot="$2"

  # If we don't know totals, just print plain
  if [ -z "${tot}" ] || [ "${tot}" -le 0 ]; then
    printf "%s" "${free}"
    return
  fi

  if [ "${free}" -le 0 ]; then
    printf "%b%s%b" "${RED}" "${free}" "${RESET}"
  else
    # "Low" = <= 25% of total GPUs
    local threshold=$(( tot / 4 ))
    if [ "${threshold}" -lt 1 ]; then
      threshold=1
    fi
    if [ "${free}" -le "${threshold}" ]; then
      printf "%b%s%b" "${YELLOW}" "${free}" "${RESET}"
    else
      printf "%b%s%b" "${GREEN}" "${free}" "${RESET}"
    fi
  fi
}

################
# Header block #
################
echo "${BOLD}==================== GPU PARTITION DASHBOARD ====================${RESET}"
echo "${BOLD}Partition:${RESET} ${PARTITION}"
if [ -n "${USER_FILTER}" ]; then
  echo "${BOLD}User filter:${RESET} ${USER_FILTER}"
else
  echo "${BOLD}User filter:${RESET} (all users)"
fi
if [ "${BRIEF}" -eq 1 ]; then
  echo "${BOLD}Mode:${RESET} brief"
fi
echo "${BOLD}Time:${RESET} $(date)"
echo

#########################################
# 1) Total GPUs + GPU type from sinfo   #
#########################################
total_gpus=$(sinfo -h -p "${PARTITION}" -o "%D %G" 2>/dev/null | \
  awk '
    {
      nodes = $1
      gres  = $2
      gpus_per_node = 0

      n = split(gres, a, ",")
      for (i = 1; i <= n; i++) {
        if (a[i] ~ /gpu:/) {
          m = split(a[i], g, ":")
          gpus_per_node = g[m]   # last field = count
        }
      }
      total += nodes * gpus_per_node
    }
    END {
      if (total == "") total = 0
      print total
    }')

gpu_type=$(sinfo -h -p "${PARTITION}" -o "%G" 2>/dev/null | \
  awk '
    NR == 1 {
      gres = $1
      n = split(gres, a, ",")
      for (i = 1; i <= n; i++) {
        if (a[i] ~ /gpu:/) {
          m = split(a[i], g, ":")
          if (m >= 2) {
            # format: gpu:h200:8 -> type = h200
            print g[2]
          } else {
            print "gpu"
          }
          exit
        }
      }
    }
  ')

[ -z "${gpu_type}" ] && gpu_type="unknown"

##########################################################
# 2) GPUs in use (running jobs, optional user filter)    #
##########################################################
used_gpus=$(squeue -h -p "${PARTITION}" ${SQ_USER_OP} -t R -o "%b" 2>/dev/null | \
  awk '
    {
      line = $0
      n = split(line, a, ",")
      for (i = 1; i <= n; i++) {
        if (a[i] ~ /gpu:/) {
          m = split(a[i], g, ":")
          cnt = g[m]
          sum += cnt
        }
      }
    }
    END {
      if (sum == "") sum = 0
      print sum
    }')

##########################################################
# 3) Job counts (running + pending, optional user)       #
##########################################################
running_jobs=$(squeue -h -p "${PARTITION}" ${SQ_USER_OP} -t R 2>/dev/null | wc -l)
pending_jobs=$(squeue -h -p "${PARTITION}" ${SQ_USER_OP} -t PD 2>/dev/null | wc -l)

###############################
# 4) Derived summary metrics  #
###############################
[ -z "${total_gpus}" ] && total_gpus=0
[ -z "${used_gpus}" ] && used_gpus=0

if [ "${total_gpus}" -gt 0 ]; then
  free_gpus=$(( total_gpus - used_gpus ))
  if [ "${free_gpus}" -lt 0 ]; then free_gpus=0; fi
  usage_pct=$(awk -v u="${used_gpus}" -v t="${total_gpus}" 'BEGIN {
    if (t == 0) { print 0; exit }
    printf "%.1f", (u / t) * 100
  }')
else
  free_gpus=0
  usage_pct=0
fi

####################
# 5) Summary block #
####################
echo "${BOLD}Summary:${RESET}"
printf "  %-28s %s\n" "GPU type (from GRES):" "${gpu_type}"
printf "  %-28s %s\n" "Total GPUs in partition:" "${total_gpus}"

if [ -n "${USER_FILTER}" ]; then
  printf "  %-28s %s\n" "GPUs in use (this user):" "${used_gpus}"
else
  printf "  %-28s %s\n" "GPUs in use (running jobs):" "${used_gpus}"
fi

printf "  %-28s %s\n" "GPUs free (partition-wide):" "${free_gpus}"
printf "  %-28s %s%%\n" "GPU usage (vs total):" "${usage_pct}"
echo
printf "  %-28s %s\n" "Running jobs:" "${running_jobs}"
printf "  %-28s %s\n" "Pending jobs:" "${pending_jobs}"
echo

##########################################################
# 6) Per-user GPU usage (running jobs, optional user)    #
##########################################################
if [ -n "${USER_FILTER}" ]; then
  echo "${BOLD}Per-user GPU usage (running jobs, user = ${USER_FILTER}):${RESET}"
else
  echo "${BOLD}Per-user GPU usage (running jobs in ${PARTITION}):${RESET}"
fi

squeue -h -p "${PARTITION}" ${SQ_USER_OP} -t R -o "%u %b" 2>/dev/null | \
awk '
  {
    user = $1
    gres = $2
    n = split(gres, a, ",")
    for (i = 1; i <= n; i++) {
      if (a[i] ~ /gpu:/) {
        m = split(a[i], g, ":")
        cnt = g[m]
        usage[user] += cnt
      }
    }
  }
  END {
    if (length(usage) == 0) {
      print "  (no running GPU jobs)"
      exit
    }
    for (u in usage) {
      printf "  %-16s %4d GPUs\n", u, usage[u]
    }
  }' | sort -k2 -nr
echo

##################################################################
# 7) Pending jobs per user (count + total GPUs requested)        #
##################################################################
if [ -n "${USER_FILTER}" ]; then
  echo "${BOLD}Pending jobs per user (user = ${USER_FILTER}, ${PARTITION}):${RESET}"
else
  echo "${BOLD}Pending jobs per user in ${PARTITION}:${RESET}"
fi

squeue -h -p "${PARTITION}" ${SQ_USER_OP} -t PD -o "%u %b" 2>/dev/null | \
awk '
  {
    user = $1
    gres = $2
    pending_jobs[user]++

    n = split(gres, a, ",")
    for (i = 1; i <= n; i++) {
      if (a[i] ~ /gpu:/) {
        m = split(a[i], g, ":")
        cnt = g[m]
        pending_gpus[user] += cnt
      }
    }
  }
  END {
    if (length(pending_jobs) == 0) {
      print "  (no pending jobs)"
      exit
    }

    printf "  %-16s %8s %10s\n", "USER", "PENDING", "GPUs"
    printf "  %-16s %8s %10s\n", "----", "-------", "----"

    for (u in pending_jobs) {
      printf "  %-16s %8d %10d\n", u, pending_jobs[u], pending_gpus[u] + 0
    }
  }'
echo

# If brief mode, stop before per-job + node sections
if [ "${BRIEF}" -eq 1 ]; then
  echo "${DIM}(Partition: ${PARTITION} | User filter: ${USER_FILTER:-all users} | mode: brief)${RESET}"
  exit 0
fi

##########################################################
# 8) Per-job GPU usage (running + pending jobs)          #
##########################################################
if [ -n "${USER_FILTER}" ]; then
  echo "${BOLD}Per-job GPU usage (R + PD, user = ${USER_FILTER}, ${PARTITION}):${RESET}"
else
  echo "${BOLD}Per-job GPU usage (R + PD in ${PARTITION}):${RESET}"
fi

printf "%-10s %-14s %-8s %-6s %-20s\n" "JOBID" "USER" "STATE" "GPUs" "GRES"
echo "-----------------------------------------------------------------------"

squeue -h -p "${PARTITION}" ${SQ_USER_OP} -t R,PD -o "%A %u %t %b" 2>/dev/null | \
awk '
  {
    job   = $1
    user  = $2
    state = $3
    gres  = $4

    gpu_count = 0
    n = split(gres, a, ",")
    for (i = 1; i <= n; i++) {
      if (a[i] ~ /gpu:/) {
        m = split(a[i], g, ":")
        gpu_count = g[m]
      }
    }
    printf "%-10s %-14s %-8s %-6d %-20s\n", job, user, state, gpu_count, gres
  }'
echo

############################################
# 9) Node-level view (all nodes/partition) #
############################################
echo "${BOLD}Node-level view for ${PARTITION}:${RESET}"
printf "%-24s %-10s %4s %-10s\n" "NODE" "GPU_TYPE" "GPUs" "STATE"
echo "--------------------------------------------------------------"

sinfo -h -N -p "${PARTITION}" -o "%N %G %T" 2>/dev/null | \
awk '
  {
    node  = $1
    gres  = $2
    state = $3

    gputype = ""
    gpus    = 0

    n = split(gres, a, ",")
    for (i = 1; i <= n; i++) {
      if (a[i] ~ /gpu:/) {
        m = split(a[i], g, ":")
        if (m == 3) {
          gputype = g[2]
          gpus    = g[3]
        } else if (m == 2) {
          gputype = "gpu"
          gpus    = g[2]
        }
      }
    }

    if (gputype == "") gputype = "gpu"

    printf "%s %s %d %s\n", node, gputype, gpus, state
  }' | \
while read -r node gputype gpus state; do
  # Color the node state
  colored_state=$(color_state "${state}")
  printf "%-24s %-10s %4d %s\n" "${node}" "${gputype}" "${gpus}" "${colored_state}"
done

echo

################################################################################
# 10) Nodes with available GPUs (TOT / USED / FREE) using AllocTRES + colors   #
################################################################################
echo "${BOLD}Nodes with available GPUs in ${PARTITION}:${RESET}"
printf "%-24s %-10s %4s %4s %4s %-10s\n" "NODE" "GPU_TYPE" "TOT" "USED" "FREE" "STATE"
echo "---------------------------------------------------------------------"

sinfo -h -N -p "${PARTITION}" -o "%N %T" 2>/dev/null | \
while read -r node state; do
  scontrol show node "${node}" 2>/dev/null | \
  awk -v node="${node}" -v state="${state}" '
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^Gres=/)      gres=$i
        if ($i ~ /^AllocTRES=/) alloc=$i
      }
    }
    END {
      gsub(/^Gres=/, "", gres)
      gsub(/^AllocTRES=/, "", alloc)

      # strip anything after "(" e.g. gpu:h200:8(S:0-7)
      sub(/\(.*/, "", gres)

      gputype = ""
      tot = 0
      usedv = 0

      # total GPUs from Gres
      if (gres ~ /gpu:/) {
        n = split(gres, a, ",")
        for (i = 1; i <= n; i++) {
          if (a[i] ~ /gpu:/) {
            m = split(a[i], g, ":")
            if (m == 3) {
              gputype = g[2]
              tot     = g[3]
            } else if (m == 2) {
              gputype = "gpu"
              tot     = g[2]
            }
          }
        }
      }

      # used GPUs from AllocTRES=...,gres/gpu=4,...
      if (alloc != "") {
        sub(/^AllocTRES=/, "", alloc)
        n = split(alloc, b, ",")
        for (i = 1; i <= n; i++) {
          if (b[i] ~ /gres\/gpu=/) {
            split(b[i], kv, "=")
            usedv = kv[2] + 0
          }
        }
      }

      if (gputype == "" && tot > 0) gputype = "gpu"

      free = tot - usedv
      if (free < 0) free = 0

      # print only nodes that have free GPUs and a positive total
      if (tot > 0 && free > 0) {
        printf "%s %s %d %d %d %s\n", node, gputype, tot, usedv, free, state
      }
    }'
done | \
while read -r node gputype tot used free state; do
  # Color FREE column and state
  colored_free=$(color_free "${free}" "${tot}")
  colored_state=$(color_state "${state}")
  printf "%-24s %-10s %4d %4d %4b %s\n" "${node}" "${gputype}" "${tot}" "${used}" "${colored_free}" "${colored_state}"
done

echo
echo "${DIM}(Partition: ${PARTITION} | User filter: ${USER_FILTER:-all users})${RESET}"
