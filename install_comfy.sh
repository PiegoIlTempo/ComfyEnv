#!/bin/bash

# ============================================
# Configuration
# ============================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_ROOT="${SCRIPT_DIR}/comfy_versions"
COMFYUI_REPO="https://github.com/Comfy-Org/ComfyUI.git"
MANAGER_REPO="https://github.com/ltdrdata/ComfyUI-Manager.git"

# Python version mapping (version -> python_version)
# Adjust based on your needs - older versions may need older Python
declare -A PYTHON_VERSION_MAP=(
    ["v0.18"]="3.13"
    ["v0.17"]="3.13"
    ["v0.16"]="3.13"
    ["v0.15"]="3.13"
    ["v0.14"]="3.13"
    ["v0.13"]="3.13"
    ["v0.12"]="3.13"
    ["v0.11"]="3.13"
    ["v0.10"]="3.13"
    ["v0.9"]="3.13"
    ["v0.8"]="3.13"
    ["v0.7"]="3.13"
    ["v0.6"]="3.12"
    ["v0.5"]="3.12"
    ["v0.4"]="3.12"
    ["v0.3"]="3.11"
    ["default"]="3.13"
)

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
# Functions
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

install_pytorch() {
    local python_bin="$1"
    local force_stable=false
    
    # Check if user wants stable version via environment variable or argument
    if [ "$FORCE_STABLE_PYTORCH" = "true" ] || [ "$2" = "--stable" ]; then
        force_stable=true
    fi
    
    echo ""
    log_info "Detecting GPU type for PyTorch installation..."
    echo ""
    
    # Try to auto-detect GPU
    local auto_detected=""
    
    # Check for NVIDIA GPU
    if command -v nvidia-smi &>/dev/null; then
        if nvidia-smi --query-gpu=name --format=csv,noheader &>/dev/null 2>&1; then
            auto_detected="nvidia"
            log_info "Auto-detected: NVIDIA GPU"
        fi
    fi
    
    # Check for AMD GPU (ROCm)
    if [ -z "$auto_detected" ] && command -v rocm-smi &>/dev/null; then
        auto_detected="amd"
        log_info "Auto-detected: AMD GPU"
    elif [ -z "$auto_detected" ] && command -v lstopo &>/dev/null; then
        if lstopo --json 2>/dev/null | grep -qi "AMD\|Radeon"; then
            auto_detected="amd"
            log_info "Auto-detected: AMD GPU"
        fi
    fi
    
    # Check for Intel Arc GPU
    if [ -z "$auto_detected" ] && command -v lspci &>/dev/null; then
        if lspci 2>/dev/null | grep -qi "Intel.*Arc\|Vivid Lake"; then
            auto_detected="intel"
            log_info "Auto-detected: Intel Arc GPU"
        fi
    fi
    
    # Check for Apple Silicon
    if [ -z "$auto_detected" ] && uname -m | grep -qi "arm64\|aarch64"; then
        if sw_vers 2>/dev/null | grep -qi "macOS"; then
            auto_detected="apple"
            log_info "Auto-detected: Apple Silicon (M1/M2/M3)"
        fi
    fi
    
    # Present options to user
    echo "Please select your GPU type:"
    echo "  1) NVIDIA (CUDA) - RTX/GTX series"
    echo "  2) AMD (ROCm) - Radeon RX series"
    echo "  3) Intel (XPU) - Arc GPUs"
    echo "  4) Apple Silicon - M1/M2/M3 chips"
    echo "  5) CPU only - No GPU acceleration"
    
    if [ -n "$auto_detected" ]; then
        case "$auto_detected" in
            nvidia) echo "  → Auto-detected: Option 1 (NVIDIA)" ;;
            amd)    echo "  → Auto-detected: Option 2 (AMD)" ;;
            intel)  echo "  → Auto-detected: Option 3 (Intel)" ;;
            apple)  echo "  → Auto-detected: Option 4 (Apple Silicon)" ;;
        esac
    fi
    
    echo ""
    read -rp "Select option [1-5] (default: $auto_detected): " gpu_choice
    
    # Set default based on auto-detection
    case "$auto_detected" in
        nvidia) [ -z "$gpu_choice" ] && gpu_choice=1 ;;
        amd)    [ -z "$gpu_choice" ] && gpu_choice=2 ;;
        intel)  [ -z "$gpu_choice" ] && gpu_choice=3 ;;
        apple)  [ -z "$gpu_choice" ] && gpu_choice=4 ;;
        *)      [ -z "$gpu_choice" ] && gpu_choice=1 ;;
    esac
    
    # Ask about stable vs nightly PyTorch
    echo ""
    read -rp "Use stable PyTorch? (nightly may have better performance) [Y/n]: " stable_choice
    [[ "$stable_choice" =~ ^[Nn]$ ]] && force_stable=false || force_stable=true
    
    local pip_install_cmd=""
    
    case "$gpu_choice" in
        1)
            # NVIDIA CUDA
            log_info "Installing PyTorch for NVIDIA GPU (CUDA)..."
            if [ "$force_stable" = true ]; then
                pip_install_cmd="$python_bin -m pip install torch torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu130"
                log_info "Using stable PyTorch with CUDA 13.0"
            else
                pip_install_cmd="$python_bin -m pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu132"
                log_info "Using nightly PyTorch with CUDA 13.2 (may have better performance)"
            fi
            ;;
        2)
            # AMD ROCm
            log_info "Installing PyTorch for AMD GPU (ROCm)..."
            if [ "$force_stable" = true ]; then
                pip_install_cmd="$python_bin -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm7.2"
                log_info "Using stable PyTorch with ROCm 7.2"
            else
                pip_install_cmd="$python_bin -m pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/rocm7.2"
                log_info "Using nightly PyTorch with ROCm 7.2 (may have better performance)"
            fi
            ;;
        3)
            # Intel XPU
            log_info "Installing PyTorch for Intel Arc GPU (XPU)..."
            if [ "$force_stable" = true ]; then
                pip_install_cmd="$python_bin -m pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/xpu"
                log_info "Using stable PyTorch with XPU"
            else
                pip_install_cmd="$python_bin -m pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/xpu"
                log_info "Using nightly PyTorch with XPU (may have better performance)"
            fi
            ;;
        4)
            # Apple Silicon
            log_info "Installing PyTorch for Apple Silicon..."
            pip_install_cmd="$python_bin -m pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cpu"
            log_info "Using nightly PyTorch (recommended for Apple Silicon)"
            log_warning "For best results, see: https://developer.apple.com/metal/pytorch/"
            ;;
        5|*)
            # CPU only
            log_info "Installing PyTorch for CPU-only mode..."
            pip_install_cmd="$python_bin -m pip install torch torchvision torchaudio"
            log_warning "CPU-only mode will be significantly slower than GPU acceleration"
            ;;
    esac
    
    echo ""
    log_info "Running: $pip_install_cmd"
    echo ""
    
    # Execute the installation
    eval "$pip_install_cmd"
    
    if [ $? -eq 0 ]; then
        log_success "PyTorch installed successfully"
    else
        log_error "Failed to install PyTorch"
        echo ""
        echo "You can manually install PyTorch later using the command above."
        echo "See: https://pytorch.org/get-started/locally/"
        exit 1
    fi
}

check_dependencies() {
    local missing=()

    for cmd in git curl pyenv python3; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing[*]}"
        echo ""
        echo "Please install them using:"
        echo "  sudo dnf install git curl python3"
        echo ""
        echo "And ensure pyenv is installed. See: https://github.com/pyenv/pyenv#installation"
        exit 1
    fi

    log_success "All dependencies found"
}

get_python_version_for_comfyui() {
    local comfyui_version="$1"

    # Try to find exact match first
    if [ -n "${PYTHON_VERSION_MAP[$comfyui_version]}" ]; then
        echo "${PYTHON_VERSION_MAP[$comfyui_version]}"
        return
    fi

    # Try partial match (e.g., v0.3 matches v0.3.*)
    for key in "${!PYTHON_VERSION_MAP[@]}"; do
        if [[ "$comfyui_version" == "$key"* ]]; then
            echo "${PYTHON_VERSION_MAP[$key]}"
            return
        fi
    done

    # Default fallback
    echo "${PYTHON_VERSION_MAP[default]}"
}

get_commit_from_tag() {
    local tag="$1"

    log_info "Fetching commit hash for tag: $tag"

    # Method 1: Use git ls-remote to get the commit hash for the tag directly (most reliable)
    local commit=$(git ls-remote --tags "$COMFYUI_REPO" | grep -E "refs/tags/$tag\^?$" | awk '{print $1}')
    
    if [ -n "$commit" ]; then
        echo "$commit"
        return 0
    fi

    # Method 2: Use GitHub API to get the release SHA
    log_warning "git ls-remote failed, trying GitHub API..."
    local response=$(curl -s "https://api.github.com/repos/Comfy-Org/ComfyUI/releases/tags/$tag")

    if [ $? -eq 0 ]; then
        # Extract the 'sha' field from the release object (this is the actual commit SHA)
        local sha=$(echo "$response" | grep -o '"sha": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
        if [ -n "$sha" ] && [ "$sha" != "null" ]; then
            echo "$sha"
            return 0
        fi
    fi

    # Method 3: Shallow clone and use git rev-parse (last resort)
    log_warning "GitHub API method failed, using shallow clone fallback..."

    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    if git clone --depth 1 --branch "$tag" "$COMFYUI_REPO" . 2>/dev/null; then
        local commit=$(git rev-parse HEAD)
        cd - > /dev/null
        rm -rf "$temp_dir"
        echo "$commit"
        return 0
    fi

    cd - > /dev/null
    rm -rf "$temp_dir"

    log_error "Could not determine commit hash for tag: $tag"
    return 1
}

ensure_pyenv_version() {
    local python_ver="$1"
    local full_ver="3.${python_ver#3.}"

    # Check if pyenv has this version installed
    if ! pyenv versions | grep -q "^${full_ver}[[:space:]]*$"; then
        log_info "Python ${full_ver} not found in pyenv, installing..."

        # Install the Python version using pyenv
        if pyenv install "$full_ver" --skip-existing 2>&1; then
            log_success "Python ${full_ver} installed via pyenv"
        else
            log_error "Failed to install Python ${full_ver}"
            echo ""
            echo "Available Python versions:"
            pyenv install --list 2>/dev/null | grep "^  3\." | head -10
            exit 1
        fi
    else
        log_info "Python ${full_ver} already available in pyenv"
    fi
}

create_python_environment() {
    local version_dir="$1"
    local python_ver="$2"

    # Create directory for python environment
    local env_name="python_${python_ver}"
    local env_path="${version_dir}/${env_name}"

    if [ -d "$env_path" ]; then
        log_warning "Python environment already exists at: $env_path"
        read -p "Overwrite existing environment? (y/N): " overwrite

        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing Python environment"
            return 0
        fi

        rm -rf "$env_path"
    fi

    log_info "Creating Python ${python_ver} virtual environment..."

    # Create virtual environment using pyenv's python
    local full_ver="3.${python_ver#3.}"
    PYENV_VERSION="$full_ver" python3 -m venv "$env_path"

    if [ $? -eq 0 ]; then
        log_success "Python environment created at: $env_path"
    else
        log_error "Failed to create Python environment"
        exit 1
    fi

    # Upgrade pip, setuptools, wheel in the new environment
    log_info "Upgrading pip, setuptools, and wheel..."
    "${env_path}/bin/pip" install --upgrade pip setuptools wheel -q
}

clone_comfyui() {
    local version_dir="$1"
    local tag_or_commit="$2"

    local comfyui_path="${version_dir}/comfyui"

    if [ -d "$comfyui_path" ]; then
        log_warning "ComfyUI directory already exists at: $comfyui_path"
        read -p "Overwrite existing installation? (y/N): " overwrite

        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            log_info "Keeping existing ComfyUI installation"
            return 0
        fi

        rm -rf "$comfyui_path"
    fi

    log_info "Cloning ComfyUI at $tag_or_commit..."

    # Check if this is a commit hash (40 hex chars) or a tag/branch name
    if [[ "$tag_or_commit" =~ ^[a-f0-9]{40}$ ]]; then
        # It's a full commit hash - use fetch + checkout approach
        git init "$comfyui_path" 2>/dev/null
        cd "$comfyui_path" || exit 1
        
        git remote add origin "$COMFYUI_REPO"
        git fetch origin "$tag_or_commit" 2>/dev/null
        git checkout "$tag_or_commit" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            cd - > /dev/null
            log_success "ComfyUI cloned successfully"
            local actual_ref=$(git rev-parse --short HEAD)
            log_info "Cloned commit: $actual_ref"
        else
            cd - > /dev/null
            rm -rf "$comfyui_path"
            log_error "Failed to clone ComfyUI at $tag_or_commit"
            echo ""
            echo "Please verify the version tag exists:"
            echo "  https://github.com/Comfy-Org/ComfyUI/releases"
            exit 1
        fi
    else
        # It's a tag or branch name - use standard clone with --branch
        if git clone --depth 1 --branch "$tag_or_commit" "$COMFYUI_REPO" "$comfyui_path" 2>&1; then
            log_success "ComfyUI cloned successfully"

            # Show what we actually got
            cd "$comfyui_path" || exit 1
            local actual_ref=$(git rev-parse --short HEAD)
            cd - > /dev/null

            log_info "Cloned commit: $actual_ref"
        else
            log_error "Failed to clone ComfyUI at $tag_or_commit"
            echo ""
            echo "Please verify the version tag exists:"
            echo "  https://github.com/Comfy-Org/ComfyUI/releases"
            exit 1
        fi
    fi
}

install_requirements() {
    local comfyui_path="$1"
    local python_bin="$2"

    log_info "Installing ComfyUI requirements..."

    if [ -f "${comfyui_path}/requirements.txt" ]; then
        "$python_bin" -m pip install -r "${comfyui_path}/requirements.txt" -q

        if [ $? -eq 0 ]; then
            log_success "ComfyUI requirements installed"
        else
            log_error "Failed to install ComfyUI requirements"
            exit 1
        fi
    else
        log_warning "No requirements.txt found in ComfyUI directory"
    fi
}

install_manager() {
    local comfyui_path="$1"
    local python_bin="$2"

    # Check if manager_requirements.txt exists (built-in manager)
    if [ -f "${comfyui_path}/manager_requirements.txt" ]; then
        log_info "Installing built-in ComfyUI Manager..."

        "$python_bin" -m pip install -r "${comfyui_path}/manager_requirements.txt" -q

        if [ $? -eq 0 ]; then
            log_success "Built-in ComfyUI Manager installed"
            return 0
        else
            log_error "Failed to install built-in manager requirements"
            exit 1
        fi
    fi

    # Fall back to cloning the standalone Manager repo
    log_info "Installing standalone ComfyUI-Manager..."

    local custom_nodes_path="${comfyui_path}/custom_nodes"
    local manager_path="${custom_nodes_path}/ComfyUI-Manager"

    mkdir -p "$custom_nodes_path"

    if [ -d "$manager_path" ]; then
        log_warning "ComfyUI-Manager already exists, updating..."
        cd "$manager_path" || exit 1
        git pull origin main 2>&1 | tail -3
        cd - > /dev/null
    else
        if git clone --depth 1 "$MANAGER_REPO" "$manager_path" 2>&1; then
            log_success "ComfyUI-Manager cloned to custom_nodes/"
        else
            log_error "Failed to clone ComfyUI-Manager"
            exit 1
        fi
    fi

    # Install manager dependencies if they exist
    if [ -f "${manager_path}/requirements.txt" ]; then
        log_info "Installing Manager dependencies..."
        "$python_bin" -m pip install -r "${manager_path}/requirements.txt" -q

        if [ $? -eq 0 ]; then
            log_success "Manager dependencies installed"
        else
            log_warning "Some manager dependencies may have failed to install"
        fi
    fi
}

create_model_symlinks() {
    local version_dir="$1"

    # Always create symlink to shared models directory at root level
    local root_models="${SCRIPT_DIR}/models"
    local version_comfyui="${version_dir}/comfyui"
    local target_models="${version_comfyui}/models"

    if [ -d "$root_models" ]; then
        # Remove existing models directory or symlink if it exists
        if [ -e "$target_models" ] || [ -L "$target_models" ]; then
            log_info "Removing existing models link..."
            rm -rf "$target_models"
        fi
        
        # Create fresh symlink to shared models directory
        log_info "Creating symlink to shared models directory..."
        ln -s "$root_models" "$target_models"
        log_success "Models symlinked from: $root_models"
    else
        log_warning "Shared models directory not found at: $root_models"
        log_info "You can create it manually and symlink later if needed."
    fi
}

show_completion_summary() {
    local version_dir="$1"
    local comfyui_version="$2"
    local python_ver="$3"

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   Installation Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "Version:     ${CYAN}${comfyui_version}${NC}"
    echo -e "Python:      ${CYAN}3.${python_ver#3.}${NC}"
    echo -e "Location:    ${CYAN}${version_dir}${NC}"
    echo ""
    echo "To launch this version, use your start_comfy.sh script or:"
    echo ""
    echo -e "  cd ${version_dir}/comfyui"
    echo -e "  ${version_dir}/python_${python_ver}/bin/python3 main.py --enable-manager --enable-manager-legacy-ui"
    echo ""
}

show_help() {
    cat << EOF
ComfyUI Version Installer

Usage: $0 [OPTIONS] <VERSION>

Arguments:
  VERSION           ComfyUI version tag (e.g., v0.3.62, v0.18.0)

Options:
  --python VER      Force specific Python version (e.g., 3.12)
  --no-manager      Skip ComfyUI-Manager installation
  --list            List available versions from GitHub
  --help            Show this help message

Examples:
  $0 v0.3.62                    # Install v0.3.62 with auto-detected Python
  $0 v0.18.0 --python 3.13      # Install v0.18.0 with Python 3.13
  $0 v0.3.62 --no-manager       # Install without ComfyUI-Manager
  $0 --list                    # List available versions

EOF
}

# Fetch all releases from GitHub with pagination
fetch_all_releases() {
    local page=1
    local per_page=100
    local done=false
    
    while [ "$done" = false ]; do
        local url="https://api.github.com/repos/Comfy-Org/ComfyUI/releases?page=$page&per_page=$per_page"
        local response=$(curl -s "$url")
        
        # Check if we got any results
        if ! echo "$response" | grep -q '"tag_name"'; then
            done=true
            continue
        fi
        
        # Extract tag names from this page
        echo "$response" | grep '"tag_name"' | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/'
        
        # Check if there are more pages by looking at response length
        local count=$(echo "$response" | grep -c '"tag_name"')
        if [ "$count" -lt "$per_page" ]; then
            done=true
        else
            page=$((page + 1))
        fi
    done
}

# ============================================
# Main Script
# ============================================

main() {
    local target_version=""
    local force_python=""
    local skip_manager=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --python)
                force_python="$2"
                shift 2
                ;;
            --no-manager)
                skip_manager=true
                shift
                ;;
            --list)
                echo "Fetching ALL available versions from GitHub..."
                echo "(This may take a moment)"
                echo ""
                fetch_all_releases | sort -V | while read -r tag; do
                    echo "  $tag"
                done
                local total=$(fetch_all_releases | wc -l)
                echo ""
                echo "Total: $total versions found"
                echo "See more at: https://github.com/Comfy-Org/ComfyUI/releases"
                exit 0
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                target_version="$1"
                shift
                ;;
        esac
    done

    # Validate version argument
    if [ -z "$target_version" ]; then
        log_error "Version argument required"
        echo ""
        show_help
        exit 1
    fi

    # Add 'v' prefix if missing
    if [[ ! "$target_version" =~ ^v ]]; then
        target_version="v${target_version}"
    fi

    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}   ComfyUI Version Installer${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""

    # Step 0: Check dependencies
    check_dependencies

    # Step 1: Get commit hash from tag
    local commit_hash=$(get_commit_from_tag "$target_version")

    if [ -z "$commit_hash" ]; then
        log_error "Could not resolve version: $target_version"
        echo ""
        echo "Available recent versions:"
        curl -s "https://api.github.com/repos/Comfy-Org/ComfyUI/releases" | \
            grep '"tag_name"' | \
            sed 's/.*"tag_name": *"\([^"]*\)".*/  • \1/' | \
            head -10
        exit 1
    fi

    log_info "Resolved $target_version → commit: ${commit_hash:0:7}..."

    # Step 2: Determine Python version
    local python_ver="$force_python"

    if [ -z "$python_ver" ]; then
        python_ver=$(get_python_version_for_comfyui "$target_version")
        log_info "Auto-selected Python version: $python_ver"
    else
        log_info "Using forced Python version: $python_ver"
    fi

    # Step 3: Create version directory
    local version_dir="${VERSIONS_ROOT}/${target_version}"

    if [ -d "$version_dir" ]; then
        log_warning "Version directory already exists: $version_dir"
        read -p "Continue and potentially overwrite? (y/N): " confirm

        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    else
        mkdir -p "$version_dir"
        log_success "Created version directory: $version_dir"
    fi

    # Step 4: Ensure pyenv has the Python version
    ensure_pyenv_version "$python_ver"

    # Step 5: Create Python virtual environment
    create_python_environment "$version_dir" "$python_ver"

    local python_bin="${version_dir}/python_${python_ver}/bin/python3"

    # Step 6: Clone ComfyUI at specific commit
    clone_comfyui "$version_dir" "$commit_hash"

    # Step 7: Install PyTorch based on GPU type
    install_pytorch "$python_bin"

    # Step 8: Install requirements.txt
    install_requirements "${version_dir}/comfyui" "$python_bin"

    # Step 9: Install ComfyUI-Manager (unless skipped)
    if [ "$skip_manager" = false ]; then
        install_manager "${version_dir}/comfyui" "$python_bin"
    else
        log_info "Skipping ComfyUI-Manager installation (--no-manager)"
    fi

    # Step 10: Create model symlinks
    create_model_symlinks "$version_dir"

    # Show completion summary
    show_completion_summary "$version_dir" "$target_version" "$python_ver"
}

# Run main function
main "$@"
