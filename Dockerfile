FROM --platform=linux/arm64 ubuntu:24.04

LABEL author="Arron Houston" maintainer="arron@example.com"

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for FEX and SteamCMD
RUN apt update && apt install -y \
    curl python3 wget iproute2 xz-utils libatomic1 \
    libsdl2-2.0-0 libpulse0 libasound2 libc6 \
    libgcc-s1 libstdc++6 sudo ca-certificates

# Install FEX-Emu via Official Script
RUN curl --silent https://raw.githubusercontent.com/FEX-Emu/FEX/main/Scripts/InstallFEX.py | python3

# Add the Pterodactyl user
RUN useradd -m -d /home/container container
USER container
ENV USER=container
ENV HOME=/home/container
WORKDIR /home/container

# Setup FEX RootFS for the container user
# Note: In a production image, you'd ideally pre-download a RootFS to /usr/share/fex-emu/RootFS
RUN FEXRootFSFetcher --distro ubuntu-24.04

COPY ./entrypoint.sh /entrypoint.sh
CMD ["/bin/bash", "/entrypoint.sh"]
