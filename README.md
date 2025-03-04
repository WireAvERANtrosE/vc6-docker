# Visual C++ 6.0 over Docker

Have you ever needed to build some C++ code for an old version of Windows using Visual C++ 6.0 from 1998? No? Well anyways here's a working toolchain on a Docker container for it.

![Thumbnail](./thumb.jpg)

## Using it

```bash
# Starts a Windows CMD
docker run --rm -it -v $(pwd):/prj giulioz/vc6-docker

# On SELinux systems (like Fedora, RHEL, CentOS), use the :Z volume flag
# docker run --rm -it -v $(pwd):/prj:Z giulioz/vc6-docker

# Inside the CMD...
cd z:\prj

# Now you can use the compiler!
cd example
cl test.cpp /IZ:\opt\vc\include /GX /link /LIBPATH:Z:\opt\vc\LIB
test # Hello world!
```

You can also use a Makefile:

```bash
# While in the example folder...
nmake
test # Hello world!
```

### Getting the includes

When working with your editor of choice (like VS Code) you may need to configure the include path for the suggestions. Since the files are inside the container, you can use the following command to copy them in your machine.

```bash
docker run --rm -v $(pwd):/prj giulioz/vc6-docker bash /opt/vc/copy_includes.sh

# On SELinux systems (like Fedora, RHEL, CentOS), use the :Z volume flag
# docker run --rm -v $(pwd):/prj:Z giulioz/vc6-docker bash /opt/vc/copy_includes.sh
```

## Building it

The Docker image is now self-contained and runs on any platform without the need for platform flags during `docker run`. It uses a multi-stage build approach where the final image is always x86_64/amd64 regardless of the build platform.

### Standard Build

```bash
# Standard build with layer caching
docker build . --tag giulioz/vc6-docker
```

### Caching Downloads

The Dockerfile is designed to cache the Visual C++ 6.0 download using Docker's layer caching mechanism. The download layer depends on the `download-options` file and an optional `cache-marker.txt` file, so it will be cached as long as these files don't change.

If you want to use a mirror or different download location, you can modify the `download-options` file:

```bash
# Example: Edit the download-options file to use a different URL
echo "VC6_DOWNLOAD_URL=https://your-mirror.example.com/vc6.7z" > download-options

# Then build as normal
docker build . --tag giulioz/vc6-docker
```

To force a re-download of the VC++ package, you can:

```bash
# Method 1: Force a clean build without using any cache
docker build --no-cache . -t giulioz/vc6-docker

# Method 2: Update the cache marker to invalidate just the download layer
echo "v2" > cache-marker.txt
```

The `cache-marker.txt` file provides a way to invalidate just the download cache without affecting other build layers, which is useful when you need to re-download the package but don't want to rebuild everything from scratch.

### Distribution

To distribute the image in a registry:

```bash
# Build and push to a registry
docker build . -t giulioz/vc6-docker
docker push giulioz/vc6-docker
```

The container will run the same way on any platform (ARM/M1/M2 Macs, x86_64 Linux/Windows) without any special flags or configuration.
