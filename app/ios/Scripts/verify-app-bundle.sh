#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /path/to/Routeva.app" >&2
  exit 64
fi

app_path=$1
if [ ! -d "$app_path" ]; then
  echo "App bundle not found: $app_path" >&2
  exit 66
fi

failed=0
for extension_path in "$app_path"/PlugIns/*.appex; do
  [ -d "$extension_path" ] || continue
  extension_name=$(basename "$extension_path")

  for binary_path in "$extension_path"/*; do
    [ -f "$binary_path" ] || continue
    if ! file "$binary_path" | grep -q 'Mach-O'; then
      continue
    fi

    for dependency in $(otool -L "$binary_path" | awk '/@rpath\/.*\.framework\// { print $1 }'); do
      framework_name=$(printf '%s\n' "$dependency" | sed -E 's#^@rpath/([^/]+\.framework)/.*#\1#')
      framework_binary=$(printf '%s\n' "$dependency" | sed -E 's#^@rpath/[^/]+\.framework/(.*)#\1#')
      if [ -f "$extension_path/Frameworks/$framework_name/$framework_binary" ] || \
         [ -f "$app_path/Frameworks/$framework_name/$framework_binary" ]; then
        continue
      fi

      echo "$extension_name has unresolved dependency: $dependency" >&2
      failed=1
    done
  done
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

codesign --verify --deep --strict "$app_path"
echo "Verified extension framework dependencies and signatures: $app_path"
