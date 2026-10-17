#!/bin/sh
# Runs inside the Windows build container with the source tree at /src.
# FULL_VERSION is embedded in the library, e.g. 2019.4.18f1-gc-roots-fix.2/6015e75b7b
#
# Builds msvc/ the way Unity's build_runtime_vs.pl does (Release, x64, bdwgc),
# with these differences for MSBuild under Wine, none of which change compiler
# or linker options:
# - config.h and version.h are generated here, because msvc/winsetup.bat needs
#   PowerShell. winsetup.bat is replaced with a no-op during the build.
# - File access tracking is off and tool paths are explicit.
# - win64.asm is assembled by wine-masm.targets instead of masm.targets.
# - Projects are built one at a time; MSBuild /m fails under wine-mono.
set -e
: "${FULL_VERSION:?set FULL_VERSION}"
cd /src

version=$(sed -n 's/^AC_INIT(mono, \[\([0-9.]*\)\].*/\1/p' configure.ac)
counter=$(sed -n 's/^MONO_CORLIB_COUNTER=//p' configure.ac)
corlib=$(echo "$version" | awk -F. -v c="$counter" '{printf "1%02d%02d%02d%03d", $1, $2, 0, c}')
sed -e "s/#MONO_VERSION#/$version/" -e "s/#MONO_CORLIB_VERSION#/$corlib/" winconfig.h > config.h
echo "#define FULL_VERSION \"$FULL_VERSION\"" > mono/mini/version.h

cp msvc/winsetup.bat /tmp/winsetup.bat
trap 'cp /tmp/winsetup.bat /src/msvc/winsetup.bat' EXIT
printf '@EXIT /b 0\r\n' > msvc/winsetup.bat

vcbin='C:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\bin\amd64'
sdkbin='C:\Program Files (x86)\Windows Kits\8.1\bin\x64'
cd msvc
for project in libgcbdwgc libmono-dynamic; do
	if ! wine 'C:\BuildTools\MSBuild\15.0\Bin\MSBuild.exe' "$project.vcxproj" /t:Build /nologo \
		/p:Configuration=Release /p:Platform=x64 /p:MONO_TARGET_GC=bdwgc \
		/p:TrackFileAccess=false /p:ExcludeMASMFromWindowsBuild=true \
		'/p:ForceImportAfterCppTargets=Z:\opt\msvc\wine-masm.targets' \
		'/p:SolutionDir=Z:\src\msvc/' \
		"/p:CLToolPath=$vcbin" "/p:LinkToolPath=$vcbin" "/p:LibToolPath=$vcbin" \
		"/p:MLToolPath=$vcbin" "/p:RCToolPath=$sdkbin" "/p:MTToolPath=$sdkbin" \
		> "../msbuild-$project.log" 2>&1; then
		tail -n 20 "../msbuild-$project.log"
		exit 1
	fi
done
cd ..
mkdir -p _out
cp msvc/build/bdwgc/x64/bin/Release/mono-2.0-bdwgc.dll msvc/build/bdwgc/x64/bin/Release/mono-2.0-bdwgc.pdb _out/
echo "_out/mono-2.0-bdwgc.dll built"
