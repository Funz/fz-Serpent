#!/bin/bash

# Serpent calculator script for fz framework
# This script runs Serpent Monte Carlo calculations
#
# Usage:
#   bash .fz/calculators/Serpent.sh <input_file_or_directory>
#
# Prerequisites:
#   - Serpent must be installed and available in PATH (as 'sss2' or 'serpent')
#   - serpentTools Python package must be installed (pip install serpentTools)

# if directory as input, cd into it
if [ -d "$1" ]; then
  cd "$1"
  # Find the first .inp input file
  input=$(ls *.inp 2>/dev/null | head -n 1)
  if [ -z "$input" ]; then
    echo "No .inp input file found in directory. Exiting."
    exit 1
  fi
  shift
# if $1 is a file, use it
elif [ -f "$1" ]; then
  input="$1"
  shift
else
  echo "Usage: $0 <input_file or input_directory>"
  exit 2
fi

PID_FILE=$PWD/PID
echo $$ >> $PID_FILE

# Get the base name of the input file (without extension)
basename="${input%.*}"

echo "Running Serpent calculation on $input..."

# Check if Serpent is available
SERPENT_CMD=""
if command -v sss2 &> /dev/null; then
    SERPENT_CMD="sss2"
elif command -v serpent &> /dev/null; then
    SERPENT_CMD="serpent"
else
    echo "Warning: Serpent not found in PATH"
    echo "Looking for sss2 or serpent commands..."
    # Try common installation paths
    if [ -x "/opt/serpent/bin/sss2" ]; then
        SERPENT_CMD="/opt/serpent/bin/sss2"
    elif [ -x "$HOME/serpent/bin/sss2" ]; then
        SERPENT_CMD="$HOME/serpent/bin/sss2"
    fi
fi

if [ -n "$SERPENT_CMD" ]; then
    echo "Using Serpent command: $SERPENT_CMD"
    # Run Serpent
    $SERPENT_CMD "$input" > serpent.out 2>&1
    exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        echo "Serpent exited with error code: $exit_code"
        cat serpent.out
    else
        echo "Serpent calculation completed successfully"
    fi
else
    echo "Serpent executable not found. Cannot run calculation."
    echo "Please ensure Serpent is installed and available in PATH."
    exit 1
fi

# Clean up PID file
if [ -f "$PID_FILE" ]; then
    rm -f "$PID_FILE"
fi
