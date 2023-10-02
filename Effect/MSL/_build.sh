cd "$(dirname "$0")"
cd ./

set -eu

PLUGIN="PLUGIN"
echo ${PLUGIN}

xcrun -sdk macosx metal -c ${PLUGIN}.metal -o ${PLUGIN}.air
xcrun -sdk macosx metallib ${PLUGIN}.air -o ${PLUGIN}.metallib
rm ${PLUGIN}.air

mkdir -p ${PLUGIN}.plugin/Contents/{MacOS,Resources}

clang++ -std=c++20 -Wc++20-extensions -bundle -dependency_info -fobjc-arc -O3 -I../../Headers -I../../Util -I./ -framework Cocoa -framework Metal -framework Quartz -framework CoreMedia ../MSL/main.mm -o ./${PLUGIN}.plugin/Contents/MacOS/${PLUGIN}

Rez -o ./${PLUGIN}PiPL.rsrc -define __MACH__ -arch arm64 -i ../../Headers -i ../../Resources ./${PLUGIN}PiPL.r
ResMerger -dstIs DF ./${PLUGIN}PiPL.rsrc -o ./${PLUGIN}.plugin/Contents/Resources/${PLUGIN}.rsrc
rm ./${PLUGIN}PiPL.rsrc

cp ./Info.plist ./${PLUGIN}.plugin/Contents/
cp ../MSL/PkgInfo ./${PLUGIN}.plugin/Contents/
cp ./${PLUGIN}.metallib ./${PLUGIN}.plugin/Contents/Resources/${PLUGIN}.metallib

codesign --force --options runtime --deep --entitlements "../MSL/entitlements.plist" --sign "Developer ID Application" --timestamp --verbose ${PLUGIN}.plugin

echo "** BUILD SUCCEEDED **"