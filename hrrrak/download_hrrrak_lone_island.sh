#!/usr/bin/env bash
# Run from hrrrak/: bash download_hrrrak_lone_island.sh YYYYMMDD [Google|AWS|Azure]
# Inclusive range: YYYYMMDD,YYYYMMDD [archive]; whole month: YYYY MM [archive].
# Requirements: Linux Bash, curl, GNU Parallel, GNU date, awk, grep, wgrib2.
# Sourcing defines functions/settings only, for small offline tests.
set -euo pipefail

# SNOD = snow depth; WEASD = instantaneous snow water equivalent. ASNOW is
# accumulated snowfall, a different quantity. Keep both APCP accumulation intervals;
# notebook 2 explicitly selects the total starting at initialization.
export HRRR_VARS='PRES:surface|HGT:surface|TMP:surface|TMP:2 m above ground|RH:2 m above ground|UGRD:10 m above ground|VGRD:10 m above ground|DSWRF:surface|DLWRF:surface|APCP:surface|PRATE:surface|SNOD:surface|WEASD:surface|SNOWC:surface|ASNOW:surface|TCDC:entire atmosphere'
export HRRR_DAY_HOURS='0 3 6 9 12 15 18 21'
HRRR_FC_HOURS=(5 6 7)
export GRIB_AREA='-136.373558:-136.217390 58.681422:58.762504'
PARALLEL_JOBS=15
export GRIB_THREADS='-ncpu 2'

set_archive_url() {
    local archive=$1
    case "$archive" in
        AWS) ARCHIVE_URL="https://noaa-hrrr-bdp-pds.s3.amazonaws.com/hrrr.${DATE}/alaska/${FILE_NAME}" ;;
        Google) ARCHIVE_URL="https://storage.googleapis.com/high-resolution-rapid-refresh/hrrr.${DATE}/alaska/${FILE_NAME}" ;;
        Azure) ARCHIVE_URL="https://noaahrrr.blob.core.windows.net/hrrr/hrrr.${DATE}/alaska/${FILE_NAME}" ;;
        *) printf 'Unsupported archive: %s\n' "$archive" >&2; return 1 ;;
    esac
}

validate_grib() {
    local file=$1 inventory required
    [[ -s "$file" ]] || return 1
    # Inventory alone may succeed on a truncated message: decode all records too.
    inventory=$(wgrib2 "$file" -s) || return 1
    [[ -n "$inventory" ]] || return 1
    wgrib2 "$file" -stats >/dev/null || return 1
    # Required notebook-2 fields; accept additional records in older valid samples.
    for required in 'PRES:surface' 'HGT:surface' 'TMP:surface' \
        'TMP:2 m above ground' 'RH:2 m above ground' \
        'UGRD:10 m above ground' 'VGRD:10 m above ground' \
        'DSWRF:surface' 'DLWRF:surface' 'PRATE:surface' \
        'SNOD:surface' 'WEASD:surface'; do
        if ! grep -Fq ":${required}:" <<< "$inventory"; then
            printf 'Missing required field %s in %s\n' "$required" "$file" >&2
            return 1
        fi
    done
    # Require the run-total APCP used by notebook 2, not just a one-hour interval.
    grep -Eq ':APCP:surface:0-[0-9]+ hour acc fcst:' <<< "$inventory" || return 1
    # Snow depth / SWE must include instantaneous forecasts, not just accumulations.
    grep -Eq ':SNOD:surface:[0-9]+ hour fcst:' <<< "$inventory" || return 1
    grep -Eq ':WEASD:surface:[0-9]+ hour fcst:' <<< "$inventory" || return 1
}

get_grib_range() {
    # One contiguous byte span covers matching messages, including the last one.
    # If the last match is the last index entry, request through end-of-file.
    awk -F: -v pattern="$HRRR_VARS" '
        $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {
            n++; offset[n]=$2
            if ($0 ~ pattern) { if (!first) first=n; last=n }
        }
        END {
            if (!first) exit 1
            if (last < n) printf "%.0f-%.0f\n", offset[first], offset[last+1]-1
            else printf "%.0f-\n", offset[first]
        }
    ' "$1"
}

attempt_download() {
    local archive=$1 work=$2 byte_range
    local -a threads area
    set_archive_url "$archive" || return 1
    printf 'Trying %s: %s\n' "$archive" "$FILE_NAME"
    # Explicit status checks allow fallback even with errexit enabled.
    curl --fail --show-error --silent --location --retry 2 \
        --connect-timeout 20 --max-time 180 \
        "${ARCHIVE_URL}.idx" -o "$work/index" || return 1
    byte_range=$(get_grib_range "$work/index") || return 1
    [[ "$byte_range" =~ ^[0-9]+-[0-9]*$ ]] || return 1
    curl --fail --show-error --silent --location --retry 2 \
        --connect-timeout 20 --max-time 600 --range "$byte_range" \
        "$ARCHIVE_URL" -o "$work/input.grib2" || return 1
    read -r -a threads <<< "$GRIB_THREADS"
    read -r -a area <<< "$GRIB_AREA"
    # Regular temporary input avoids FIFO deadlocks. pipefail catches either stage.
    if ! wgrib2 "$work/input.grib2" -v0 "${threads[@]}" -set_grib_type same \
        -small_grib "${area[@]}" - | \
        wgrib2 - -v0 "${threads[@]}" -match "$HRRR_VARS" -grib "$work/output.grib2"; then
        return 1
    fi
    validate_grib "$work/output.grib2" || return 1
}

download_day() (
    # Each GNU Parallel job has its own subshell, temporary directory, and cleanup.
    set -euo pipefail
    local run=$1 lead=$2 work archive
    local -a archives
    FILE_NAME=$(printf 'hrrr.t%02dz.wrfsfcf%02d.ak.grib2' "$run" "$lead")
    if validate_grib "$FILE_NAME"; then
        printf 'Valid existing file: %s\n' "$FILE_NAME"
        return 0
    fi
    # Preserve invalid existing files until a validated replacement is ready.
    work=$(mktemp -d "./.${FILE_NAME}.XXXXXX") || return 1
    trap 'rm -rf -- "$work"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    archives=("$ARCHIVE")
    for archive in AWS Google Azure; do
        [[ "$archive" == "$ARCHIVE" ]] || archives+=("$archive")
    done
    for archive in "${archives[@]}"; do
        rm -f -- "$work/input.grib2" "$work/output.grib2" "$work/index"
        if attempt_download "$archive" "$work"; then
            # Same-filesystem rename publishes only complete, decoded output.
            mv -f -- "$work/output.grib2" "$FILE_NAME" || return 1
            printf 'Created: %s\n' "$FILE_NAME"
            return 0
        fi
        printf 'Failed on %s: %s; trying next archive if available\n' "$archive" "$FILE_NAME" >&2
    done
    printf 'All archives failed: %s/%s\n' "$DATE" "$FILE_NAME" >&2
    return 1
)

main() {
    local spec=${1:-} start end current archive tool folder month_end
    local -a dates runs
    if [[ $# -lt 1 || $# -gt 3 ]]; then
        printf 'Usage: %s YYYYMMDD[,YYYYMMDD] [Google|AWS|Azure] OR YYYY MM [archive]\n' "$0" >&2
        return 2
    fi
    if [[ "$spec" =~ ^[0-9]{4}$ && ${2:-} =~ ^[0-9]{2}$ ]]; then
        start=$(date -d "$spec-$2-01" +%Y%m%d) || return 2
        month_end=$(date -d "${start} +1 month -1 day" +%Y%m%d) || return 2
        end=$month_end
        archive=${3:-Google}
    else
        [[ $# -le 2 ]] || return 2
        if [[ "$spec" =~ ^[0-9]{8},[0-9]{8}$ ]]; then
            start=${spec%,*}; end=${spec#*,}
        elif [[ "$spec" =~ ^[0-9]{8}$ ]]; then
            start=$spec; end=$spec
        else
            printf 'Use one YYYYMMDD date or an inclusive YYYYMMDD,YYYYMMDD range.\n' >&2
            return 2
        fi
        archive=${2:-Google}
    fi
    case "$archive" in Google|AWS|Azure) ;; *) printf 'Unsupported archive: %s\n' "$archive" >&2; return 2 ;; esac
    [[ $(date -d "$start" +%Y%m%d) == "$start" && $(date -d "$end" +%Y%m%d) == "$end" && "$start" -le "$end" ]] || return 2
    for tool in curl parallel wgrib2 date awk grep mktemp; do
        command -v "$tool" >/dev/null || { printf 'Missing command: %s\n' "$tool" >&2; return 2; }
    done
    dates=(); current=$start
    while [[ "$current" -le "$end" ]]; do
        dates+=("$current")
        current=$(date -d "$current +1 day" +%Y%m%d) || return 2
    done
    export ARCHIVE=$archive
    export -f set_archive_url validate_grib get_grib_range attempt_download download_day
    read -r -a runs <<< "$HRRR_DAY_HOURS"
    for DATE in "${dates[@]}"; do
        export DATE
        folder="hrrr.${DATE}"
        mkdir -p "$folder" || return 1
        # GNU Parallel returns nonzero for failed jobs; propagate it to the caller.
        (cd "$folder" && parallel --halt soon,fail=1 --jobs "$PARALLEL_JOBS" \
            --tagstring 'hour-{1}-fc-{2}' download_day ::: "${runs[@]}" ::: "${HRRR_FC_HOURS[@]}") || return 1
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
