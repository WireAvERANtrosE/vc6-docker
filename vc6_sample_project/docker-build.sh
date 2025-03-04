#!/bin/bash

# Get the absolute path of the project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run the Docker container and build the project
docker run --rm --platform linux/amd64 \
  -v "${PROJECT_DIR}:/project" \
  -w "/project" \
  vc6-docker \
  bash -c "apt-get update && apt-get install -y make python3 && ./build.sh"

echo "Docker build completed."