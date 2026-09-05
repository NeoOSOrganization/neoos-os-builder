# NeoOS OS Builder

Interactive and config-driven OS image builder for NeoOS.

## Features

- **Interactive TUI** — Interactively select kernel options, CPU features, and ports
- **Config-driven** — Reproducible builds from YAML/JSON configuration files
- **Single output** — Produces bootable ISO + disk images + metadata + ready-to-run QEMU script

## Quick Start

```sh
# Interactive mode
neoos-builder

# Config-driven mode
neoos-builder build config.yaml

# Preview what would be built
neoos-builder preview config.yaml
```

## Output

```
build/
├── neoos-custom.iso          # Bootable ISO
├── disk1.img                 # Data disk
├── disk2.img                 # Additional storage
├── metadata.json             # Build details
├── config.yaml               # Configuration used
└── qemu-run.sh               # Ready-to-run QEMU launcher
```

Run immediately:
```sh
./build/qemu-run.sh
```

## Configuration Example

```yaml
kernel:
  version: "latest"           # or specific git tag
  cpu_features: "auto"        # or "minimal", "standard", "optimized"
  optimization_level: "O2"

ports:
  - busybox
  - 3d-ascii-viewer

iso:
  name: "neoos-custom"
  disk_size: 2G
```

## Documentation

- **Detailed usage:** See `USAGE.md`
- **Build contracts:** See https://github.com/NeoOSOrganization/neoos-kernel/blob/main/BUILD.md
- **Port template:** See https://github.com/NeoOSOrganization/neoos-busybox

## License

Same as NeoOS kernel (license TBD).

## In This Organization

- **[neoos-kernel](https://github.com/NeoOSOrganization/neoos-kernel)** — Kernel source
- **[neoos-musl](https://github.com/NeoOSOrganization/neoos-musl)** — musl libc (kernel dependency)
- **[neoos-docs](https://github.com/NeoOSOrganization/neoos-docs)** — Guides and architecture
- **[Port Examples](https://github.com/NeoOSOrganization/neoos-busybox)** — See how to structure a port
