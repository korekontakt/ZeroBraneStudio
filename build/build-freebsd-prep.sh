#!/usr/bin/env sh

# this script installs prerequisites to build binary files on FreeBSD with pkg

sudo pkg install -y gcc git cmake wx30-gtk2 wget sqlite libGLw gzip bash

#WX_LUA_VERSION=5.1
# ./build-freebsd.sh wxwidgets
# ./build-freebsd.sh lua luasocket luasec
# ./build-freebsd.sh lua jit luasocket luasec
# ./build-freebsd.sh lua 5.2 luasocket luasec
# ./build-freebsd.sh lua 5.3 luasocket luasec
# ./build-freebsd.sh $WX_LUA_VERSION wxlua
# ./build-freebsd.sh $WX_LUA_VERSION luasocket
# ./build-freebsd.sh $WX_LUA_VERSION luasec
# To build all
# ./build-freebsd.sh wxwidgets lua 5.1 luasocket luasec wxlua
