#!/bin/bash

# ============================================
# Configuration
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_ROOT="${SCRIPT_DIR}/environments"
DEFAULT_PORT=8188
PORT_FILE_DIR="${SCRIPT_DIR}/.running_instances"
LOG_DIR="${SCRIPT_DIR}/.logs"
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
SELECTED_ENV=""
PYTHON_PATH=""
COMFY_PATH=""
EXTRA_ARGS=""
CUSTOM_PORT=""
ACTUAL_PORT=$DEFAULT_PORT
INSTANCE_LOG_FILE=""

# ============================================
# Functions
# ============================================

get_creation_date() {
    local path="$1"
    # Use stat to get birth time (creation date), fallback to modification time if not available
    stat -c %w "$path" 2>/dev/null | cut -d' ' -f1 || \
    stat -c %y "$path" 2>/dev/null | cut -d' ' -f1
}

get_last_edit_date() {
    local path="$1"
    # Get modification time (last edit date)
    stat -c %y "$path" 2>/dev/null | cut -d' ' -f1
}

list_available_environments() {
    local envs=()

    if [ ! -d "$VERSIONS_ROOT" ]; then
        echo -e "${RED}✗ Environments directory not found: ${VERSIONS_ROOT}${NC}"
        return 1
    fi

    # Find all environment directories (directories directly under environments)
    while IFS= read -r -d '' dir; do
        local name=$(basename "$dir")
        envs+=("$name")
    done < <(find "$VERSIONS_ROOT" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [ ${#envs[@]} -eq 0 ]; then
        echo -e "${RED}✗ No environments found in: ${VERSIONS_ROOT}${NC}"
        return 1
    fi

    printf '%s\n' "${envs[@]}"
    return 0
}

# Get port for a running environment (returns empty if not running)
get_env_port() {
    local env_name="$1"
    
    if [ ! -d "$PORT_FILE_DIR" ]; then
        echo ""
        return
    fi
    
    for pid_file in "${PORT_FILE_DIR}"/port_*.pid; do
        [ -f "$pid_file" ] || continue
        
        local port=$(basename "$pid_file" .pid | sed 's/port_//')
        local running_env=$(cat "${PORT_FILE_DIR}/port_${port}.env" 2>/dev/null)
        local pid=$(cat "$pid_file" 2>/dev/null)
        
        if [ "$running_env" = "$env_name" ] && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "$port"
            return
        fi
    done
    
    echo ""
}

# Get PID for a running environment (returns empty if not running)
get_env_pid() {
    local env_name="$1"
    
    if [ ! -d "$PORT_FILE_DIR" ]; then
        echo ""
        return
    fi
    
    for pid_file in "${PORT_FILE_DIR}"/port_*.pid; do
        [ -f "$pid_file" ] || continue
        
        local port=$(basename "$pid_file" .pid | sed 's/port_//')
        local running_env=$(cat "${PORT_FILE_DIR}/port_${port}.env" 2>/dev/null)
        local pid=$(cat "$pid_file" 2>/dev/null)
        
        if [ "$running_env" = "$env_name" ] && [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return
        fi
    done
    
    echo ""
}

display_environment_menu() {
    local envs=($(list_available_environments))

    if [ ${#envs[@]} -eq 0 ]; then
        echo -e "${RED}✗ No environments available!${NC}"
        exit 1
    fi

    # If only one environment, use it automatically
    if [ ${#envs[@]} -eq 1 ]; then
        SELECTED_ENV="${envs[0]}"
        return 0
    fi

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Select ComfyUI Environment to Launch${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Print header with running status columns
    printf "%2s %-18s %-6s %-10s %-10s %-10s %s\n" "#" "ENVIRONMENT" "PORT" "PID" "CREATED" "LAST EDIT" "STATUS"
    printf "%2s %-18s %-6s %-10s %-10s %-10s %s\n" "#" "-----------" "----" "---" "-------" "---------" "------"

    for i in "${!envs[@]}"; do
        local env="${envs[$i]}"
        local comfy_path="${VERSIONS_ROOT}/${env}/comfyui"
        local python_dir=""
        local env_path="${VERSIONS_ROOT}/${env}"

        # Find the python directory for this environment
        while IFS= read -r -d '' pydir; do
            python_dir=$(basename "$pydir")
            break
        done < <(find "${VERSIONS_ROOT}/${env}" -maxdepth 1 -type d -name "python_*" -print0)

        # Get running info
        local port_info="-"
        local pid_info="-"
        local status="stopped"
        local running_port=$(get_env_port "$env")
        local running_pid=$(get_env_pid "$env")
        if [ -n "$running_port" ]; then
            port_info="$running_port"
            pid_info="$running_pid"
            status="✓ Running"
        fi
        
        # Get dates
        local created=$(get_creation_date "$env_path")
        local edited=$(get_last_edit_date "$env_path")

        printf "%2d %-18s %-6s %-10s %-10s %-10s %s\n" $((i+1)) "$env" "$port_info" "$pid_info" "$created" "$edited" "$status"
    done

    echo ""
}

select_environment() {
    local envs=($(list_available_environments))

    if [ ${#envs[@]} -eq 0 ]; then
        exit 1
    fi

    # If only one environment, use it automatically
    if [ ${#envs[@]} -eq 1 ]; then
        SELECTED_ENV="${envs[0]}"
        echo -e "${BLUE}Only one environment found, using: ${GREEN}${SELECTED_ENV}${NC}"
        return 0
    fi

    display_environment_menu

    # Read user selection
    while true; do
        read -p "Enter environment number [1-${#envs[@]}]: " choice

        # Validate input is a number
        if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}✗ Please enter a valid number.${NC}"
            continue
        fi

        # Convert to array index (1-based to 0-based)
        local idx=$((choice - 1))

        if [ "$idx" -lt 0 ] || [ "$idx" -ge ${#envs[@]} ]; then
            echo -e "${RED}✗ Invalid selection. Please choose between 1 and ${#envs[@]}.${NC}"
            continue
        fi

        SELECTED_ENV="${envs[$idx]}"
        break
    done

    echo ""
}

validate_environment() {
    local env="$1"

    COMFY_PATH="${VERSIONS_ROOT}/${env}/comfyui"

    # Find python directory (python_*) - find already returns full path!
    while IFS= read -r -d '' PYTHON_PATH; do
        break
    done < <(find "${VERSIONS_ROOT}/${env}" -maxdepth 1 -type d -name "python_*" -print0)

    # Validate paths exist
    if [ ! -d "$COMFY_PATH" ]; then
        echo -e "${RED}✗ ComfyUI directory not found: ${COMFY_PATH}${NC}"
        exit 1
    fi

    if [ -z "$PYTHON_PATH" ] || [ ! -d "$PYTHON_PATH" ]; then
        echo -e "${RED}✗ Python environment not found in environment: ${env}${NC}"
        exit 1
    fi

    # Check for main.py
    if [ ! -f "${COMFY_PATH}/main.py" ]; then
        echo -e "${RED}✗ main.py not found in: ${COMFY_PATH}${NC}"
        exit 1
    fi

    # Determine manager arguments based on whether built-in manager is available
    if [ -f "${COMFY_PATH}/manager_requirements.txt" ]; then
        ARGS="--enable-manager --enable-manager-legacy-ui"
    else
        ARGS=""
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

    # Unregister this instance from tracking
    if [ -n "$ACTUAL_PORT" ]; then
        unregister_instance "$ACTUAL_PORT"
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
    echo "  --env ENVIRONMENT   Launch specific environment (e.g., v0.18)"
    echo "  --port PORT         Use specific port (default: auto-select from $DEFAULT_PORT+)"
    echo "  --args ARGUMENTS    Extra arguments to pass to ComfyUI (quote if multiple)"
    echo "  --list              List available environments with running status and exit"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    # Interactive selection, auto port"
    echo "  $0 --env v0.18        # Launch specific environment"
    echo "  $0 --port 9000        # Use port 9000 (or next available)"
    echo "  $0 --args '--listen'   # Pass --listen to ComfyUI"
    echo "  $0 --list             # List available environments with status"
}

# Get next available port starting from DEFAULT_PORT
get_available_port() {
    local requested_port="$1"
    
    # If a specific port was requested, check if it's available
    if [ -n "$requested_port" ]; then
        if is_port_in_use "$requested_port"; then
            echo -e "${RED}✗ Port $requested_port is already in use${NC}"
            return 1
        fi
        echo "$requested_port"
        return 0
    fi
    
    # Auto-increment: find first available port starting from DEFAULT_PORT
    local port=$DEFAULT_PORT
    while is_port_in_use "$port"; do
        port=$((port + 1))
        # Safety limit - don't go beyond port 65535
        if [ $port -gt 65535 ]; then
            echo -e "${RED}✗ No available ports found${NC}"
            return 1
        fi
    done
    echo "$port"
    return 0
}

# Check if a port is currently in use by checking PID files or network
is_port_in_use() {
    local port="$1"
    
    # Method 1: Check PID file
    if [ -f "${PORT_FILE_DIR}/port_${port}.pid" ]; then
        local pid=$(cat "${PORT_FILE_DIR}/port_${port}.pid" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0  # Port is in use
        fi
    fi
    
    # Method 2: Check network socket (more reliable)
    if command -v ss &>/dev/null; then
        ss -tuln 2>/dev/null | grep -q ":${port} "
        return $?
    elif command -v netstat &>/dev/null; then
        netstat -tuln 2>/dev/null | grep -q ":${port} "
        return $?
    fi
    
    return 1  # Port is available
}

# List all running ComfyUI instances
list_running_instances() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   Running ComfyUI Instances${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Check if port file directory exists
    if [ ! -d "$PORT_FILE_DIR" ]; then
        echo -e "${YELLOW}No running instances found.${NC}"
        return 0
    fi
    
    local count=0
    printf "%-6s %-12s %-25s %s\n" "PORT" "PID" "ENVIRONMENT" "STATUS"
    printf "%-6s %-12s %-25s %s\n" "----" "---" "-----------" "------"
    
    # Check all port PID files
    for pid_file in "${PORT_FILE_DIR}"/port_*.pid; do
        [ -f "$pid_file" ] || continue
        
        local port=$(basename "$pid_file" .pid | sed 's/port_//')
        local pid=$(cat "$pid_file" 2>/dev/null)
        local env_name=$(cat "${PORT_FILE_DIR}/port_${port}.env" 2>/dev/null || echo "unknown")
        
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            printf "%-6s %-12s %-25s %s\n" "$port" "$pid" "$env_name" "✓ Running"
            count=$((count + 1))
        else
            # Stale PID file - process not running
            printf "%-6s %-12s %-25s %s\n" "$port" "$pid" "$env_name" "✗ Stale"
        fi
    done
    
    echo ""
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No running instances found.${NC}"
    else
        echo -e "Found ${GREEN}$count${NC} running instance(s)"
    fi
}

# Clean up stale PID files
cleanup_stale_pids() {
    if [ ! -d "$PORT_FILE_DIR" ]; then
        return 0
    fi
    
    for pid_file in "${PORT_FILE_DIR}"/port_*.pid; do
        [ -f "$pid_file" ] || continue
        
        local port=$(basename "$pid_file" .pid | sed 's/port_//')
        local pid=$(cat "$pid_file" 2>/dev/null)
        
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            # Process not running, remove stale files
            rm -f "$pid_file" "${PORT_FILE_DIR}/port_${port}.env" 2>/dev/null
        fi
    done
}

# Register this instance's port and PID
register_instance() {
    local port="$1"
    local env_name="$2"
    local pid="$3"
    
    mkdir -p "$PORT_FILE_DIR"
    echo "$pid" > "${PORT_FILE_DIR}/port_${port}.pid"
    echo "$env_name" > "${PORT_FILE_DIR}/port_${port}.env"
}

# Unregister this instance's port and PID
unregister_instance() {
    local port="$1"
    
    rm -f "${PORT_FILE_DIR}/port_${port}.pid" "${PORT_FILE_DIR}/port_${port}.env" 2>/dev/null
}

# ============================================
# Parse Command Line Arguments
# ============================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --env)
            SELECTED_ENV="$2"
            shift 2
            ;;
        --version)
            # Deprecated, but kept for backward compatibility
            echo -e "${YELLOW}⚠ Warning: --version is deprecated. Use --env instead.${NC}"
            SELECTED_ENV="$2"
            shift 2
            ;;
        --port)
            CUSTOM_PORT="$2"
            shift 2
            ;;
        --args)
            EXTRA_ARGS="$2"
            shift 2
            ;;
        --list)
            echo "Available environments:"
            echo ""
            
            # Print header with running status columns
            printf "%-20s %-6s %-10s %-12s %-12s %s\n" "ENVIRONMENT" "PORT" "PID" "CREATED" "LAST EDIT" "STATUS"
            printf "%-20s %-6s %-10s %-12s %-12s %s\n" "-----------" "----" "---" "-------" "---------" "------"
            
            # List environments with dates and running status
            list_available_environments | while read -r env; do
                env_path="${VERSIONS_ROOT}/${env}"
                created=$(get_creation_date "$env_path")
                edited=$(get_last_edit_date "$env_path")
                
                # Get running info
                port_info="-"
                pid_info="-"
                status="stopped"
                running_port=$(get_env_port "$env")
                running_pid=$(get_env_pid "$env")
                if [ -n "$running_port" ]; then
                    port_info="$running_port"
                    pid_info="$running_pid"
                    status="✓ Running"
                fi
                
                printf "%-20s %-6s %-10s %-12s %-12s %s\n" "$env" "$port_info" "$pid_info" "$created" "$edited" "$status"
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

# Clean up any stale PID files from previous crashed sessions
cleanup_stale_pids

# Select environment if not specified via command line
if [ -z "$SELECTED_ENV" ]; then
    select_environment
fi

# Validate and set paths for selected environment
validate_environment "$SELECTED_ENV"

# Check if this environment is already running
existing_port=$(get_env_port "$SELECTED_ENV")
if [ -n "$existing_port" ]; then
    echo -e "${RED}✗ Environment '${SELECTED_ENV}' is already running on port ${existing_port}${NC}"
    echo -e "${YELLOW}Use Ctrl+C to stop the existing instance, or use a different environment.${NC}"
    exit 1
fi

# Determine which port to use
ACTUAL_PORT=$(get_available_port "$CUSTOM_PORT")
if [ $? -ne 0 ]; then
    exit 1
fi

# Update browser URL with actual port
BROWSER_URL="http://127.0.0.1:${ACTUAL_PORT}"

echo -e "${BLUE}Selected Environment: ${GREEN}${SELECTED_ENV}${NC}"
echo -e "${BLUE}ComfyUI Path:     ${CYAN}${COMFY_PATH}${NC}"
echo -e "${BLUE}Python Env:       ${CYAN}${PYTHON_PATH}${NC}"
echo -e "${BLUE}Port:           ${GREEN}${ACTUAL_PORT}${NC}"

# Show manager status
if [ -n "$ARGS" ]; then
    echo -e "${BLUE}Manager Args:     ${GREEN}${ARGS}${NC}"
else
    echo -e "${BLUE}Manager Args:     ${YELLOW}(none - standalone or no manager)${NC}"
fi

# Show extra args if provided
if [ -n "$EXTRA_ARGS" ]; then
    echo -e "${BLUE}Extra Args:       ${CYAN}${EXTRA_ARGS}${NC}"
fi

# Show port info
if [ -n "$CUSTOM_PORT" ]; then
    echo -e "${BLUE}Port Mode:        ${GREEN}User-specified ($CUSTOM_PORT)${NC}"
else
    if [ $ACTUAL_PORT -eq $DEFAULT_PORT ]; then
        echo -e "${BLUE}Port Mode:        ${GREEN}Default ($DEFAULT_PORT)${NC}"
    else
        echo -e "${BLUE}Port Mode:        ${YELLOW}Auto-selected (ports $DEFAULT_PORT-$((ACTUAL_PORT-1)) in use)${NC}"
    fi
fi
echo ""

# Clear old log file for fresh start
# Create unique log file per instance in .logs directory
mkdir -p "$LOG_DIR"
INSTANCE_LOG_FILE="${LOG_DIR}/${SELECTED_ENV}_port_${ACTUAL_PORT}.log"
> "$INSTANCE_LOG_FILE"

echo -e "${BLUE}[1/3] Starting ComfyUI Server on port ${ACTUAL_PORT}...${NC}"

# Launch the Python script in background, redirecting output to log file
cd "$COMFY_PATH" || exit 1

# Use the python from the selected environment's Python installation
# Combine manager args with extra user-provided args and port
ALL_ARGS="$ARGS --port $ACTUAL_PORT $EXTRA_ARGS"
"${PYTHON_PATH}/bin/python3" "main.py" $ALL_ARGS > "$INSTANCE_LOG_FILE" 2>&1 &

SERVER_PID=$!
echo -e "${GREEN}✓ Server started with PID: ${SERVER_PID}${NC}"

# Register this instance for tracking
register_instance "$ACTUAL_PORT" "$SELECTED_ENV" "$SERVER_PID"

# Wait for server to be ready (with timeout) - SHOWING LOGS IN REALTIME
echo -e "${BLUE}[2/3] Waiting for server to initialize...${NC}"
echo -e "${YELLOW}   (Showing startup logs below)${NC}"
echo ""
TIMEOUT=60
COUNTER=0
LAST_LINE_COUNT=0

while ! curl --silent --output /dev/null --fail "$BROWSER_URL" 2>/dev/null; do
    # Show new log lines in real-time during startup
    if [ -f "$INSTANCE_LOG_FILE" ]; then
        CURRENT_LINES=$(wc -l < "$INSTANCE_LOG_FILE" 2>/dev/null || echo "0")

        if [ "$CURRENT_LINES" -gt "$LAST_LINE_COUNT" ]; then
            # Show only new lines
            tail -n +"$((LAST_LINE_COUNT + 1))" "$INSTANCE_LOG_FILE" | \
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

            # Unregister this instance from tracking
            if [ -n "$ACTUAL_PORT" ]; then
                unregister_instance "$ACTUAL_PORT"
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
    if [ -f "$INSTANCE_LOG_FILE" ]; then
        CURRENT_LINES=$(wc -l < "$INSTANCE_LOG_FILE" 2>/dev/null || echo "0")

        if [ "$CURRENT_LINES" -gt "$LAST_LINE_COUNT" ]; then
            # Show only new lines since last check
            tail -n +"$((LAST_LINE_COUNT + 1))" "$INSTANCE_LOG_FILE" | \
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
