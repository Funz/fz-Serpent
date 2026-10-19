#!/bin/bash
# Serpent.sh — fz runner for the Serpent 2 Monte Carlo code (https://serpent.vtt.fi/docs/)
#
# Usage: Serpent.sh <compiled input file(s) | case directory>
#
# fz calls this script inside a fresh case directory, with the compiled input file(s)
# as arguments. With several files (main input + `include`d files), the main input is
# $SERPENT_INPUT if set, else the first *.inp file, else the first argument.
#
# Environment:
#   SERPENT_BIN    Serpent executable (default: sss2, then sss, then serpent in PATH)
#   SERPENT_OMP    number of OpenMP threads, passed as `-omp N` (default: Serpent's own)
#   SERPENT_ARGS   extra command-line options, placed before the input file
#   SERPENT_INPUT  name of the main input file when several files are given
# Serpent itself reads SERPENT_DATA, SERPENT_ACELIB, SERPENT_DECLIB, SERPENT_NFYLIB.
#
# Results: Serpent writes <input>_res.m (parsed by the Serpent model), <input>.out,
# and optional _det/_dep files. Exit status is non-zero if Serpent fails or if
# <input>_res.m is missing, so fz marks the case as failed.

if [ -d "$1" ]; then
  cd "$1" || exit 2
  set -- *
fi

input=""
if [ $# -gt 1 ]; then
  if [ -n "$SERPENT_INPUT" ]; then
    input="$SERPENT_INPUT"
  else
    for f in "$@"; do
      case "$f" in *.inp) input="$f"; break ;; esac
    done
  fi
fi
input=${input:-$1}
if [ ! -f "$input" ]; then
  echo "Usage: $0 <input file or case directory> (input '$input' not found)" >&2
  exit 2
fi

SERPENT=${SERPENT_BIN:-$(command -v sss2 || command -v sss || command -v serpent)}
if [ -z "$SERPENT" ] || ! command -v "$SERPENT" >/dev/null; then
  echo "Serpent executable not found: install it in PATH as sss2, or set SERPENT_BIN" >&2
  exit 2
fi

opts=()
[ -n "$SERPENT_OMP" ] && opts+=(-omp "$SERPENT_OMP")
# shellcheck disable=SC2206  # SERPENT_ARGS is intentionally word-split
[ -n "$SERPENT_ARGS" ] && opts+=($SERPENT_ARGS)

# Serpent appends to an existing _res.m: drop a stale one (retry, re-run)
rm -f "${input}_res.m"
echo "Running: $SERPENT ${opts[*]:+${opts[*]} }$input"
"$SERPENT" "${opts[@]}" "$input" &
echo $! >> PID            # let fz kill the run on interrupt
wait $!
status=$?
rm -f PID

if [ $status -ne 0 ]; then
  echo "Serpent exited with status $status" >&2
  exit $status
fi
if [ ! -s "${input}_res.m" ]; then
  echo "Serpent produced no ${input}_res.m (see ${input}.out)" >&2
  exit 1
fi
