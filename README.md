# fffd

[![Build Status](https://travis-ci.org/georgy7/fffd.svg?branch=master)](https://travis-ci.org/georgy7/fffd)

D port of [flood-fill-filter](https://github.com/georgy7/flood_fill_filter).

## Installation

* [dub package manager installation](https://github.com/dlang/dub#installation)
* [LDC installation](https://github.com/ldc-developers/ldc#installation)

```sh
dub build --build=release --compiler=ldc2
sudo cp fffd /usr/local/bin/
```

## Usage

```
fffd [--help] [--diff=(0, 1) Default: 0.08.]
            [--activation-threshold=(0, 1) Default: 0.45.]
            [--radius=[1, 5] Default: 4.]
            [--denoise]
            input output

Positional arguments:
 input           Input file or "-" for reading from STDIN.
 output          Output file or "-" for writing to STDOUT.

Optional arguments:
 --help, -h      Prints this help.
 --diff, -d (0, 1) Default: 0.08.
                 Y (CIE XYZ) sensitivity.
 --activation-threshold, -a (0, 1) Default: 0.45.
                 The fraction of filled pixels within the fill window needed for
                 the white pixel in the output.
 --radius, -r [1, 5] Default: 4.
                 The fill window margin. The window width equals 2r+1.
 --denoise       Remove free-standing points.

```

## Performance

```
$ time flood_fill_filter --denoise samples2/IMG_2164_q40_orig.bmp samples2/out_fff.png

real    0m4,510s
user    0m14,724s
sys     0m0,577s

$ time fffd --denoise samples2/IMG_2164_q40_orig.bmp samples2/out_fffd.png

real    0m0,624s
user    0m3,777s
sys     0m0,072s

$ /usr/bin/time -v flood_fill_filter --denoise samples2/IMG_2164_q40_orig.bmp samples2/out_fff.png |& grep "Maximum resident"
	Maximum resident set size (kbytes): 172592

$ /usr/bin/time -v fffd --denoise samples2/IMG_2164_q40_orig.bmp samples2/out_fffd.png |& grep "Maximum resident"
	Maximum resident set size (kbytes): 61084
```

## Commercial use

All the code in this repository is written by one person.
So you may buy a non-exclusive right to use it in a closed-source products.
Copyright owner: Georgy Ustinov <georgy.ustinov.hello@gmail.com>
