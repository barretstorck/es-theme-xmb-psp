# Headless batocera-emulationstation for es-theme-xmb-psp theme testing.
# Renders via desktop GL21 (Mesa software) — a dev aid, NOT a release gate.
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

# Pinned Knulli batocera-emulationstation commit (Knulli Scarab 2026-05-11).
ARG ES_PIN=9bbb16a
RUN git clone --recursive \
      https://github.com/knulli-cfw/batocera-emulationstation.git /opt/es \
    && git -C /opt/es checkout "${ES_PIN}" \
    && git -C /opt/es submodule update --init --recursive

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
