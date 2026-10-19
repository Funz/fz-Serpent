#!/bin/bash

# Serpent calculator script for fz framework
# This script runs Serpent Monte Carlo calculations
#
# Usage:
#   bash .fz/calculators/Serpent.sh <input_file_or_directory>
#
# Environment variables (all optional):
#   SERPENT_EXE      Serpent executable (default: sss2 or serpent in PATH, then /opt/serpent/bin/sss2,
#                    $HOME/serpent/bin/sss2)
#   SERPENT_OMP      number of OpenMP threads, passed as "-omp N" (default: 1)
#   SERPENT_DATA     directory of the cross section data, SERPENT_ACELIB default cross section directory file:
#                    read by Serpent itself, needed when the input has no absolute "set acelib" path
#
# Exit code: 0 when Serpent completed and wrote <input>_res.m; otherwise non-zero, with the Serpent error
# message ("Input error ...", "Fatal error ...", "Tracking error ...") written to stderr, so that fz reports it.

# if directory as input, cd into it
if [ -d "$1" ]; then
  cd "$1"
  # Find the first .inp input file
  input=$(ls *.inp 2>/dev/null | head -n 1)
  if [ -z "$input" ]; then
    echo "No .inp input file found in directory. Exiting." >&2
    exit 1
  fi
  shift
# if $1 is a file, use it
elif [ -f "$1" ]; then
  input="$1"
  shift
else
  echo "Usage: $0 <input_file or input_directory>" >&2
  exit 2
fi

PID_FILE=$PWD/PID
echo $$ >> $PID_FILE
trap 'rm -f "$PID_FILE"' EXIT

echo "Running Serpent calculation on $input..."

# Find the Serpent executable: $SERPENT_EXE, then PATH, then common installation paths
SERPENT_CMD=""
if [ -n "$SERPENT_EXE" ]; then
    if [ -x "$SERPENT_EXE" ] || command -v "$SERPENT_EXE" &> /dev/null; then
        SERPENT_CMD="$SERPENT_EXE"
    else
        echo "SERPENT_EXE=$SERPENT_EXE is not an executable" >&2
        exit 127
    fi
elif command -v sss2 &> /dev/null; then
    SERPENT_CMD="sss2"
elif command -v serpent &> /dev/null; then
    SERPENT_CMD="serpent"
elif [ -x "/opt/serpent/bin/sss2" ]; then
    SERPENT_CMD="/opt/serpent/bin/sss2"
elif [ -x "$HOME/serpent/bin/sss2" ]; then
    SERPENT_CMD="$HOME/serpent/bin/sss2"
fi

if [ -z "$SERPENT_CMD" ]; then
    echo "Serpent executable not found: set SERPENT_EXE to its path, or put sss2 in PATH." >&2
    exit 127
fi

echo "Using Serpent command: $SERPENT_CMD (OpenMP threads: ${SERPENT_OMP:-1})"
# Serpent writes <input>_res.m: remove the result of a previous run so that it cannot be mistaken for this one
rm -f "${input}_res.m"
"$SERPENT_CMD" "$input" -omp "${SERPENT_OMP:-1}" > serpent.out 2>&1
exit_code=$?

# Serpent reports input / fatal / tracking errors in its output (exit code 255 for input errors, but not always
# non-zero), and a run that did not complete writes no _res.m: all are failures, with the message on stderr
message=$(awk '/Input error|Fatal error|Tracking error|Geometry error:|Segmentation fault|error while loading/ {f=1}
               f && NF && !/^For parameter description|^http/ {print; n++} n>=6 {exit}' serpent.out)
if [ -z "$message" ] && [ ! -s "${input}_res.m" ]; then
    message="no ${input}_res.m written (run incomplete). Last lines of serpent.out:
$(tail -n 5 serpent.out)"
fi
if [ $exit_code -ne 0 ] || [ -n "$message" ]; then
    echo "Serpent failed (exit code $exit_code): ${message:-see serpent.out}" >&2
    [ $exit_code -ne 0 ] && exit $exit_code
    exit 1
fi

echo "Serpent calculation completed successfully"
exit 0
