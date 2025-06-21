#!/bin/bash
# update-zlib.sh
set -ex

TAG_OR_HASH=${1:-main}
rm -rf zlib/
git clone https://github.com/gabrieldemarmiesse/mojo-zlib.git temp-zlib
cd temp-zlib
git checkout $TAG_OR_HASH
cd ..
cp -r temp-zlib/zlib ./
rm -rf temp-zlib/
git add zlib/
git commit -m "Update vendored zlib to $TAG_OR_HASH"