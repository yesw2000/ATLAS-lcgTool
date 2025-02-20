# lcgPkg.sh

## Description

`lcgPkg.sh` is a shell script designed to simplify the management and setup
of software packages available under the `/cvmfs/sft.cern.ch/lcg/releases`
directory (referred to as `$sft_top` within the script).  It provides a
convenient way to list available packages, versions, and set up the
necessary environment to use them.  This script is particularly useful in
environments where software dependencies and specific versions are critical.

It intelligently handles platform information, automatically detecting it
from environment variables (`BINARY_TAG` or `CMTCONFIG`) if defined.  It
also checks for compatibility with existing LCG releases already set up in
your environment (e.g., within an **ATLAS** release).

## Features

  *  **Listing Packages:**  Quickly view all available LCG packages.
  *  **Version Discovery:**  Find available versions for a specific package, filtered by OS, compiler, and optimization level.
  *  **Environment Setup:**  Set up the environment (PATH, LD\_LIBRARY_PATH, etc.) for a specific package and version, making it ready for use.
  *  **Dependency Management:**  Provides options to count or list dependencies of a package.
  *  **LCG Release Awareness:** Integrates with LCG release conventions, ensuring compatibility when used within established environments.
  *  **Platform Detection:** Automatically detects the platform based on environment variables or user-specified arguments.

## Usage

### Basic Usage

The script is designed to be sourced, meaning you execute it with `source
lcgPkg.sh` (or `.  lcgPkg.sh`).  This ensures that any environment changes
made by the script are applied to your current shell.

1.  **Print out the usage**

    ```
    source lcgPkg.sh -h
    ```

2.  **List available packages:**

    ```
    source lcgPkg.sh  # Lists all available LCG packages
    ```

3.  **List versions for a specific package:**

    ```
    source lcgPkg.sh julia  # Lists versions for "julia"
    source lcgPkg.sh Python clang # Lists versions for clang-based "Python"
    ```

    Output of `source lcgPkg.sh julia`:

    ```
    List versons for package=julia, os=el9, compiler=, opt=opt
    1.9.2
    1.9.4
    1.10.3
    1.10.4
    1.11.3
    ```

4.  **Set up the environment for a specific package and version:**

    ```
    source lcgPkg.sh julia 1.10.4,gcc14  # Sets up the env of julia-1.10.4 with gcc14

    #Specifying LCG release
    source lcgPkg.sh julia LCG_107,gcc14 # set up the env of julia in the lcg release of LCG_107

    source lcgPkg.sh Python 3.11.9,x86_64-el9-gcc14-opt  # Sets up env for Python 3.11.9 on a specific platform
    source lcgPkg.sh Python 3.11.9,gcc14,dbg # Set up the env of Python-3.11.9 with debug mode
    ```

5. **Show dependency count**
    ```
    source lcgPkg.sh -d Python 3.11.9,gcc14 # Show dependency count
    ```

6. **List all dependencies**
    ```
    source lcgPkg.sh -D ROOT 6.32.06,gcc14 # List all dependencies
    ```

### Options

   *  `-h` or `--help`:  Prints the help message with usage instructions.
   *  `-V` or `--version`: Prints the script version.
   *  `-d` or `--deps`: Count total dependencies (up to 2 levels).
   *  `-D` or `--deps-list`: List all dependencies (up to 2 levels).

### Specifying Package and Version

The script uses a comma-separated list of arguments to specify the package, version, and platform. The general format is:

`source lcgPkg.sh <package_name> <version>,<compiler>,<optimization>`

   *  `<package_name>`:  The name of the package (e.g., `julia`, `Python`, `ROOT`).
   *  `<version>`: The version of the package (e.g., `1.10.4`, `3.11.9`, `6.32.06`).  Can also be an LCG release (e.g. `LCG_107`).
   *  `<compiler>`: The compiler used to build the package (e.g., `gcc14`, `clang16`).
   *  `<optimization>`:  The optimization level (`opt` or `dbg`). Defaults to `opt` if not specified.

### Platform Specification

Platform information (OS, compiler, optimization) can be provided in several ways:

1. **Environment Variables:** The script automatically detects platform
     information from the `BINARY_TAG` or `CMTCONFIG` environment variables, 
     if they are set.  This is the preferred method in many HEP environments.

2. **Command-line Arguments:**  You can explicitly specify the platform as
    a comma-separated list of arguments, as shown in the examples above.
    For example: `source lcgPkg.sh Python 3.9.7,x86_64-el8-gcc11-opt`.

3.  **Mixing:** You can combine environment variables and command-line
    arguments.  However, if there are conflicts, the script will report an error.

### LCG Releases

The script is aware of LCG release conventions.  You can specify an LCG
release to ensure that the environment is set up correctly within the
context of that release.


### Examples

  * List all available packages:

    ```
    source lcgPkg.sh
    ```

  * List available versions of Python:

    ```
    source lcgPkg.sh Python
    ```

  * Set up the environment for ROOT version 6.32.06 with gcc14:

    ```
    source lcgPkg.sh ROOT 6.32.06,gcc14
    ```

  * Set up the environment for julia within LCG release LCG\_107 with gcc14:

    ```
    source lcgPkg.sh julia LCG_107,gcc14
    ```

  * Show the number of dependencies for a specific package:

    ```
    source lcgPkg.sh -d ROOT 6.30.02,gcc12
    ```

  * List all dependencies for a specific package:

    ```
    source lcgPkg.sh -D ROOT 6.32.06,gcc14
    ```

    Output:

    ```
    Davix-0.8.7
    GSL-2.7
    Python-3.11.9
    Vc-1.4.5
    blas-0.3.20.openblas
    cfitsio-3.48
    fftw-3.3.10
    gl2ps-1.4.2
    jsonmcpp-3.11.3
    libxml2-2.10.4
    mysql-10.5.20
    numpy-1.26.4
    protobuf-4.25.4
    tbb-2021.10.0
    vdt-0.4.4
    xrootd-5.7.1
    ```

## Error Handling

The script includes error handling to check for:

  *  Invalid package names
  *  Incompatible platform specifications
  *  Missing dependencies
  *  Conflicts between environment variables and command-line arguments

## Implementation Details

The script works by:

  1.  Parsing the command-line arguments and environment variables.
  2.  Searching the `$sft_top` directory for the specified package and version.
  3.  Locating the appropriate platform directory.
  4.  Sourcing the `lcgenv` script within the platform directory, which sets up the environment variables.

## Notes

   *  The script relies on the directory structure under `$sft_top` following a specific convention.  
      If the directory structure is modified, the script may not work correctly.
   *  The script uses `find` and `ls` commands extensively. Ensure that these commands are available 
      in your environment.
   *  The script attempts to optimize PATH and LD\_LIBRARY_PATH if the package has a large number of dependencies,
      by suggesting the use of `lsetup views`.

## Author

Shuwei Ye - yesw@bnl.gov
