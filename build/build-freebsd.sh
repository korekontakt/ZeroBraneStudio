#!/usr/bin/env bash

# exit if the command line is empty
if [ $# -eq 0 ]; then
  echo "Usage: $0 LIBRARY..."
  exit 0
fi

case "$(uname -m)" in
	x86_64)
		FPIC="-fpic"
		ARCH="x64"
		;;
	armv7l)
		FPIC="-fpic"
		ARCH="armhf"
		;;
	*)
		FPIC=""
		ARCH="x86"
		;;
esac

OS="$(uname)"
OS_BIN=`echo ${OS,,}`
if [[ $OS == "FreeBSD" ]]; then
	LOCALBASE=/usr/local
    LD_LIBRARY_PATH=${LOCALBASE}/lib/gcc48:$LD_LIBRARY_PATH
    CMAKE_LIBRARY_PATH=${LOCALBASE}/lib:$LD_LIBRARY_PATH:$CMAKE_LIBRARY_PATH
    CMAKE_INCLUDE_PATH=${LOCALBASE}/include:$CMAKE_INCLUDE_PATH
    CC=gcc
    CXX=g++

	if [[ "$(uname -m)" == "amd64" ]]; then
		FPIC="-fPIC"
		ARCH="x64"
	fi
	echo "Building for $OS ($ARCH) ..."
else
	OS_BIN="linux"
fi

# binary directory
BIN_DIR="$(dirname "$PWD")/bin/$OS_BIN/$ARCH"
echo "BIN_DIR = $BIN_DIR"

# temporary installation directory for dependencies
INSTALL_DIR="$PWD/deps"

# number of parallel jobs used for building
MAKEFLAGS="-j4"

# flags for manual building with gcc
BUILD_FLAGS="-O2 -shared -s -I $INSTALL_DIR/include -I ${LOCALBASE}/include -L $INSTALL_DIR/lib -L ${LOCALBASE}/lib $FPIC"

# paths configuration
WXWIDGETS_BASENAME="wxWidgets"
WXWIDGETS_URL="https://github.com/pkulchenko/wxWidgets.git"

WXLUA_BASENAME="wxlua"
WXLUA_URL="https://github.com/korekontakt/wxlua.git"

WXSTEDIT_BASENAME="wxstedit"
WXSTEDIT_FILENAME="wxstedit-1.2.5.tar.gz"
WXSTEDIT_URL="http://ufpr.dl.sourceforge.net/project/wxcode/Components/wxStEdit/$WXSTEDIT_FILENAME"

LUASOCKET_BASENAME="luasocket-3.0-rc1"
LUASOCKET_FILENAME="v3.0-rc1.zip"
LUASOCKET_URL="https://github.com/diegonehab/luasocket/archive/$LUASOCKET_FILENAME"

LUASEC_BASENAME="luasec-0.6"
LUASEC_FILENAME="$LUASEC_BASENAME.zip"
LUASEC_URL="https://github.com/brunoos/luasec/archive/$LUASEC_FILENAME"

WXWIDGETSDEBUG="--disable-debug"
WXLUABUILD="MinSizeRel"               

# iterate through the command line arguments
for ARG in "$@"; do
  case $ARG in
  5.1)
    BUILD_LUA=true
	WX_LUA_VERSION=5.1
    ;;
  5.2)
    BUILD_52=true
	WX_LUA_VERSION=5.2
    ;;
  5.3)
    BUILD_53=true
    BUILD_FLAGS="$BUILD_FLAGS -DLUA_COMPAT_APIINTCASTS"
	WX_LUA_VERSION=5.3
	WXLUA_CXX_FLAGS="-DLUA_COMPAT_MODULE -DLUA_COMPAT_5_2"
    ;;
  jit)
    BUILD_JIT=true
    ;;
  wxwidgets)
    BUILD_WXWIDGETS=true
    ;;
  lua)
    BUILD_LUA=true
    ;;
  wxlua)
    BUILD_WXLUA=true
    ;;
  luasec)
    BUILD_LUASEC=true
    ;;
  luasocket)
    BUILD_LUASOCKET=true
    ;;
  debug)
    WXWIDGETSDEBUG="--enable-debug=max --enable-debug_gdb"
    WXLUABUILD="Debug"
    ;;
  release)
    WXLUABUILD="Release"
    ;;
  useclang)
	USE_CLANG=true
	;;
  rmdir)
	RM_DIR=true
	;;
  all)
    BUILD_WXWIDGETS=true
    BUILD_LUA=true
    BUILD_WXLUA=true
    BUILD_LUASOCKET=true
    ;;
  *)
    echo "Error: invalid argument $ARG"
    exit 1
    ;;
  esac
done

WX_LUA_VERSION=${WX_LUA_VERSION:-"5.1"} # by default install lua 5.1
WXLUA_BUILD_FLAGS="-Os -fPIC -Wdeprecated-declarations"
if [ $USE_CLANG ]; then
	WXLUA_CC=clang
	WXLUA_CXX=clang++
	WXLUA_BUILD_FLAGS="${WXLUA_BUILD_FLAGS} -I${LOCALBASE}/include -L${LOCALBASE}/lib"
else
	WXLUA_CC=$CC
	WXLUA_CXX=$CXX
fi

# check for g++
if [ ! "$(which g++)" ]; then
  echo "Error: g++ isn't found. Please install GNU C++ compiler."
  exit 1
fi

# check for cmake
if [ ! "$(which cmake)" ]; then
  echo "Error: cmake isn't found. Please install CMake and add it to PATH."
  exit 1
fi

# check for git
if [ ! "$(which git)" ]; then
  echo "Error: git isn't found. Please install console GIT client."
  exit 1
fi

# check for wget
if [ ! "$(which wget)" ]; then
  echo "Error: wget isn't found. Please install GNU Wget."
  exit 1
fi

# create the installation directory
mkdir -p "$INSTALL_DIR" || { echo "Error: cannot create directory $INSTALL_DIR"; exit 1; }

LUAV="51"
LUAS=""
LUA_BASENAME="lua-5.1.5"

if [ $BUILD_52 ]; then
  LUAV="52"
  LUAS=$LUAV
  LUA_BASENAME="lua-5.2.4"
fi

LUA_FILENAME="$LUA_BASENAME.tar.gz"
LUA_URL="http://www.lua.org/ftp/$LUA_FILENAME"

if [ $BUILD_53 ]; then
  LUAV="53"
  LUAS=$LUAV
  LUA_BASENAME="lua-5.3.3"
  LUA_FILENAME="$LUA_BASENAME.tar.gz"
  LUA_URL="http://www.lua.org/ftp/$LUA_FILENAME"
fi

if [ $BUILD_JIT ]; then
  LUA_BASENAME="LuaJIT-2.1.0-beta2"
  LUA_FILENAME="$LUA_BASENAME.tar.gz"
  LUA_URL="http://luajit.org/download/$LUA_FILENAME"
fi

# build wxWidgets
if [ $BUILD_WXWIDGETS ]; then
  if [[ ! -d "$WXWIDGETS_BASENAME" ]]; then
    git clone "$WXWIDGETS_URL" "$WXWIDGETS_BASENAME" || { echo "Error: failed to get wxWidgets"; exit 1; }
  fi
  cd "$WXWIDGETS_BASENAME"
  ./configure --prefix="$INSTALL_DIR" $WXWIDGETSDEBUG --disable-shared --enable-unicode --disable-precomp-headers \
    --enable-compat28 \
    --with-libjpeg=builtin --with-libpng=builtin --with-libtiff=builtin --with-expat=sys \
    --with-zlib=builtin --with-opengl --with-gtk2 \
		--enable-backtrace \
		--enable-graphics_ctx \
		--enable-compat26 \
		--enable-compat28 \
    CFLAGS="-Os -fPIC" CXXFLAGS="-Os -fPIC -std=c++11" CPPFLAGS="-I${LOCALBASE}/include" LIBS="-L${LOCALBASE}/lib" \
	USES="compiler:c++11-lib execinfo gmake iconv jpeg pkgconfig tar:bzip2" \
	USE_XORG="x11 sm xxf86vm xinerama" \
	USE_GL="glu" \
	USE_GNOME="gtk20" \
	USE_LDCONFIG="yes" \
	GNU_CONFIGURE="yes" \
	CONFIGURE_ENV="X11BASE=\"${LOCALBASE}\" \
			ac_cv_header_sys_inotify_h=no" \
	OPTIONS_DEFINE="GSTREAMER MSPACK NLS WEBKIT" \
	OPTIONS_DEFAULT="GSTREAMER MSPACK WEBKIT" \
	MSPACK_DESC="Microsoft archives support" \
	OPTIONS_SUB="yes" \
	NLS_USES="gettext" \
	GSTREAMER_CONFIGURE_ENABLE="mediactrl" \
	GSTREAMER_USE="GNOME=gconf2 GSTREAMER=yes" \
	MSPACK_CONFIGURE_WITH="libmspack" \
	MSPACK_LIB_DEPENDS="libmspack.so:archivers/libmspack" \
	WEBKIT_CONFIGURE_ENABLE="webview" \
	WEBKIT_LIB_DEPENDS="libwebkitgtk-1.0.so:www/webkit-gtk2"
  make $MAKEFLAGS || { echo "Error: failed to build wxWidgets"; exit 1; }
  make install
  cd ..
  if [ $RM_DIR ]; then
    rm -rf "$WXWIDGETS_BASENAME"
  fi
fi

# build Lua
if [ $BUILD_LUA ]; then
  if [[ ! -d "$LUA_BASENAME" ]]; then
    wget -c "$LUA_URL" -O "$LUA_FILENAME" || { echo "Error: failed to download Lua"; exit 1; }
    tar -xzf "$LUA_FILENAME"
  fi
  cd "$LUA_BASENAME"

  if [ $BUILD_JIT ]; then
	export MAKE=gmake
    $MAKE CCOPT="-DLUAJIT_ENABLE_LUA52COMPAT" || { echo "Error: failed to build Lua"; exit 1; }
    $MAKE install PREFIX="$INSTALL_DIR"
    cp "$INSTALL_DIR/bin/luajit" "$INSTALL_DIR/bin/lua"
    # move luajit to lua as it's expected by luasocket and other components
    cp "$INSTALL_DIR"/include/luajit*/* "$INSTALL_DIR/include/"
  else
    # use POSIX as it has minimum dependencies (no readline and no ncurses required)
    # LUA_USE_DLOPEN is required for loading libraries
    (cd src; make all MYCFLAGS="$FPIC -DLUA_USE_POSIX -DLUA_USE_DLOPEN" MYLIBS="-Wl,-E -L${LOCALBASE}/lib -ledit") || { echo "Error: failed to build Lua"; exit 1; }
    make install INSTALL_TOP="$INSTALL_DIR"
  fi
  cp "$INSTALL_DIR/bin/lua" "$INSTALL_DIR/bin/lua$LUAV"

  cd ..
  if [ $RM_DIR ]; then
    rm -rf "$LUA_FILENAME" "$LUA_BASENAME"
  fi
fi

# build wxLua
if [ $BUILD_WXLUA ]; then
  if [[ ! -d "$WXSTEDIT_BASENAME" ]]; then
    wget -c "$WXSTEDIT_URL" -O "$WXSTEDIT_FILENAME" || { echo "Error: failed to download wxStEdit"; exit 1; }
    gzip -d < "$WXSTEDIT_FILENAME" | tar xvf -
  fi
  WXSTEDIT_DIR="$(dirname "$PWD")/build/$WXSTEDIT_BASENAME"

  if [[ ! -d "$WXLUA_BASENAME" ]]; then
    git clone "$WXLUA_URL" "$WXLUA_BASENAME" || { echo "Error: failed to get wxWidgets"; exit 1; }
	TO_SED=true
  fi
  cd "$WXLUA_BASENAME/wxLua"
  git checkout wxwidgets311

  if [[ $TO_SED ]]; then
	# the following patches wxlua source to fix live coding support in wxlua apps
	# http://www.mail-archive.com/wxlua-users@lists.sourceforge.net/msg03225.html
	sed -i 's/\(m_wxlState = wxLuaState(wxlState.GetLuaState(), wxLUASTATE_GETSTATE|wxLUASTATE_ROOTSTATE);\)/\/\/ removed by ZBS build process \/\/ \1/' modules/wxlua/wxlcallb.cpp

	# remove "Unable to call an unknown method..." error as it leads to a leak
	# see http://sourceforge.net/p/wxlua/mailman/message/34629522/ for details
	sed -i '/Unable to call an unknown method/{N;s/.*/    \/\/ removed by ZBS build process/}' modules/wxlua/wxlbind.cpp
  fi

  WXLUA_COMPONENTS="stc;gl;html;aui;adv;core;net;base"
  if [ $BUILD_JIT ]; then
	WXLUA_C_FLAGS="-std=gnu99"
	WXLUA_CXX_FLAGS="-std=gnu++11"
	WXLUA_USE_LUAJIT="TRUE"
  else
	WXLUA_COMPONENTS="${WXLUA_COMPONENTS};webview;xrc;richtext;propgrid;media;xml"
	WXLUA_C_FLAGS="-std=gnu99"
	WXLUA_CXX_FLAGS="${WXLUA_CXX_FLAGS} -std=gnu++11 -Wall -DLUA_USE_POSIX -DLUA_USE_DLOPEN -DLUA_COMPAT_ALL"
	WXLUA_USE_LUAJIT="FALSE"
  fi

  if [ $USE_CLANG ]; then
	CC=clang
	CXX=clang++
  fi
  cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" -DCMAKE_BUILD_TYPE=$WXLUABUILD -DBUILD_SHARED_LIBS=FALSE \
    -DwxWidgets_CONFIG_EXECUTABLE="$INSTALL_DIR/bin/wx-config" \
	-DCMAKE_C_FLAGS="$WXLUA_BUILD_FLAGS $WXLUA_C_FLAGS" -DCMAKE_CXX_FLAGS="$WXLUA_BUILD_FLAGS $WXLUA_CXX_FLAGS" \
	-DwxLua_LUA_LIBRARY_VERSION=$WX_LUA_VERSION -DwxLua_USE_LUAJIT=$WXLUA_USE_LUAJIT \
    -DwxWidgets_COMPONENTS="$WXLUA_COMPONENTS" \
    -DwxLuaBind_COMPONENTS="$WXLUA_COMPONENTS" -DwxLua_LUA_LIBRARY_USE_BUILTIN=FALSE \
    -DwxLua_LUA_INCLUDE_DIR="$INSTALL_DIR/include" -DwxLua_LUA_LIBRARY="$INSTALL_DIR/lib/liblua.a" .
  (cd modules/luamodule; make $MAKEFLAGS) || { echo "Error: failed to build wxLua"; exit 1; }
  (cd modules/luamodule; make install)
  [ -f "$INSTALL_DIR/lib/libwx.so" ] || { echo "Error: libwx.so isn't found"; exit 1; }
  [ "$WXLUABUILD" != "Debug" ] && strip --strip-unneeded "$INSTALL_DIR/lib/libwx.so"
  cd ../..
  #if [ $RM_DIR ]; then
  #  rm -rf "$WXLUA_BASENAME"
  #fi
fi

# build LuaSocket
if [ $BUILD_LUASOCKET ]; then
  if [[ ! -d "$LUASOCKET_BASENAME" ]]; then
    wget --no-check-certificate -c "$LUASOCKET_URL" -O "$LUASOCKET_FILENAME" || { echo "Error: failed to download LuaSocket"; exit 1; }
    unzip "$LUASOCKET_FILENAME"
  fi
  cd "$LUASOCKET_BASENAME"
  mkdir -p "$INSTALL_DIR/lib/lua/$LUAV/"{mime,socket}
  gcc $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAV/mime/core.so" src/mime.c -llua \
    || { echo "Error: failed to build LuaSocket"; exit 1; }
  gcc $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAV/socket/core.so" \
    src/{auxiliar.c,buffer.c,except.c,inet.c,io.c,luasocket.c,options.c,select.c,tcp.c,timeout.c,udp.c,usocket.c} -llua \
    || { echo "Error: failed to build LuaSocket"; exit 1; }
  mkdir -p "$INSTALL_DIR/share/lua/$LUAV/socket"
  cp src/{ftp.lua,http.lua,smtp.lua,tp.lua,url.lua} "$INSTALL_DIR/share/lua/$LUAV/socket"
  cp src/{ltn12.lua,mime.lua,socket.lua} "$INSTALL_DIR/share/lua/$LUAV"
  [ -f "$INSTALL_DIR/lib/lua/$LUAV/mime/core.so" ] || { echo "Error: mime/core.so isn't found"; exit 1; }
  [ -f "$INSTALL_DIR/lib/lua/$LUAV/socket/core.so" ] || { echo "Error: socket/core.so isn't found"; exit 1; }
  cd ..
  if [ $RM_DIR ]; then
    rm -rf "$LUASOCKET_FILENAME" "$LUASOCKET_BASENAME"
  fi
fi

# build LuaSec
if [ $BUILD_LUASEC ]; then
  # build LuaSec
  if [[ ! -d "$LUASEC_BASENAME" ]]; then
    wget --no-check-certificate -c "$LUASEC_URL" -O "$LUASEC_FILENAME" || { echo "Error: failed to download LuaSec"; exit 1; }
	unzip "$LUASEC_FILENAME"
  fi
  # the folder in the archive is "luasec-luasec-....", so need to fix
  mv "luasec-$LUASEC_BASENAME" $LUASEC_BASENAME
  cd "$LUASEC_BASENAME"
  gcc $BUILD_FLAGS -o "$INSTALL_DIR/lib/lua/$LUAD/ssl.so" \
    src/luasocket/{timeout.c,buffer.c,io.c,usocket.c} src/{context.c,x509.c,ssl.c} -Isrc \
    -lssl -lcrypto \
    || { echo "Error: failed to build LuaSec"; exit 1; }
  cp src/ssl.lua "$INSTALL_DIR/share/lua/$LUAD"
  mkdir -p "$INSTALL_DIR/share/lua/$LUAD/ssl"
  cp src/https.lua "$INSTALL_DIR/share/lua/$LUAD/ssl"
  [ -f "$INSTALL_DIR/lib/lua/$LUAD/ssl.so" ] || { echo "Error: ssl.so isn't found"; exit 1; }
  strip --strip-unneeded "$INSTALL_DIR/lib/lua/$LUAD/ssl.so"
  cd ..
  if [ $RM_DIR ]; then
    rm -rf "$LUASEC_FILENAME" "$LUASEC_BASENAME"
  fi
fi

# now copy the compiled dependencies to ZBS binary directory
if [[ ! -d "$BIN_DIR" ]]; then
  mkdir -p "$BIN_DIR" || { echo "Error: cannot create directory $BIN_DIR"; exit 1; }
fi
if [ $BUILD_LUA ]; then
  cp "$INSTALL_DIR/bin/lua$LUAS" "$BIN_DIR"
  if [ $LUAV == "51" ]; then
    cp "$INSTALL_DIR/bin/lua" "$BIN_DIR/lua$LUAV"
  fi
fi
if [ $BUILD_JIT ]; then
  cp "$INSTALL_DIR/bin/luajit" "$BIN_DIR"
fi
if [ $BUILD_WXLUA ]; then
  cp "$INSTALL_DIR/lib/libwx.so" "$BIN_DIR"
  if [ $BUILD_JIT ]; then
    cp "$INSTALL_DIR/lib/libwx.so" "$BIN_DIR/libwx-jit.so"
  else
    cp "$INSTALL_DIR/lib/libwx.so" "$BIN_DIR/libwx-$LUAV.so"
  fi
fi

if [ $BUILD_LUASOCKET ]; then
  mkdir -p "$BIN_DIR/clibs$LUAS/"{mime,socket}
  cp "$INSTALL_DIR/lib/lua/$LUAV/mime/core.so" "$BIN_DIR/clibs$LUAS/mime"
  cp "$INSTALL_DIR/lib/lua/$LUAV/socket/core.so" "$BIN_DIR/clibs$LUAS/socket"
fi

if [ $BUILD_LUASEC ]; then
  cp "$INSTALL_DIR/lib/lua/$LUAD/ssl.so" "$BIN_DIR/clibs$LUAS"
  cp "$INSTALL_DIR/share/lua/$LUAD/ssl.lua" ../lualibs
  cp "$INSTALL_DIR/share/lua/$LUAD/ssl/https.lua" ../lualibs/ssl
fi

echo "*** Build has been successfully completed ***"
exit 0
