#!/usr/bin/env bash
town="$1"
nhood="$2"
# is there already a release called dist? if not, create one
if ! gh release view dist; then
  gh release create dist --title "acs basic profile data" --notes ""
fi
gh release upload dist "$town" "$nhood" --clobber

gh release view dist \
  --json id,tagName,assets,createdAt,url > \
  .uploaded.json