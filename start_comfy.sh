#!/bin/bash

# ============================================
# Configuration
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_ROOT="${SCRIPT_DIR}/comfy_versions"
ARGS="--enable-manager --enable-manager-legacy-ui"
BROWSER_URL="http://127.0.0.1:8188"
LOG_FILE="comfyui.log"

# App mode window settings
WINDOW_WIDTH=1920
WINDOW_HEIGHT=1080

# Separate profile directory (isolated from main browser)
PROFILE_DIR="/tmp/comfyui-browser-profile-$$"

# ============================================
# Colors for output
# ============================================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================
# Global Variables for Process Tracking
# ============================================
SERVER_PID=""
BROWSER_PID=""
SHUTDOWN_REQUESTED=0
SELECTED_VERSION=""
PYTHON_PATH=""
COMFY_PATH=""

# ============================================
# Functions
# ============================================

list_available_versions() {
    local versions=()

    if [ ! -d "$VERSIONS_ROOT" ]; then
        echo -e "${RED}✗ Versions directory not found: ${VERSIONS_ROOT}${NC}"
        return 1
    fi

    # Find all version directories (directories directly under comfy_versions)
    while IFS= read -r -d '' dir; do
        local name=$(basename "$dir")
        versions+=("$name")
    done < <(find "$VERSIONS_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [ ${#versions[@]} -eq 0 ]; then
        echo -e "${RED}✗ No versions found in: ${VERSIONS_ROOT}${NC}"
        return 1
    fi

    printf '%s\n' "${versions[@]}"
    return 0
}

display_version_menu() {
    local versions=($(list_available_versions))

    if [ ${#versions[@]} -eq 0 ]; then
        echo -e "${RED}✗ No versions available!${NC}"
        exit 1
    fi

    # If only one version, use it automatically
    if [ ${#versions[@]} -eq 1 ]; then
        SELECTED_VERSION="${versions[0]}"
        return 0
    fi

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Select ComfyUI Version to Launch${NC}"
    echo -e "${CYAN}========================================${NC}"

    for i in "${!versions[@]}"; do
        local ver="${versions[$i]}"
        local comfy_path="${VERSIONS_ROOT}/${ver}/comfyui"
        local python_dir=""

        # Find the python directory for this version
        while IFS= read -r -d '' pydir; do
            python_dir=$(basename "$pydir")
            break
        done < <(find "${VERSIONS_ROOT}/${ver}" -maxdepth 1 -type d -name "python_*" -print0)

        local status="✓"
        if [ ! -d "$comfy_path" ]; then
            status="✗ (missing comfyui)"
        fi

        printf "%2d. %-20s %s\n" $((i+1)) "$ver" "${status}"
    done

    echo ""
}

select_version() {
    local versions=($(list_available_versions))

    if [ ${#versions[@]} -eq 0 ]; then
        exit 1
    fi

    # If only one version, use it automatically
    if [ ${#versions[@]} -eq 1 ]; then
        SELECTED_VERSION="${versions[0]}"
        echo -e "${BLUE}Only one version found, using: ${GREEN}${SELECTED_VERSION}${NC}"
        return 0
    fi

    display_version_menu

    # Read user selection
    while true; do
        read -p "Enter version number [1-${#versions[@]}]: " choice

        # Validate input is a number
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}✗ Please enter a valid number.${NC}"
            continue
        fi

        # Convert to array index (1-based to 0-based)
        local idx=$((choice - 1))

        if [ "$idx" -lt 0 ] || [ "$idx" -ge ${#versions[@]} ]; then
            echo -e "${RED}✗ Invalid selection. Please choose between 1 and ${#versions[@]}.${NC}"
            continue
        fi

        SELECTED_VERSION="${versions[$idx]}"
        break
    done

    echo ""
}

validate_version() {
    local version="$1"

    COMFY_PATH="${VERSIONS_ROOT}/${version}/comfyui"

    # Find python directory (python_*) - find already returns full path!
    while IFS= read -r -d '' PYTHON_PATH; do
        break
    done < <(find "${VERSIONS_ROOT}/${version}" -maxdepth 1 -type d -name "python_*" -print0)

    # Validate paths exist
    if [ ! -d "$COMFY_PATH" ]; then
        echo -e "${RED}✗ ComfyUI directory not found: ${COMFY_PATH}${NC}"
        exit 1
    fi

    if [ -z "$PYTHON_PATH" ] || [ ! -d "$PYTHON_PATH" ]; then
        echo -e "${RED}✗ Python environment not found in version: ${version}${NC}"
        exit 1
    fi

    # Check for main.py
    if [ ! -f "${COMFY_PATH}/main.py" ]; then
        echo -e "${RED}✗ main.py not found in: ${COMFY_PATH}${NC}"
        exit 1
    fi

    return 0
}

detect_default_browser() {
    # PRIORITY 1: Check for regular Chrome/Chromium
    if command -v google-chrome &>/dev/null; then
        echo "chrome"
        return
    fi

    if command -v chromium-browser &>/dev/null; then
        echo "chromium"
        return
    fi

    # PRIORITY 2: Check xdg-settings (most reliable on modern Fedora)
    if command -v xdg-settings &>/dev/null; then
        local desktop_file=$(xdg-settings get default-web-browser 2>/dev/null)

        # Parse the .desktop file name more carefully
        local browser_name=$(basename "$desktop_file" | sed 's/\.desktop$//')

        case "$browser_name" in
            *google-chrome*|*chrome*) echo "chrome"; return ;;
            *chromium*) echo "chromium"; return ;;
            *firefox*) echo "firefox"; return ;;
            *edge*) echo "edge"; return ;;
            *opera*) echo "opera"; return ;;
            *brave*) echo "brave"; return ;;
        esac
    fi

    # PRIORITY 3: Check alternatives symlink (fallback)
    if [ -L /etc/alternatives/x-www-browser ]; then
        local target=$(readlink -f /etc/alternatives/x-www-browser 2>/dev/null)

        case "$target" in
            *google-chrome*|*chrome*) echo "chrome"; return ;;
            *chromium*) echo "chromium"; return ;;
            *firefox*) echo "firefox"; return ;;
            *edge*) echo "edge"; return ;;
            *opera*) echo "opera"; return ;;
            *brave*) echo "brave"; return ;;
        esac
    fi

    # PRIORITY 4: Check common browsers in order of preference (Chrome first!)
    for b in google-chrome chromium-browser brave-browser microsoft-edge-stable firefox; do
        if command -v "$b" &>/dev/null; then
            case "$b" in
                *chrome*|*chromium*) echo "chrome"; return ;;
                *brave*) echo "brave"; return ;;
                *edge*) echo "edge"; return ;;
                *firefox*) echo "firefox"; return ;;
            esac
        fi
    done

    # PRIORITY 5: Check .desktop files in standard locations
    for desktop_dir in /usr/share/applications ~/.local/share/applications; do
        if [ -d "$desktop_dir" ]; then
            for f in "$desktop_dir"/google-chrome*.desktop "$desktop_dir"/chromium*.desktop; do
                if [ -f "$f" ]; then
                    echo "chrome"
                    return
                fi
            done
        fi
    done

    # Last resort: Check what xdg-open would use
    local mime_handler=$(xdg-mime query default text/html 2>/dev/null)
    case "$mime_handler" in
        *google-chrome*|*chrome*) echo "chrome"; return ;;
        *chromium*) echo "chromium"; return ;;
        *firefox*) echo "firefox"; return ;;
    esac

    # Ultimate fallback - check if any browser exists
    if command -v google-chrome &>/dev/null; then
        echo "chrome"
    elif command -v firefox &>/dev/null; then
        echo "firefox"
    else
        echo ""
    fi
}

get_browser_command() {
    local type="$1"

    case "$type" in
        chrome)
            # Try Chrome first, then Chromium variants
            command -v google-chrome &>/dev/null && echo "google-chrome" || \
            command -v chromium-browser &>/dev/null && echo "chromium-browser" || \
            command -v chromium &>/dev/null && echo "chromium"
            ;;
        chromium)
            command -v chromium-browser &>/dev/null && echo "chromium-browser" || \
            command -v chromium &>/dev/null && echo "chromium"
            ;;
        firefox)
            command -v firefox &>/dev/null && echo "firefox"
            ;;
        brave)
            command -v brave-browser &>/dev/null && echo "brave-browser" || \
            command -v brave &>/dev/null && echo "brave"
            ;;
        edge)
            command -v microsoft-edge-stable &>/dev/null && echo "microsoft-edge-stable" || \
            command -v microsoft-edge &>/dev/null && echo "microsoft-edge"
            ;;
        opera)
            command -v opera-browser &>/dev/null && echo "opera-browser" || \
            command -v opera &>/dev/null && echo "opera"
            ;;
    esac
}

cleanup() {
    local exit_code=$?

    # Prevent double cleanup
    if [ $SHUTDOWN_REQUESTED -eq 1 ]; then
        return
    fi
    SHUTDOWN_REQUESTED=1

    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}   Shutting down...${NC}"
    echo -e "${YELLOW}========================================${NC}"

    # Kill browser process if running
    if [ -n "$BROWSER_PID" ] && kill -0 "$BROWSER_PID" 2>/dev/null; then
        echo -e "${BLUE}Stopping browser (PID: ${BROWSER_PID})...${NC}"
        kill "$BROWSER_PID" 2>/dev/null
        wait "$BROWSER_PID" 2>/dev/null
    fi

    # Kill server process if running
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        echo -e "${BLUE}Stopping ComfyUI server (PID: ${SERVER_PID})...${NC}"
        kill "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null
    fi

    # Clean up profile directory
    if [ -d "$PROFILE_DIR" ]; then
        echo -e "${BLUE}Cleaning up temporary profile...${NC}"
        rm -rf "$PROFILE_DIR" 2>/dev/null
    fi

    echo -e "${GREEN}✓ All processes stopped.${NC}"
    exit $exit_code
}

# Set up cleanup trap for Ctrl+C and script exit
trap cleanup EXIT INT TERM HUP

open_browser_app_mode() {
    local url="$1"

    # Detect default browser (Chrome prioritized)
    local browser_type=$(detect_default_browser)
    local browser_cmd=$(get_browser_command "$browser_type")

    if [ -z "$browser_cmd" ]; then
        echo -e "${RED}✗ No browser found on system!${NC}"
        xdg-open "$url" &
        BROWSER_PID=$!
        return 1
    fi

    # Create separate profile directory
    mkdir -p "$PROFILE_DIR"

    echo -e "${BLUE}Detected default browser: ${GREEN}${browser_type}${NC}"
    echo -e "${BLUE}Browser command: ${GREEN}${browser_cmd}${NC}"
    echo -e "${BLUE}Profile directory: ${YELLOW}${PROFILE_DIR}${NC}"

    case "$browser_type" in
        chrome|chromium|brave|edge)
            # Chromium-based browsers (Chrome, Brave, Edge)
            echo -e "${BLUE}Opening in App Mode with isolated profile...${NC}"

            $browser_cmd \
                --app="$url" \
                --window-size=$WINDOW_WIDTH,$WINDOW_HEIGHT \
                --user-data-dir="$PROFILE_DIR" \
                --disable-extensions \
                --disable-infobars \
                --no-first-run \
                &
            BROWSER_PID=$!
            ;;
        firefox)
            # Firefox - use a fresh temporary profile (avoids the "profile cannot be loaded" error)
            echo -e "${BLUE}Opening in standalone window with fresh profile...${NC}"

            # Create a proper Firefox profile structure
            local ff_profile="$PROFILE_DIR/firefox-profile"
            mkdir -p "$ff_profile"

            $browser_cmd \
                --width=$WINDOW_WIDTH \
                --height=$WINDOW_HEIGHT \
                --no-remote \
                -profile "$ff_profile" \
                "$url" \
                &
            BROWSER_PID=$!
            ;;
        opera)
            # Opera (limited app mode support)
            echo -e "${BLUE}Opening in standalone window...${NC}"

            $browser_cmd \
                --width=$WINDOW_WIDTH \
                --height=$WINDOW_HEIGHT \
                "$url" \
                &
            BROWSER_PID=$!
            ;;
        *)
            # Fallback to generic browser opening
            echo -e "${YELLOW}⚠ Using fallback method...${NC}"
            xdg-open "$url" &
            BROWSER_PID=$!
            ;;
    esac

    if [ -n "$BROWSER_PID" ]; then
        echo -e "${GREEN}✓ Browser started with PID: ${BROWSER_PID}${NC}"
    fi
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION   Launch specific version (e.g., v0.18)"
    echo "  --list              List available versions and exit"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive selection"
    echo "  $0 --version v0.18    # Launch specific version"
    echo "  $0 --list             # List available versions"
}

# ============================================
# Parse Command Line Arguments
# ============================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            SELECTED_VERSION="$2"
            shift 2
            ;;
        --list)
            echo "Available versions:"
            list_available_versions | while read ver; do
                printf "  • %s\n" "$ver"
            done
            exit 0
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# ============================================
# Main Script
# ============================================

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   ComfyUI Auto-Start Script${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Select version if not specified via command line
if [ -z "$SELECTED_VERSION" ]; then
    select_version
fi

# Validate and set paths for selected version
validate_version "$SELECTED_VERSION"

echo -e "${BLUE}Selected Version: ${GREEN}${SELECTED_VERSION}${NC}"
echo -e "${BLUE}ComfyUI Path:     ${CYAN}${COMFY_PATH}${NC}"
echo -e "${BLUE}Python Env:       ${CYAN}${PYTHON_PATH}${NC}"
echo ""

# Clear old log file for fresh start
> "$LOG_FILE"

echo -e "${BLUE}[1/3] Starting ComfyUI Server...${NC}"

# Launch the Python script in background, redirecting output to log file
cd "$COMFY_PATH" || exit 1

# Use the python from the selected version's environment
"${PYTHON_PATH}/bin/python3" "main.py" $ARGS > "$LOG_FILE" 2>&1 &

SERVER_PID=$!
echo -e "${GREEN}✓ Server started with PID: ${SERVER_PID}${NC}"

# Wait for server to be ready (with timeout) - SHOWING LOGS IN REALTIME
echo -e "${BLUE}[2/3] Waiting for server to initialize...${NC}"
echo -e "${YELLOW}   (Showing startup logs below)${NC}"
echo ""
TIMEOUT=60
COUNTER=0
LAST_LINE_COUNT=0

while ! curl --silent --output /dev/null --fail "$BROWSER_URL" 2>/dev/null; do
    # Show new log lines in real-time during startup
    if [ -f "$LOG_FILE" ]; then
        CURRENT_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")

        if [ "$CURRENT_LINES" -gt "$LAST_LINE_COUNT" ]; then
            # Show only new lines
            tail -n +"$((LAST_LINE_COUNT + 1))" "$LOG_FILE" | \
                while IFS= read -r line; do
                    case "$line" in
                        *"ERROR"*|*"Exception"*) echo -e "${RED}${line}${NC}" ;;
                        *"WARNING"*) echo -e "${YELLOW}${line}${NC}" ;;
                        *) echo "$line" ;;
                    esac
                done
            LAST_LINE_COUNT=$CURRENT_LINES
        fi
    fi

    sleep 0.5
    COUNTER=$((COUNTER + 1))

    if [ $COUNTER -ge $TIMEOUT ]; then
        echo ""
        echo -e "${YELLOW}⚠ Server took longer than expected, opening browser anyway...${NC}"
        break
    fi
done

echo ""
echo -e "${GREEN}✓ Server is ready!${NC}"


# Open the Browser in App Mode (standalone, minimal UI)
echo -e "${BLUE}[3/3] Opening default browser in App Mode (${WINDOW_WIDTH}x${WINDOW_HEIGHT})...${NC}"
open_browser_app_mode "$BROWSER_URL"

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}  Server is running! Logs below:${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${BLUE}Close the browser window OR press Ctrl+C to stop.${NC}"
echo ""

# ============================================
# MAIN LOOP: Monitor both browser and display logs
# ============================================

while true; do
    # Check if browser is still running
    if [ -n "$BROWSER_PID" ]; then
        if ! kill -0 "$BROWSER_PID" 2>/dev/null; then
            echo ""
            echo -e "${YELLOW}========================================${NC}"
            echo -e "${YELLOW}   Browser closed. Shutting down...${NC}"
            echo -e "${YELLOW}========================================${NC}"

            # Kill server process if running
            if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
                echo -e "${BLUE}Stopping ComfyUI server (PID: ${SERVER_PID})...${NC}"
                kill "$SERVER_PID" 2>/dev/null
                wait "$SERVER_PID" 2>/dev/null
            fi

            # Clean up profile directory
            if [ -d "$PROFILE_DIR" ]; then
                echo -e "${BLUE}Cleaning up temporary profile...${NC}"
                rm -rf "$PROFILE_DIR" 2>/dev/null
            fi

            echo -e "${GREEN}✓ All processes stopped.${NC}"
            exit 0
        fi
    fi

    # Display only NEW log lines with colorization (avoid printing same line repeatedly)
    if [ -f "$LOG_FILE" ]; then
        CURRENT_LINES=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")

        if [ "$CURRENT_LINES" -gt "$LAST_LINE_COUNT" ]; then
            # Show only new lines since last check
            tail -n +"$((LAST_LINE_COUNT + 1))" "$LOG_FILE" | \
                while IFS= read -r line; do
                    case "$line" in
                        *"ERROR"*|*"Exception"*) echo -e "${RED}${line}${NC}" ;;
                        *"WARNING"*) echo -e "${YELLOW}${line}${NC}" ;;
                        *"✓"*|*"ready"*|*"started"*) echo -e "${GREEN}${line}${NC}" ;;
                        *) echo "$line" ;;
                    esac
                done
            LAST_LINE_COUNT=$CURRENT_LINES
        fi
    fi

    # Small sleep to prevent CPU spinning
    sleep 0.5
done
