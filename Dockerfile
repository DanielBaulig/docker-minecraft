# MinecraftServerControl
#
# This Dockerfile creates a Docker image for running running and controlling
# Minecraft servers. It is based off of gliderlabs alpine image and the
# MinecraftServerControl script.
FROM gliderlabs/alpine

MAINTAINER Daniel Baulig <daniel.baulig@gmx.de>

RUN apk add --update \
    # add alpine  community reporisory to install tini
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ \
    # install tini to have a proper init process
    tini && \
    rm -rf /var/cache/apk/*
RUN apk --update add\
    # install tools & requirements for mscs
    sudo procps coreutils \
    git bash bash-completion rdiff-backup \
    python openjdk8-jre-base perl \
    perl-json socat wget && \
    rm -rf /var/cache/apk/*

# make sure to run everything in bash
RUN ln -sf /bin/bash /bin/sh

# We are running mscs as root in the container, because otherwise sharing
# volumes across Docker containers becomes complicated.
ARG USER_NAME=root
# The default world name. You can mount a volume into ${LOCATIONN}/worlds
# to load already existing worlds into new instances of this image.
ARG WORLD_NAME=default
ARG LOCATION=/opt/mscs

# install mscs
RUN mkdir -p ${LOCATION}
RUN git clone https://github.com/MinecraftServerControl/mscs.git ${LOCATION}
# we are not using `make install`, because we do not intend to create an
# additional user et all
RUN ln -s ${LOCATION}/mscs /usr/local/bin
RUN ln -s ${LOCATION}/msctl /usr/local/bin

# create mscs default configuration
RUN mkdir -p /etc/default
RUN echo USER_NAME=${USER_NAME} >>/etc/default/mscs
RUN echo LOCATION=${LOCATION} >>/etc/default/mscs

WORKDIR ${LOCATION}

# setup the default world in case no existing worlds are mounted
RUN mscs create ${WORLD_NAME} 25565
RUN mscs start
# Change this to true or pass --build-arg EULA=true into the docker build call
# to accept Mojang EULA.
ARG EULA=false
RUN echo "eula=${EULA}" >${LOCATION}/worlds/${WORLD_NAME}/eula.txt

# dump minecraft version. can be useful for tagging of the image
    #alias exit, so sourcing msctl does not exit the shell
RUN alias exit=true && \
    # source msctl to get access to it's functions. redirect output, we don't
    # need it.
    . ${LOCATION}/msctl >/dev/null && \
    # echo Minecraft version using msctl's getCurrentMinecraftVersion function
    echo Minecraft Version: $(getCurrentMinecraftVersion ${WORLD_NAME})

# Mount existing worlds that you want to run into this volume.
VOLUME ${LOCATION}/worlds
# Mount a location for your backups into this volume. Fair warning: rdiff-backup
# is unable to write to curlftpfs destinations. I tried. For long.
VOLUME ${LOCATION}/backups
# Mount scripts to run in cron into /etc/periodic/[folder], where [folder] is
# one (or multiple) of 15min, hourly, daily, weekly or monthly. E.g. for
# syncing mirrored worlds or creating backups.
VOLUME /etc/periodic

EXPOSE 25565

# use tini as our entrypoint so we have a proper init script
ENTRYPOINT ["tini", "--"]
    # start cron
CMD crond && \
    # start the minecraft servers
    mscs start && \
    # watch the first running minecraft server
    # this will allow you to follow what happens, but will also prevent the
    # container from exiting. If you intent on starting and stopping servers in
    # the container without it exiting, then replace the following line with a
    # simple tail -f /dev/null
    mscs watch `mscs ls running | head -n 1 | cut -f1 -d: | tr -d '[:blank:]'`
