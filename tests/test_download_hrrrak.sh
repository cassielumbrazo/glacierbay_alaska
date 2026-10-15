#!/usr/bin/env bash
# Offline regression checks: run `bash tests/test_download_hrrrak.sh` from repo root.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo/hrrrak/download_hrrrak_lone_island.sh"
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export MOCK_INVENTORY="$work/inventory" MOCK_LOG="$work/requests"
cat > "$MOCK_INVENTORY" <<'INVENTORY'
1:0:d=2019040100:PRES:surface:5 hour fcst:
2:100:d=2019040100:HGT:surface:5 hour fcst:
3:200:d=2019040100:TMP:surface:5 hour fcst:
4:300:d=2019040100:TMP:2 m above ground:5 hour fcst:
5:400:d=2019040100:RH:2 m above ground:5 hour fcst:
6:500:d=2019040100:UGRD:10 m above ground:5 hour fcst:
7:600:d=2019040100:VGRD:10 m above ground:5 hour fcst:
8:700:d=2019040100:DSWRF:surface:5 hour fcst:
9:800:d=2019040100:DLWRF:surface:5 hour fcst:
10:900:d=2019040100:APCP:surface:0-5 hour acc fcst:
11:1000:d=2019040100:PRATE:surface:5 hour fcst:
12:1100:d=2019040100:SNOD:surface:5 hour fcst:
13:1200:d=2019040100:WEASD:surface:5 hour fcst:
14:1300:d=2019040100:UNRELATED:surface:5 hour fcst:
INVENTORY
# Shell functions replace all network calls and GRIB work; no actual downloads.
curl() {
    local url='' output='' arg
    while (($#)); do
        arg=$1; shift
        case "$arg" in
            -o) output=$1; shift ;;
            https://*) url=$arg ;;
        esac
    done
    printf '%s\n' "$url" >> "$MOCK_LOG"
    if [[ "$TEST_MODE" == terminate ]]; then kill -TERM "$BASHPID"; return 1; fi
    [[ "$TEST_MODE" != all_http_fail ]] || return 22
    if [[ "$TEST_MODE" == first_two_fail && "$url" != *blob.core.windows.net* ]]; then return 22; fi
    if [[ "$url" == *storage.googleapis.com* ]]; then
        [[ "$TEST_MODE" != primary_http_fail ]] || return 22
        [[ "$TEST_MODE" != primary_transport_fail ]] || return 6
        if [[ "$TEST_MODE" == primary_data_fail && "$url" != *.idx ]]; then return 22; fi
    fi
    if [[ "$url" == *.idx ]]; then
        if [[ "$TEST_MODE" == bad_index ]]; then printf 'not an index\n' > "$output"
        else cat "$MOCK_INVENTORY" > "$output"; fi
    else printf 'VALID\n' > "$output"; fi
}
wgrib2() {
    local input=$1; shift
    local arg output=''
    if [[ "$input" != - ]]; then
        [[ -s "$input" ]] && grep -q VALID "$input" || return 1
    fi
    case " $* " in
        *' -stats '*) [[ "$TEST_MODE" != decode_fail ]]; return ;;
        *' -s '*)
            if [[ "$TEST_MODE" == missing_snow ]]; then grep -v ':SNOD:' "$MOCK_INVENTORY"
            elif [[ "$TEST_MODE" == hourly_only ]]; then sed 's/:0-5 hour acc fcst:/:4-5 hour acc fcst:/' "$MOCK_INVENTORY"
            else cat "$MOCK_INVENTORY"; fi
            return ;;
        *' -small_grib '*)
            [[ "$TEST_MODE" != crop_fail ]] || return 9
            cat "$input"; return ;;
    esac
    [[ "$input" != - ]] || cat >/dev/null
    while (($#)); do
        arg=$1; shift
        if [[ "$arg" == -grib ]]; then output=$1; shift; fi
    done
    [[ "$TEST_MODE" != filter_fail ]] || return 9
    printf 'VALID\n' > "$output"
}
export -f curl wgrib2
export DATE=20190401 ARCHIVE=Google
file=hrrr.t00z.wrfsfcf05.ak.grib2

# Matching span includes the complete last selected record, excludes unrelated tail.
[[ $(get_grib_range "$MOCK_INVENTORY") == 0-1299 ]]
sed '$d' "$MOCK_INVENTORY" > "$work/last_match"
[[ $(get_grib_range "$work/last_match") == 0- ]]
printf 'not an index\n' > "$work/no_matches"
if get_grib_range "$work/no_matches"; then exit 1; fi
[[ ! "$HRRR_VARS" == *'|' ]]
! grep -Eq "$HRRR_VARS" <<< ':UNRELATED:surface:'
for mode in primary_http_fail primary_transport_fail primary_data_fail first_two_fail; do
    mkdir "$work/$mode"
    (
        cd "$work/$mode"
        export TEST_MODE=$mode
        : > "$MOCK_LOG"
        download_day 0 5
        validate_grib "$file"
        grep -q noaa-hrrr-bdp-pds "$MOCK_LOG"
        if [[ "$mode" == first_two_fail ]]; then grep -q blob.core.windows.net "$MOCK_LOG"; fi
        [[ $(find . -mindepth 1 -maxdepth 1 | wc -l) -eq 1 ]]
    )
done
for mode in all_http_fail bad_index crop_fail filter_fail missing_snow hourly_only decode_fail terminate; do
    mkdir "$work/$mode"
    (
        cd "$work/$mode"
        export TEST_MODE=$mode
        if download_day 0 5; then printf 'Expected failure: %s\n' "$mode" >&2; exit 1; fi
        [[ ! -e "$file" ]]
        [[ -z $(find . -mindepth 1 -print -quit) ]]
    )
done
mkdir "$work/existing"
(
    cd "$work/existing"
    export TEST_MODE=success
    printf VALID > "$file"
    : > "$MOCK_LOG"
    download_day 0 5
    [[ ! -s "$MOCK_LOG" ]]  # Valid existing file: no network calls.
    printf OLD_UNDECODABLE > "$file"
    export TEST_MODE=all_http_fail
    if download_day 0 5; then exit 1; fi
    [[ $(cat "$file") == OLD_UNDECODABLE ]]  # Failure preserves existing work.
    export TEST_MODE=success
    download_day 0 5
    [[ $(cat "$file") == VALID ]]
)
# Check supported parsing without running any actual jobs.
parallel() { printf '%s\n' "$DATE" >> "$work/dates"; }
export -f parallel
(
    cd "$work"
    export TEST_MODE=success
    main 20190401,20190407 AWS
    [[ $(wc -l < "$work/dates") -eq 7 ]]
    rm "$work/dates"
    main 2019 04 Azure
    [[ $(wc -l < "$work/dates") -eq 30 ]]
    if main 20190407,20190401; then exit 1; fi
    if main 20190401 UofU; then exit 1; fi
    if main 20190230; then exit 1; fi
    parallel() { return 1; }
    if main 20190401; then exit 1; fi  # Failed jobs propagate to script status.
)
printf 'PASS: offline downloader failure, fallback, validation, parsing, and cleanup checks.\n'
