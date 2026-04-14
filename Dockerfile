# --- STAGE 1: Build rcon-cli natively for the target architecture ---
FROM --platform=$BUILDPLATFORM golang:1.22-alpine AS rcon-builder
ARG TARGETARCH
WORKDIR /src

# Install git to clone the repo
RUN apk add --no-cache git

# Clone, go to the source directory, and build
RUN git clone --depth 1 --branch v0.10.3 https://github.com/gorcon/rcon-cli.git . \
    && cd cmd/rcon \
    && GOARCH=$TARGETARCH go build -o /build/rcon .


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
COPY --from=rcon-builder /go/bin/rcon-cli /usr/local/bin/rcon
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
RUN useradd -m -d /home/container container
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
