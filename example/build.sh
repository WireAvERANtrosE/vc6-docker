#!/bin/bash

# Exit on error
set -e

# Add the tools directory to the PATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
TOOLS_DIR="$PARENT_DIR/tools"

export PATH="$TOOLS_DIR:$PATH"

# Create build directory
BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure using our VC6 toolchain
cmake -DCMAKE_TOOLCHAIN_FILE="$PARENT_DIR/vc6-toolchain.cmake" ..

# Build the project
cmake --build .

echo "Build complete. To run the example, use: ./run.sh"