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

### 4. Add Release Date to Version List ✅
- **Goal**: Show when each ComfyUI version was released in `--list` output
- **Benefit**: Helps users choose versions based on recency/stability
- **Implementation**:
  - Fetch release date from GitHub API alongside version tags
  - Add column to `--list` output: `VERSION | RELEASE DATE`
  - Example:
    ```
    VERSION      RELEASE DATE   DOWNLOADS
    v0.3.62      2024-12-15     1,234
    v0.18.0      2024-06-20     5,678
    ```

---

### 5. Run Multiple ComfyUI Instances on Different Ports ✅
- **Goal**: Start multiple ComfyUI environments simultaneously on different ports
- **Benefit**:
  - Compare versions side-by-side in browser
  - Test workflows across different setups at once
  - No need to stop/start between switching versions
- **Implementation**:
  - Add `--port PORT` option to start script
  - Auto-increment port if not specified (default: 8188, then 8189, 8190...)
  - Track running instances with PID files
  - Add `--list-running` to see active instances
  - Example:
    ```bash
    ./start_comfy.sh v0.3.62 --port 8188
    ./start_comfy.sh v0.18.0 --port 8189
    ```

---

## Future Ideas (Not Yet Planned)

- [ ] Batch install multiple versions at once
- [ ] Update command to upgrade specific environments
- [ ] Export/import environment configurations
- [ ] GUI interface?
- [ ] Integration with ComfyUI custom node managers

---

*Last updated: $(date +%Y-%m-%d)*
