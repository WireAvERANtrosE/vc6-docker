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
# Standard build
docker build . --tag giulioz/vc6-docker
```

### Caching Downloads

The Dockerfile is designed to cache the Visual C++ 6.0 download from WinWorld. When rebuilding the image, Docker will use the cached download layer if available, avoiding the need to re-download the large files.

If you want to provide a mirror or different download location, you can modify the `download-options` file:

```bash
# Example: Edit the download-options file to use a different URL
echo "VC6_DOWNLOAD_URL=https://your-mirror.example.com/vc6.7z" > download-options

# Then build as normal
docker build . --tag giulioz/vc6-docker
```

For complete cache control, you can use Docker's cache options:

```bash
# Force a clean build without using cache
docker build --no-cache . -t giulioz/vc6-docker

# Cache only the download stage (useful for CI/CD)
docker build --target downloader . -t vc6-download-cache
docker build . -t giulioz/vc6-docker
```

### Distribution

To distribute the image in a registry:

```bash
# Build and push to a registry
docker build . -t giulioz/vc6-docker
docker push giulioz/vc6-docker
```

The container will run the same way on any platform (ARM/M1/M2 Macs, x86_64 Linux/Windows) without any special flags or configuration.
