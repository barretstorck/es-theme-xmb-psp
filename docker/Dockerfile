# Headless batocera-emulationstation for es-theme-xmb-psp theme testing.
# Renders via desktop GL21 (Mesa software) — a dev aid, NOT a release gate.
#
# Two images come out of this one file, selected by WITH_VIDEO:
#   WITH_VIDEO=0 (default) -> es-xmb-harness:knulli-<pin>
#       Authoritative for layout regression and scripts/tests. libvlc is linked
#       but has no plugins, so <video> elements never play.
#   WITH_VIDEO=1           -> es-xmb-harness:knulli-<pin>-video
#       Same ES pin plus VLC's plugins and one patch (see docker/patches), so
#       preview video actually plays. Used for video work only.
# Same source pin either way — see docker/README.md.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Build deps for batocera-emulationstation + headless render/screenshot tools.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git pkg-config ca-certificates curl \
      libsdl2-dev libsdl2-mixer-dev \
      libfreeimage-dev libfreetype6-dev \
      libcurl4-openssl-dev rapidjson-dev \
      libvlc-dev vlc-bin \
      libgl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dri \
      libasound2-dev libboost-all-dev libpugixml-dev gettext \
      xvfb x11-utils mesa-utils imagemagick xdotool \
    && rm -rf /var/lib/apt/lists/*

# Video-capable variant: VLC's plugins (libvlc-dev alone ships headers and the
# library, no demuxers or decoders — without these libvlc_new() gives back an
# instance that cannot open any file) plus the ES source patch below.
ARG WITH_VIDEO=0
RUN if [ "${WITH_VIDEO}" = "1" ]; then \
      apt-get update && apt-get install -y --no-install-recommends vlc-plugin-base \
      && rm -rf /var/lib/apt/lists/*; \
    fi

# Pinned Knulli batocera-emulationstation commit (Knulli Scarab 2026-05-11).
ARG ES_PIN=9bbb16a
RUN git clone --recursive \
      https://github.com/knulli-cfw/batocera-emulationstation.git /opt/es \
    && git -C /opt/es checkout "${ES_PIN}" \
    && git -C /opt/es submodule update --init --recursive

# Harness-only source patches. Applied to the video image alone: the default
# image has to keep building the pinned source unmodified, or it stops being a
# faithful stand-in for the device.
COPY patches /opt/patches
RUN if [ "${WITH_VIDEO}" = "1" ]; then \
      git -C /opt/es apply --verbose /opt/patches/vlc-parse-no-block.patch; \
    fi

WORKDIR /opt/es
RUN cmake -DBATOCERA=ON -DKNULLI=ON -DGL=ON -DDISABLE_KODI=ON \
          -DENABLE_PULSE=OFF -DUSE_SYSTEM_PUGIXML=ON . \
    && make -j"$(nproc)" \
    && cp emulationstation /usr/local/bin/emulationstation

# es_input.cfg (keyboard + controller map) so injected keystrokes drive ES.
RUN mkdir -p /usr/share/emulationstation \
    && curl -fsSL -o /usr/share/emulationstation/es_input.cfg \
       https://raw.githubusercontent.com/knulli-cfw/distribution/knulli-main/package/batocera/emulationstation/batocera-emulationstation/controllers/es_input.cfg \
    || echo "WARNING: es_input.cfg fetch failed; Task 4 will supply a keyboard map"

CMD ["bash"]
