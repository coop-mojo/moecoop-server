FROM frolvlad/alpine-glibc:latest
LABEL maintainer="Mojo"

RUN apk add --no-cache curl && \
    curl -o /etc/apk/keys/ttanjo@gmail.com-58e06647.rsa.pub \
         https://raw.githubusercontent.com/tom-tan/alpine-pkg-cmigemo/master/ttanjo%40gmail.com-58e06647.rsa.pub && \
    curl -L -o cmigemo.apk https://github.com/tom-tan/alpine-pkg-cmigemo/releases/download/1.2.r38/cmigemo-1.2.r38-r0.apk && \
    apk add --no-cache cmigemo.apk libevent && \
    rm cmigemo.apk && \
    apk del curl

ADD moecoop.tgz /moecoop

WORKDIR /moecoop

EXPOSE 8080

ENTRYPOINT ["./fukurod"]
