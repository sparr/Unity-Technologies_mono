#!/bin/sh
# Builds the Unity Mono runtime library in a container.
#
#   scripts/container-build/build.sh linux <full version>
#   scripts/container-build/build.sh windows <full version>
#
# linux builds _out/libmonobdwgc-2.0.so with an old glibc baseline. Run it from
# an unconfigured checkout.
# windows builds _out/mono-2.0-bdwgc.dll and its .pdb with MSVC 2015 under Wine.
# Building its image downloads Visual Studio Build Tools from Microsoft and
# requires ACCEPT_MSVC_LICENSE=yes in the environment to accept their license.
# That image contains Microsoft software; do not push it to a registry.
#
# Both need external/bdwgc and its libatomic_ops submodule populated. Logs are
# left in the source tree. CONTAINER_ENGINE selects podman (default) or docker.
set -e
usage="usage: $0 linux|windows <full version, e.g. 2019.4.18f1-gc-roots-fix.2/6015e75b7b>"
platform=${1:?$usage}
version=${2:?$usage}
here=$(cd "$(dirname "$0")" && pwd)
src=$(cd "$here/../.." && pwd)
engine=${CONTAINER_ENGINE:-podman}

case "$platform" in
linux)
	image=unity-mono-linux-build
	"$engine" build -t "$image" -f "$here/Containerfile.linux" "$here"
	# Build as the invoking user so the output in the source tree is theirs.
	if [ "$engine" = podman ]; then
		user=--userns=keep-id
	else
		user="--user $(id -u):$(id -g)"
	fi
	;;
windows)
	image=unity-mono-windows-build
	"$engine" build -t "$image" -f "$here/Containerfile.windows" \
		--build-arg ACCEPT_MSVC_LICENSE="${ACCEPT_MSVC_LICENSE:-}" "$here"
	# The Wine prefix belongs to the image's root user. Rootless podman maps
	# that user to the invoking user; with docker, fix ownership afterwards.
	user=
	;;
*)
	echo "$usage" >&2
	exit 2
	;;
esac

"$engine" run --rm $user --network=none -e FULL_VERSION="$version" \
	-v "$src:/src" -v "$here/build-$platform.sh:/build.sh:ro" \
	"$image" sh /build.sh

if [ "$platform" = windows ] && [ "$engine" != podman ]; then
	"$engine" run --rm -v "$src:/src" "$image" \
		find /src -user 0 -exec chown "$(id -u):$(id -g)" {} +
fi
