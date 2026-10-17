#!/bin/sh
# Builds the Linux runtime library in a container.
#
#   scripts/container-build/build.sh <full version>
#
# Run from an unconfigured checkout with external/bdwgc and its libatomic_ops
# submodule populated. Output is _out/libmonobdwgc-2.0.so; logs are left in the
# source tree. CONTAINER_ENGINE selects podman (default) or docker.
set -e
version=${1:?usage: $0 <full version, e.g. 2019.4.18f1-gc-roots-fix.2/6015e75b7b>}
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$here/../.." && pwd)
engine=${CONTAINER_ENGINE:-podman}
image=unity-mono-linux-build
if [ "$engine" = podman ]; then
	user=--userns=keep-id
else
	user="--user $(id -u):$(id -g)"
fi
"$engine" build -t "$image" -f "$here/Containerfile.linux" "$here"
"$engine" run --rm $user --network=none -e FULL_VERSION="$version" \
	-v "$src:/src" -v "$here/build-linux.sh:/build-linux.sh:ro" \
	"$image" sh /build-linux.sh
