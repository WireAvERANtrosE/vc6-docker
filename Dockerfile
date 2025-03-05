# syntax=docker/dockerfile:1

# Stage 0: Download stage using Docker build cache
FROM --platform=linux/amd64 debian:bullseye AS downloader

# Install only what's needed for downloading
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Create a directory for downloads
WORKDIR /downloads

# Copy files for download caching
# The cache-marker.txt is optional and only used to invalidate cache when needed
COPY download-options cache-marker.txt* /downloads/

# Download VC++ 6.0 archive - this will be cached by Docker layer caching
# The download will be cached as long as download-options and cache-marker.txt don't change
RUN . /downloads/download-options && \
    echo "Downloading VC++ 6.0 from: $VC6_DOWNLOAD_URL" && \
    wget -O vc6.7z "$VC6_DOWNLOAD_URL"

# Stage 1: Extract and prepare VC++ 6.0 files (Always using amd64/x86_64)
FROM --platform=linux/amd64 debian:latest AS builder

# Install necessary tools to extract files
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    p7zip-full && \
    rm -rf /var/lib/apt/lists/*

# Copy the downloaded files from the downloader stage
COPY --from=downloader /downloads/vc6.7z /tmp/vc6.7z

# Extract and setup Visual C++ 6.0
RUN mkdir -p /opt/vc && cd /opt/vc && \
    7z x /tmp/vc6.7z && \
    mkdir -p /opt/vc/setup && cd /opt/vc/setup && \
    7z x '../Microsoft Visual C++ 6.0 Standard.iso' && \
    rm -f ../*.iso && \
    find .. -name "*.txt" -type f -delete && \
    find .. -name "*.7z" -type f -delete && \
    mv VC98/* .. && \
    cp -r COMMON/MSDEV98/BIN/* ../BIN

# Fix inconsistent file names
RUN \
  mv /opt/vc/CRT/SRC/ALGRITHM /opt/vc/CRT/SRC/ALGORITHM && \
  mv /opt/vc/CRT/SRC/FCTIONAL /opt/vc/CRT/SRC/FUNCTIONAL && \
  mv /opt/vc/CRT/SRC/MAKEFILE /opt/vc/CRT/SRC/EXT_MKF && \
  mv /opt/vc/CRT/SRC/MAKEFILE.INC /opt/vc/CRT/SRC/EXT_MKF.INC && \
  mv /opt/vc/CRT/SRC/MAKEFILE.SUB /opt/vc/CRT/SRC/EXT_MKF.SUB && \
  mv /opt/vc/CRT/SRC/STDXCEPT /opt/vc/CRT/SRC/STDEXCEPT && \
  mv /opt/vc/CRT/SRC/STREAMBF /opt/vc/CRT/SRC/STREAMBUF && \
  mv /opt/vc/CRT/SRC/STRSTREM /opt/vc/CRT/SRC/STRSTREAM && \
  mv /opt/vc/CRT/SRC/XCEPTION /opt/vc/CRT/SRC/EXCEPTION && \
  mv /opt/vc/INCLUDE/ALGRITHM /opt/vc/INCLUDE/ALGORITHM && \
  mv /opt/vc/INCLUDE/FCTIONAL /opt/vc/INCLUDE/FUNCTIONAL && \
  mv /opt/vc/INCLUDE/STDXCEPT /opt/vc/INCLUDE/STDEXCEPT && \
  mv /opt/vc/INCLUDE/STREAMBF /opt/vc/INCLUDE/STREAMBUF && \
  mv /opt/vc/INCLUDE/STRSTREM /opt/vc/INCLUDE/STRSTREAM && \
  mv /opt/vc/INCLUDE/XCEPTION /opt/vc/INCLUDE/EXCEPTION && \
  mv /opt/vc/INCLUDE/EVNCPTSI.C /opt/vc/INCLUDE/EVENTCPTS_I.C && \
  mv /opt/vc/INCLUDE/EVNTCPTS.H /opt/vc/INCLUDE/EVENTCPTS.H && \
  mv /opt/vc/INCLUDE/MTSEVNTS.H /opt/vc/INCLUDE/MTSEVENTS.H && \
  mv /opt/vc/INCLUDE/MTSEVT_I.C /opt/vc/INCLUDE/MTSEVENTS_I.C && \
  mv /opt/vc/INCLUDE/MTXADM_I.C /opt/vc/INCLUDE/MTXADMIN_I.C && \
  mv /opt/vc/INCLUDE/OLEDBSPC.HH /opt/vc/INCLUDE/OLEDB11SPEC.HH && \
  mv /opt/vc/INCLUDE/SDKPRBLD.MAK /opt/vc/INCLUDE/SDKPROPBLD.MAK && \
  mv /opt/vc/INCLUDE/SCRDDT_I.C /opt/vc/INCLUDE/SCARDDAT_I.C && \
  mv /opt/vc/INCLUDE/SCRMGR_I.C /opt/vc/INCLUDE/SCARDMGR_I.C && \
  mv /opt/vc/INCLUDE/SCRSRV_I.C /opt/vc/INCLUDE/SCARDSRV_I.C && \
  mv /opt/vc/INCLUDE/SSPSDL_I.C /opt/vc/INCLUDE/SSPSID_I.C

# Stage 2: Final container that will always run as x86_64
FROM --platform=linux/amd64 debian:latest

# Add i386 architecture support and install wine, xvfb, cmake and git
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine \
    wine32 \
    cmake \
    make \
    xvfb \
    ca-certificates \
    cmake \
    git \
    python3 \
    python-is-python3 && \
    rm -rf /var/lib/apt/lists/*

# Copy prepared VC++ 6.0 files from the builder stage
COPY --from=builder /opt/vc /opt/vc

# Setup environment for headless wine operation
ENV DISPLAY=:0.0
ENV WINEDEBUG=-all

# Create entrypoint script to start Xvfb
RUN echo '#!/bin/bash\nXvfb :0 -screen 0 1024x768x16 &\nsleep 1\nexec "$@"' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Create a helper script to launch wine with VC6 environment
RUN echo '#!/bin/bash\nwine cmd /c Z:\\opt\\vc\\setup.bat "&&" "$@"' > /opt/vc/runvc6.sh && \
    chmod +x /opt/vc/runvc6.sh

# Create a helper script for building CnC projects with CMake
RUN echo '#!/bin/bash\n\
# Configure and build CnC Generals Zero Hour with CMake using the Python proxy approach\n\
if [ "$#" -lt 1 ]; then\n\
  echo "Usage: $0 <source_dir> [build_dir]"\n\
  exit 1\n\
fi\n\
\n\
SOURCE_DIR="$1"\n\
BUILD_DIR="${2:-${SOURCE_DIR}/build/vc6}"\n\
\n\
# Create build directory if it doesn\'t exist\n\
mkdir -p "$BUILD_DIR"\n\
cd "$BUILD_DIR"\n\
\n\
# Add our tools directory to the PATH\n\
export PATH="/opt/vc/tools:$PATH"\n\
\n\
# Configure with CMake using our toolchain file\n\
cmake \\\n\
  -DCMAKE_TOOLCHAIN_FILE="/opt/vc/vc6-toolchain.cmake" \\\n\
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \\\n\
  -DCMAKE_BUILD_TYPE=Release \\\n\
  "$SOURCE_DIR"\n\
\n\
if [ $? -ne 0 ]; then\n\
  echo "CMake configuration failed"\n\
  exit 1\n\
fi\n\
\n\
# Build with CMake\n\
cmake --build .\n\
\n\
if [ $? -ne 0 ]; then\n\
  echo "Build failed"\n\
  exit 1\n\
fi\n\
\n\
echo "Build completed successfully"\n\
' > /opt/vc/build_cnc.sh && \
    chmod +x /opt/vc/build_cnc.sh

# Skip wine initialization during build (will initialize on first run)

# Copy configuration files
COPY setup.bat /opt/vc/setup.bat
COPY copy_includes.sh /opt/vc/copy_includes.sh

# Copy our Python proxy tools
COPY tools /opt/vc/tools
COPY vc6-toolchain.cmake /opt/vc/vc6-toolchain.cmake
RUN chmod +x /opt/vc/tools/*.py

# Copy example project
COPY example /opt/vc/example
RUN chmod +x /opt/vc/example/build.sh

# Set working directory
WORKDIR /opt/vc

# Use the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
