#!/bin/bash -e
#
# Script to generate a .deb package for Python.
#
# Tested with 2.7.*, 3.5.*, 3.6.*, 3.7.*, 3.8.*, 3.9.*, 3.10.*, 3.11.*, 3.12.*.
#
distro=$(lsb_release --release --short)
platform=$(lsb_release --id --short | tr A-Z a-z)
if [ "$platform" = pop ] ; then
    platform=ubuntu
fi
VERSION=${1:-3.6.7}
ver=$VERSION
MAJOR=`echo $ver | sed 's/^\([0-9][0-9]*\)[.].*$/\1/'`
MINOR=`echo $ver | sed 's/^[0-9][0-9]*[.]\([0-9][0-9]*\)[.].*$/\1/'`
PATCH=`echo $ver | sed 's/^[0-9][0-9]*[.][0-9][0-9]*[.]\([0-9][0-9]*\).*$/\1/'`
SHORTVERSION="${MAJOR}${MINOR}"
NAME="cleanpython${SHORTVERSION}"
# Make sure the filename reflects the distro version for easy identification:
BUILD="${2:-1}${platform}${distro}"
ARCH="`dpkg --print-architecture`"

top=$(dirname "$0")
top=$(cd "$top"; pwd)

PVAVERSION=`echo "$VERSION" | sed 's/\([a-z]\)/~\1/'`
pva="${NAME}_${PVAVERSION}-${BUILD}_${ARCH}"
pkgfile="${pva}.deb"
destdir="/tmp/${pva}"
prefix="/opt/${NAME}"
buildroot="/tmp/pydeb-${VERSION}-$$"
root="${destdir}${prefix}"
sources="${top}/sources"
source="${sources}/Python-${VERSION}.tar.xz"

deps=''
deppfx="${top}/dependencies/${platform}"

for sfx in "py${SHORTVERSION}.${distro}" "${distro}" "py${SHORTVERSION}" ; do
    fn="${deppfx}.${sfx}"
    echo "checking for $fn"
    if [ -f "$fn" ] ; then
	deps="$fn"
	break
    fi
done
if [ -z "${deps}" ] ; then
    echo >&2 "Could not locate dependencies specification."
    exit 1
fi

# Start with a clean slate:
rm -rf "$destdir"
rm -rf "$buildroot"

mkdir -p "$root"
mkdir -p "$buildroot"

cd "$buildroot"
xzcat "$source" | tar x
cd "Python-${VERSION}"

LDFLAGS="-Wl,-rpath=$prefix/lib" \
./configure \
    --enable-ipv6 \
    --enable-optimizations \
    --enable-shared \
    --enable-unicode=ucs4 \
    --with-system-ffi \
    --prefix "$prefix"

make
# make test
make DESTDIR="$destdir" install
LD_LIBRARY_PATH="$root/lib" "${root}/bin/python${MAJOR}" -m ensurepip

# ensurepip installs pip & setuptools into the python we just built, but
# does not honor DESTDIR correctly.  We re-write the shbang lines so the
# results work.
#
# https://bugs.python.org/issue31916
#
(cd "${root}/bin";
 for fn in `find -type f | xargs file --mime |
                grep text/ | sed 's|[.]/\([^:]*\):.*$|\1|'` ; do
     if head -1 "$fn" | grep -q -- "^#!${destdir}${prefix}/bin/" ; then
         sed --in-place -e "s|^#!${destdir}/|#!/|" "$fn"
     fi
 done)

cd "$top"
rm -r "$buildroot"

(cd "$root/lib";
 export LD_LIBRARY_PATH="`pwd`";
 ../bin/python${MAJOR} -m compileall -fq -d "${prefix}/lib" . || true)
chmod -R go-w "$root"
mkdir "${destdir}/DEBIAN"
sed -e 's|::SHORTVERSION::|'"${SHORTVERSION}"'|g' \
    -e 's|::VERSION::|'"${VERSION}"'|g' \
    -e 's|::BUILD::|'"${BUILD}"'|g' \
    -e 's|::ARCH::|'"${ARCH}"'|g' \
    -e 's|::NAME::|'"${NAME}"'|g' \
    -e 's|::MAJOR::|'"${MAJOR}"'|g' \
    -e 's|::MINOR::|'"${MINOR}"'|g' \
    -e 's|::PATCH::|'"${PATCH}"'|g' \
    <"${top}/control.in" >"${destdir}/DEBIAN/control"

echo "Using dependencies: ${deps}"
cat "$deps" >>"${destdir}/DEBIAN/control"

(cd /tmp; fakeroot dpkg-deb -z9 -Zgzip -b "$pva")
rm -rf "${top}/${pkgfile}"
mv "/tmp/${pkgfile}" "${top}/"
chmod a-w "${top}/${pkgfile}"
chmod -R u+w "$destdir"
rm -r "$destdir"
