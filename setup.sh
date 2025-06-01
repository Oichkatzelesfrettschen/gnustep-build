#!/bin/bash

# #############################################################################
# setup.sh - GNUstep Build and Installation Script
# #############################################################################
#
# Purpose:
# This script automates the download, build, and installation of the GNUstep
# development environment and its core components from source.
#
# Supported Operating Systems:
# - Ubuntu (tested on versions like 20.04, 22.04, 24.04)
# - Debian (tested on versions like 10, 11, 12)
#
# Usage:
# 1. Ensure you have an internet connection.
# 2. Make the script executable: chmod +x setup.sh
# 3. Run the script: ./setup.sh
#
# Note: The script requires superuser (sudo) privileges for:
# - Installing system dependencies via apt-get.
# - Installing compiled components into system directories (e.g., /usr/GNUstep or /usr/local).
# You will be prompted for your password by sudo when needed.
#
# Configuration Variables (modify these at the top of the script if needed):
# - PROMPT_AFTER_STEPS: Set to 'true' to pause after each major build step
#                       for verification. Default is 'false'.
# - BUILD_APPS:         Set to 'true' to also build and install a selection
#                       of optional GNUstep applications. Default is 'false'.
# - BUILD_DIR:          The directory where sources will be cloned and built.
#                       Default is "GNUstep-build".
#
# Idempotency:
# The script is partially idempotent. If run multiple times, it will attempt
# to update dependencies and re-clone/re-build components. Cleaning build
# directories before re-running specific component builds is handled by 'rm -rf build'.
#
# #############################################################################

# Exit immediately if a command exits with a non-zero status.
set -e
# Print commands and their arguments as they are executed.
set -x

# --- Configuration ---
# Set to true to pause after each major build step
PROMPT_AFTER_STEPS=false
# Set to true to also build and install optional applications
BUILD_APPS=false
# Build directory name
BUILD_DIR="GNUstep-build"

# --- Colors for Output ---
GREEN=$(tput setaf 2)
NC=$(tput sgr0) # No Color

# --- Helper Functions ---
show_prompt() {
  if [ "$PROMPT_AFTER_STEPS" = true ] ; then
    echo -e "\n\n"
    read -p "${GREEN}Press enter to continue to the next step...${NC}"
  fi
}

# --- OS Detection ---
echo -e "${GREEN}Detecting operating system...${NC}"
OS_ID=""
OS_VERSION_ID=""

if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_ID=$ID
  OS_VERSION_ID=$VERSION_ID
  echo "Detected OS: $OS_ID $OS_VERSION_ID"
else
  echo "Cannot detect OS from /etc/os-release. Exiting."
  exit 1
fi

# --- Dependency Installation ---
echo -e "\n${GREEN}Installing dependencies...${NC}"
sudo apt-get update

if [[ "$OS_ID" == "ubuntu" ]]; then
  echo "Installing dependencies for Ubuntu $OS_VERSION_ID"
  sudo apt-get -y install clang build-essential wget git subversion cmake libffi-dev libxml2-dev \
  libgnutls28-dev libicu-dev libblocksruntime-dev libkqueue-dev libpthread-workqueue-dev autoconf libtool \
  libjpeg-dev libtiff-dev libcairo2-dev libx11-dev libxt-dev libxft-dev libxrandr-dev \
  g++ # Using default g++ for the Ubuntu version, specific versions like g++-14 might not always be available or needed initially.
  # Add other Ubuntu specific packages if needed
  if [ "$BUILD_APPS" = true ] ; then
    sudo apt-get -y install curl
  fi
elif [[ "$OS_ID" == "debian" ]]; then
  echo "Installing dependencies for Debian $OS_VERSION_ID"
  # Add backports if necessary for newer packages, e.g., for Debian 10 (buster)
  if [[ "$OS_VERSION_ID" == "10" ]]; then
    echo "deb http://deb.debian.org/debian buster-backports main" | sudo tee /etc/apt/sources.list.d/backports.list
    sudo apt-get update
  fi
  # Common Debian dependencies (adjust based on specific Debian version needs)
  sudo apt-get -y install clang build-essential git subversion cmake \
  libc6-dev libxml2-dev libffi-dev libicu-dev libblocksruntime-dev libkqueue-dev libpthread-workqueue-dev \
  autoconf libtool libjpeg-dev libtiff-dev libcairo2-dev libx11-dev libxt-dev libxft-dev libxrandr-dev \
  libgnutls28-dev # libgnutls30 might be available on newer Debians
  # Add other Debian specific packages if needed
  # Example: sudo apt -y install libavahi-client-dev libdbus-1-dev
  if [ "$BUILD_APPS" = true ] ; then
    sudo apt-get -y install curl
  fi
else
  echo "Unsupported OS: $OS_ID. This script currently supports Ubuntu and Debian."
  exit 1
fi
show_prompt

# --- Environment Setup ---
echo -e "\n${GREEN}Setting up build environment...${NC}"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Set clang as compiler (adjust paths if necessary)
export CC=clang
export CXX=clang++
export CXXFLAGS="-std=c++11" # Common default, can be overridden by specific components
export RUNTIME_VERSION="gnustep-2.1" # Default, check if this is suitable for all targets
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH" # Prepend to allow overrides
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH" # Prepend for installed libs

# For ld.gold, ensure it's installed and explicitly set if preferred.
# Some scripts use ld.gold, others don't explicitly set it, relying on defaults or clang's choice.
# For now, let's keep it simple and not force ld.gold unless it becomes a clear necessity.
# export LD="/usr/bin/ld.gold"
# export LDFLAGS="-fuse-ld=/usr/bin/ld.gold -L/usr/local/lib"
export LDFLAGS="-L/usr/local/lib"


# --- Source Code Checkout ---
echo -e "\n${GREEN}Checking out sources...${NC}"
# Using https for wider compatibility (firewalls, etc.)
git clone https://github.com/apple/swift-corelibs-libdispatch.git
git clone https://github.com/gnustep/libobjc2.git
cd libobjc2
  git submodule init && git submodule sync && git submodule update
cd ..
git clone https://github.com/gnustep/tools-make.git # Preferred over 'make' for newer setups
git clone https://github.com/gnustep/libs-base.git   # Preferred over 'base'
git clone https://github.com/gnustep/libs-corebase.git # Included as per Ubuntu 24.04 script
git clone https://github.com/gnustep/libs-gui.git
git clone https://github.com/gnustep/libs-back.git

if [ "$BUILD_APPS" = true ] ; then
  echo -e "\n${GREEN}Checking out sources for applications...${NC}"
  git clone https://github.com/gnustep/apps-projectcenter.git
  git clone https://github.com/gnustep/apps-gorm.git
  # PDFKit from SVN, consider if still relevant or if there's a git mirror
  # svn co http://svn.savannah.nongnu.org/svn/gap/trunk/libs/PDFKit/
  git clone https://github.com/gnustep/apps-gworkspace.git
  git clone https://github.com/gnustep/apps-systempreferences.git
fi
show_prompt

# --- Build and Install Process ---

# Build GNUstep make (1st time)
# GNUstep Make needs to be built first, as it provides the build system for other components.
# It's built twice: once with system libraries, then again after libobjc2 is built,
# to link against the new Objective-C runtime.
echo -e "\n${GREEN}Building GNUstep-make (1st pass)...${NC}"
cd tools-make
CC=$CC ./configure \
          --with-layout=gnustep \ # Install into a GNUstep-specific layout (/usr/GNUstep)
          --disable-importing-config-file \ # Avoids issues with pre-existing user configs
          --enable-native-objc-exceptions \ # Use native Objective-C exceptions
          --enable-objc-arc \ # Enable Automatic Reference Counting support
          --enable-install-ld-so-conf \ # Helps ensure libraries are found
          --with-library-combo=ng-gnu-gnu \ # Specifies the library naming and runtime scheme
          --enable-debug-by-default # For verbose debugging as requested
make -j$(nproc)
sudo -E make install
sudo ldconfig
show_prompt

# Source GNUstep environment script
# This script sets up necessary environment variables (PATH, LD_LIBRARY_PATH, etc.)
# for the GNUstep development environment.
echo -e "\n${GREEN}Sourcing GNUstep environment script...${NC}"
if [ -f /usr/GNUstep/System/Library/Makefiles/GNUstep.sh ]; then
  . /usr/GNUstep/System/Library/Makefiles/GNUstep.sh # Source it in the current shell
  echo "Sourced GNUstep.sh"
  # Ensure it's added to .bashrc to be available in new terminal sessions
  echo "GNUstep environment sourced. Adding to .bashrc if not already present."
  grep -qxF '. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh' ~/.bashrc || echo '. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh' >> ~/.bashrc
  grep -qxF "export RUNTIME_VERSION=\"$RUNTIME_VERSION\"" ~/.bashrc || echo "export RUNTIME_VERSION=\"$RUNTIME_VERSION\"" >> ~/.bashrc
  grep -qxF "export CXXFLAGS=\"$CXXFLAGS\"" ~/.bashrc || echo "export CXXFLAGS=\"$CXXFLAGS\"" >> ~/.bashrc
else
  echo "Error: /usr/GNUstep/System/Library/Makefiles/GNUstep.sh not found after installing tools-make."
  echo "This script is crucial for the subsequent build steps."
  exit 1
fi
show_prompt

# Build libdispatch (swift-corelibs-libdispatch)
echo -e "\n${GREEN}Building libdispatch...${NC}"
cd ../swift-corelibs-libdispatch
rm -rf build # Clean previous build attempts
mkdir build && cd build
cmake .. -DCMAKE_C_COMPILER="${CC}" \
         -DCMAKE_CXX_COMPILER="${CXX}" \
         -DCMAKE_BUILD_TYPE=Release \ # Build optimized release version
         -DCMAKE_INSTALL_PREFIX=/usr/GNUstep \ # Install into the main GNUstep hierarchy
         -DCMAKE_INSTALL_LIBDIR=System/Library/Libraries \ # Standard GNUstep library location
         -DINSTALL_DISPATCH_HEADERS_DIR=System/Library/Headers/dispatch \ # Headers for libdispatch
         -DINSTALL_BLOCK_HEADERS_DIR=System/Library/Headers/block \ # Headers for Blocks runtime
         -DINSTALL_OS_HEADERS_DIR=System/Library/Headers/os \ # Headers for OS compatibility
         -DUSE_GOLD_LINKER=NO # Set to YES if ld.gold is confirmed and used
make -j$(nproc)
sudo -E make install
sudo ldconfig
show_prompt

# Build libobjc2
# This provides the modern Objective-C runtime.
echo -e "\n${GREEN}Building libobjc2...${NC}"
cd ../../libobjc2
rm -rf build # Clean previous build attempts
mkdir build && cd build
cmake ../ -DCMAKE_C_COMPILER=$CC -DCMAKE_CXX_COMPILER=$CXX -DCMAKE_ASM_COMPILER=$CC \
          -DTESTS=OFF \ # Disable building tests for faster build
          -DBUILD_STATIC_LIBOBJC=ON \ # Build a static version of libobjc2
          -DCMAKE_INSTALL_PREFIX=/usr/GNUstep # Install into the main GNUstep hierarchy
#         -DGNUSTEP_INSTALL_TYPE='SYSTEM' # This was in debian script, check if compatible with /usr/local prefix
cmake --build . -j$(nproc)
sudo -E make install
sudo ldconfig
show_prompt

# Build GNUstep make (2nd time)
# Rebuilding GNUstep Make ensures it links against the just-built libobjc2 runtime
# and picks up any changes or new capabilities from it.
echo -e "\n${GREEN}Building GNUstep-make (2nd pass)...${NC}"
cd ../../tools-make
# It's common to re-run configure and make for tools-make with the same flags
CC=$CC ./configure \
          --with-layout=gnustep \
          --disable-importing-config-file \
          --enable-native-objc-exceptions \
          --enable-objc-arc \
          --enable-install-ld-so-conf \
          --with-library-combo=ng-gnu-gnu \
          --enable-debug-by-default
make -j$(nproc)
sudo -E make install
# Re-source GNUstep.sh as make might have changed/updated it
. /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
show_prompt

# Build GNUstep libs-base
echo -e "\n${GREEN}Building GNUstep libs-base...${NC}"
cd ../libs-base
./configure # Add --enable-debug-by-default if needed for this component
make -j$(nproc)
sudo -E make install
sudo ldconfig
show_prompt

# Build GNUstep libs-corebase
echo -e "\n${GREEN}Building GNUstep libs-corebase...${NC}"
cd ../libs-corebase
# Configure flags might be different here, check original scripts
# Example from Ubuntu 24.04 script:
# CPP=`gnustep-config --variable=CPP` CPPFLAGS=`gnustep-config --objc-flags` CC=`gnustep-config --variable=CC` CFLAGS=`gnustep-config --objc-flags` LDFLAGS=`gnustep-config --objc-libs` ./configure
# For simplicity, starting with a standard configure, can be adjusted.
# Using gnustep-config for flags is generally more robust after make is installed.
gnustep_config_flags() {
  echo "CPP=\$(gnustep-config --variable=CPP) \
CPPFLAGS=\$(gnustep-config --objc-flags) \
CC=\$(gnustep-config --variable=CC) \
CFLAGS=\$(gnustep-config --objc-flags) \
LDFLAGS=\$(gnustep-config --objc-libs)"
}
eval $(gnustep_config_flags) ./configure # Add --enable-debug-by-default if needed
make -j$(nproc)
sudo -E make install
sudo ldconfig
show_prompt

# Build GNUstep libs-gui
echo -e "\n${GREEN}Building GNUstep libs-gui...${NC}"
cd ../libs-gui
./configure # Add --enable-debug-by-default if needed
make -j$(nproc)
sudo -E make install
sudo ldconfig
show_prompt

# Build GNUstep libs-back
echo -e "\n${GREEN}Building GNUstep libs-back...${NC}"
cd ../libs-back
./configure # Add --enable-debug-by-default if needed
make -j$(nproc)
sudo -E make install
sudo ldconfig
show_prompt

# --- Finalization ---
# Re-source GNUstep.sh one last time
if [ -f /usr/GNUstep/System/Library/Makefiles/GNUstep.sh ]; then
  . /usr/GNUstep/System/Library/Makefiles/GNUstep.sh
fi

echo -e "\n${GREEN}GNUstep build and installation process complete.${NC}"
echo "Open a new terminal or source your ~/.bashrc to use the new environment."
echo "Example: source ~/.bashrc"

# Optional: Build applications if BUILD_APPS is true
if [ "$BUILD_APPS" = true ] ; then
  echo -e "\n${GREEN}Building optional applications...${NC}"

  echo -e "${GREEN}Building ProjectCenter...${NC}"
  cd ../apps-projectcenter/
  make clean && make -j$(nproc) && sudo -E make install
  show_prompt

  echo -e "${GREEN}Building Gorm...${NC}"
  cd ../apps-gorm/
  make clean && make -j$(nproc) && sudo -E make install
  show_prompt

  # PDFKit might require svn and has specific build steps
  # echo -e "${GREEN}Building PDFKit...${NC}"
  # cd ../PDFKit/ # Assuming it was checked out
  # ./configure && make -j$(nproc) && sudo -E make install
  # show_prompt

  echo -e "${GREEN}Building GWorkspace...${NC}"
  cd ../apps-gworkspace/
  ./configure && make -j$(nproc) && sudo -E make install
  show_prompt

  echo -e "${GREEN}Building SystemPreferences...${NC}"
  cd ../apps-systempreferences/
  make clean && make -j$(nproc) && sudo -E make install
  show_prompt

  echo -e "\n${GREEN}Optional applications build complete.${NC}"
fi

cd .. # Back to the root of the repository from BUILD_DIR
echo -e "\n${GREEN}All done! setup.sh finished.${NC}"
