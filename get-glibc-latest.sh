PACKAGE=glibc
VERSION=latest
URL=https://ftp.gnu.org/gnu/libc
EXT="tar.xz"

latest_version() {
  wget -qO - $URL 2>/dev/null | \
  grep -oE "$PACKAGE-([0-9.]+).$EXT" | sed -E "s/$PACKAGE-([0-9.]+)\.tar\.[glx]z/\1/" | \
  sort -Vr | sed q
}

if [ "$VERSION" = "latest" ]; then
  VERSION=$(latest_version)
  echo $VERSION
fi

echo $VERSION
download(){
  wget -O "$PACKAGE-$VERSION.$EXT" "$URL/$PACKAGE-$VERSION.$EXT"
}

prepare() {
  tar xvf "$PACKAGE-$VERSION.$EXT" 
  cd "$PACKAGE-$VERSION"
}

download
prepare