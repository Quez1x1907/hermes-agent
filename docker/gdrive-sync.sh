#!/bin/sh
# Fork: persist /opt/data to Google Drive so state survives redeploys.
# Driven by env: GDRIVE_RCLONE_TOKEN (rclone token JSON for the drive remote),
# optional GDRIVE_CLIENT_ID / GDRIVE_CLIENT_SECRET,
# GDRIVE_SYNC_SECONDS (push interval, default 600).
set -e

[ -n "${GDRIVE_RCLONE_TOKEN:-}" ] || exit 0
command -v rclone >/dev/null 2>&1 || exit 0

export RCLONE_CONFIG_GDRIVE_TYPE=drive
export RCLONE_CONFIG_GDRIVE_TOKEN="$GDRIVE_RCLONE_TOKEN"
if [ -n "${GDRIVE_CLIENT_ID:-}" ]; then
    export RCLONE_CONFIG_GDRIVE_CLIENT_ID="$GDRIVE_CLIENT_ID"
    export RCLONE_CONFIG_GDRIVE_CLIENT_SECRET="${GDRIVE_CLIENT_SECRET:-}"
fi

if rclone copy gdrive:hermes-state /opt/data --transfers 4 --quiet; then
    echo "[gdrive-sync] restored /opt/data from gdrive:hermes-state"
else
    echo "[gdrive-sync] restore failed (first boot or drive error); starting empty"
fi
chown -R hermes:hermes /opt/data 2>/dev/null || true

INTERVAL="${GDRIVE_SYNC_SECONDS:-600}"
nohup sh -c "
    while true; do
        sleep $INTERVAL
        rclone copy /opt/data gdrive:hermes-state --transfers 4 --quiet || true
    done
" >/var/log/gdrive-sync.log 2>&1 &
echo "[gdrive-sync] background push loop started (interval ${INTERVAL}s)"
