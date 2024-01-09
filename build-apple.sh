#!/bin/bash

current_dir=$(pwd)/$(dirname "$0")
lib_prefix="${current_dir}/output"

# Define platforms in an array
platforms=("SIMULATOR_COMBINED" "MAC_COMBINED" "OS64")

build_and_package() {
    local platform=$1
    local build_dir="${current_dir}/build-${platform}"

    # Check if libsimple.a already exists
    if [ -f "${lib_prefix}/${platform}/libsimple.a" ]; then
        echo "libsimple.a for ${platform} already exists, skipping..."
        return
    fi

    # Configure and build
    cmake "$current_dir" -G Xcode -DCMAKE_TOOLCHAIN_FILE=contrib/ios.toolchain.cmake \
        -DPLATFORM=${platform} \
        -DCMAKE_INSTALL_PREFIX="" -B "$build_dir" \
        -DDEPLOYMENT_TARGET=1.0

    cd "$build_dir" || exit

    cmake --build "$build_dir" --config Release
    cmake --install "$build_dir" --config Release --prefix "${lib_prefix}"

    # Move libsimple.a
    mv "${lib_prefix}/libsimple.a" "${lib_prefix}/${platform}/"
}

# Build for each platform in the array
for platform in "${platforms[@]}"; do
    build_and_package "$platform"
done

# Create xcframework
xcodebuild_args=()
for platform in "${platforms[@]}"; do
    xcodebuild_args+=("-library" "${lib_prefix}/${platform}/libsimple.a")
done
xcodebuild -create-xcframework "${xcodebuild_args[@]}" -output "${lib_prefix}/libsimple.xcframework"
