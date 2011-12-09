#!/bin/sh

NAME=iplant-zoidberg-`cat zoidberg.spec | grep Version | cut -d ' ' -f 2`
BUILD=build/$NAME

if [ -d build ]; then
    rm -rf build
fi

mkdir -p $BUILD
cp README $BUILD
cp Makefile $BUILD
cp -r src $BUILD
cp -r conf $BUILD
cp -r scripts $BUILD
cp *.spec $BUILD

pushd build
tar czf $NAME.tar.gz $NAME/
popd