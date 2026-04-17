# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2026-04-17] - Latest Updates

### Added
- **Persistent Browser Profiles**: Each environment now has its own isolated browser profile for a cleaner browsing experience
  - Automatic profile creation and management per environment
  - Separate cookies, cache, and session data for each ComfyUI instance
  - Integrated into both installation and runtime workflows
- **Port Persistence Per Environment**: Ports are now remembered per environment for consistent session restoration
  - Session module tracks port assignments across restarts
  - Ensures you always connect to the same port for a given environment
- **Multi-Instance Support**: Run multiple ComfyUI instances simultaneously on different ports!
  - `--port PORT` option to specify custom port (default: auto-select from 8188+)
  - Automatic port selection when default is in use
  - Instance tracking system with PID files for lifecycle management
  - `--list` now shows running status of all instances
  - Per-instance logs stored in `.logs/` directory
  - Cleanup stale PIDs to handle crashed sessions gracefully
- **Shared Workflows Directory**: New `_shared` subfolder inside `workflows/` for globally accessible workflows
  - Create `workflows/_shared/` to store workflows available from ALL environments
  - Automatically linked as `shared/` subfolder inside each environment's workflow folder
  - Perfect for utility nodes, common templates, and frequently-used workflows
- **Custom ComfyUI Settings**: Apply your custom `comfy.settings.json` automatically during installation
  - Place your settings file in `configs/comfy.settings.json`
  - Automatically copied to every new environment's `comfyui/user/default/` folder
  - Customize UI preferences, API settings, and other defaults across all installations
- **Symlink Repair Tool**: New `--fix-symlinks` option that automatically detects and repairs broken symlinks across all environments, including models, workflows, inputs, outputs directories
- **Enhanced Rename Functionality**: The rename environment feature now handles not just the environment directory but also associated workflows, inputs, and outputs folders - ensuring complete renaming without orphaned references
- **Centralized I/O Management**: New symlink management system for input/output folders, allowing centralized storage of images and files that can be shared across all environments
- **Workflow Symlink Support**: Added workflow folder symlink management with automatic cloning support when duplicating environments
- **Release Date Display**: The `--list` output now shows release dates alongside version numbers, helping users identify the age and stability of each ComfyUI version
- **Environment Metadata Display**: Environment list and start menu now display creation date and last edit date for each environment, making it easier to track when setups were created or modified
- **Reserved Names Validation**: Added validation to prevent creating environments with reserved internal names like `_shared`

### Changed
- **Terminology Update**: Renamed "version" terminology to "environment" throughout the script for clarity - installations are now referred to as "environments" to better reflect that they can have custom names beyond just version numbers
- **Directory Rename**: The `comfy_versions/` directory has been renamed to `environments/` to align with the new terminology and provide clearer organization

### Fixed
- **Server Cleanup Tracking**: Ensured proper cleanup tracking for server instances to prevent resource leaks and orphaned processes

### Changed
- **Log File Naming**: Simplified log file naming convention for easier identification and management

### Improved
- **Version Detection Reliability**: ComfyUI version detection now reads directly from `comfyui_version.py` file instead of relying on git tags, providing more accurate and reliable version identification even in detached HEAD states or shallow clones

---

## [2026-04-16] - Major Feature Release

### Added
- **Shared Configs Folder**: New `configs/` folder that allows you to import your ComfyUI settings (`comfy.settings.json`) to all environments automatically. Simply place your existing config file in the root `configs/` folder and it will be available across all installations
- **Symlink Repair Tool**: New `--fix-symlinks` option that automatically detects and repairs broken symlinks across all environments, including models, workflows, inputs, and outputs directories
- **Enhanced Rename Functionality**: The rename environment feature now handles not just the environment directory but also associated workflows, inputs, and outputs folders - ensuring complete renaming without orphaned references
- **Centralized I/O Management**: New symlink management system for input/output folders, allowing centralized storage of images and files that can be shared across all environments
- **Workflow Symlink Support**: Added workflow folder symlink management with automatic cloning support when duplicating environments
- **Release Date Display**: The `--list` output now shows release dates alongside version numbers, helping users identify the age and stability of each ComfyUI version
- **Environment Metadata Display**: Environment list and start menu now display creation date and last edit date for each environment, making it easier to track when setups were created or modified

### Changed
- **Terminology Update**: Renamed "version" terminology to "environment" throughout the script for clarity - installations are now referred to as "environments" to better reflect that they can have custom names beyond just version numbers
- **Directory Rename**: The `comfy_versions/` directory has been renamed to `environments/` to align with the new terminology and provide clearer organization

### Improved
- **Version Detection Reliability**: ComfyUI version detection now reads directly from `comfyui_version.py` file instead of relying on git tags, providing more accurate and reliable version identification even in detached HEAD states or shallow clones

---

## [2026-04-09] - Foundation Release

### Added
- **Comprehensive README Documentation**: Complete documentation with feature overview, prerequisites, usage guide, GPU configuration examples, troubleshooting section, and directory structure visualization
- **Environment Management System**: Full suite of environment management commands:
  - `--env-list`: List all installed environments with version and Python information
  - `--env-delete`: Safely remove environments with confirmation prompts
  - `--env-rename`: Rename or move environment directories
  - `--env-clone`: Quickly duplicate existing environments
- **Flexible Naming Support**: Environment names now support letters, numbers, underscores, hyphens, and dots (e.g., `production.v1`, `dev-test-env`)
- **Verbose Installation Logs**: Detailed progress output showing exactly what's happening during installation
- **TODO.md**: Project roadmap and feature tracking document
- **MIT License**: Added LICENSE.md with MIT open source license

### Changed
- **Project Rename**: Renamed project for better branding and discoverability
- **Code Cleanup**: Removed old scripts and consolidated functionality into main installer

### Improved
- **Python Version Handling**: Smart Python version selection based on ComfyUI version requirements
- **GPU Auto-Detection**: Automatic detection of NVIDIA, AMD, Intel Arc, and Apple Silicon GPUs
- **Shared Models Architecture**: Single central models folder shared across all installations to save disk space

---

## Legend

| Symbol | Meaning |
|--------|---------|
| 🎉 | New features |
| 🔧 | Improvements and optimizations |
| 🐛 | Bug fixes |
| ⚡ | Performance improvements |
| 📝 | Documentation updates |
| 🔨 | Refactoring and code quality |

---

## Notes

- **Backward Compatibility**: The rename from "version" to "environment" is purely terminological - all existing functionality remains the same
- **Migration**: Existing `comfy_versions/` directories should be renamed to `environments/` for consistency with the new terminology
- **Symlink Management**: The new symlink features require read/write permissions on the project root directory

---

## How to Contribute

When making changes, please update this CHANGELOG.md with:
1. The type of change (Added, Changed, Deprecated, Removed, Fixed, Security)
2. A clear description of what changed
3. Any breaking changes or migration notes
4. References to related issues or pull requests if applicable

---

*Generated on 2026-04-17*
