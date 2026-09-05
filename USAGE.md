# NeoOS OS Builder — Usage Guide

## Installation

```bash
git clone https://github.com/NeoOSOrganization/neoos-os-builder
cd neoos-os-builder
# Full installation steps in Phase 4
```

## Interactive Mode (TUI)

```bash
neoos-builder
```

Walk through:
1. Select kernel version (shows available tags, default: latest)
2. Choose CPU features (shows auto-detected, or pick manually)
3. Select optimization level (O0–O3)
4. Choose ports to include (shows available, checkboxes)
5. Review build summary
6. Confirm or save config for later

Output appears in `build/`.

## Config-Driven Mode

Create a config file (`config.yaml`):

```yaml
kernel:
  version: "v1.0.0"
  cpu_features: "avx2 sse4_2"
  optimization_level: "O2"

ports:
  - busybox
  - 3d-ascii-viewer

iso:
  name: "neoos-production"
  disk_size: 2G
```

Build:

```bash
neoos-builder build config.yaml
# Output in build/
```

Reproducible builds: same config = same ISO.

## QEMU Runner

After build, run the generated script:

```bash
cd build
./qemu-run.sh
# Boots the ISO in QEMU headless, logs to qemu.log
```

Or modify the script for custom QEMU flags:

```bash
./qemu-run.sh -display gtk   # Show GUI
./qemu-run.sh -smp 4          # 4 CPUs (doesn't work without modifying script)
```

## Build Metadata

After build, check what was included:

```bash
cat build/metadata.json
# Shows kernel version, ports, CPU features, timestamps
```

## Troubleshooting

**"neoos-builder: command not found"** → Make sure you're in the repo directory or install the builder globally (Phase 4).

**Build hangs** → Check disk space. Large ports can take time. Add `-v` for verbose output.

**ISO won't boot** → Check `qemu.log` for errors. Verify selected ports are compatible with kernel version.

---

**See also:** Build contracts at https://github.com/NeoOSOrganization/neoos-kernel/blob/main/BUILD.md
