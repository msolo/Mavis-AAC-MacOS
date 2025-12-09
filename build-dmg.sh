#!/bin/sh

set -e

APP_NAME="Mavis AAC"
APP_PATH="Build/Products/Release/$APP_NAME.app"
DMG_NAME="Build/Products/Release/Mavis-AAC.dmg"
VOLUME_NAME="$APP_NAME"

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH not found" >&2
    exit 1
fi

# Get the size of the app and leave a bit of padding.
DMG_SIZE=$(du -sm "$APP_PATH" | awk '{print $1*1.1"m"}')

# Create temporary directory
TMP_DIR=$(mktemp -d -t build-dmg)
TMP_DMG="$TMP_DIR/temp.dmg"
MOUNT_NAME="temp-$(date +%s).mnt"
MOUNT_DIR="$TMP_DIR/$MOUNT_NAME"

function cleanup {
  rm -rf "$TMP_DIR" || hdiutil detach -quiet "$MOUNT_DIR"
  rm -rf "$TMP_DIR"
}
trap "cleanup" EXIT
rm -rf "./$DMG_NAME"

# Create temporary DMG
hdiutil create -quiet -size $DMG_SIZE -fs APFS -volname "$VOLUME_NAME" "$TMP_DMG"

# Mount the DMG
hdiutil attach -quiet -readwrite -noverify -noautoopen -mountpoint "$MOUNT_DIR" "$TMP_DMG"

# Copy app to DMG
cp -R "$APP_PATH" "$MOUNT_DIR/"

# Create Applications symlink for drag-and-drop
ln -s /Applications "$MOUNT_DIR/Applications"

mkdir "$MOUNT_DIR/.background"
cp dmg/background.png "$MOUNT_DIR/.background/"

# Background size 654 × 422
# The geometry is a trainwreck. The container window at {0,0} has padding.
# y offset is 40, x offset is 28
# The MOUNT_NAME is what the Finder uses - not the cosmetic VOLUME_NAME.
osascript <<EOF
tell application "Finder"
    tell disk "$MOUNT_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 754, 550}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background picture of viewOptions to file ".background:background.png"
        set position of item "$APP_NAME.app" of container window to {200, 190}
        set position of item "Applications" of container window to {470, 190}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

sync
hdiutil detach -quiet "$MOUNT_DIR"

# Convert to compressed, read-only DMG
hdiutil convert -quiet "$TMP_DMG" -format UDZO -o "$DMG_NAME"

team_id=$(awk '/DEVELOPMENT_TEAM/{sub(";", "", $NF); gsub("\"", "", $NF); if (length($NF)) { a[$NF]=1; }} END { for (x in a) { print x; } }' < Mavis.xcodeproj/project.pbxproj)
notary_profile=notary-profile

# The DMG won't work if the app isn't notarized.
spctl --assess --type execute -vvv "$APP_PATH"

codesign --sign "$team_id" --timestamp "$DMG_NAME"
codesign --verify --deep --strict --verbose=2 "$DMG_NAME"

# This may be required once to create a profile.
# xcrun notarytool store-credentials "$notary_profile"
xcrun notarytool submit \
    --keychain-profile "$notary_profile" \
    --wait \
    "$DMG_NAME"

xcrun stapler staple "$DMG_NAME"

xcrun stapler validate "$DMG_NAME"

echo "$DMG_NAME"
