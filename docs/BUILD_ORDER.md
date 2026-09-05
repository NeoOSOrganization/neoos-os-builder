# NeoOS Build Order

## Full Pipeline

```
┌────────────────────────────────────────────────┐
│ 1. neoos-kernel (git repository)              │
│    └─ Provides: kernel + syscall interface    │
│    └─ Located: ../neoos-kernel                │
└────────────────────────────────────────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│ 2. neoos-musl (git repository)                │
│    └─ Provides: libc.a + headers              │
│    └─ Located: ../neoos-musl                  │
│    └─ Consumes: kernel shim from neoos-kernel│
└────────────────────────────────────────────────┘
                    ↓
        ┌───────────┴──────────────┐
        ↓                          ↓
┌──────────────────────┐  ┌──────────────────────────┐
│ 3. Port Repositories │  │ 3. Port Repositories     │
│ (parallel)           │  │ (parallel)               │
│                      │  │                          │
│ neoos-busybox        │  │ neoos-3d-ascii-viewer    │
│ └─ Produces:         │  │ └─ Produces:             │
│   busybox.nex        │  │   3d-ascii-viewer.nex    │
│ └─ Located:          │  │ └─ Located:              │
│   ../neoos-busybox   │  │   ../neoos-3d-ascii-... │
└──────────────────────┘  └──────────────────────────┘
        ↓                          ↓
        └───────────┬──────────────┘
                    ↓
┌────────────────────────────────────────────────┐
│ 4. neoos-os-builder                           │
│    Input: kernel + musl + ports               │
│    Output: bootable ISO + disk image          │
│    Located: ../neoos-os-builder               │
└────────────────────────────────────────────────┘
```

## Build Command Sequence

### Step 1: Build kernel and toolchain
```bash
cd neoos-kernel
./toolchain/build.sh
export PATH=$(pwd)/toolchain/x86_64-elf/bin:$PATH
```

### Step 2: Build musl
```bash
cd ../neoos-musl
make
# Output: build-output/lib/libc.a + headers
```

### Step 3: Build ports (parallel)
```bash
# Terminal 1
cd ../neoos-busybox
make MUSL_DIR=../neoos-musl/build-output

# Terminal 2
cd ../neoos-3d-ascii-viewer
make MUSL_DIR=../neoos-musl/build-output
```

### Step 4: Assemble OS image
```bash
cd ../neoos-os-builder
make \
  KERNEL_DIR=../neoos-kernel \
  MUSL_DIR=../neoos-musl/build-output \
  BUSYBOX_DIR=../neoos-busybox/build \
  VIEWER_DIR=../neoos-3d-ascii-viewer/build
```

### Step 5: Boot in QEMU
```bash
./qemu-run.sh
```

## Dependency Validation

Before building each layer, validate dependencies:

### Kernel
```bash
cd neoos-kernel
ls -l toolchain/x86_64-elf/bin/gcc  # Toolchain built?
```

### Musl
```bash
cd ../neoos-musl
ls -l ../neoos-kernel/third_party/shim/*.h  # Shim exists?
ls -lh build-output/lib/libc.a  # musl built?
```

### Ports
```bash
cd ../neoos-busybox
ls -lh ../neoos-musl/build-output/lib/libc.a  # musl available?
make smoke-test  # Binary valid?
```

### OS Builder
```bash
cd ../neoos-os-builder
[ -f ../neoos-kernel/build/neoos.bin ] || echo "Kernel not built"
[ -f ../neoos-musl/build-output/lib/libc.a ] || echo "musl not built"
ls ../neoos-busybox/build/*.nex || echo "Ports not built"
```

## Parallel vs Sequential

### Parallelizable
- Multiple ports can build at the same time (they only depend on musl)
- Example: build BusyBox and 3D viewer simultaneously

### Sequential
1. Kernel → musl (musl needs kernel shim)
2. musl → ports (ports need musl)
3. ports → OS builder (builder needs kernel + ports)

## Troubleshooting Build Order

### "undefined reference" in port build
- musl not built: Run `cd ../neoos-musl && make`

### "Kernel shim not found"
- Kernel not cloned: `git clone https://github.com/NeoOSOrganization/neoos-kernel ../neoos-kernel`

### "x86_64-elf-gcc not found"
- Toolchain not built: `cd ../neoos-kernel && ./toolchain/build.sh`

### OS builder errors
- Verify all dependencies above exist and are recent
- Check file paths match your directory layout
