# Headless batocera-emulationstation for es-theme-xmb-psp theme testing.
# Renders via desktop GL21 (Mesa software) — a dev aid, NOT a release gate.
# See docker/README.md.
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

# VLC's plugins. libvlc-dev above ships the library and headers and not one
# demuxer or decoder, so without these libvlc_new() hands back an instance that
# cannot open a single file and every <video> element stays dark — which is why
# video looked "compiled out" of this harness for so long.
RUN apt-get update && apt-get install -y --no-install-recommends vlc-plugin-base \
    && rm -rf /var/lib/apt/lists/*

# Pinned Knulli batocera-emulationstation commit (Knulli Scarab 2026-05-11).
ARG ES_PIN=9bbb16a
RUN git clone --recursive \
      https://github.com/knulli-cfw/batocera-emulationstation.git /opt/es \
    && git -C /opt/es checkout "${ES_PIN}" \
    && git -C /opt/es submodule update --init --recursive

# Harness-only source patch: without it, ES freezes the moment a <video>
# element is shown with a path libvlc cannot parse. It changes no rendering
# behaviour — see docker/README.md for the full story.
COPY patches /opt/patches
RUN git -C /opt/es apply --verbose /opt/patches/vlc-parse-no-block.patch

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
