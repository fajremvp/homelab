ARG FRESHRSS_VERSION
FROM freshrss/freshrss:${FRESHRSS_VERSION}

ARG YTDLP_VERSION
ARG DENO_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        python3 \
        unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL \
      "https://github.com/yt-dlp/yt-dlp/releases/download/${YTDLP_VERSION}/yt-dlp" \
      -o /usr/local/bin/yt-dlp \
    && chmod 0755 /usr/local/bin/yt-dlp

RUN curl -fsSL \
      "https://github.com/denoland/deno/releases/download/v${DENO_VERSION}/deno-x86_64-unknown-linux-gnu.zip" \
      -o /tmp/deno.zip \
    && unzip /tmp/deno.zip -d /usr/local/bin \
    && chmod 0755 /usr/local/bin/deno \
    && rm /tmp/deno.zip

RUN yt-dlp --version \
    && deno --version \
    && python3 --version
