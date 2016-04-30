FROM gliderlabs/alpine

RUN apk add --update \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ tini && \
    rm -rf /var/cache/apk/*
RUN apk --update \
    add tini sudo procps coreutils \
    git bash bash-completion rdiff-backup \
    python openjdk8-jre-base perl \
    perl-json make socat wget && \
    rm -rf /var/cache/apk/*

RUN ln -sf /bin/bash /bin/sh

ARG LOCATION=/opt/mscs
ARG USER_NAME=root
ARG WORLD_NAME=default

# Change this to true to accept Mojang EULA.
ARG EULA=false

RUN mkdir -p ${LOCATION}
RUN git clone https://github.com/MinecraftServerControl/mscs.git ${LOCATION}
RUN ln -s ${LOCATION}/mscs /usr/local/bin
RUN ln -s ${LOCATION}/msctl /usr/local/bin

RUN mkdir -p /etc/default
RUN echo USER_NAME=${USER_NAME} >>/etc/default/mscs
RUN echo LOCATION=${LOCATION} >>/etc/default/mscs

WORKDIR ${LOCATION}


RUN mscs create ${WORLD_NAME} 25565
RUN mscs start
RUN echo "eula=${EULA}" >${LOCATION}/worlds/${WORLD_NAME}/eula.txt

VOLUME ${LOCATION}/worlds
VOLUME ${LOCATION}/backups

EXPOSE 25565

ENTRYPOINT ["tini", "--"]
CMD mscs start && \
    mscs watch `mscs ls running | head -n 1 | cut -f1 -d: | tr -d '[:blank:]'`
