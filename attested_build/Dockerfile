FROM antdl/ccf:latest

LABEL maintainer="antdl@microsoft.com"
LABEL description="Attested build image and Debian package release for SCITT application"

ENV DEBIAN_FRONTEND noninteractive

RUN git clone https://github.com/ad-l/cts
WORKDIR cts

RUN build.sh

