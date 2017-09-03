FROM ubuntu:latest
LABEL maintainer="Mojo"

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --no-install-suggests --no-install-recommends -y \
    locales && \
    locale-gen ja_JP.UTF-8

ENV LANG=ja_JP.UTF-8 \
    PORT=8080

RUN apt-get update && \
    apt-get install --no-install-suggests --no-install-recommends -y \
            cmigemo libevent-2.0-5 libssl1.0.0 libevent-pthreads-2.0-5 && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /tmp/* /var/tmp/* /var/lib/apt/lists/* && \
    mkdir moecoop

ADD moecoop.tgz /moecoop

WORKDIR /moecoop

CMD ["./fukurod"]
