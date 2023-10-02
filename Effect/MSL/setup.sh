cd "$(dirname "$0")"
cd ./

set -eu

if [ $# -ne 1 ]; then
	exit 1
fi

mkdir ../$1

sed -e "s/PLUGIN=\"PLUGIN\"/PLUGIN=\"$1\"/g" ./_build.sh >> ../$1/build.sh
sed -e "s/#define MFR Plugin/#define MFR $1/g" \
-e "s/#define IDENTIFIER @\"Ae.MSL.Plugin\"/#define IDENTIFIER @\"Ae.MSL.$1\"/g" \
-e "s/#define METALLIB @\"Plugin.metallib\"/#define METALLIB @\"$1.metallib\"/g" ./_Config.h >> ../$1/Config.h
cp ./default.metal ../$1/$1.metal
sed -e "s/\<string\>Plugin\<\/string\>/\<string\>$1\<\/string\>/g" \
-e "s/\<string\>Ae.MSL.Plugin\<\/string\>/\<string\>Ae.MSL.$1\<\/string\>/g" \
./Info.plist >> ../$1/Info.plist
sed -e "s/\"Plugin\"/\"$1\"/g" \
-e "s/\"Ae.MSL.Plugin\"/\"Ae.MSL.$1\"/g" \
./PiPL.r >> ../$1/$1PiPL.r

echo $1