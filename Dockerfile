# --- STAGE 1: Build rcon-cli natively for ARM64 ---
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS rcon-builder
ARG TARGETARCH

RUN apk add --no-cache git
RUN git clone --depth 1 https://github.com/gorcon/rcon-cli.git /src

# CGO_ENABLED=0 creates a static binary that won't Segfault on Ubuntu
RUN cd /src/cmd/gorcon && \
    CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -ldflags="-s -w" -o /rcon .

# --- STAGE 2: Shared Base ---
FROM --platform=linux/arm64 ubuntu:24.04 AS base
LABEL author="Arron Houston"
ENV DEBIAN_FRONTEND=noninteractive

# Install shared dependencies
RUN apt update && apt install -y \
    curl python3 python3-packaging python3-setuptools wget iproute2 xz-utils \
    libatomic1 libsdl2-2.0-0 libpulse0 libasound2t64 libc6 \
    libgcc-s1 libstdc++6 sudo ca-certificates software-properties-common expect \
    netcat-openbsd inetutils-telnet

# Install FEX-Emu
RUN add-apt-repository -y ppa:fex-emu/fex \
    && apt update \
    && apt install -y fex-emu-armv8.2

# FEX RootFS fetching
ARG ROOTFS_CACHEBUST=2024-05-01
RUN unbuffer FEXRootFSFetcher -y -x --distro-name ubuntu --distro-version 24.04 \
    && mkdir -p /opt/fex-emu/share /opt/fex-emu/config \
    && mv /root/.local/share/fex-emu/* /opt/fex-emu/share/ \
    && chmod -R 755 /opt/fex-emu

# --- NEW: Copy the native ARM64 rcon binary from Stage 1 ---
COPY --from=rcon-builder /rcon /usr/local/bin/rcon
RUN chmod +x /usr/local/bin/rcon

# SteamCMD manual install fallback
RUN if [ ! -f "/usr/lib/games/steamcmd/steamcmd.sh" ]; then \
    echo "SteamCMD not found in image, downloading manually..."; \
    mkdir -p /usr/lib/games/steamcmd; \
    cd /usr/lib/games/steamcmd; \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -; \
    fi

# --- STAGE 3: Installer Version ---
FROM base AS installer
RUN mkdir -p /root/.local/share /root/.config \
    && ln -s /opt/fex-emu/share/RootFS /root/.local/share/fex-emu/RootFS

# --- STAGE 4: Runtime Version ---
FROM base AS runtime

# Create the user and the home directory
RUN useradd -m -d /home/container container

# Switch to the unprivileged user
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]

# --- STAGE 5: Proton Asset Downloader ---
FROM base AS proton-downloader
ARG PROTON_VERSION="GE-Proton9-4"
RUN mkdir -p /opt/proton-ge && \
    curl -Lo /tmp/proton-ge.tar.gz "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz" && \
    tar -xvf /tmp/proton-ge.tar.gz -C /opt/proton-ge --strip-components=1 && \
    rm /tmp/proton-ge.tar.gz
    
# --- STAGE 6: Runtime - Proton (Separate Image) ---
FROM base AS runtime-proton

# Add libdbus-1-3 (often needed for Wine initialization)
RUN apt update && apt install -y \
    xvfb libvulkan1 libvulkan-dev vulkan-tools libgdiplus \
    libglu1-mesa libxcomposite1 libxcursor1 libxi6 libxtst6 libosmesa6 libdbus-1-3

# Pull Proton assets from the downloader
COPY --from=proton-downloader /opt/proton-ge /opt/proton-ge

# --- NEW: Bridge libraries into the FEX RootFS ---
# This links the Proton unix-side drivers into the emulated system's library path
RUN mkdir -p /opt/fex-emu/share/RootFS/Ubuntu_24_04/usr/lib/x86_64-linux-gnu && \
    ln -sf /opt/proton-ge/files/lib64/wine/x86_64-unix/*.so* /opt/fex-emu/share/RootFS/Ubuntu_24_04/usr/lib/x86_64-linux-gnu/ && \
    ln -sf /opt/proton-ge/files/lib64/*.so* /opt/fex-emu/share/RootFS/Ubuntu_24_04/usr/lib/x86_64-linux-gnu/

# Configure environment
ENV PATH="/opt/proton-ge/files/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/proton-ge/files/lib64:/opt/proton-ge/files/lib:${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

RUN chmod -R +x /opt/proton-ge/files/bin/
RUN useradd -m -d /home/container container
USER container
ENV USER=container HOME=/home/container WORKDIR=/home/container
ENV WINEPREFIX="/home/container/.wine"

COPY --chown=container:container ./entrypoint-proton.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
