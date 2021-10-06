ARG ALPINE_BUILDER_VERSION
ARG RTL_433_VERSION
ARG S6_ARCH
FROM alpine:${ALPINE_BUILDER_VERSION:-latest} as builder

RUN apk add --no-cache \
    build-base \
    libusb-dev \
    libressl-dev \
    librtlsdr-dev \
    cmake \
    git

WORKDIR /build
RUN git clone https://github.com/merbanan/rtl_433
WORKDIR ./rtl_433
RUN git checkout ${RTL_433_VERSION:-master}

RUN cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DENABLE_OPENSSL=ON .
RUN make
RUN mkdir -p /build/root
RUN make DESTDIR=/build/root install

ARG S6_ARCH
FROM oznu/s6-node:14.18.0-${S6_ARCH:-amd64}

RUN apk add --no-cache git python2 python3 make g++ avahi-compat-libdns_sd avahi-dev dbus \
    iputils sudo nano \
    libusb librtlsdr libressl tzdata \
  && chmod 4755 /bin/ping \
  && mkdir /homebridge \
  && npm set global-style=true \
  && npm set audit=false \ 
  && npm set fund=false

RUN case "$(uname -m)" in \
    x86_64) FFMPEG_ARCH='x86_64';; \
    armv6l) FFMPEG_ARCH='armv6l';; \
    armv7l) FFMPEG_ARCH='armv6l';; \
    aarch64) FFMPEG_ARCH='aarch64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
    && set -x \
    && curl -Lfs https://github.com/oznu/ffmpeg-for-homebridge/releases/download/v0.0.9/ffmpeg-alpine-${FFMPEG_ARCH}.tar.gz | tar xzf - -C / --no-same-owner

ENV PATH="${PATH}:/homebridge/node_modules/.bin"

ENV HOMEBRIDGE_VERSION=1.3.4
RUN npm install -g --unsafe-perm homebridge@${HOMEBRIDGE_VERSION}

ENV CONFIG_UI_VERSION=4.41.2 HOMEBRIDGE_CONFIG_UI=1 HOMEBRIDGE_CONFIG_UI_PORT=8581
RUN npm install -g --unsafe-perm homebridge-config-ui-x@${CONFIG_UI_VERSION}

WORKDIR /homebridge
VOLUME /homebridge

COPY root /
COPY --from=builder /build/root/ /

ARG AVAHI
ENV ENABLE_AVAHI="${AVAHI:-0}"
