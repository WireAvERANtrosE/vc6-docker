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
    wget -O vc6.7z "$VC6_DOWNLOAD_URL" && \
    echo "Downloading CMake for Windows (64-bit)" && \
    wget -O cmake-win64.zip "https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-windows-x86_64.zip" && \
    echo "Downloading CMake for Windows (32-bit)" && \
    wget -O cmake-win32.zip "https://github.com/Kitware/CMake/releases/download/v3.28.1/cmake-3.28.1-windows-i386.zip" && \
    echo "Downloading Git for Windows (32-bit)" && \
    wget -O git-win32.zip "https://github.com/git-for-windows/git/releases/download/v2.44.0.windows.1/PortableGit-2.44.0-32-bit.7z.exe"

# Stage 1: Extract and prepare VC++ 6.0 files and CMake (Always using amd64/x86_64)
FROM --platform=linux/amd64 debian:latest AS builder

# Install necessary tools to extract files
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    p7zip-full \
    unzip && \
    rm -rf /var/lib/apt/lists/*

# Copy the downloaded files from the downloader stage
COPY --from=downloader /downloads/vc6.7z /tmp/vc6.7z
COPY --from=downloader /downloads/cmake-win64.zip /tmp/cmake-win64.zip
COPY --from=downloader /downloads/cmake-win32.zip /tmp/cmake-win32.zip
COPY --from=downloader /downloads/git-win32.zip /tmp/git-win32.zip

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

# Extract CMake for Windows (both 32-bit and 64-bit)
RUN mkdir -p /opt/cmake && \
    mkdir -p /opt/cmake/win64 && \
    mkdir -p /opt/cmake/win32 && \
    cd /opt/cmake/win64 && \
    unzip /tmp/cmake-win64.zip && \
    mv cmake-*/* . && \
    rmdir cmake-* && \
    cd /opt/cmake/win32 && \
    unzip /tmp/cmake-win32.zip && \
    mv cmake-*/* . && \
    rmdir cmake-*

# Extract Git for Windows (32-bit)
RUN mkdir -p /opt/git && \
    cd /opt/git && \
    7z x /tmp/git-win32.zip

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

# Add i386 architecture support and install wine and xvfb for headless operation
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    wine \
    wine32 \
    xvfb \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Copy prepared VC++ 6.0 files, CMake, and Git from the builder stage
COPY --from=builder /opt/vc /opt/vc
COPY --from=builder /opt/cmake /opt/cmake
COPY --from=builder /opt/git /opt/git

# Setup environment for headless wine operation
ENV DISPLAY=:0.0
ENV WINEDEBUG=-all

# Create entrypoint script to start Xvfb
RUN echo '#!/bin/bash\nXvfb :0 -screen 0 1024x768x16 &\nsleep 1\nexec "$@"' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

# Skip wine initialization during build (will initialize on first run)

# Copy configuration files
COPY setup.bat /opt/vc/setup.bat
COPY copy_includes.sh /opt/vc/copy_includes.sh

# Copy test project
COPY cmake_test_project /opt/vc/cmake_test_project

# Set working directory
WORKDIR /opt/vc

# Use the entrypoint script
ENTRYPOINT ["/entrypoint.sh"]
CMD ["wine", "cmd", "/k", "setup.bat"]