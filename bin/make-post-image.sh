#!/bin/bash

set -eu -o pipefail

ID=$1
TITLE=$2

mkdir ./assets/static/images/blog &>/dev/null || true

convert "./assets/static/images/pattern-wide.png" \
  \( -background none -fill white -size 320x -font ./assets/static/fonts/FiraCode-SemiBold.ttf \
     label:"bernheisel.com" \
  \) -gravity southeast -geometry +0+0 -compose over -composite \
  \( -background none -fill white -size 963x381 -font ./assets/static/fonts/Inter-SemiBold.otf \
     -size 963x381 caption:"$TITLE" \
  \) -gravity northwest -geometry +0+0 -compose over -composite \
  "./assets/static/images/blog/$ID.png"
