# See https://github.com/jlesage/docker-baseimage-gui

ARG app_version="3.70.2"
# Bump if publishing a new image with the same app_version, reset to 1 with new app versions
ARG image_revision="1"
# BUILDPLATFORM and TARGETPLATFORM are defined when using BuildKit (i.e. docker buildx)
# Do NOT define a default value or it will override what BuildKit sets
# Do NOT declare TARGETPLATFORM as an ARG before FROM either or it becomes empty
#ARG TARGETPLATFORM

FROM jlesage/baseimage-gui:debian-12-v4 AS extract-stage
ARG TARGETPLATFORM
ARG app_version
ARG download_url_template="https://github.com/mifi/lossless-cut/releases/download/v${app_version}/LosslessCut-linux-#ARCH#.tar.bz2"
#ARG download_url_template="https://github.com/mifi/lossless-cut/releases/latest/download/LosslessCut-linux-#ARCH#.tar.bz2"

# Fail early if TARGETPLATFORM isn't set
RUN test -n "${TARGETPLATFORM}"

# Note ADDing a local tarball automatically extracts it whereas a tarball url is downloaded AS-IS
#ADD ${download_url} /

# The LC_ALL is an attempt to prevent apt complaining about the locale
# Deduce LosslessCut architecture suffix based on TARGETPLATFORM
RUN LC_ALL=C add-pkg \
                ca-certificates \
                pbzip2 \
                wget \
    && { \
        [ $TARGETPLATFORM = linux/amd64 ] && echo x64 ; \
        [ $TARGETPLATFORM = linux/arm64 ] && echo arm64 ; \
        [ $TARGETPLATFORM = linux/arm/v7 ] && echo armv7l ; \
    } \
    | xargs -I '#ARCH#' \
        wget --progress=dot:giga -O /app.tbz ${download_url_template} \
    && tar -C / -I pbzip2 -xvf /app.tbz \
    && mv /LosslessCut-linux-*/ /LosslessCut

FROM jlesage/baseimage-gui:debian-12-v4 AS final-stage
ARG app_icon="https://raw.githubusercontent.com/mifi/lossless-cut/master/src/renderer/src/icon.svg"
ARG app_version
ARG image_revision
# Missing libraries as of v3.70.2 (Electron 42), adjusted to Debian 12
#  See the helper script 'generate_dependencies_list.bash'
RUN LC_ALL="C.UTF-8" add-pkg \
      libasound2 \
      libatk1.0-0 \
      libatk-bridge2.0-0 \
      libatspi2.0-0 \
      libavahi-client3 \
      libavahi-common3 \
      libblkid1 \
      libbrotli1 \
      libbsd0 \
      libcairo2 \
      libcairo-gobject2 \
      libcups2 \
      libdatrie1 \
      libdrm2 \
      libepoxy0 \
      libffi8 \
      libfontconfig1 \
      libfreetype6 \
      libfribidi0 \
      libgbm1 \
      libgcrypt20 \
      libgdk-pixbuf-2.0-0 \
      libglib2.0-0 \
      libgmp10 \
      libgnutls30 \
      libgraphite2-3 \
      libgssapi-krb5-2 \
      libgtk-3-0 \
      libharfbuzz0b \
      libhogweed6 \
      libidn2-0 \
      libjpeg62-turbo \
      libk5crypto3 \
      libkrb5-3 \
      libkrb5support0 \
      liblz4-1 \
      libmd0 \
      libmount1 \
      libnettle8 \
      libnspr4 \
      libnss3 \
      libp11-kit0 \
      libpango-1.0-0 \
      libpangocairo-1.0-0 \
      libpangoft2-1.0-0 \
      libpcre2-8-0 \
      libpixman-1-0 \
      libpng16-16 \
      libpulse0 \
      libsystemd0 \
      libtasn1-6 \
      libthai0 \
      libunistring2 \
      libuuid1 \
      libwayland-client0 \
      libwayland-cursor0 \
      libwayland-egl1 \
      libwayland-server0 \
      libx11-6 \
      libxau6 \
      libxcb1 \
      libxcb-randr0 \
      libxcb-render0 \
      libxcb-shm0 \
      libxcomposite1 \
      libxcursor1 \
      libxdamage1 \
      libxdmcp6 \
      libxext6 \
      libxfixes3 \
      libxi6 \
      libxinerama1 \
      libxkbcommon0 \
      libxrandr2 \
      libxrender1 \
      libzstd1

# some manual additions, mostly from v3.47.1
RUN LC_ALL="C.UTF-8" add-pkg \
      libgl1 \
      libx11-xcb1

COPY --from=extract-stage /LosslessCut /LosslessCut

# Workaround for LosslessCut on armv7l not containing ffmpeg
#  v3.70.x bundles FFmpeg 8.1 for x64 and arm64; only armv7l relies on this fallback
#  (which installs Debian's ffmpeg, an older version)
RUN test -x /LosslessCut/resources/ffmpeg \
    || ( LC_ALL=C add-pkg ffmpeg \
        && ln -s /usr/bin/ffmpeg /usr/bin/ffprobe /LosslessCut/resources/ \
    )

# Sandboxing doesn't appear to work, Docker should be sandboxed enough though
RUN echo '#!/bin/sh' > /startapp.sh \
    && echo 'exec /LosslessCut/losslesscut --no-sandbox' >> /startapp.sh \
    && chmod 0755 /startapp.sh

# Set app name, version and generate favicons
# The master icon is an SVG: render it to PNG first (imagemagick6 lacks an SVG delegate)
RUN set-cont-env APP_NAME "LosslessCut" \
    && set-cont-env APP_VERSION ${app_version} \
    && set-cont-env DOCKER_IMAGE_VERSION ${image_revision} \
    && LC_ALL=C add-pkg --virtual icon-tools ca-certificates libcurl4 curl librsvg2-bin \
    && curl -sS -L -f -o /tmp/master_icon.svg "$app_icon" \
    && rsvg-convert -w 512 -h 512 -o /tmp/master_icon.png /tmp/master_icon.svg \
    && install_app_icon.sh /tmp/master_icon.png \
    && del-pkg icon-tools

VOLUME ["/config", "/storage"]

# 5800: Web, 5900: VNC
EXPOSE 5800/tcp 5900/tcp

# Note the org.label-schema.* labels are inherited from the base image
LABEL \
      org.opencontainers.image.title="losslesscut-docker" \
      org.opencontainers.image.description="Docker container to make LosslessCut ${app_version} usable via web browser and VNC" \
      org.opencontainers.image.version="${app_version}-${image_revision}" \
      org.opencontainers.image.source="https://github.com/losslesscut-docker/losslesscut-docker" \
      org.opencontainers.image.licenses="GPL-2.0"

# Define HOME to ease usage of the file chooser
ENV HOME=/storage

# Default display size: a smaller framebuffer reduces noVNC encode/decode work
#  and makes the browser interface noticeably more responsive.
#  Override at runtime with -e DISPLAY_WIDTH=... -e DISPLAY_HEIGHT=...
ENV DISPLAY_WIDTH=1440
ENV DISPLAY_HEIGHT=900

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 CMD \
    pidof cinit \
    && pidof losslesscut \
    && nc -z -v 127.0.0.1 $WEB_LISTENING_PORT
