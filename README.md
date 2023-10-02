##### Build

```
cd "$(dirname "$0")"
cd ./

mkdir -p Invert.plugin/Contents/{MacOS,Resources}

clang++ -std=c++20 -Wc++20-extensions -bundle -dependency_info -fobjc-arc -O3 -I../../Headers -I../../Util -framework Cocoa -framework Metal -framework Quartz -framework CoreMedia ./Invert.mm -o ./Invert

Rez -o ./InvertPiPL.rsrc -define __MACH__ -arch arm64 -i ../../Headers -i ../../Resources ./InvertPiPL.r
ResMerger -dstIs DF ./InvertPiPL.rsrc -o ./Invert.rsrc

cp ./Info.plist ./Invert.plugin/Contents/
cp ./PkgInfo ./Invert.plugin/Contents/
cp ./Invert.rsrc ./Invert.plugin/Contents/Resources/Invert.rsrc
cp ./shaders/Invert.metallib ./Invert.plugin/Contents/Resources/Invert.metallib

cp ./Invert ./Invert.plugin/Contents/MacOS/Invert

codesign --force --options runtime --deep --entitlements "entitlements.plist" --sign "Developer ID Application" --timestamp --verbose Invert.plugin
```