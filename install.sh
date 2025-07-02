#!/bin/sh

# -----------------------------------------------------------------------------
# 1) Define environment variables and colors for terminal output.
# -----------------------------------------------------------------------------
NEXUS_HOME="$HOME/.nexus"
BIN_DIR="$NEXUS_HOME/bin"
GREEN='\033[1;32m'
ORANGE='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'  # No Color

# Ensure the $NEXUS_HOME and $BIN_DIR directories exist.
[ -d "$NEXUS_HOME" ] || mkdir -p "$NEXUS_HOME"
[ -d "$BIN_DIR" ] || mkdir -p "$BIN_DIR"

# -----------------------------------------------------------------------------
# 2) Display a message if we're interactive (NONINTERACTIVE is not set) and the
#    $NODE_ID is not a 28-character ID. This is for Testnet III info.
# -----------------------------------------------------------------------------
if [ -z "$NONINTERACTIVE" ] && [ "${#NODE_ID}" -ne "28" ]; then
    echo ""
    echo "${GREEN}Testnet III is now live!${NC}"
    echo ""
fi

# -----------------------------------------------------------------------------
# 3) Prompt the user to agree to the Nexus Beta Terms of Use if we're in an
#    interactive mode (i.e., NONINTERACTIVE is not set) and no config.json file exists.
#    We explicitly read from /dev/tty to ensure user input is requested from the
#    terminal rather than the script's standard input.
# -----------------------------------------------------------------------------
while [ -z "$NONINTERACTIVE" ] && [ ! -f "$NEXUS_HOME/config.json" ]; do
    read -p "Do you agree to the Nexus Beta Terms of Use (https://nexus.xyz/terms-of-use)? (Y/n) " yn </dev/tty
    echo ""

    case $yn in
        [Nn]* )
            echo ""
            exit;;
        [Yy]* )
            echo ""
            break;;
        "" )
            echo ""
            break;;
        * )
            echo "Please answer yes or no."
            echo "";;
    esac
done

# -----------------------------------------------------------------------------
# 4) Determine the platform and architecture
# -----------------------------------------------------------------------------
case "$(uname -s)" in
    Linux*)
        PLATFORM="linux"
        case "$(uname -m)" in
            x86_64)
                ARCH="x86_64"
                BINARY_NAME="nexus-network-linux-x86_64"
                ;;
            aarch64|arm64)
                ARCH="arm64"
                BINARY_NAME="nexus-network-linux-arm64"
                ;;
            *)
                echo "${RED}Unsupported architecture: $(uname -m)${NC}"
                echo "Please build from source:"
                echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
                echo "  cd nexus-cli/clients/cli"
                echo "  cargo build --release"
                exit 1
                ;;
        esac
        ;;
    Darwin*)
        PLATFORM="macos"
        case "$(uname -m)" in
            x86_64)
                ARCH="x86_64"
                BINARY_NAME="nexus-network-macos-x86_64"
                echo "${ORANGE}Note: You are running on an Intel Mac.${NC}"
                ;;
            arm64)
                ARCH="arm64"
                BINARY_NAME="nexus-network-macos-arm64"
                echo "${ORANGE}Note: You are running on an Apple Silicon Mac (M1/M2/M3).${NC}"
                ;;
            *)
                echo "${RED}Unsupported architecture: $(uname -m)${NC}"
                echo "Please build from source:"
                echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
                echo "  cd nexus-cli/clients/cli"
                echo "  cargo build --release"
                exit 1
                ;;
        esac
        ;;
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="windows"
        case "$(uname -m)" in
            x86_64)
                ARCH="x86_64"
                BINARY_NAME="nexus-network-windows-x86_64.exe"
                ;;
            *)
                echo "${RED}Unsupported architecture: $(uname -m)${NC}"
                echo "Please build from source:"
                echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
                echo "  cd nexus-cli/clients/cli"
                echo "  cargo build --release"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "${RED}Unsupported platform: $(uname -s)${NC}"
        echo "Please build from source:"
        echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
        echo "  cd nexus-cli/clients/cli"
        echo "  cargo build --release"
        exit 1
        ;;
esac

# -----------------------------------------------------------------------------
# 5) Select and download release binary
# -----------------------------------------------------------------------------
# Function to fetch available releases
fetch_releases() {
    curl -s https://api.github.com/repos/nexus-xyz/nexus-cli/releases | \
        grep '"tag_name":' | \
        sed -E 's/.*"tag_name":\s*"([^"]+)".*/\1/' | \
        sort -rV
}

# Function to find download URL for a specific version
get_download_url() {
    local version="$1"
    curl -s "https://api.github.com/repos/nexus-xyz/nexus-cli/releases/tags/$version" | \
        grep "browser_download_url" | \
        grep "$BINARY_NAME\"" | \
        cut -d '"' -f 4
}

# Check if VERSION is specified (via environment variable or command-line argument)
if [ -n "$VERSION" ]; then
    SELECTED_VERSION="$VERSION"
else
    # Interactive mode: List available releases
    if [ -z "$NONINTERACTIVE" ]; then
        echo "Fetching available releases..."
        RELEASES=$(fetch_releases)
        if [ -z "$RELEASES" ]; then
            echo "${RED}Could not fetch releases from GitHub${NC}"
            echo "Please check your internet connection or try building from source:"
            echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
            echo "  cd nexus-cli/clients/cli"
            echo "  cargo build --release"
            exit 1
        fi

        echo ""
        echo "Available releases:"
        echo "$RELEASES" | nl -w2 -s'. '
        echo ""
        echo "Enter the number of the release you want to install (or press Enter for the latest):"
        read -p "> " choice </dev/tty
        echo ""

        if [ -z "$choice" ]; then
            SELECTED_VERSION=$(echo "$RELEASES" | head -n 1)
        else
            SELECTED_VERSION=$(echo "$RELEASES" | sed -n "${choice}p")
            if [ -z "$SELECTED_VERSION" ]; then
                echo "${RED}Invalid selection${NC}"
                exit 1
            fi
        fi
    else
        # Non-interactive mode without VERSION: Use latest
        SELECTED_VERSION=$(fetch_releases | head -n 1)
    fi
fi

# Get download URL for the selected version
echo "Selected version: $SELECTED_VERSION"
LATEST_RELEASE_URL=$(get_download_url "$SELECTED_VERSION")

if [ -z "$LATEST_RELEASE_URL" ]; then
    echo "${RED}Could not find a precompiled binary for $PLATFORM-$ARCH in version $SELECTED_VERSION${NC}"
    echo "Please check the release assets or build from source:"
    echo "  git clone https://github.com/nexus-xyz/nexus-cli.git"
    echo "  cd nexus-cli/clients/cli"
    echo "  cargo build --release"
    exit 1
fi

echo "Downloading release $SELECTED_VERSION for $PLATFORM-$ARCH..."
curl -L -o "$BIN_DIR/nexus-network" "$LATEST_RELEASE_URL"
chmod +x "$BIN_DIR/nexus-network"
ln -s "$BIN_DIR/nexus-network" "$BIN_DIR/nexus-cli"
chmod +x "$BIN_DIR/nexus-cli"

# -----------------------------------------------------------------------------
# 6) Add $BIN_DIR to PATH if not already present
# -----------------------------------------------------------------------------
case "$SHELL" in
    */bash)
        PROFILE_FILE="$HOME/.bashrc"
        ;;
    */zsh)
        PROFILE_FILE="$HOME/.zshrc"
        ;;
    *)
        PROFILE_FILE="$HOME/.profile"
        ;;
esac

# Only append if not already in PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    if ! grep -qs "$BIN_DIR" "$PROFILE_FILE"; then
        echo "" >> "$PROFILE_FILE"
        echo "# Add Nexus CLI to PATH" >> "$PROFILE_FILE"
        echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$PROFILE_FILE"
        echo "${GREEN}Updated PATH in $PROFILE_FILE${NC}"
    fi
fi

echo ""
echo "${GREEN}Installation complete!${NC}"
echo "Restart your terminal or run the following command to update your PATH:"
echo "  source $PROFILE_FILE"
echo ""
echo "${ORANGE}To get your node ID, visit: https://app.nexus.xyz/nodes${NC}"
echo ""
echo "Register your user to begin linked proving with the Nexus CLI by: nexus-cli register-user --wallet-address <WALLET_ADDRESS>"
echo "Or follow the guide at https://docs.nexus.xyz/layer-1/testnet/cli-node"
