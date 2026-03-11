#!/usr/bin/env bash

# gpu_usage.sh
# Colorized NVIDIA GPU usage report with per-GPU tables and owner mapping.

set -u
set -o pipefail

for cmd in nvidia-smi ps awk sed sort date hostname tput; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: required command not found: $cmd"
        exit 1
    fi
done

if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_MAGENTA=""
    C_CYAN=""
    C_WHITE=""
else
    C_RESET="$(tput sgr0)"
    C_BOLD="$(tput bold)"
    C_DIM="$(tput dim)"
    C_RED="$(tput setaf 1)"
    C_GREEN="$(tput setaf 2)"
    C_YELLOW="$(tput setaf 3)"
    C_BLUE="$(tput setaf 4)"
    C_MAGENTA="$(tput setaf 5)"
    C_CYAN="$(tput setaf 6)"
    C_WHITE="$(tput setaf 7)"
fi

TERM_WIDTH="${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}"

line() {
    printf '%*s\n' "$TERM_WIDTH" '' | tr ' ' '-'
}

section() {
    echo
    echo "${C_BOLD}${C_CYAN}$1${C_RESET}"
    line
}

trim() {
    sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

safe_ps() {
    ps -p "$1" -o user=,%cpu=,rss=,etime=,lstart=,args= 2>/dev/null || true
}

human_gpu_util_color() {
    local util="$1"
    if [[ "$util" =~ ^[0-9]+$ ]]; then
        if (( util >= 90 )); then
            printf "%s%s%%%s" "$C_RED" "$util" "$C_RESET"
        elif (( util >= 50 )); then
            printf "%s%s%%%s" "$C_YELLOW" "$util" "$C_RESET"
        else
            printf "%s%s%%%s" "$C_GREEN" "$util" "$C_RESET"
        fi
    else
        printf "%s" "$util"
    fi
}

human_mem_pct_color() {
    local used="$1"
    local total="$2"
    if [[ "$used" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ && "$total" -gt 0 ]]; then
        local pct=$(( used * 100 / total ))
        if (( pct >= 90 )); then
            printf "%s%d%%%s" "$C_RED" "$pct" "$C_RESET"
        elif (( pct >= 60 )); then
            printf "%s%d%%%s" "$C_YELLOW" "$pct" "$C_RESET"
        else
            printf "%s%d%%%s" "$C_GREEN" "$pct" "$C_RESET"
        fi
    else
        printf "?"
    fi
}

shorten_cmd() {
    local maxlen="${1:-70}"
    local text="${2:-}"
    if (( ${#text} > maxlen )); then
        printf "%s..." "${text:0:maxlen-3}"
    else
        printf "%s" "$text"
    fi
}

NOW="$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOST="$(hostname 2>/dev/null || echo unknown-host)"

echo "${C_BOLD}${C_MAGENTA}GPU PROCESS REPORT${C_RESET}"
line
printf "%-12s %s\n" "Host:" "$HOST"
printf "%-12s %s\n" "Generated:" "$NOW"

mapfile -t GPU_LINES < <(
    nvidia-smi \
      --query-gpu=index,name,uuid,temperature.gpu,utilization.gpu,memory.used,memory.total \
      --format=csv,noheader,nounits 2>/dev/null
)

if [[ ${#GPU_LINES[@]} -eq 0 ]]; then
    echo
    echo "${C_RED}No GPUs found or nvidia-smi returned no data.${C_RESET}"
    exit 1
fi

declare -A GPU_NAME GPU_UUID GPU_TEMP GPU_UTIL GPU_MEM_USED GPU_MEM_TOTAL

for line_raw in "${GPU_LINES[@]}"; do
    IFS=',' read -r idx name uuid temp util mem_used mem_total <<< "$line_raw"
    idx="$(echo "$idx" | trim)"
    GPU_NAME["$idx"]="$(echo "$name" | trim)"
    GPU_UUID["$idx"]="$(echo "$uuid" | trim)"
    GPU_TEMP["$idx"]="$(echo "$temp" | trim)"
    GPU_UTIL["$idx"]="$(echo "$util" | trim)"
    GPU_MEM_USED["$idx"]="$(echo "$mem_used" | trim)"
    GPU_MEM_TOTAL["$idx"]="$(echo "$mem_total" | trim)"
done

declare -A UUID_TO_GPU
for idx in "${!GPU_UUID[@]}"; do
    UUID_TO_GPU["${GPU_UUID[$idx]}"]="$idx"
done

mapfile -t PROC_LINES < <(
    nvidia-smi \
      --query-compute-apps=gpu_uuid,pid,process_name,used_gpu_memory \
      --format=csv,noheader,nounits 2>/dev/null | sort -t',' -k1,1 -k2,2n
)

section "GPU SUMMARY"

printf "%-5s %-28s %-8s %-10s %-18s %-10s %-9s\n" \
    "GPU" "Name" "Temp" "Util" "Mem Used" "Mem %" "Procs"
line

for idx in $(printf "%s\n" "${!GPU_NAME[@]}" | sort -n); do
    util_raw="${GPU_UTIL[$idx]}"
    mem_used="${GPU_MEM_USED[$idx]}"
    mem_total="${GPU_MEM_TOTAL[$idx]}"
    temp="${GPU_TEMP[$idx]}"
    name="${GPU_NAME[$idx]}"

    proc_count=0
    for p in "${PROC_LINES[@]}"; do
        IFS=',' read -r puuid _ _ _ <<< "$p"
        puuid="$(echo "$puuid" | trim)"
        [[ "${UUID_TO_GPU[$puuid]:-}" == "$idx" ]] && ((proc_count++))
    done

    util_colored="$(human_gpu_util_color "$util_raw")"
    mem_pct_colored="$(human_mem_pct_color "$mem_used" "$mem_total")"

    printf "%-5s %-28s %-8s %-10b %-18s %-10b %-9s\n" \
        "$idx" \
        "$(shorten_cmd 28 "$name")" \
        "${temp}C" \
        "$util_colored" \
        "${mem_used} / ${mem_total} MiB" \
        "$mem_pct_colored" \
        "$proc_count"
done

section "PER-GPU PROCESS TABLES"

if [[ ${#PROC_LINES[@]} -eq 0 ]]; then
    echo "${C_GREEN}No active GPU compute processes found.${C_RESET}"
else
    declare -A USER_PROC_COUNT USER_GPU_MEM_MB

    for idx in $(printf "%s\n" "${!GPU_NAME[@]}" | sort -n); do
        echo "${C_BOLD}${C_BLUE}GPU $idx${C_RESET} - ${GPU_NAME[$idx]}"
        printf "  UUID: %s\n" "${GPU_UUID[$idx]}"
        printf "  Status: Util %b, Memory %s / %s MiB, Temp %sC\n" \
            "$(human_gpu_util_color "${GPU_UTIL[$idx]}")" \
            "${GPU_MEM_USED[$idx]}" \
            "${GPU_MEM_TOTAL[$idx]}" \
            "${GPU_TEMP[$idx]}"
        echo

        printf "%-8s %-16s %-10s %-8s %-9s %-12s %-24s %-s\n" \
            "PID" "OWNER" "GPU_MEM" "CPU%" "RSS_MB" "ELAPSED" "STARTED" "COMMAND"
        line

        found=0
        for pline in "${PROC_LINES[@]}"; do
            IFS=',' read -r puuid pid pname gpu_mem <<< "$pline"
            puuid="$(echo "$puuid" | trim)"
            pid="$(echo "$pid" | trim)"
            pname="$(echo "$pname" | trim)"
            gpu_mem="$(echo "$gpu_mem" | trim)"

            [[ "${UUID_TO_GPU[$puuid]:-}" != "$idx" ]] && continue
            found=1

            ps_out="$(safe_ps "$pid")"
            if [[ -z "${ps_out// }" ]]; then
                printf "%-8s %-16s %-10s %-8s %-9s %-12s %-24s %-s\n" \
                    "$pid" "<exited?>" "${gpu_mem}MiB" "-" "-" "-" "-" "$pname"
                continue
            fi

            owner="$(awk '{print $1}' <<< "$ps_out")"
            cpu_pct="$(awk '{print $2}' <<< "$ps_out")"
            rss_kb="$(awk '{print $3}' <<< "$ps_out")"
            elapsed="$(awk '{print $4}' <<< "$ps_out")"
            started="$(awk '{print $5" "$6" "$7" "$8" "$9}' <<< "$ps_out")"
            cmd="$(awk '{$1=$2=$3=$4=$5=$6=$7=$8=$9=""; sub(/^[ \t]+/, ""); print}' <<< "$ps_out")"

            rss_mb=$(( rss_kb / 1024 ))
            cmd_short="$(shorten_cmd 90 "$cmd")"

            printf "%-8s %-16s %-10s %-8s %-9s %-12s %-24s %-s\n" \
                "$pid" \
                "$owner" \
                "${gpu_mem}MiB" \
                "$cpu_pct" \
                "$rss_mb" \
                "$elapsed" \
                "$started" \
                "$cmd_short"

            if [[ "$owner" != "<exited?>" ]]; then
                USER_PROC_COUNT["$owner"]=$(( ${USER_PROC_COUNT["$owner"]:-0} + 1 ))
                if [[ "$gpu_mem" =~ ^[0-9]+$ ]]; then
                    USER_GPU_MEM_MB["$owner"]=$(( ${USER_GPU_MEM_MB["$owner"]:-0} + gpu_mem ))
                fi
            fi
        done

        if [[ "$found" -eq 0 ]]; then
            echo "${C_DIM}No active compute processes on this GPU.${C_RESET}"
        fi

        echo
    done

    section "USER SUMMARY"

    printf "%-18s %-12s %-15s\n" "OWNER" "PROC_COUNT" "TOTAL_GPU_MEM"
    line

    for user in $(printf "%s\n" "${!USER_PROC_COUNT[@]}" | sort); do
        printf "%-18s %-12s %-15s\n" \
            "$user" \
            "${USER_PROC_COUNT[$user]}" \
            "${USER_GPU_MEM_MB[$user]:-0} MiB"
    done
fi
