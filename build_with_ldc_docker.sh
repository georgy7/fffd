#!/bin/sh

# docker pull dlang2/ldc-ubuntu

docker run --rm --volume=$(pwd):/mnt -w="/mnt" \
        dlang2/ldc-ubuntu \
        dub build --build=release --compiler=ldc2
