FROM alpine:latest as builder

ARG NSD_VERSION=4.3.5
ARG GPG_FINGERPRINT="EDFAA3F2CA4E6EB05681AF8E9F6F1C2D7E045F8D"
ARG SHA256_HASH="7da2b43e30b3d7f307722c608f719bfb169f0d985c764a34fa0669dc33484472"


RUN apk add --no-cache \
      bash \
      curl \
      gnupg \
      build-base \
      libevent-dev \
      openssl-dev \
      ca-certificates

SHELL [ "/bin/bash", "-o", "pipefail", "-c" ]

WORKDIR /tmp
RUN \
   curl -OO https://www.nlnetlabs.nl/downloads/nsd/nsd-${NSD_VERSION}.tar.gz{,.asc} && \
   echo "Verifying authenticity of nsd-${NSD_VERSION}.tar.gz..." && \
   CHECKSUM=$(sha256sum nsd-${NSD_VERSION}.tar.gz | awk '{print $1}') && \
   if [ "${CHECKSUM}" != "${SHA256_HASH}" ]; then echo "ERROR: Checksum does not match!" && exit 1; fi && \
   ( \
      gpg --keyserver ha.pool.sks-keyservers.net --recv-keys ${GPG_FINGERPRINT} || \
      gpg --keyserver keyserver.pgp.com --recv-keys ${GPG_FINGERPRINT} || \
      gpg --keyserver pgp.mit.edu --recv-keys ${GPG_FINGERPRINT} \
   ) && \
   FINGERPRINT="$(LANG=C gpg --verify nsd-${NSD_VERSION}.tar.gz.asc nsd-${NSD_VERSION}.tar.gz 2>&1 \
                | sed -n 's#^Primary key fingerprint: \(.*\)#\1#p' | tr -d '[:space:]')" && \
   if [ -z "${FINGERPRINT}" ]; then echo "ERROR: Invalid GPG signature!" && exit 1; fi && \
   if [ "${FINGERPRINT}" != "${GPG_FINGERPRINT}" ]; then echo "ERROR: Wrong GPG fingerprint!" && exit 1; fi && \
   echo "SHA256 and GPG signature are correct"

RUN echo "Extracting nsd-${NSD_VERSION}.tar.gz..." && \
    tar -xzf "nsd-${NSD_VERSION}.tar.gz"
WORKDIR /tmp/nsd-${NSD_VERSION}

RUN ./configure \
    CFLAGS="-O2 -flto -fPIE -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=2 -fstack-protector-strong \
            -Wformat -Werror=format-security" \
    LDFLAGS="-Wl,-z,now -Wl,-z,relro" && \
    make && \
    make install DESTDIR=/builder


FROM alpine:latest

LABEL Maintainer "Selfhosting-tools (https://github.com/selfhosting-tools)"

RUN apk add --no-cache \
   ldns \
   ldns-tools \
   libevent \
   openssl \
   tini

COPY --from=builder /builder /
COPY bin /usr/local/bin

ENV UID=991 GID=991

EXPOSE 53 53/udp

CMD ["start_nsd.sh"]
