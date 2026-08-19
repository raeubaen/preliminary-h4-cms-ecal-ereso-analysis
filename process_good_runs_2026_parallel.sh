#!/bin/bash
#
# Parallel driver for the June 2026 "Good Run" pipeline: same three steps
# as process_good_runs_2026.sh (h4_raw2root unpack -> hadd merge -> h4_reco)
# but processing NJOBS runs concurrently.
#
# Resume semantics ("campaign restart"): every output file (spill root,
# merged root, reco root) whose mtime is newer than CAMPAIGN_START is
# trusted and kept; anything older is re-processed from scratch.  This
# redoes all the pre-campaign (June) outputs while skipping the runs
# already completed by the serial job earlier today.
#
# The crystal mapping and the good-run list are read from the serial
# script, which stays the single source of truth.
#
# Usage:
#   ./process_good_runs_2026_parallel.sh              # all runs, 5 workers
#   ./process_good_runs_2026_parallel.sh -j 8         # 8 workers
#   ./process_good_runs_2026_parallel.sh -r 20521     # single run

set -uo pipefail

DANTE_DIR="/afs/cern.ch/user/e/ecalgit/DANTE_reco"
EOS_DIR="/eos/cms/store/group/dpg_ecal/comm_ecal/upgrade/testbeam/ECALTB_H4_Jun2026"
EB_DIR="$EOS_DIR/EB"
DATATREE_DIR="$EOS_DIR/DataTree"
MERGED_DIR="$DATATREE_DIR/merged"
RECO_DIR="$EOS_DIR/Reco"

BUILD_DIR="$DANTE_DIR/build"
LOGBOOK="$DANTE_DIR/logbook_db_2026.txt"
TEMPLATE_LIB="$DANTE_DIR/template_library_default.root"
SERIAL_SCRIPT="$DANTE_DIR/process_good_runs_2026.sh"
LOG_DIR="$DANTE_DIR/logs_parallel"

NJOBS=5
ONLY_RUN=""
CAMPAIGN_START="2026-08-18 17:00"

help()
{
	cat <<EOF
Usage: process_good_runs_2026_parallel.sh [OPTIONS...]

Parallel unpack/merge/reco of the June 2026 good runs.  Outputs newer
than "$CAMPAIGN_START" are kept, everything else is redone.

  OPTIONS:
    -h        print this help
    -j N      number of runs processed in parallel (default $NJOBS)
    -r RUN    process only run RUN
EOF
}

while getopts "hj:r:" opt; do
	case "$opt" in
		h) help; exit 0;;
		j) NJOBS="$OPTARG";;
		r) ONLY_RUN="$OPTARG";;
		*) help; exit 1;;
	esac
done

# crystal mapping and run list from the serial script
eval "$(grep '^declare -A CRYSTAL_' "$SERIAL_SCRIPT")"
eval "$(sed -n '/^RUN_SPECS=(/,/^)$/p' "$SERIAL_SCRIPT")"
if [ "${#RUN_SPECS[@]}" -eq 0 ]; then
	echo "[error] could not read RUN_SPECS from $SERIAL_SCRIPT" >&2
	exit 1
fi

# output produced after the campaign start -> trusted, keep it
fresh()
{
	[ -f "$1" ] && [ -n "$(find "$1" -newermt "$CAMPAIGN_START" 2>/dev/null)" ]
}

unpack_run()
{
	local run=$1
	local in_dir="$EB_DIR/$run"
	local out_dir="$DATATREE_DIR/$run"
	if [ ! -d "$in_dir" ]; then
		echo "  [error] $in_dir not found, cannot unpack run $run"
		return 1
	fi
	mkdir -p "$out_dir"
	local raw out n_raw=0 n_skip=0
	for raw in "$in_dir"/*.raw; do
		[ -e "$raw" ] || break
		n_raw=$((n_raw + 1))
		out="$out_dir/$(basename "${raw%.raw}").root"
		if fresh "$out"; then
			n_skip=$((n_skip + 1))
			continue
		fi
		if ! "$BUILD_DIR/h4_raw2root" -i "$raw" -o "$out" > "${out%.root}_unpack.log" 2>&1; then
			echo "  [error] h4_raw2root failed on $raw (see ${out%.root}_unpack.log)"
			rm -f "$out"
			return 1
		fi
	done
	if [ "$n_raw" -eq 0 ]; then
		echo "  [error] no .raw files in $in_dir"
		return 1
	fi
	echo "  unpacked $((n_raw - n_skip))/$n_raw spills ($n_skip fresh, kept)"
}

merge_run()
{
	local run=$1
	local out="$MERGED_DIR/${run}_merged.root"
	if fresh "$out"; then
		echo "  [skip] $out is fresh"
		return 0
	fi
	if ! compgen -G "$DATATREE_DIR/$run/[0-9]*.root" > /dev/null; then
		echo "  [error] no spill root files in $DATATREE_DIR/$run"
		return 1
	fi
	mkdir -p "$MERGED_DIR"
	if ! hadd -f "$out" "$DATATREE_DIR/$run"/[0-9]*.root > "$MERGED_DIR/${run}_hadd.log" 2>&1; then
		echo "  [error] hadd failed for run $run (see $MERGED_DIR/${run}_hadd.log)"
		rm -f "$out"
		return 1
	fi
	echo "  merged -> $out"
}

reco_run()
{
	local run=$1 bcp=$2 crystal=$3 energy=$4
	local in="$MERGED_DIR/${run}_merged.root"
	local out="$RECO_DIR/${run}_${energy}_reco.root"
	if fresh "$out"; then
		echo "  [skip] $out is fresh"
		return 0
	fi
	if [ ! -f "$in" ]; then
		echo "  [error] $in not found, cannot run reco for run $run"
		return 1
	fi
	if [ -z "${CRYSTAL_ETA[$crystal]:-}" ]; then
		echo "  [error] unknown central crystal $crystal (run $run)"
		return 1
	fi
	local eta=${CRYSTAL_ETA[$crystal]} phi=${CRYSTAL_PHI[$crystal]}
	mkdir -p "$RECO_DIR"
	if ! "$BUILD_DIR/h4_reco" -i "$in" -r "$run" -o "$RECO_DIR" -l "$LOGBOOK" \
		-c "${bcp}-${crystal}" -g "$energy" \
		-de $((eta - 1)) -dE $((eta + 1)) -dp $((phi - 1)) -dP $((phi + 1)) \
		-tb "$TEMPLATE_LIB" > "$LOG_DIR/${run}_reco.log" 2>&1; then
		echo "  [error] h4_reco failed for run $run (see $LOG_DIR/${run}_reco.log)"
		return 1
	fi
	echo "  reco -> $out"
}

process_one_run()
{
	local run=$1 bcp=$2 crystal=$3 energy=$4
	echo "== run $run (crystal ${bcp}-${crystal}, ${energy} GeV) started $(date '+%F %T') =="
	unpack_run "$run" && merge_run "$run" && reco_run "$run" "$bcp" "$crystal" "$energy"
	local rc=$?
	echo "== run $run finished $(date '+%F %T') rc=$rc =="
	return "$rc"
}

# h4_reco & co. read dante.toml from the working directory
cd "$DANTE_DIR" || exit 1

if [ ! -x "$BUILD_DIR/h4_raw2root" ] || [ ! -x "$BUILD_DIR/h4_reco" ]; then
	echo "[error] missing executables in $BUILD_DIR: run 'make -j' in $DANTE_DIR first" >&2
	exit 1
fi
if [ ! -f "$TEMPLATE_LIB" ]; then
	echo "[error] template library $TEMPLATE_LIB not found" >&2
	exit 1
fi
mkdir -p "$LOG_DIR"

n_ok=0
n_fail=0
failed_runs=()
declare -A SEEN=()
declare -A PID_RUN=()

reap_one()
{
	local pid rc run
	wait -n -p pid
	rc=$?
	run=${PID_RUN[$pid]:-?}
	unset "PID_RUN[$pid]"
	if [ "$rc" -eq 0 ]; then
		n_ok=$((n_ok + 1))
		echo "[done] run $run OK   ($n_ok ok, $n_fail failed so far)"
	else
		n_fail=$((n_fail + 1))
		failed_runs+=("$run")
		echo "[done] run $run FAILED (see $LOG_DIR/$run.log; $n_ok ok, $n_fail failed so far)"
	fi
}

echo "== parallel processing: ${#RUN_SPECS[@]} specs, $NJOBS workers, campaign start $CAMPAIGN_START =="
for spec in "${RUN_SPECS[@]}"; do
	IFS='|' read -r run bcp crystal energy <<< "$spec"
	if [ -n "$ONLY_RUN" ] && [ "$run" != "$ONLY_RUN" ]; then
		continue
	fi
	if [ -n "${SEEN[$run]:-}" ]; then
		continue
	fi
	SEEN[$run]=1
	while [ "$(jobs -rp | wc -l)" -ge "$NJOBS" ]; do
		reap_one
	done
	echo "[start] run $run (crystal ${bcp}-${crystal}, ${energy} GeV)"
	process_one_run "$run" "$bcp" "$crystal" "$energy" > "$LOG_DIR/${run}.log" 2>&1 &
	PID_RUN[$!]=$run
done
while [ "$(jobs -rp | wc -l)" -gt 0 ]; do
	reap_one
done

echo
echo "== summary: $n_ok runs processed, $n_fail failed =="
if [ "$n_fail" -gt 0 ]; then
	echo "   failed runs: ${failed_runs[*]}"
	exit 1
fi
