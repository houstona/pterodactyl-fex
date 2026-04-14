ARG TARGETPLATFORM=linux/arm64
FROM --platform=$TARGETPLATFORM ubuntu:24.04

LABEL author="Arron Houston"

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for FEX and SteamCMD
# (Added software-properties-common for add-apt-repository)
RUN apt update && apt install -y \
    curl python3 python3-packaging python3-setuptools wget iproute2 xz-utils \
    libatomic1 libsdl2-2.0-0 libpulse0 libasound2t64 libc6 \
    libgcc-s1 libstdc++6 sudo ca-certificates software-properties-common

# Add the FEX PPA and install the FEX emulator directly.
# We explicitly install armv8.2 for Oracle Cloud compatibility 
RUN add-apt-repository -y ppa:fex-emu/fex \
    && apt update \
    && apt install -y fex-emu-armv8.2

# Install native ARM64 rcon-cli
RUN cd /tmp \
    && curl -sSL https://github.com/itzg/rcon-cli/releases/download/1.6.4/rcon-cli_1.6.4_linux_arm64.tar.gz -o rcon-cli.tar.gz \
    && tar -xzvf rcon-cli.tar.gz rcon-cli \
    && mv rcon-cli /usr/local/bin/rcon-cli \
    && chmod +x /usr/local/bin/rcon-cli \
    && rm rcon-cli.tar.gz

# Add the Pterodactyl user
RUN useradd -m -d /home/container container
USER container
ENV USER=container
ENV HOME=/home/container
WORKDIR /home/container

# Setup FEX RootFS for the container user
# Note: In a production image, you'd ideally pre-download a RootFS to /usr/share/fex-emu/RootFS
RUN FEXRootFSFetcher -y -x --distro-name ubuntu --distro-version 24.04

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
