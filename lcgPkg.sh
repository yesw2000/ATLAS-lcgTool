#!/bin/bash
#
# This script helps list/set up LCG package.
#
# February, 2025
# Author: Shuwei Ye <yesw@bnl.gov>
#---------------------------------

# Enable word splitting in zsh
if [ -n "$ZSH_VERSION" ]; then
    # setopt shwordsplit GLOB_SUBST
    setopt shwordsplit
fi

sft_top=/cvmfs/sft.cern.ch/lcg/releases
arch=$(uname -m)

# Function to print the tool version
print_version() {
    local version="2025-02-24-r01"
    echo $version
}

# Function to check if lcgPkg function is defined and contains the correct path
check_lcgpkg_function() {
    # Check if function is defined
    if type lcgPkg >/dev/null 2>&1; then
        return 0
    fi
    return 1  # Function doesn't exist or doesn't contain the path
}

# Function to print the tool version
print_help() {
    local cmd="source lcgPkg.sh"
    if check_lcgpkg_function; then
        cmd="lcgPkg"
    fi

    cat << EOF
Description: This is a tool to list/set up packages under $sft_top.
             Platform info will be taken from the env variable BINARY_TAG/CMTCONFIG if defined.
             If LCG release is already used in the set up ATLAS release, 
             the packages would be picked up only from the compatible LCG releases.

Option:
      -h|--help:     Print out this help
      -V|--version:  Print out the tool version
      -d|--deps:       Count total dependencies (up to 2 levels)
      -D|--deps-list:  List all dependencies (up to 2 levels)

Usage:
  $cmd                      # list all available lcg packages
  $cmd julia                # list versions for "julia"
  $cmd Python clang         # list versions for clang-based "Python"
  $cmd julia 1.10.4,gcc14   # set up the env of julia-1.10.4
  $cmd julia LCG_107,gcc14  # set up the env of julia in the lcg release of LCG_107
  $cmd Python 3.11.9,x86_64-el9-gcc14-opt  # set up the env of Python-3.11.9
  $cmd Python 3.11.9,gcc14,dbg  # set up the env of Python-3.11.9 with debug mode
  $cmd -d Python 3.11.9,gcc14   # Show dependency count
  $cmd -D ROOT 6.32.06,gcc14    # List all dependencies

Visit https://github.com/yesw2000/ATLAS-lcgTool for more details.
EOF
}

# Function to list package names
list_packages() {
    local lcg_arg=$1
    
    if [ -z "$lcg_arg" ]; then
        # Case 1: Only one argument - original behavior
        find $sft_top -maxdepth 1 -mindepth 1 -type d \
          ! -name "LCG_*" -iname "*" -printf '%P\n' 2>/dev/null | \
          sort | awk -v cols=$(tput cols) '{printf "%-"int(cols/6-2)"s %s", $0, NR%6==0?"\n":""}'
    else
        local target_lcg=""
        if [[ "$lcg_arg" == LCG_* ]]; then
            # Case 2: Second argument starts with LCG_
            target_lcg="$lcg_arg"
        else
            # Case 3: Second argument is a full path
            target_lcg=$(basename "$lcg_arg")
            # If there are multiple underscores, keep only up to the second one
            if [[ $(echo "$target_lcg" | grep -o "_" | wc -l) -gt 1 ]]; then
                target_lcg=$(echo "$target_lcg" | awk -F_ '{print $1"_"$2}')
            fi
        fi

        if [[ "$target_lcg" != LCG_* ]]; then
            # Case 4: the External in the ATLAS release is NOT a LCG release 
            find $sft_top -maxdepth 1 -mindepth 1 -type d \
              ! -name "LCG_*" -iname "*" -printf '%P\n' 2>/dev/null | \
            while read pkg; do
                if [ ! -d "$lcg_arg/$pkg" ]; then
                    echo "$pkg"
                fi
            done | sort | awk -v cols=$(tput cols) '{printf "%-"int(cols/6-2)"s %s", $0, NR%6==0?"\n":""}'
        elif [ -d "$sft_top/$target_lcg" ]; then
            # Find all subdirs and format them in a pretty grid
            find "$sft_top/$target_lcg" -maxdepth 1 -mindepth 1 -type d -printf '%P\n' 2>/dev/null | \
            while read pkg; do
                if [ ! -d "$lcg_arg/$pkg" ]; then
                    echo "$pkg"
                fi
            done | sort | awk -v cols=$(tput cols) '{printf "%-"int(cols/6-2)"s %s", $0, NR%6==0?"\n":""}'
        fi
    fi
    # Add a final newline if the last row wasn't complete
    echo ""
    echo -e "\nPlease specify one package name from the above list"
}

# Function to find the package name, ignoreing the case
find_package() {
    local packInput=$1
    local packFound=$(find $sft_top -maxdepth 1 -mindepth 1 -type d \
      ! -name "LCG_*" -iname "${packInput}" -printf '%P\n' 2>/dev/null)
    if [ $? ]; then
        echo $packFound
    else
        echo ""
    fi
}

# Function to list versions for a given package
list_versions() {
    local packageName=$1
    local os=$2
    local compiler=$3
    local opt=${4:-opt}  # Default to "opt" if not provided

    echo "List versons for package=$packageName, os=$os, compiler=$compiler, opt=$opt"
    if [ -z "$os" -a -z "$compiler" ]; then
        /bin/ls -1 $sft_top/$packageName 2>/dev/null | sed 's/-[0-9a-f]\+$//' | sort -u -V
    else
        [[ -z "$compiler" ]] && compiler="*"
        find $sft_top/$packageName -maxdepth 2 -mindepth 2 -type d -path "$sft_top/$packageName/*/${arch}-${os}-${compiler}-${opt}" -printf '%h\n' 2>/dev/null \
          | awk -F'/' '{print $(NF)}' | sed 's/-[0-9a-f]\+$//' | sort -u -V
    fi
}

# Function to list versions matching a platform
list_platform_versions() {
    local packageName=$1
    local version=$2
    local os=$3
    local compiler=$4
    local opt=${5:-opt}  # Default to "opt" if not provided
    local platforms
    [[ -z "$compiler" ]] && compiler="*"
    
    if [[ "$version" == LCG_* ]]; then
        # Handle LCG release - first get the package version directory
        local pkg_version_dir=$(/bin/ls -1 $sft_top/$version/$packageName 2>/dev/null)
        if [[ -n "$pkg_version_dir" ]]; then
            # Then look for platform directories inside the version directory
            platforms=$(find -L $sft_top/$version/$packageName/$pkg_version_dir -maxdepth 1 -mindepth 1 -type d -path "$sft_top/$version/$packageName/$pkg_version_dir/${arch}-${os}-${compiler}-${opt}" -printf '%f\n' 2>/dev/null | sort -u)
        fi
    else
        # Handle regular package version
        platforms=$(find $sft_top/$packageName -maxdepth 2 -mindepth 2 -type d -path "$sft_top/$packageName/${version}-*/${arch}-${os}-${compiler}-${opt}" -printf '%f\n' 2>/dev/null | sort -u)
    fi
    echo ${platforms[@]}
}

# Function to find full paths for a package with specific version and platform
find_full_paths() {
    local packageName=$1
    local version=$2
    local os=$3
    local compiler=$4
    local opt=${5:-opt}  # Default to "opt" if not provided
    
    # First try using the current LCG release if available
    local lcg_release=$(get_lcg_release)
    if [ -n "$lcg_release" ]; then
        local specific_path="$sft_top/$lcg_release/$packageName/$version/${arch}-${os}-${compiler}-${opt}"
        if [ -d "$specific_path" ]; then
            echo "$specific_path"
            return 0
        fi
    fi
    
    # Fall back to existing search patterns if specific path not found
    eval "/bin/ls -d $sft_top/LCG_10[56]*/$packageName/$version/${arch}-${os}-${compiler}-${opt}" 2>/dev/null
    if [ $? ]; then
        eval "/bin/ls -d $sft_top/LCG_*/$packageName/$version/${arch}-${os}-${compiler}-${opt}" 2>/dev/null
    fi
}

# Function to get host OS
get_host_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            centos) echo "centos${VERSION_ID%%.*}" ;;
            rhel) echo "el${VERSION_ID%%.*}" ;;
            almalinux) echo "el${VERSION_ID%%.*}" ;;
            *) echo "unknown" ;;
        esac
    else
        echo "unknown"
    fi
}

# Function to get dependencies (with optional mode)
get_num_depends() {
    local packageName=$1
    local fullpath=$2
    local mode=${3:-1}  # Default mode=1 (count), mode=2 (list)
    local buildinfo="$fullpath/.buildinfo_${packageName}.txt"

    # Check if buildinfo exists
    if [ ! -e "$buildinfo" ]; then
        [ "$mode" = 1 ] && echo "0" || echo ""
        return
    fi

    # Extract dependencies
    local deps_line=$(grep -oP '(?<=DEPENDS: ).*' "$buildinfo")
    [ -z "$deps_line" ] && { [ "$mode" = 1 ] && echo 0 || echo ""; return; }

    # Process direct dependencies
    local LCG_DIR=$(dirname $(dirname $(dirname "$fullpath")))
    local platform=$(basename "$fullpath")
    local main_deps=($(echo "$deps_line" | tr ',' ' '))
    local all_deps=()

    # Function to process a single dependency
    process_dep() {
        local dep=$1
        dep=${dep%-*}
        local dep_pkg=${dep%%/*}
        local dep_version=$(echo "$dep" | cut -d'/' -f2)
        local dep_buildinfo="${LCG_DIR}/${dep_pkg}/${dep_version}/${platform}/.buildinfo_${dep_pkg}.txt"

        # Add current dependency
        all_deps+=("$dep")

        # Process sub-dependencies if buildinfo exists
        if [ -e "$dep_buildinfo" ]; then
            local sub_deps_line=$(grep -oP '(?<=DEPENDS: ).*' "$dep_buildinfo" 2>/dev/null)
            [ -n "$sub_deps_line" ] && all_deps+=($(echo "$sub_deps_line" | tr ',' ' ' | cut -d'/' -f1 | sed 's/-[^-]*$//'))
        fi
    }

    # Process all dependencies
    for dep in "${main_deps[@]}"; do
        process_dep "$dep"
    done

    # Return results based on mode
    if [ "$mode" = 1 ]; then
        echo ${#all_deps[@]}
    else
        printf '%s\n' "${all_deps[@]}" | sort -u
    fi
}

# Function to get the lcg release from the path of command 'root'
get_lcg_release() {
    local rootpath=$(\which root 2>/dev/null)
    if [[ $? != 0 || "$rootpath" != */lcg/releases/* ]]; then
        echo ""
        return 1
    fi
    # Extract LCG release from path
    local lcg_release=${rootpath#*/releases/}
    lcg_release=${lcg_release%%/*}
    echo "$lcg_release"
}

# Function to get the lcg release path and platform (if needed) from root path
get_ext_path_in_atlas() {
    local rootpath=$(\which root 2>/dev/null)
    if [[ $? != 0 ]]; then
        echo ""
        return 1
    fi

    local ext_path
    if [[ "$rootpath" != */lcg/releases/* ]]; then
        ext_path=${rootpath%bin/root}src/External
        if [[ ! -d "$ext_path" ]]; then
            echo ""
            return 1
          else
            echo "$ext_path"
            return 0
        fi
    fi

    # Extract the path up to /ROOT/ (this gives us the full LCG release path)
    ext_path=${rootpath%/ROOT/*}

    echo "$ext_path"
}

# Function to set up package environment
setup_package_env() {
    local packageName=$1
    local version_or_release=$2 version=""
    local os=$3
    local compiler=$4
    local opt=${5:-opt}  # Default to "opt" if not provided
    local check_deps=${6:-1}  # New argument: 1 to check deps (default), 0 to skip
    local package_fullPaths
    local fullpath

    # Check if second argument is an LCG release (starts with LCG_)
    if [[ "$version_or_release" == LCG_* ]]; then
        # LCG release case - construct path using $sft_top
        local package_dir="$sft_top/$version_or_release/$packageName"
        if [ ! -d "$package_dir" ]; then
            echo "Error: Package $packageName not found under LCG release $version_or_release"
            return 1
        fi
        
        # Check there's exactly one version subdirectory
        local version_count=$(/bin/ls -1d "$package_dir"/*/ 2>/dev/null | wc -l)
        if [ "$version_count" -ne 1 ]; then
            echo "Error: Expected exactly one version directory under $package_dir, found $version_count"
            return 1
        fi
        
        # Get the version directory (should be only one)
        local version_dir=$(/bin/ls -1d "$package_dir"/*/ 2>/dev/null | head -1)
        version_dir=${version_dir%/}  # Remove trailing slash
        version=$(basename "$version_dir")
        
        # Construct the full path with platform
        local platform="x86_64-${os}-${compiler}-${opt}"
        fullpath="$version_dir/$platform"
        
        if [ ! -d "$fullpath" ]; then
            echo "Error: Platform directory $platform not found under $version_dir"
            return 1
        fi
    else
        # Traditional version-based case
        version=$version_or_release
        package_fullPaths=$(find_full_paths "$packageName" "$version" "$os" "$compiler" "$opt")
        if [ -z "$package_fullPaths" ]; then
            echo "Error: Package not found with the specified parameters"
            return 1
        fi
        fullpath=$(echo "$package_fullPaths" | head -n 1)
    fi

    # Check dependencies only if check_deps is 1
    if [ "$check_deps" = "1" ]; then
        local n_depends=$(get_num_depends "$packageName" "$fullpath")
        if [ $n_depends -gt 5 ]; then
            local lcg_release=${fullpath#*/releases/}
            lcg_release=${lcg_release%%/*}
            local platform=$(basename "$fullpath")
            echo "There are $n_depends (up to 2 levels) dependencies in $packageName"
            echo "It is recommended to execute the following command next time to"
            echo " set up the package, optimizing your PATH and LD_LIBRARY_PATH"
            echo -e "\n\tlsetup" \"views $lcg_release $platform\" "\n"
        fi
    fi
    echo "Set up the $packageName env under $fullpath"

    LCGDIR=${fullpath%/*/*/*}
    local platform=${fullpath##*/}
    lcgenv=$(/bin/ls $LCGDIR/lcgenv/*/$platform/lcgenv | head -1)
    local tmpenv=$(mktemp)
    (cd $LCGDIR; python3 $lcgenv $packageName $version $platform) >> $tmpenv
    source $tmpenv; rm -f $tmpenv
}

# Main function to parse arguments and execute commands
main() {
    local packageName=""
    local platform=""
    local os="" os_source=""
    local compiler="" compiler_source=""
    local version=""
    local opt="opt" opt_source=""
    local show_deps=0 show_deps_list=0
    local lcg_release="" ext_path_atlas=""
    local i parts

    # First parse options
    while [[ "$1" =~ ^- ]]; do
        case "$1" in
            -h|--help) print_help; return 0 ;;
            -V|--version) print_version; return 0 ;;
            -d|--deps) show_deps=1 ;;
            -D|--deps-list) show_deps_list=1 ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    # Check if $sft_top exists
    if [ ! -d "$sft_top" ]; then
        echo "Error: The directory $sft_top does not exist. Please ensure CVMFS is properly mounted."
        return 1
    fi
  
    # Handle environment-defined platform configurations
    for var in BINARY_TAG CMTCONFIG; do
        local env_value=$(eval "echo \$$var")  # Works in both Bash and Zsh
        if [ -n "$env_value" ]; then
            platform=$env_value
            parts=($(echo $env_value | tr '-' ' '))
            local arch_env=${parts[@]:0:1}
            # Check architecture match
            if [ "$arch_env" != "$arch" ]; then
                echo "Error: The arch $arch_env from ${var}=${env_value} is not supported for the $arch machine"
                return 1
            fi
            # Set configuration sources and values
            os_source=$var
            compiler_source=$var
            opt_source=$var
            os=${parts[@]:1:1}
            compiler=${parts[@]:2:1}
            opt=${parts[@]:3:1}
            ext_path_atlas=$(get_ext_path_in_atlas)
            lcg_release=$(basename "$ext_path_atlas")
            if [[ "$lcg_release" != LCG_* ]]; then
                lcg_release=""
            fi
            break  # Process only the first valid env var
        fi
    done

    # Parse arguments
    local tags=($(echo "$@" | tr ',' ' '))
    for i in "${tags[@]}"; do
        case $i in
            LCG_*)
                if [[ -n "$lcg_release" && "$i" != "$lcg_release" && "$lcg_release" != ${i}_* ]]; then
                    echo "Error: The input arg=$i conflicts with the lcg release=$lcg_release in ATLAS release"
                    return 1
                fi
                if [[ -n "$version" ]]; then
                    echo "Error: It is not allowed to specify both $version and $i at the same time"
                    return 1
                fi
                lcg_release=$i
                ;;
            x86_64-*|aarch64-*|arm64-*)
                local platform=$i
                # Split platform into array using tr
                parts=($(echo $platform | tr '-' ' '))

                # Use array[@] notation which works the same in both shells
                local arch_elem=${parts[@]:0:1}    # Get first element
                local os_elem=${parts[@]:1:1}      # Get second element
                local compiler_elem=${parts[@]:2:1} # Get third element
                local opt_elem=${parts[@]:3:1}     # Get fourth element

                # Check architecture
                if [ "$arch_elem" != "$arch" ]; then
                     echo "Error: The arch $arch_elem from $platform is not supported for the $arch machine"
                     return 1
                fi

                # Get OS (always second element)
                echo "os_source=$os_source; os_elem=$os_elem; os=$os"
                if [[ "$os_elem" != "$os" && -n "$os_source" ]]; then
                    echo "Error: The input arg=$i conflicts with os=$os in other envvar/arg $os_source"
                    return 1
                else
                    os=$os_elem
                    os_source=$i
                fi

                # Get compiler if third element exists
                if [ ${#parts[@]} -ge 3 ]; then
                    if [[ -n "$compiler_source" && $compiler_elem != $compiler ]]; then
                        echo "Error: The input arg=$i conflicts with compiler=$compiler in other envvar/arg $os_source"
                        return 1
                    else
                        compiler=$compiler_elem
                        compiler_source=$i
                    fi
                fi

                # Get opt if fourth element exists
                if [ ${#parts[@]} -ge 4 ]; then
                    opt=$opt_elem
                    opt_source=$i
                fi
                ;;
            opt|dbg)
                opt=$i
                opt_source=$i
                if [[ -n "$platform" ]]; then
                    platform=${platform%-*}-$i
                fi
                ;;
            slc6|centos7|centos8|el9|alma9|almalinux9)
                local os_arg=$i
                if [[ "$os" =~ 9$ ]]; then
                    os_arg="el9"
                fi
                if [[ -n "$os_source" ]]; then
                    echo "Error: redudant input os=$i conflicts with $os in other envvar/arg $os_source"
                    return 1
                else
                    os=$os_arg
                    os_source=$i
                fi
                ;;
            gcc[0-9]*|clang[0-9]*)
                if [[ -n "$compiler_source" && "$i" != ${compiler} ]]; then
                    echo "Error: The input arg=$i conflicts with compiler=$compiler in other envvar/arg $os_source"
                    return 1
                else
                    compiler=$i
                    compiler_source=$i
                fi
                ;;
            gcc|clang)
                if [[ -n "$compiler_source" && ${compiler} != ${i}* ]]; then
                    echo "Error: The input arg=$i conflicts with compiler=$compiler in other envvar/arg $os_source"
                    return 1
                else
                    compiler="${i}*"
                    compiler_source=$i
                fi
                ;;
            *)
                if [[ -d "$sft_top/$i" ]]; then
                    packageName="$i"
                else
                    if [ -z "$packageName" ]; then
                        packageName=$(find_package "$i")
                        if [ -z "$packageName" ]; then
                            version="$i"
                        else
                            echo "Found package=$packageName matching the input arg=$i"
                        fi
                    else
                        version="$i"
                    fi
                    if [[ -n "$version" && -n "$lcg_release" ]]; then
                        if [[ -n "$ext_path_atlas" ]]; then
                            echo "Additonal Package version=$version is not necessary/allowed under an ATLAS release env"
                            return 1
                        else
                            echo "It is not allowed to specify both $version and $lcg_release at the same time"
                            return 1
                        fi
                    fi
                fi
                ;;
        esac
    done

    # Set default values if not provided
    [ -z "$os" ] && os=$(get_host_os)

    # Execute commands based on provided arguments
    # Handle dependency options
    if [ -n "$packageName" ]; then
        if [[ -n "$ext_path_atlas" ]]; then
            if [[ -d "$ext_path_atlas/$packageName" ]]; then
                echo "Warning: Package $packageName is already set up in $ext_path_atlas/$packageName"
                return 1
            elif [[ -n "$lcg_release" && -d "$sft_top/$lcg_release/$packageName" ]]; then
                setup_package_env "$packageName" "$lcg_release" "$os" "$compiler" "$opt" 0
                return 1
            elif [[ -n "$lcg_release" ]]; then
                # If there are multiple underscores, keep only up to the second one
                if [[ $(echo "$lcg_release" | grep -o "_" | wc -l) -gt 1 ]]; then
                    lcg_release=$(echo "$lcg_release" | awk -F_ '{print $1"_"$2}')
                fi
                if [[ -d "$sft_top/$lcg_release/$packageName" ]]; then
                    setup_package_env "$packageName" "$lcg_release" "$os" "$compiler" "$opt" 0
                else
                    echo "Warning: Package $packageName is not available in $sft_top/$lcg_release"
                    echo -e "\t to be compatible with $ext_path_atlas"
                fi
            fi
        fi
        if [[ ${#version} -eq 0 && -z ${lcg_release} ]]; then
            list_versions "$packageName" "$os" "$compiler" "$opt"
        elif [[ "X$compiler" == "X" || "$compiler" == *"*" ]]; then
            local platforms
            if [[ -n "$lcg_release" ]]; then
                platforms=$(list_platform_versions "$packageName" "$lcg_release" "$os" "$compiler" "$opt")
            else
                platforms=$(list_platform_versions "$packageName" "$version" "$os" "$compiler" "$opt")
            fi
            local n_found=$(echo $platforms | wc -w)
            if [[ "$n_found" == "0" ]]; then
                echo "no matched package with required platform is found"
            elif [[ "$n_found" == "1" ]]; then
                echo "Found one platform $platforms for the package $packageName, going to set up the env"
                if [[ -n "$lcg_release" ]]; then
                    setup_package_env "$packageName" "$lcg_release" "$os" "$compiler" "$opt"
                else
                    setup_package_env "$packageName" "$version" "$os" "$compiler" "$opt"
                fi
            else
                echo $platforms | tr " " "\n"
            fi
        else
            if [ $show_deps -eq 0 ] && [ $show_deps_list -eq 0 ]; then
                local check_deps=1
                [[ -n "$ext_path_atlas" ]] && check_deps=0
                
                if [[ -n "$lcg_release" ]]; then
                    setup_package_env "$packageName" "$lcg_release" "$os" "$compiler" "$opt" "$check_deps"
                else
                    setup_package_env "$packageName" "$version" "$os" "$compiler" "$opt" "$check_deps"
                fi
            else
                local fullpath=$(find_full_paths "$packageName" "$version" "$os" "$compiler" "$opt" | head -n1)
                if [ $show_deps_list -eq 1 ]; then
                    mode=2
                else
                    mode=1
                fi
                get_num_depends "$packageName" "$fullpath" $mode
            fi
        fi
    elif [[ -n "$version" ]]; then
        # No package is given, the assigned $version is presumed to be un-recognized package name"
        echo "The package=$version is NOT available"
        local cmd="source lcgPkg.sh"
        if check_lcgpkg_function; then
            cmd="lcgPkg"
        fi
        echo "Please run '$cmd' to list available Packages"
        return 1
    else
        if [[ -n "$ext_path_atlas" ]]; then
            echo -e "Additional packages available compatible with $ext_path_atlas:\n"
            list_packages "$ext_path_atlas"
        elif [[ -n "$lcg_release" ]]; then
            echo -e "Packages available in LCG release $lcg_release:\n"
            list_packages "$lcg_release"
        else
            echo -e "Available packages:\n"
            list_packages
        fi
    fi
}

# Run the main function with all provided arguments
main "$@"
