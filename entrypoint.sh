#!/bin/bash

# 1. Architecture Pivot (Move this to the VERY top)
if [ "$(uname -m)" != "x86_64" ]; then
    # Use the specific distro folder verified by your 'ls' output
    export FEX_ROOTFS='/opt/fex-emu/share/RootFS/Ubuntu_24_04'
    export FEX_LOGFILE=0
    export FEX_SILENT=1
    export FEX_TSO_EMULATION=0
    
    # Force FEX to look for its internal config in a place it can actually write to
    export XDG_CONFIG_HOME='/home/container/.config'
    export XDG_DATA_HOME='/home/container/.local/share'
    export FEX_MAX_CODE_CACHE_SIZE=512
    mkdir -p /home/container/.config/fex-emu
    
    echo "Pivoting to x86_64 environment using RootFS at $FEX_ROOTFS..."
    
    # exec replaces the ARM process with the x86 translated process
    exec FEXBash "$0" "$@"
fi

# --- Everything below runs as x86_64 ---

# 2. Standard Pterodactyl setup
cd /home/container
export USER=container
export HOME=/home/container

export FEX_ROOTFS='/opt/fex-emu/share/RootFS/Ubuntu_24_04'
export FEX_LOGFILE=0
export FEX_SILENT=1
export FEX_TSO_EMULATION=0

# Force FEX to look for its internal config in a place it can actually write to
export XDG_CONFIG_HOME='/home/container/.config'
export XDG_DATA_HOME='/home/container/.local/share'
export FEX_MAX_CODE_CACHE_SIZE=512
ulimit -n 65535

mkdir -p /home/container/.steam/sdk64
ln -sf /home/container/steamclient.so /home/container/.steam/sdk64/steamclient.so

# 3. Startup logic
MODIFIED_STARTUP=$(echo -e ${STARTUP} | sed -e 's/{{/${/g' -e 's/}}/}/g')

echo "LAUNCHING: ${MODIFIED_STARTUP}"

# Run the command
eval "${MODIFIED_STARTUP}" &
GAME_PID=$!

# The Bridge: By putting a '-' in front of $GAME_PID, we hit PID 19, 20, and anything else in that tree
trap 'echo "[SIGNAL] Forwarding to Process Group... "; kill -TERM -"$GAME_PID"; wait "$GAME_PID"; exit 0' SIGINT SIGTERM

echo "ENTRYPOINT: Monitoring Process Group: $GAME_PID"
wait "$GAME_PID"
