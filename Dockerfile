FROM frolvlad/alpine-glibc:latest
LABEL maintainer="Mojo"

ENV PORT=8080

RUN apk add --no-cache curl && \
    curl -Lo cmigemo.apk https://github.com/tom-tan/alpine-pkg-cmigemo/releases/download/1.2.r38/cmigemo-1.2.r38-r0.apk && \
    apk add --no-cache --allow-untrusted cmigemo.apk libevent && \
    rm -rf cmigemo.apk /usr/share/migemo/cp932 /usr/share/migemo/utf-8 && \
    apk del curl && \
    mkdir moecoop

ADD moecoop.tgz /moecoop

WORKDIR /moecoop

CMD ["./fukurod"]
