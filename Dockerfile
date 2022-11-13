FROM ubuntu:20.04 as builder

ARG RTL_433_VERSION

RUN set -x \
  && apt-get update \
  && apt-get install -y tzdata locales \
  && locale-gen en_US.UTF-8 \
  && apt-get install -y libusb-1.0-0-dev librtlsdr-dev libssl-dev cmake gcc git make

WORKDIR /build
RUN git clone https://github.com/merbanan/rtl_433
WORKDIR ./rtl_433
RUN git checkout ${RTL_433_VERSION:-master}

RUN cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DENABLE_OPENSSL=ON .
RUN make
RUN mkdir -p /build/root
RUN make DESTDIR=/build/root install

FROM ubuntu:20.04

LABEL org.opencontainers.image.title="Homebridge in Docker"
LABEL org.opencontainers.image.description="Official Homebridge Docker Image"
LABEL org.opencontainers.image.authors="oznu"
LABEL org.opencontainers.image.url="https://github.com/oznu/docker-homebridge"
LABEL org.opencontainers.image.licenses="GPL-3.0"

ENV S6_OVERLAY_VERSION=3.1.1.2 \
 S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
 S6_KEEP_ENV=1 \
 ENABLE_AVAHI=1 \
 USER=root \
 HOMEBRIDGE_APT_PACKAGE=1 \
 UIX_CUSTOM_PLUGIN_PATH="/var/lib/homebridge/node_modules" \
 PATH="/opt/homebridge/bin:/var/lib/homebridge/node_modules/.bin:$PATH" \
 HOME="/home/homebridge" \
 npm_config_prefix=/opt/homebridge

RUN set -x \
  && apt-get update \
  && apt-get install -y curl wget tzdata locales psmisc procps iputils-ping logrotate \
    libatomic1 apt-transport-https apt-utils jq openssl sudo nano net-tools \
    libusb-1.0-0 librtlsdr0 \
  && locale-gen en_US.UTF-8 \
  && ln -snf /usr/share/zoneinfo/Etc/GMT /etc/localtime && echo Etc/GMT > /etc/timezone \
  && apt-get install -y python3 python3-pip python3-setuptools git python make g++ libnss-mdns \
    avahi-discover libavahi-compat-libdnssd-dev \
  && pip3 install tzupdate \
  && chmod 4755 /bin/ping \
  && apt-get clean \
  && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* \
  && rm -rf /etc/cron.daily/apt-compat /etc/cron.daily/dpkg /etc/cron.daily/passwd /etc/cron.daily/exim4-base
  
RUN case "$(uname -m)" in \
    x86_64) S6_ARCH='x86_64';; \
    armv7l) S6_ARCH='armhf';; \
    aarch64) S6_ARCH='aarch64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && cd /tmp \
  && set -x \
  && curl -SLOf https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
  && curl -SLOf  https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz \
  && tar -C / -Jxpf /tmp/s6-overlay-${S6_ARCH}.tar.xz

RUN case "$(uname -m)" in \
    x86_64) FFMPEG_ARCH='x86_64';; \
    armv7l) FFMPEG_ARCH='armv7l';; \
    aarch64) FFMPEG_ARCH='aarch64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && set -x \
  && curl -Lfs https://github.com/homebridge/ffmpeg-for-homebridge/releases/download/v0.1.0/ffmpeg-debian-${FFMPEG_ARCH}.tar.gz | tar xzf - -C / --no-same-owner

ENV HOMEBRIDGE_PKG_VERSION=1.0.31

RUN case "$(uname -m)" in \
    x86_64) DEB_ARCH='amd64';; \
    armv7l) DEB_ARCH='armhf';; \
    aarch64) DEB_ARCH='arm64';; \
    *) echo "unsupported architecture"; exit 1 ;; \
    esac \
  && set -x \
  && curl -sSLf -o /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb https://github.com/homebridge/homebridge-apt-pkg/releases/download/${HOMEBRIDGE_PKG_VERSION}/homebridge_${HOMEBRIDGE_PKG_VERSION}_${DEB_ARCH}.deb \
  && dpkg -i /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb \
  && rm -rf /homebridge_${HOMEBRIDGE_PKG_VERSION}.deb \
  && chown -R root:root /opt/homebridge \
  && rm -rf /var/lib/homebridge

COPY rootfs /
COPY --from=builder /build/root/ /

EXPOSE 8581/tcp
VOLUME /homebridge
WORKDIR /homebridge

ENTRYPOINT [ "/init" ]
