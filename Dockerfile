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

sudo apt-get update
sudo apt-get install xvfb

# Inside your Dockerfile, after FEX is installed:
WORKDIR /usr/local/wine
# Download a portable Wine build (Make sure to grab the x86_64 tar.xz)
RUN curl -L "https://github.com/Kron4ek/Wine-Builds/releases/download/8.14/wine-8.14-amd64.tar.xz" -o wine.tar.xz \
    && tar -xvf wine.tar.xz --strip-components=1 \
    && rm wine.tar.xz

RUN ln -s /usr/local/wine/bin/wine /usr/local/bin/wine \
    && ln -s /usr/local/wine/bin/wine64 /usr/local/bin/wine64

# Fix permissions
# Ensure the non-root user can read and execute the Wine binaries
RUN chmod -R 755 /usr/local/wine

# Create the user and the home directory first as root
RUN useradd -m -d /home/container container

# Now switch to the unprivileged user
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
