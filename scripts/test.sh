#!/usr/bin/env bash

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/autoclix"
mkdir -p "$cache_dir"
if [[ $? -ne 0 ]]; then
    printf '%s\n' "Error: Failed to create cache directory ${cache_dir}" >&2
    exit 1
fi

if [[ ! -d "Sources" ]]; then
    printf '%s\n' "Error: Sources directory not found" >&2
    exit 1
fi

sdk_file="${cache_dir}/sdk_path.tmp"
xcrun --show-sdk-path >"$sdk_file" 2>/dev/null
if [[ $? -ne 0 || ! -s "$sdk_file" ]]; then
    rm -f "$sdk_file"
    printf '%s\n' "Error: Failed to locate macOS SDK via xcrun" >&2
    exit 1
fi

IFS= read -r sdk_path <"$sdk_file"
rm -f "$sdk_file"

test_dir="${XDG_RUNTIME_DIR:-/tmp}"
test_bin="${test_dir}/AutoCliXSyntaxTest"

printf '%s\n' "Executing AutoCliX compilation and verification checks..."

swiftc -sdk "$sdk_path" \
    -parse-as-library \
    Sources/Models/*.swift \
    Sources/Services/*.swift \
    Sources/Engine/*.swift \
    Sources/Views/Components/*.swift \
    Sources/Views/*.swift \
    Sources/AutoclixApp.swift \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Carbon \
    -framework CoreGraphics \
    -framework ApplicationServices \
    -o "$test_bin"
if [[ $? -ne 0 ]]; then
    printf '%s\n' "Error: Swift test compilation failed" >&2
    exit 1
fi

rm -f "$test_bin"
printf '%s\n' "✅ AutoCliX test checks passed successfully."
