#!/bin/sh

# dub fetch profdump

find trace.def -delete
find trace.log -delete

dub build --build=profile --compiler=ldc2

echo ------- START -------

./fffd samples2/IMG_2164_q40_orig.bmp

find profiling_info.txt -delete

dub run profdump -- --blame=10 trace.log profiling_info.txt
