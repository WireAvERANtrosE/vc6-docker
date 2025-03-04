#!/bin/bash

# Get the absolute path of the project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the Docker container and execute the binary
docker run --rm --platform linux/amd64 \
  -v "${PROJECT_DIR}:/project" \
  -w "/project" \
  vc6-docker \
  ./build/run.sh