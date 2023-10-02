##### Build PiPL.rsrc

```
cd "$(dirname "$0")"
cd ./

Rez -o ./InvertPiPL.rsrc -define __MACH__ -arch arm64 -i ../../Headers -i ../../Resources ./InvertPiPL.r
ResMerger -dstIs DF ./InvertPiPL.rsrc -o ./Invert.rsrc
```