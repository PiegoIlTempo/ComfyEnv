# 🎨 ComfyUI Multi-Version Manager

<div align="center">

**Easily manage multiple ComfyUI installations with different versions, Python setups, and GPU configurations - all from one simple script.**

[![Bash](https://img.shields.io/badge/Bash-5.0+-886942?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Python-3.11%2B-blue?logo=python)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

</div>

---

## ✨ Features

### 📂 Shared Models Folder
- **One central location for all your models** - Every installation automatically connects to a single `models/` folder at the root level
- **No duplicate downloads** - Download each model once and it's available across all your setups
- **Saves disk space** - No need to store multiple copies of the same checkpoints, LoRAs, VAEs, etc.
- **Always accessible** - Your models stay with you even when you create or delete installations

### 🚀 Multi-Version Installation
- **Install any ComfyUI version** - Supports all versions from v0.3.x to latest
- **Automatic Python setup** - Smart selection based on what your version needs
- **Custom names for your setups** - Give them meaningful names like `production.v1` or `dev-test`
- **Browse available versions** - See all GitHub releases

### 🎯 GPU-Aware Setup
- **Auto-detects your graphics card** - Works with NVIDIA, AMD, Intel Arc, and Apple Silicon
- **Stable or experimental options** - Choose between reliable or cutting-edge performance
- Follows official [ComfyUI documentation](https://github.com/Comfy-Org/ComfyUI) installation commands

### 📦 Environment Management
| Command | Description |
|---------|-------------|
| `--env-list` | See all your installed setups with version info |
| `--env-delete NAME` | Safely remove a setup (asks for confirmation first) |
| `--env-rename OLD NEW` | Rename or move a setup directory |
| `--env-clone SRC DST` | Duplicate an existing setup quickly |

### 🔧 Additional Features
- **ComfyUI-Manager support** - Installed automatically by default
- **Detailed progress output** - See exactly what's happening during installation
- **Flexible naming** - Use letters, numbers, underscores, hyphens, and dots in names

---

### 💡 Pro Tip: Keep Your Workflows Safe!

**Store your workflow files outside the `comfy_versions/` folder!** This way:
- ✅ You can use the same workflows across different setups
- ✅ They won't disappear if you delete or reinstall a setup
- ✅ Easy to back up and share with others

A good place is right next to the script, like `workflows/`

---

## 📋 Prerequisites

### Required Software
```bash
# On Fedora/RHEL/CentOS:
sudo dnf install git curl python3

# On Ubuntu/Debian:
sudo apt install git curl python3

# On Arch Linux:
sudo pacman -S git curl python
```

### Pyenv Installation (Needed for managing Python versions)

**Using pyenv-installer:**
```bash
curl https://pyenv.run | bash
```

**Manual installation:**
```bash
git clone https://github.com/pyenv/pyenv.git ~/.pyenv

# Add to ~/.bashrc or ~/.zshrc:
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
```

**Verify installation:**
```bash
pyenv --version  # Should output version number
```

---

## 🚀 Quick Start

### Install Latest ComfyUI (Auto-Detected Python)
```bash
./install_comfy.sh v0.3.62
```

### Install with Custom Name
```bash
./install_comfy.sh v0.18.0 --name my-production-env
```

### List All Available Versions
```bash
./install_comfy.sh --list
```

---

## 📖 Usage Guide

### Installation Commands

#### Basic Installation
```bash
# Install specific version with auto-detected Python
./install_comfy.sh v0.3.62

# Force specific Python version
./install_comfy.sh v0.18.0 --python 3.13

# Skip ComfyUI-Manager installation
./install_comfy.sh v0.3.62 --no-manager
```

#### Named Environments
```bash
# Create environment with custom name
./install_comfy.sh v0.3.62 --name production.v1

# Valid characters: a-z, A-Z, 0-9, _, -, .
./install_comfy.sh v0.18.0 --name dev-test-env
```

### Environment Management Commands

#### List All Environments
```bash
./install_comfy.sh --env-list

# Output:
# NAME                         VERSION      PYTHON             PATH
# ----                         -------      ------             ----
# v0.3.62                      v0.3.62      python_3.11        /path/to/comfy_versions/v0.3.62/
# production.v1                v0.18.0      python_3.13        /path/to/comfy_versions/production.v1/
```

#### Delete Environment
```bash
./install_comfy.sh --env-delete old-environment-name
```

#### Rename Environment
```bash
./install_comfy.sh --env-rename old-name new-name
```

#### Clone Environment
```bash
# Creates a complete copy (faster than fresh install)
./install_comfy.sh --env-clone source-env target-env
```

### Help & Information
```bash
./install_comfy.sh --help
```

---

## 🗂️ Directory Structure

After installation, your folder will look like this:

```
comfy/
├── install_comfy.sh          # Main installer script
├── models/                   # ⭐ Shared models - all setups use this one!
│   ├── checkpoints/
│   ├── vae/
│   └── loras/
├── workflows/                # 💡 Keep your workflow files here (recommended)
└── comfy_versions/           # All installations stored here
    ├── v0.3.62/
    │   ├── python_3.11/      # Python setup
    │   ├── comfyui/          # ComfyUI source code
    │   └── models -> ../models/  # Points to shared models folder
    └── production.v1/
        ├── python_3.13/
        ├── comfyui/
        └── models -> ../models/
```

---

## 🎯 GPU Configuration Examples

### NVIDIA GPU (CUDA)
```bash
./install_comfy.sh v0.3.62
# Select: 1) NVIDIA (CUDA)
# Choose stable or nightly PyTorch when prompted
```

**PyTorch versions:**
- **Stable**: CUDA 13.0 - Production-ready
- **Nightly**: CUDA 13.2 - Latest features, may have better performance

### AMD GPU (ROCm)
```bash
./install_comfy.sh v0.3.62
# Select: 2) AMD (ROCm)
```

**Note:** Ensure ROCm drivers are installed on your system.

### Intel Arc GPU (XPU)
```bash
./install_comfy.sh v0.3.62
# Select: 3) Intel (XPU)
```

### Apple Silicon (M1/M2/M3)
```bash
./install_comfy.sh v0.3.62
# Select: 4) Apple Silicon
```

**Note:** Uses nightly PyTorch for best Metal performance.

---

## 🔧 Troubleshooting

### Common Issues

#### "pyenv command not found"
```bash
# Add to ~/.bashrc or ~/.zshrc:
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Reload shell:
source ~/.bashrc  # or source ~/.zshrc
```

#### Python version not found in pyenv
```bash
# List available versions:
pyenv install --list | grep "^  3."

# Install specific version:
pyenv install 3.13.0
```

#### PyTorch installation fails
- **NVIDIA**: Ensure CUDA drivers are up to date
- **AMD**: Verify ROCm is properly installed
- Try switching between stable/nightly PyTorch versions

#### "Environment already exists" error
```bash
# List existing environments:
./install_comfy.sh --env-list

# Delete if needed:
./install_comfy.sh --env-delete conflicting-name
```

---
## 📚 Resources

- **[ComfyUI Official Repository](https://github.com/Comfy-Org/ComfyUI)** - Main project
- **[PyTorch Installation Guide](https://pytorch.org/get-started/locally/)** - GPU-specific builds
- **[ComfyUI Documentation](https://comfyanonymous.github.io/ComfyUI_examples/)** - Examples and tutorials
- **[Pyenv Documentation](https://github.com/pyenv/pyenv#readme)** - Python version manager

---

## 🙏 Support & Attribution

### Vibecoded With
<div align="center">
  <a href="https://huggingface.co/Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF" target="_blank">
    <img src="https://img.shields.io/badge/vibecoded%20with-Qwen3.5%2027B-orange?style=for-the-badge&logo=huggingface" alt="Vibecoded with Qwen3.5-27B">
  </a>
</div>

This project was vibecoded with: **[Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF](https://huggingface.co/Jackrong/Qwen3.5-27B-Claude-4.6-Opus-Reasoning-Distilled-v2-GGUF)**

### Support Development
<div align="center">
  <a href="https://ko-fi.com/piegoiltempo" target="_blank">
    <img src="https://storage.ko-fi.com/cdn/kofi1.png?v=3" alt="Buy Me a Coffee at ko-fi.com" style="height: 36px; width: auto; border-radius: 5px;">
  </a>
</div>

<p align="center">If this project helped you, consider buying me a coffee!</p>

---

<div align="center">
  <strong>Made with ❤️ for the ComfyUI community</strong>
</div>
