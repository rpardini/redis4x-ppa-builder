FROM ubuntu:bionic as ubuntuBuilder
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN apt-get -y --no-install-recommends install devscripts build-essential lintian debhelper fakeroot lsb-release figlet dh-systemd tcl procps

# Add the modified/debianized source and the originals
ADD redis-src /opt/redis4ppa/build/sources
COPY redis-targz/redis_4.0.11.orig.tar.gz /opt/redis4ppa/build/

# Do a binary build (for sanity reasons)
WORKDIR /opt/redis4ppa/build/sources
ADD changelog/xenial /opt/redis4ppa/build/sources/debian/changelog
RUN debuild -us -uc

# List contents
WORKDIR /opt/redis4ppa/build/
RUN ls -la

# Do a source build, for Launchpad...
# source-only build, no signing.
# this is for xenial's changelog
WORKDIR /opt/redis4ppa/build/sources
ADD changelog/xenial /opt/redis4ppa/build/sources/debian/changelog
RUN debuild -S -us -uc

# Replace changelog with the one for bionic and rebuild source
ADD changelog/bionic /opt/redis4ppa/build/sources/debian/changelog
RUN debuild -S -us -uc

# List contents
WORKDIR /opt/redis4ppa/build/
RUN ls -la


########################################################################################################################
## -- the final image produced from this Dockerfile just contains the produced source and binary packages.
##    it uses alpine:3.8 because that's light enough, and already downloaded for node:10-alpine
FROM alpine:3.8

COPY --from=ubuntuBuilder /opt/redis4ppa/build/*_source* /sourcepkg/
COPY --from=ubuntuBuilder /opt/redis4ppa/build/*.dsc /sourcepkg/
COPY --from=ubuntuBuilder /opt/redis4ppa/build/*debian.tar.xz /sourcepkg/

# Hack: use volumes to "exfiltrate" the source files back to the host machine.
# This is just a marker directory to avoid mistakes when mounting volumes.
RUN mkdir -p /exfiltrate_to/empty

# Simple script to exfiltrate on run.
COPY docker/exfiltrate.sh /opt/exfiltrate.sh
CMD /opt/exfiltrate.sh
