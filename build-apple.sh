#!/bin/bash

current_dir=$(pwd)/$(dirname "$0")
lib_prefix="${current_dir}/output"

# Define platforms in an array
platforms=("OS64" "SIMULATOR64" "SIMULATORARM64" "TVOS" "SIMULATOR_TVOS" "SIMULATORARM64_TVOS" "WATCHOS" "SIMULATOR_WATCHOS" "SIMULATORARM64_WATCHOS" "MAC_CATALYST" "MAC_CATALYST_ARM64" "VISIONOS" "SIMULATOR_VISIONOS")
combinations=(
    "COMBINED_SIMULATORAR:SIMULATOR64:SIMULATORARM64"
    "COMBINED_SIMULATOR_TVOS:SIMULATOR_TVOS:SIMULATORARM64_TVOS"
    "COMBINED_MAC_CATALYST:MAC_CATALYST:MAC_CATALYST_ARM64"
    "COMBINED_SIMULATOR_WATCHOS:SIMULATOR_WATCHOS:SIMULATORARM64_WATCHOS"
)

build_and_package() {
    local platform=$1
    local build_dir="${current_dir}/build/build-${platform}"
    local target_dir="${lib_prefix}/${platform}"
    mkdir -p "$target_dir"

    # Check if libsimple.a already exists
    if [ -f "${lib_prefix}/${platform}/libsimple.a" ]; then
        echo "libsimple.a for ${platform} already exists, skipping..."
        return
    fi

    # Configure and build
    cmake "$current_dir" -G Xcode -DCMAKE_TOOLCHAIN_FILE=contrib/ios.toolchain.cmake \
        -DPLATFORM=${platform} \
        -DCMAKE_INSTALL_PREFIX="" -B "$build_dir"

    cd "$build_dir" || exit

    cmake --build "$build_dir" --config Release
    cmake --install "$build_dir" --config Release --prefix "${lib_prefix}"

    # Move libsimple.a
    mv "${lib_prefix}/bin/libsimple.a" "$target_dir"
}

combine_libraries_with_lipo() {
    local output_dir=$1
    shift
    local sources=("$@")

    local output_path="${lib_prefix}/${output_dir}/libsimple.a"
    if [ -f "${output_path}" ]; then
        echo "Combined library ${output_path} already exists, skipping..."
        return
    fi

    mkdir -p "${lib_prefix}/${output_dir}"
    lipo_args=()
    for src in "${sources[@]}"; do
        lipo_args+=("${lib_prefix}/${src}/libsimple.a")
    done
    lipo -create -output "${output_path}" "${lipo_args[@]}"
}

# Build for each platform in the array
for platform in "${platforms[@]}"; do
    build_and_package "$platform"
done

# Parsing combinations and combining libraries
for combo in "${combinations[@]}"; do
    IFS=':' read -ra ADDR <<< "$combo"
    output_dir=${ADDR[0]}
    unset ADDR[0]  # Remove the first element which is output_dir
    combine_libraries_with_lipo "$output_dir" "${ADDR[@]}"
done

# Create xcframework
combined_platforms=()
for combo in "${combinations[@]}"; do
    IFS=':' read -ra ADDR <<< "$combo"
    combined_platforms+=("${ADDR[@]:1}")  # Skip the first element which is the output directory
done

# Create xcframework
xcodebuild_command="xcodebuild -create-xcframework"
for platform in "${platforms[@]}"; do
    if [[ ! " ${combined_platforms[@]} " =~ " ${platform} " ]]; then
        # If the platform is not part of a combination, add it to the command
        if [ -f "${lib_prefix}/${platform}/libsimple.a" ]; then
            xcodebuild_command+=" -library ${lib_prefix}/${platform}/libsimple.a"
        fi
    fi
done
for output_dir in "${combinations[@]}"; do
    IFS=':' read -ra ADDR <<< "$output_dir"
    output_dir=${ADDR[0]}
    if [ -f "${lib_prefix}/${output_dir}/libsimple.a" ]; then
        xcodebuild_command+=" -library ${lib_prefix}/${output_dir}/libsimple.a"
    fi
done
xcodebuild_command+=" -output ${lib_prefix}/libsimple.xcframework"

# Print and execute the command
echo "Executing command: $xcodebuild_command"
eval "$xcodebuild_command"