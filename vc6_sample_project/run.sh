#!/bin/bash

# Check if Wine is available
if ! command -v wine &> /dev/null; then
    echo "Error: Wine is not installed or not in PATH."
    echo "This script is meant to run inside the Docker container."
    echo "Use docker-run.sh to run with Docker."
    exit 1
fi

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
EXECUTABLE="${BUILD_DIR}/vc6_sample.exe"

# Check if the executable exists
if [ ! -f "${EXECUTABLE}" ]; then
    echo "Error: Executable file not found: ${EXECUTABLE}"
    echo "Please build the project first using build.sh"
    exit 1
fi

# Run the executable through Wine
wine "${EXECUTABLE}"