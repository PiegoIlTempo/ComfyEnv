# 📝 ComfyEnv - Feature Roadmap & Todo List

## Planned Features

### 1. Symlink for Internal Workflow Folders ✅
- **Goal**: Create symlinks from each ComfyUI version's internal `workflows/` folder to a central location
- **Benefit**: Workflows remain accessible even if you delete/rename environments
- **Implementation**: 
  - Add option during install: `--workflow-dir PATH`
  - Default: `./workflows/<env-name>/`
  - Create symlink inside each ComfyUI instance pointing to this location

---

### 2. Symlink for Outputs and Inputs Folders ✅
- **Goal**: Centralize outputs/inputs across all environments
- **Benefit**: 
  - Easy access to generated images from any version
  - Share input images between different setups
  - Prevents clutter in each environment folder
- **Implementation**:
  - Add options: `--output-dir PATH`, `--input-dir PATH`
  - Default: `./outputs/<env-name>/` and `./inputs/<env-name>/`
  - Create symlinks inside ComfyUI instances
- **Note**: May need to update ComfyUI config files to point to these locations

---

### 3. Global Default ComfyUI Settings for New Environments ✅
- **Goal**: Apply custom ComfyUI settings automatically when creating new environments
- **Benefit**: 
  - Pre-configure UI preferences, API settings, performance options
  - Consistent setup across all installations
  - Save time on repetitive configuration
- **Implementation**:
  - Create `./default_comfy_settings.json` template file
  - Copy to each new environment's `user_data/` folder during install
  - Can include:
    ```json
    {
      "Comfy.Devices": {"cpu": false, "cuda": true},
      "ComfyUI.frontend.version": "latest",
      "ComfyUI.extra_model_paths_string": "..."
    }
    ```
  - Add `--settings-file PATH` option to override per-installation

---

## Future Ideas (Not Yet Planned)

- [ ] Batch install multiple versions at once
- [ ] Update command to upgrade specific environments
- [ ] Export/import environment configurations
- [ ] GUI interface?
- [ ] Integration with ComfyUI custom node managers

---

*Last updated: $(date +%Y-%m-%d)*
