# 📝 ComfyEnv - Feature Roadmap & Todo List

## Planned Features

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

*Last updated: $(date +%Y-%m-%d)*
