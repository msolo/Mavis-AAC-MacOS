#!/bin/bash

set -eu

command -v yugo >/dev/null 2>&1 || go install github.com/msolo/yugo@latest

# Allow README.md to serve in two place.

cp README.md docs/index.md

# Remove docs/ prefix in HTML links.
sed -i "" -e 's|"docs/|"|g' docs/index.md
# Remove docs/ prefix in Markdown links.
sed -i "" -e 's|[\(]docs/|(|g' docs/index.md

yugo build --base-template standalone.html --site ../lazybearlabs.github.io-priv docs/help.md ./Help/help.html
