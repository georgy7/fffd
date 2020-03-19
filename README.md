# fffd

D port of flood-fill-filter

## Installation

```sh
dub build --build=release --compiler=ldc2
sudo cp fffd /usr/local/bin/
```

## Performance

TODO

## Restrictions

It uses [dlib](https://github.com/gecko0307/dlib) for image decoding.
It does not support reading progressive JPEGs yet.
Anyway, it is not very important for online services, cause the images
may be re-encoded before by third-party tools.

## Commercial use

All the code in this repository is written by one person.
So you may buy a non-exclusive right to use it in a closed-source products.
Copyright owner: Georgy Ustinov <georgy.ustinov.hello@gmail.com>

AGPLv3 defines "modify" as "to copy from or adapt all or part of the work
in a fashion requiring copyright permission, other than the making of an
exact copy". Thus "covered work" includes derivative works.
Sublicensing is not allowed, except for paragraph 13 of this license
allows you to link any covered work with the GPLv3 code.
