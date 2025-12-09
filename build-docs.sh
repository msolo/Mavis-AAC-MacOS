#!/bin/bash

set -eu

command -v yugo >/dev/null 2>&1 || go install github.com/msolo/yugo@latest
yugo build --base-template standalone.html --site ../lazybearlabs.github.io-priv docs/help.md ./Help/help.html

# Export README so it shows up on GitHub reasonably well.
./export-readme.py docs/index.md ./README.md