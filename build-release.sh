#!/bin/bash

set -e

corrector_repo="https://github.com/msolo/mavis-corrector"
corrector_dir="./mavis-corrector"

# This could be a submodule, but that somehow feels like a lot of baggage.
if ! test -d "$corrector_dir"; then
  git clone "$corrector_repo" "$corrector_dir"
fi

if ! test -d "$corrector_dir/derived.noindex/dist/MavisCorrector.plugin"; then
  (cd "$corrector_dir" && ./build-release.sh)
fi

# Handle site and documentation.
./build-docs.sh

APP_NAME="Mavis AAC"
# Set the version and build numbers
VERSION_NUMBER="1.0.16"
BUILD_NUMBER="16"

# Set the Xcode project file path
PROJECT_DIR="Mavis.xcodeproj"
PROJECT_FILE="$PROJECT_DIR/project.pbxproj"
RELEASE_DIR="Build/Products/Release"
APP_BUNDLE="$APP_NAME.app"

# Update the MARKETING_VERSION and CURRENT_PROJECT_VERSION values in the project file
sed -i "" "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION_NUMBER;/g" "$PROJECT_FILE"
sed -i "" "s/CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $BUILD_NUMBER;/g" "$PROJECT_FILE"

xcodebuild \
  -scheme "Mavis" \
  -project "$PROJECT_DIR" \
  -configuration "Release" \
  clean

xcodebuild \
  -scheme "Mavis" \
  -project "$PROJECT_DIR" \
  -configuration "Release" \
  build


team_id=$(awk '/DEVELOPMENT_TEAM/{sub(";", "", $NF); gsub("\"", "", $NF); if (length($NF)) { a[$NF]=1; }} END { for (x in a) { print x; } }' < "$PROJECT_FILE")
notary_profile=notary-profile

APP="$RELEASE_DIR/$APP_BUNDLE"
PLUGIN_SRC="mavis-corrector/derived.noindex/dist/MavisCorrector.plugin"
PLUGIN_DST="$APP/Contents/Resources/MavisCorrector.plugin"

# Xcode apparently breaks the signing/notarization of our plugin.
# I can only assume this is because the plugin is a py2app artifact.
# We will recopy it and resign the main application.
rm -rf "$PLUGIN_DST"
cp -a "$PLUGIN_SRC" "$(dirname "$PLUGIN_DST")"
spctl --assess --type execute -vvv "$PLUGIN_DST"

codesign --force --sign $team_id -v --deep --timestamp --options runtime "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# spctl --assess --type execute -vvv "$APP"

ditto -c -k --keepParent "$APP" "$APP.zip"

xcrun notarytool submit \
    --keychain-profile "$notary_profile" \
    --wait \
    "$APP.zip"

xcrun stapler staple "$APP"

spctl --assess --type execute -vvv "$APP"

./build-dmg.sh

# Publish for updater.
rm docs/version.txt
echo "$VERSION_NUMBER" > docs/version.txt

if [[ $(git tag -l "release-$VERSION_NUMBER") == "" ]]; then
    echo "Run git tag release-$VERSION_NUMBER" >&2
fi
