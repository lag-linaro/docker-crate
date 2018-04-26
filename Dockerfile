## -*- docker-image-name: "docker-crate" -*-
#
# Crate Dockerfile
# https://github.com/crate/docker-crate
#

FROM openjdk:11-jre-slim
MAINTAINER Crate.IO GmbH office@crate.io

RUN set -x

# install gosu
ENV GOSU_VERSION 1.9
ENV CRATE_VERSION 2.3.6

RUN apt update && apt install -y --no-install-recommends curl gnupg python3 openssl tar \
    && echo "Installing gosu ${GOSU_VERSION} ..." \
    && export ARCH=$(echo $(dpkg --print-architecture) | cut -d"-" -f3) \
    && curl -o /usr/local/bin/gosu -fSL "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$ARCH" \
    && curl -o /usr/local/bin/gosu.asc -fSL "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$ARCH.asc" \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
    && rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
    && chmod +x /usr/local/bin/gosu \
    && gosu nobody true \
    && echo "Installing CrateDB ${CRATE_VERSION} ..." \
    && curl -fSL -O https://cdn.crate.io/downloads/releases/crate-$CRATE_VERSION.tar.gz \
    && curl -fSL -O https://cdn.crate.io/downloads/releases/crate-$CRATE_VERSION.tar.gz.asc \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 90C23FC6585BC0717F8FBFC37FAAE51A06F6EAEB \
    && gpg --batch --verify crate-$CRATE_VERSION.tar.gz.asc crate-$CRATE_VERSION.tar.gz \
    && rm -rf "$GNUPGHOME" crate-$CRATE_VERSION.tar.gz.asc \
    && mkdir /crate \
    && tar -xf crate-$CRATE_VERSION.tar.gz -C /crate --strip-components=1 \
    && rm crate-$CRATE_VERSION.tar.gz \
    && ln -s /usr/bin/python3 /usr/bin/python \
    && rm -rf /var/lib/apt/lists/*

# add crate user
RUN addgroup --system --gid 1000 crate \
    && adduser --system --no-create-home --gid 1000 --uid 1001 crate

ENV PATH /crate/bin:$PATH
# Default heap size for Docker, can be overwritten by args
ENV CRATE_HEAP_SIZE 512M

# This healthcheck indicates if a CrateDB node is up and running. It will fail
# if we cannot get any response from the CrateDB (connection refused, timeout
# etc). If any response is received (regardless of http status code) we
# consider the node as running.
HEALTHCHECK CMD curl $(hostname):4200

VOLUME ["/data"]

ADD config/crate.yml /crate/config/crate.yml
ADD config/log4j2.properties /crate/config/log4j2.properties
COPY docker-entrypoint.sh /

WORKDIR /data

# http: 4200 tcp
# transport: 4300 tcp
# postgres protocol ports: 5432 tcp
EXPOSE 4200 4300 5432

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["crate"]
