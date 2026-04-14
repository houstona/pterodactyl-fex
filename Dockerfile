# --- STAGE 1: Shared Base ---
# This stage contains everything both versions need. 
# It is built once and cached for both targets.
FROM --platform=linux/arm64 ubuntu:24.04 AS base
LABEL author="Arron Houston"
ENV DEBIAN_FRONTEND=noninteractive

# Install shared dependencies (including 'expect' for unbuffer)
RUN apt update && apt install -y \
    curl python3 python3-packaging python3-setuptools wget iproute2 xz-utils \
    libatomic1 libsdl2-2.0-0 libpulse0 libasound2t64 libc6 \
    libgcc-s1 libstdc++6 sudo ca-certificates software-properties-common expect \
    netcat-openbsd inetutils-telnet

# Install FEX-Emu (armv8.2 specifically for Oracle Cloud compatibility) [cite: 4]
RUN add-apt-repository -y ppa:fex-emu/fex \
    && apt update \
    && apt install -y fex-emu-armv8.2

# Heavy RootFS download - this will be the main cached layer
ARG ROOTFS_CACHEBUST=2024-05-01
RUN unbuffer FEXRootFSFetcher -y -x --distro-name ubuntu --distro-version 24.04 \
    && mkdir -p /opt/fex-emu/share /opt/fex-emu/config \
    && mv /root/.local/share/fex-emu/* /opt/fex-emu/share/ \
    && chmod -R 755 /opt/fex-emu

# Install rcon-cli (shared by both for management)
RUN cd /tmp \
    && curl -sSL https://github.com/gorcon/rcon-cli/releases/download/v0.10.3/rcon-0.10.3-linux-arm64.tar.gz -o rcon.tar.gz \
    && tar -xzvf rcon.tar.gz \
    && mv rcon-0.10.3-linux-arm64/rcon /usr/local/bin/rcon \
    && chmod +x /usr/local/bin/rcon \
    && rm -rf rcon.tar.gz rcon-0.10.3-linux-arm64

RUN if [ ! -f "/usr/lib/games/steamcmd/steamcmd.sh" ]; then \
    echo "SteamCMD not found in image, downloading manually..."; \
    mkdir -p /usr/lib/games/steamcmd; \
    cd /usr/lib/games/steamcmd; \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -; \
    fi


# --- STAGE 2: Installer Version ---
# This stage builds off the base but stays as the 'root' user for Pterodactyl's installation phase.
FROM base AS installer
# Create symlinks so FEX works for root even if Pterodactyl mounts over /root
RUN mkdir -p /root/.local/share /root/.config \
    && ln -s /opt/fex-emu/share/RootFS /root/.local/share/fex-emu/RootFS


# --- STAGE 3: Runtime Version ---
# This stage builds off the same base but adds the unprivileged 'container' user for running the game.
FROM base AS runtime
RUN useradd -m -d /home/container container
USER container
ENV USER=container HOME=/home/container
WORKDIR /home/container

# Copy entrypoint at the very end to prevent it from busting the FEX cache 
COPY --chown=container:container ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
