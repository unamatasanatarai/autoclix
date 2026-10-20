#!/usr/bin/env bash

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/autoclix"
mkdir -p "$cache_dir"
if [[ $? -ne 0 ]]; then
    printf '%s\n' "Error: Failed to create cache directory ${cache_dir}" >&2
    exit 1
fi

if [[ ! -d "Sources" || ! -d "Tests" ]]; then
    printf '%s\n' "Error: Sources or Tests directory not found" >&2
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

test_bin="${cache_dir}/AutoCliXTests"
frameworks=(
    -framework Cocoa
    -framework SwiftUI
    -framework Carbon
    -framework CoreGraphics
    -framework ApplicationServices
)

printf '%s\n' "1. Type-checking full application..."
swiftc -sdk "$sdk_path" \
    -typecheck \
    -parse-as-library \
    Sources/Models/*.swift \
    Sources/Services/*.swift \
    Sources/Engine/*.swift \
    Sources/Views/Components/*.swift \
    Sources/Views/*.swift \
    Sources/AutoclixApp.swift
if [[ $? -ne 0 ]]; then
    printf '%s\n' "Error: Application type-check failed" >&2
    exit 1
fi

# The app entry point (@main) is excluded so Tests/main.swift can provide its own.
printf '%s\n' "2. Compiling unit tests..."
swiftc -sdk "$sdk_path" \
    Sources/Models/*.swift \
    Sources/Services/*.swift \
    Sources/Engine/*.swift \
    Sources/Views/Components/*.swift \
    Sources/Views/*.swift \
    Tests/*.swift \
    "${frameworks[@]}" \
    -o "$test_bin"
if [[ $? -ne 0 ]]; then
    printf '%s\n' "Error: Test compilation failed" >&2
    exit 1
fi

printf '%s\n' "3. Running unit tests..."
"$test_bin"
test_status=$?
rm -f "$test_bin"
if [[ $test_status -ne 0 ]]; then
    printf '%s\n' "Error: Unit tests failed" >&2
    exit 1
fi

printf '%s\n' "✅ AutoCliX tests passed."
