#!/bin/sh
# Runs during the Windows image build. Installs the VS2015 (v140) toolset,
# Windows SDK 8.1, the Universal CRT, and MSBuild 15 into /opt/msvc, and sets
# up a Wine prefix that finds them where a Windows installation would.
#
#   setup-msvc.sh download   download and extract the toolchain
#   setup-msvc.sh wine       create the Wine prefix
set -e
cd /opt/msvc
vc="msi/Program Files/Microsoft Visual Studio 14.0/VC"

case "$1" in
download)
	cache=/tmp/vs-cache
	python3 vsdownload.py --accept-license --major 15 --only-unpack --cache "$cache" \
	  --dest /opt/msvc/buildtools \
	  Microsoft.VisualStudio.Component.VC.140 Microsoft.VisualStudio.Component.Windows81SDK \
	  Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.VC.CoreBuildTools

	# vsdownload.py only extracts Windows 10 SDK MSIs. Extract the x64 VC 2015
	# tools, CRT, and resources, the Windows 8.1 SDK (its Store MSI has the core
	# headers and import libraries), and the Universal CRT. Each MSI goes to its
	# own directory and is then merged.
	mkdir -p msi
	for dir in "$cache"/*/; do
		pkg=$(basename "$dir")
		case "$pkg" in
		Microsoft.VisualC.140.*|Microsoft.Windows.81SDK.Desktop.Msi-*|Microsoft.Windows.81SDK.Store.Msi-*|Microsoft.Windows.UniversalCRT.*) ;;
		*) continue ;;
		esac
		case "$pkg" in
		*HeadersLibsSources*|Microsoft.VisualC.140.CRT.x64.Store.*|Microsoft.VisualC.140.CRT.x64.OneCore.*|Microsoft.Windows.81SDK.Store.*) ;;
		*ARM*|*arm*|*.x86.*|*X86.Msi*|*x86.Msi*|*MFC*|*Store*|*OneCore*|*.[Ss]ource.Msi*|*Redist*|*Msu*) continue ;;
		esac
		for m in "$dir"*.msi; do
			[ -e "$m" ] || continue
			out=$(mktemp -d)
			msiextract -C "$out" "$m" > /dev/null
			cp -a "$out/." msi/
			rm -rf "$out"
		done
	done
	rm -rf "$cache"
	for f in "$vc/bin/amd64/cl.exe" "$vc/bin/amd64/1033/clui.dll" "$vc/lib/amd64/libcmt.lib" "$vc/lib/amd64/oldnames.lib" \
		"msi/Program Files/Windows Kits/8.1/Include/um/Windows.h" \
		"msi/Program Files/Windows Kits/8.1/Lib/winv6.3/um/x64/kernel32.Lib" \
		"msi/Program Files/Windows Kits/10/Lib/10.0.10240.0/ucrt/x64/libucrt.lib"; do
		test -e "$f" || { echo "missing after extraction: $f" >&2; exit 1; }
	done
	# The VC telemetry uploader crashes under wine-mono.
	mv "$vc/bin/amd64/vctip.exe" "$vc/bin/amd64/vctip.exe.disabled"
	;;

wine)

	export WINEPREFIX=/opt/msvc/wineprefix WINEDEBUG=-all WINEDLLOVERRIDES="mshtml=d;winemenubuilder.exe=d"
	wineboot -i
	wine msiexec /i 'Z:\opt\msvc\wine-mono-9.4.0-x86.msi' /qn
	pf="$WINEPREFIX/drive_c/Program Files (x86)"
	mkdir -p "$pf/Windows Kits" "$pf/MSBuild/Microsoft.Cpp/v4.0"
	ln -s "/opt/msvc/msi/Program Files/Microsoft Visual Studio 14.0" "$pf/Microsoft Visual Studio 14.0"
	ln -s "/opt/msvc/msi/Program Files/Windows Kits/8.1" "$pf/Windows Kits/8.1"
	ln -s "/opt/msvc/msi/Program Files/Windows Kits/10" "$pf/Windows Kits/10"
	ln -s "/opt/msvc/msi/Program Files/MSBuild/Microsoft.Cpp/v4.0/v140" "$pf/MSBuild/Microsoft.Cpp/v4.0/V140"
	ln -s /opt/msvc/buildtools "$WINEPREFIX/drive_c/BuildTools"
	sed 's/\\Wow6432Node//' vc140.reg > vc140-64.reg
	wine regedit /S 'Z:\opt\msvc\vc140.reg'
	wine regedit /S 'Z:\opt\msvc\vc140-64.reg'
	wine 'C:\BuildTools\MSBuild\15.0\Bin\MSBuild.exe' -version
	wineserver -w
	;;

*)
	echo "usage: $0 download|wine" >&2
	exit 2
	;;
esac
