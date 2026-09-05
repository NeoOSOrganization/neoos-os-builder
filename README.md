# NeoOS OS Builder

Config-driven OS image assembly for NeoOS: clones `neoos-libneoos`,
`neoos-musl`, the selected ports, and (optionally) the regression
suite, builds each, then asks `neoos-kernel` to assemble the ISO and
disk images itself via its own `make iso disk-image`.

An interactive TUI is an explicit open question (see the org design
spec's "Open Questions") and not implemented — this is the
config-driven mode only.

## Quick Start

```sh
make                          # builds config/example.yaml
make CONFIG=myconfig.yaml     # or your own config
make test                     # build, then boot headless and check it reached the scheduler
make run                      # build, then boot interactively in QEMU
```

## Output

```
build/
├── <name>.iso        # Bootable ISO (name from config's iso.name)
├── disk1.img         # Data disk
├── disk2.img         # Additional storage
├── metadata.json     # Kernel ref, ports, whether tests were included, build timestamp
└── qemu-run.sh        # Ready-to-run QEMU launcher
```

Run immediately: `./build/qemu-run.sh`

## Configuration

```yaml
kernel:
  version: "main"      # a branch, tag, or "main"

tests:
  include: false        # pull the regression suite into the image? false by default

ports:
  - busybox
  - 3d-ascii-viewer

iso:
  name: "neoos-custom-build"
```

`tests.include: true` additionally clones and builds
[neoos-kernel-tests-common](https://github.com/NeoOSOrganization/neoos-kernel-tests-common)
and adds its `build/` to the kernel's `EMBED_DIRS` — a production
image shouldn't carry the regression suite by default, but a
development or CI image can opt in.

## Documentation

- **Build conventions across the org:** https://neoosorganization.github.io/neoos-docs/docs/build-conventions
- **Porting guide:** https://neoosorganization.github.io/neoos-docs/docs/porting-guide

## License

Same as NeoOS kernel (license TBD).

## In This Organization

- **[neoos-kernel](https://github.com/NeoOSOrganization/neoos-kernel)** — Kernel source
- **[neoos-musl](https://github.com/NeoOSOrganization/neoos-musl)** — musl libc
- **[neoos-libneoos](https://github.com/NeoOSOrganization/neoos-libneoos)** — NeoOS-native libc
- **[neoos-kernel-tests-common](https://github.com/NeoOSOrganization/neoos-kernel-tests-common)** — Regression suite
- **[neoos-docs](https://github.com/NeoOSOrganization/neoos-docs)** — Guides and architecture
- **[neoos-busybox](https://github.com/NeoOSOrganization/neoos-busybox)**, **[neoos-3d-ascii-viewer](https://github.com/NeoOSOrganization/neoos-3d-ascii-viewer)** — Ports
