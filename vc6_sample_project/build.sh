#!/bin/bash

# Check prerequisites
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is required but not found."
    exit 1
fi

if ! command -v cmake &> /dev/null; then
    echo "Error: CMake is required but not found."
    exit 1
fi

if ! command -v make &> /dev/null; then
    echo "Error: make is required but not found."
    exit 1
fi

# Get the script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"

# Clean up any existing build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}/obj"
mkdir -p "${BUILD_DIR}/idl_output/sample"

# Make sure the tools directory is in the PATH
export PATH="${SCRIPT_DIR}/tools:${PATH}"
chmod +x "${SCRIPT_DIR}/tools/winetools.py"

# Configure using CMake
echo "Configuring with CMake..."
cd "${BUILD_DIR}"
cmake "${SCRIPT_DIR}"

if [ $? -ne 0 ]; then
    echo "Error: CMake configuration failed."
    exit 1
fi

# Build with make
echo "Building the project..."
make

if [ $? -ne 0 ]; then
    echo "Error: Build failed."
    exit 1
fi

echo "Build completed successfully!"
echo "To run the program, use: ./build/run.sh"