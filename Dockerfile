FROM frolvlad/alpine-glibc:alpine-3.5
LABEL maintainer="Mojo"

RUN apk add --no-cache curl && \
    curl -o /etc/apk/keys/ttanjo@gmail.com-58e06647.rsa.pub \
         https://raw.githubusercontent.com/tom-tan/alpine-pkg-cmigemo/master/ttanjo%40gmail.com-58e06647.rsa.pub && \
    curl -L -o cmigemo.apk https://github.com/tom-tan/alpine-pkg-cmigemo/releases/download/1.2.r38/cmigemo-1.2.r38-r0.apk && \
    apk add --no-cache cmigemo.apk libevent openssl && \
    rm -rf cmigemo.apk /usr/share/migemo/cp932 /usr/share/migemo/euc-jp && \
    apk del curl

ADD moecoop.tgz /moecoop

WORKDIR /moecoop

EXPOSE 8080

ENTRYPOINT ["./fukurod"]
