# Base image with R
FROM rocker/r-ver:4.3.3

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies required by KrigR and R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # General utilities
    curl git unzip gzip tar less debianutils \
    # GDAL / raster packages
    gdal-bin libgdal-dev libgeos-dev libproj-dev libudunits2-dev \
    # Fonts for systemfonts / ragg
    libfontconfig1-dev libfreetype6-dev libpng-dev libjpeg-dev libx11-dev \
    # SSL / XML / Git
    libssl-dev libxml2-dev libgit2-dev libsecret-1-dev \
    # Pandoc for R Markdown / pkgdown / knitr
    pandoc \
     # Text rendering
    libharfbuzz-dev libfribidi-dev \
    # Build tools
    cmake pkg-config \
    # Java (REQUIRED for rJava)
    openjdk-11-jdk-headless \
    libbz2-dev liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# Explicitly set JAVA_HOME (important for rJava)
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    PATH=/usr/lib/jvm/java-11-openjdk-amd64/bin:$PATH

RUN R CMD javareconf
# Set working directory
WORKDIR /src

# Copy renv.lock first for layer caching
COPY renv.lock /src/

# Install renv and restore packages from lockfile
RUN Rscript -e 'install.packages("renv"); renv::restore(prompt=FALSE)'
# Optionally, remove unused package caches to reduce image size
RUN Rscript -e 'renv::clean()'

# Default command
ENTRYPOINT ["Rscript"]
CMD ["--help"]
