#!/bin/sh
set -e
set -x

PLATFORM=OS
VERBOSE=no
SDK_VERSION=$(xcodebuild -showsdks | grep iphoneos | sort | tail -n 1 | awk '{print substr($NF,9)}')
# FIXME: why min deploy target can't use 5.1.1
SDK_MIN=6.0
ARCH=armv7
BUILD_MODE=release

# TODO: configure to compile speficy 3rd party libraries
OPTIONS=""
IS_EXPORT_CFLAGS=yes

usage()
{
cat << EOF
usage: $0 [-s] [-k sdk] [-a arch] [-l libname] [-m biuld mode] [-e export]

OPTIONS
   -k <sdk version>      Specify which sdk to use ('xcodebuild -showsdks', current: ${SDK_VERSION})
   -s            Build for simulator
   -a <arch>     Specify which arch to use (current: ${ARCH})
   -l <libname>  Specify which static library to build
   -m <build mode> Specify release or debug mode(current: ${BUILD_MODE})
   -e <export>  Specify whether to export cflags or not
EOF
}

spushd()
{
    pushd "$1" 2>&1> /dev/null
}

spopd()
{
    popd 2>&1> /dev/null
}

info()
{
    local blue="\033[1;34m"
    local normal="\033[0m"
    echo "[${blue}info${normal}] $1"
}


while getopts "hvsk:a:l:m:e:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         v)
             VERBOSE=yes
             ;;
         s)
             PLATFORM=Simulator
             ;;
         k)
             SDK_VERSION=$OPTARG
             ;;
         a)
             ARCH=$OPTARG
             ;;
         l)
             OPTIONS=--enable-$OPTARG
             ;;
         m)  BUILD_MODE=$OPTARG
             ;;
         e)
             IS_EXPORT_CFLAGS=$OPTARG
             ;;
         ?)
             usage
             exit 1
             ;;
     esac
done

if test -z "$OPTIONS"
then
    echo "You must specify a OPTIONS parameter."
    usage
    exit 1
fi

shift $(($OPTIND - 1))


if [ "x$1" != "x" ]; then
    usage
    exit 1
fi


out="/dev/null"
if [ "$VERBOSE" = "yes" ]; then
   out="/dev/stdout"
fi

info "Building cocos2d-x third party libraries for iOS"

if [ "$PLATFORM" = "Simulator" ]; then
    TARGET="${ARCH}-apple-darwin"
else
    TARGET="arm-apple-darwin"
fi

if [ $BUILD_MODE = "release" ]; then
    OPTIM="-O3 -DNDEBUG"
fi

if [ $BUILD_MODE = "debug" ]; then
    OPTIM="-O0 -g -DDEBUG"
fi

info "Using ${ARCH} with SDK version ${SDK_VERSION}"

THIS_SCRIPT_PATH=`pwd`

COCOSROOT=`pwd`/../../

if test -z "$SDKROOT"
then
    SDKROOT=`xcode-select -print-path`/Platforms/iPhone${PLATFORM}.platform/Developer/SDKs/iPhone${PLATFORM}${SDK_VERSION}.sdk
    echo "SDKROOT not specified, assuming $SDKROOT"
fi

if [ ! -d "${SDKROOT}" ]
then
    echo "*** ${SDKROOT} does not exist, please install required SDK, or set SDKROOT manually. ***"
    exit 1
fi

PREFIX="${COCOSROOT}/contrib/install-ios-${PLATFORM}/${ARCH}"

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/X11/bin"


info "Building contrib for iOS in '${COCOSROOT}/contrib/iPhone${PLATFORM}-${ARCH}'"

# The contrib will read the following
if [ $IS_EXPORT_CFLAGS = "yes" ]; then
export AR="xcrun ar"
export RANLIB="xcrun ranlib"
export CC="xcrun clang"
export OBJC="xcrun clang"
export CXX="xcrun clang++"
export LD="xcrun ld"
export STRIP="xcrun strip"

if [ "$PLATFORM" = "OS" ]; then
export CFLAGS="-isysroot ${SDKROOT} -arch ${ARCH} -miphoneos-version-min=${SDK_MIN} ${OPTIM}"
if [ "$ARCH" != "arm64" ]; then
export CFLAGS="${CFLAGS} -mcpu=cortex-a8"
fi
else
export CFLAGS="-isysroot ${SDKROOT} -arch ${ARCH} -miphoneos-version-min=${SDK_MIN} ${OPTIM}"
fi

export CPP="xcrun cc -E"
export CXXCPP="xcrun c++ -E"

if [ "$PLATFORM" = "Simulator" ]; then
    # Use the new ABI on simulator, else we can't build
    export OBJCFLAGS="-fobjc-abi-version=2 -fobjc-legacy-dispatch ${OBJCFLAGS}"
fi

export LDFLAGS="-L${SDKROOT}/usr/lib -arch ${ARCH} -isysroot ${SDKROOT} -miphoneos-version-min=${SDK_MIN}"

EXTRA_CFLAGS=""

info "LD FLAGS SELECTED = '${LDFLAGS}'"
fi

export PLATFORM=$PLATFORM
export SDK_VERSION=$SDK_VERSION


export BUILDFORIOS="yes"

spushd ${COCOSROOT}

echo ${COCOSROOT}
mkdir -p "${COCOSROOT}/contrib/iPhone${PLATFORM}-${ARCH}"
spushd "${COCOSROOT}/contrib/iPhone${PLATFORM}-${ARCH}"

## FIXME: do we need to replace Apple's gas?
if [ "$PLATFORM" = "OS" ]; then
    export AS="gas-preprocessor.pl ${CC}"
    export ASCPP="gas-preprocessor.pl ${CC}"
    export CCAS="gas-preprocessor.pl ${CC}"
    if [ "$ARCH" = "arm64" ]; then
        export GASPP_FIX_XCODE5=1
    fi
else
    export ASCPP="xcrun as"
fi



../bootstrap ${OPTIONS} \
        --build=x86_64-apple-darwin14 \
        --host=${TARGET} \
        --prefix=${PREFIX} > ${out}

echo "EXTRA_CFLAGS = ${EXTRA_CFLAGS}" >> config.mak
echo "EXTRA_LDFLAGS = ${EXTRA_LDFLAGS}" >> config.mak
echo "IOS_ARCH := ${ARCH}" >> config.mak
echo "BUILD_MODE := ${BUILD_MODE}" >> config.mak
echo "OPTIM := ${OPTIM}" >> config.mak

make fetch
make list
make
spopd
