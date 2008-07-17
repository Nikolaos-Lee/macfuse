#!/bin/bash
# Copyright (C) 2008 Google. All Rights Reserved.
#
# Creates MacFUSE.pkg with all supported platforms.

PATH="/bin:/usr/bin:/usr/sbin"; export PATH

CUT=/usr/bin/cut
DIRNAME=/usr/bin/dirname
TRUE=/usr/bin/true

# Set of platforms to build for. We start with '0' to clean things up.
PLATFORMS=${PLATFORMS:-"0 8 9"}
if [ "$SKIP_PLATFORMS" = "1" ]
then
  PLATFORMS=""
fi

# TODO: Remove this when updater is in tree!
MACFUSE_UPDATER="$1"
if [ -z "$MACFUSE_UPDATER" ]
then
  echo "Temporary: Must pass MACFUSE_UPDATER path as argument."
  exit 1
fi

sudo $TRUE  # Need root password to delete previous builds
if [ $? -ne 0 ]
then
  echo "Administrator password is required."
  exit 1
fi

is_absolute_path=`echo "$0" | $CUT -c1`
if [ "$is_absolute_path" = "/" ]
then
    macfuse_dir="`$DIRNAME $0`/.."
else
    macfuse_dir="`pwd`/`$DIRNAME $0`/.."
fi
pushd . > /dev/null
cd "$macfuse_dir" || exit 1
macfuse_dir=`pwd`
popd > /dev/null

# Build for requested platforms.
for i in $PLATFORMS
do
$macfuse_dir/core/build_macfuse.sh $i
if [ $? -ne 0 ]
then
  echo "Failed building for platform: $i"
  exit 1
fi
done

TIGER_VERSION=33
LEOPARD_VERSION=44
DMG_SIZE=
DMG_HASH=
DMG_NAME=

# We construct the os_version=platform_pkg argument string for each platform
# that is found.
PLATFORM_ARG=""
PLATFORM_DIRS=`ls -d /tmp/macfuse-core-*`
echo "PLATFORMS: ${PLATFORM_DIRS}"
for i in $PLATFORM_DIRS 
do
  # The platform dirs look like: /tmp/macfuse-core-10.5-1.6.1
  VERSIONS=${i#*core-}      # Grab 10.5-1.6.1
  RELEASE_VERSION=${VERSIONS#*-}  # Save example release version (i.e. 1.6.1)
  OS_VERSION=${VERSIONS%-*}       # Grab os version (i.e. 10.5)
  PLATFORM_ARG="${PLATFORM_ARG},${OS_VERSION}=${i}/MacFUSE Core.pkg"
  case "$OS_VERSION" in
    10.5)
      LEOPARD_VERSION=$RELEASE_VERSION
      ;;
    10.4)
      TIGER_VERSION=$RELEASE_VERSION
      ;;
  esac
  echo "OS_VERSION: $OS_VERSION"
  echo "RELEASE_VERSION: $RELEASE_VERSION"
done

# Our MacFUSE.pkg will have only the major version (i.e. 1.6)
MAJOR_RELEASE_VERSION=${RELEASE_VERSION%.*}  # Strip off final version part
OUTPUT_DIR="/tmp/macfuse-$MAJOR_RELEASE_VERSION"

# Clean up any previous iteration.
rm -rf "$OUTPUT_DIR"

echo "-Building MacFUSE.pkg-"
echo "RELEASE_ARG=$MAJOR_RELEASE_VERSION"
echo "MACFUSE_UPDATER=$MACFUSE_UPDATER"
echo "PLATFORM_ARG=${PLATFORM_ARG}"
pushd "$macfuse_dir/core/packaging/macfuse/"
./make-pkg.sh "$MAJOR_RELEASE_VERSION" "$MACFUSE_UPDATER" "$PLATFORM_ARG"
if [ $? -ne 0 ]
then
  echo "Failed to build MacFUSE.pkg"
  popd
  exit 1
fi
popd

# Make CurrentRelease.plist

DMG_NAME="MacFUSE-$MAJOR_RELEASE_VERSION.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"
DMG_HASH=$(openssl sha1 -binary "$DMG_PATH" | openssl base64)
DMG_SIZE=$(stat -f%z "$DMG_PATH")

cat > "$OUTPUT_DIR/CurrentRelease.plist" <<__END_CONFIG
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Rules</key>
  <array>
    <dict>
      <key>ProductID</key>
      <string>com.google.filesystems.fusefs</string>
      <key>Predicate</key>
      <string>SystemVersion.ProductVersion beginswith "10.5" AND Ticket.version != "$LEOPARD_VERSION"</string>
      <key>Version</key>
      <string>$LEOPARD_VERSION</string>
      <key>Codebase</key>
      <string>http://macfuse.googlecode.com/files/$DMG_NAME</string>
      <key>Hash</key>
      <string>$DMG_HASH</string>
      <key>Size</key>
      <string>$DMG_SIZE</string>
    </dict>
    <dict>
      <key>ProductID</key>
      <string>com.google.filesystems.fusefs</string>
      <key>Predicate</key>
      <string>SystemVersion.ProductVersion beginswith "10.4" AND Ticket.version != "$TIGER_VERSION"</string>
      <key>Version</key>
      <string>$TIGER_VERSION</string>
      <key>Codebase</key>
      <string>http://macfuse.googlecode.com/files/$DMG_NAME</string>
      <key>Hash</key>
      <string>$DMG_HASH</string>
      <key>Size</key>
      <string>$DMG_SIZE</string>
    </dict>
  </array>
</dict>
</plist>
__END_CONFIG

exit 0