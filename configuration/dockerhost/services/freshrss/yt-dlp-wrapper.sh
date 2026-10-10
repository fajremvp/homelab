#!/bin/sh
set -eu

if [ -n "${YTDLP_PROXY_URL:-}" ]; then
    exec /usr/local/bin/yt-dlp.real \
        --proxy "$YTDLP_PROXY_URL" "$@"
fi

exec /usr/local/bin/yt-dlp.real "$@"
