# 🎨 ComfyUI Multi-Version Manager

<div align="center">

**A powerful bash script for managing multiple ComfyUI installations with different Python versions, GPU configurations, and custom environments.**

[![Bash](https://img.shields.io/badge/Bash-5.0+-886942?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![Python](https://img.shields.io/badge/Python-3.11%2B-blue?logo=python)](https://www.python.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

</div>

---

## ✨ Features

### 🚀 Multi-Version Installation
- **Install any ComfyUI version** - Supports all versions from v0.3.x to latest
- **Automatic Python version detection** - Smart mapping based on ComfyUI requirements
- **Custom environment names** - Name your installations meaningfully (e.g., `production.v1`, `dev-test`)
- **Version listing** - Browse all available GitHub releases with pagination support

### 🎯 GPU-Aware PyTorch Installation
- **Auto-detection** for NVIDIA, AMD, Intel Arc, and Apple Silicon GPUs
- **Interactive selection** when auto-detection fails
- **Stable vs Nightly** PyTorch options for performance tuning
- Follows official [ComfyUI documentation](https://github.com/Comfy-Org/ComfyUI) installation commands

### 📦 Environment Management
| Command | Description |
|---------|-------------|
| `--env-list` | List all installed environments with version info |
| `--env-delete NAME` | Safely remove an environment (with confirmation) |
| `--env-rename OLD NEW` | Rename/move an environment directory |
| `--env-clone SRC DST` | Clone an existing environment (uses rsync if available) |

### 🔧 Advanced Options
- **Shared models directory** - Automatic symlink to root-level models folder
- **ComfyUI-Manager support** - Built-in or standalone installation
- **Verbose output** - Real-time progress for all installations
- **Flexible naming** - Supports letters, numbers, underscores, hyphens, and dots

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

### Pyenv Installation (Required for Python version management)

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

After installation, your directory will look like:

```
comfy/
├── install_comfy.sh          # Main installer script
├── models/                   # Shared models directory (create this)
│   ├── checkpoints/
│   ├── vae/
│   └── loras/
└── comfy_versions/           # All installations stored here
    ├── v0.3.62/
    │   ├── python_3.11/      # Python virtual environment
    │   ├── comfyui/          # ComfyUI source code
    │   └── models -> ../models/  # Symlink to shared models
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

## 📝 License

This project is licensed under the MIT License - see below for details:

> Permission is hereby granted, free of charge, to any person obtaining a copy
> of this software and associated documentation files (the "Software"), to deal
> in the Software without restriction, including without limitation the rights
> to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is
> furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all
> copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
> IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
> FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
> AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
> LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
> OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
> SOFTWARE.

---

<div align="center">
  <strong>Made with ❤️ for the ComfyUI community</strong>
</div>
