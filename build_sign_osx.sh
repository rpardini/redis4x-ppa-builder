#!/bin/bash

set -e

declare -i SIGN_OSX=1
declare -i LAUNCHPAD=1
#declare NO_CACHE="--no-cache"
declare NO_CACHE=""

# Make sure we can GPG sign stuff (eg, ask for yubikey PIN first)
echo "not important" | gpg --sign --armor

# Clear the local dirs.
rm -rf ${PWD}/exfiltrated

# Build the packages themselves.
docker build ${NO_CACHE} -t redis4x/deb:latest -f Dockerfile .

# Build the launchpad utility image.
[[ ${LAUNCHPAD} -gt 0 ]] && docker build ${NO_CACHE} -t redis4x/launchpad:latest -f Dockerfile.launchpad .

# Run the packages image to copy over the packages to local system, using the "to_sign" directory as volume
docker run -it -v ${PWD}/exfiltrated/:/exfiltrate_to redis4x/deb:latest
# Now the local ${PWD}/exfiltrated dir contains all the packages. Unsigned!

# sign the source packages for launchpad
if [[ ${SIGN_OSX} -gt 0 ]]; then
  echo "Signing Launchpad source packages locally..."
  osx/debsign_osx.sh --no-conf -S exfiltrated/sourcepkg/*_source.changes
  # Now the local ${PWD}/exfiltrated/sourcepkg contains signed source packages for Launchpad.
fi

# Run the Launchpad utility image, it will upload to Launchpad via dput.
if [[ ${LAUNCHPAD} -gt 0 ]]; then
  echo "Uploading to Launchpad..."
  docker run -it -v ${PWD}/exfiltrated/sourcepkg/:/to_upload redis4x/launchpad:latest
  # This is the final stop for Launchpad. Watch it build the source packages there!
fi
