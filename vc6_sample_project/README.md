# VC6 Sample Project with CMake

This project demonstrates how to use CMake to build a C++ project using Visual C++ 6.0 through Wine on Linux or macOS. It provides a complete cross-compilation setup with proper path conversion between Unix and Windows paths.

## Features

- Uses CMake to manage the build process
- Uses Python to handle path conversions
- Compiles C++ code with Visual C++ 6.0 through Wine
- Processes IDL files with the MIDL compiler
- Works on Linux and macOS (including M1 Macs) using Docker

## Prerequisites

To use this project, you need:

1. Docker installed on your system
2. The VC6 Docker image built from the parent directory

## Project Structure

```
vc6_sample_project/
├── build.sh              - Build script for Docker
├── docker-build.sh       - Script to build using Docker
├── docker-run.sh         - Script to run using Docker
├── tools/
│   └── winetools.py      - Python helper for Wine/VC6 commands
├── cmake/               
├── CMakeLists.txt        - Main CMake configuration
├── include/
│   └── sample.h          - Header file
└── src/
    ├── main.cpp          - Main application source
    ├── sample.cpp        - Sample class implementation
    └── sample.idl        - IDL file for MIDL compiler
```

## Building the Project

### Using Docker (Recommended)

1. First, build the Docker image if you haven't already:

```bash
cd /path/to/vc6-docker
docker build -t vc6-docker .
```

2. Run the Docker build script:

```bash
./docker-build.sh
```

## Running the Project

```bash
./docker-run.sh
```

## How It Works

### Python Helper (winetools.py)

The project uses a Python script (`tools/winetools.py`) to:

1. Convert paths between Unix and Windows formats using `winepath`
2. Create temporary batch files for executing VC6 commands
3. Run commands through Wine with the proper environment

### CMake Integration

The CMake build system:

1. Defines custom targets for IDL compilation, C++ compilation, and linking
2. Uses the Python helper to execute VC6 commands
3. Manages dependencies between different build steps
4. Creates a run script for the final executable

### Build Process

1. The IDL file is compiled using MIDL.EXE
2. C++ source files are compiled using CL.EXE
3. The generated object files are linked using LINK.EXE
4. A run script is created to execute the program through Wine

## Using with Your Own Projects

To adapt this for your own projects:

1. Copy the `tools/winetools.py` file to your project
2. Create a CMakeLists.txt that uses the winetools.py helper
3. Add your source files and IDL files to the project
4. Update the build scripts as needed