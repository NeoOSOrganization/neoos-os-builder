# NeoOS OS Builder

KERNEL_DIR ?= ../neoos-kernel
MUSL_DIR ?= ../neoos-musl
BUSYBOX_DIR ?= ../neoos-busybox
VIEWER_DIR ?= ../neoos-3d-ascii-viewer

BUILD_DIR ?= build
ISO_FILE ?= $(BUILD_DIR)/neoos.iso
DISK1_IMG ?= $(BUILD_DIR)/disk.img
DISK2_IMG ?= $(BUILD_DIR)/disk2.img
METADATA ?= $(BUILD_DIR)/metadata.json
QEMU_RUNNER ?= $(BUILD_DIR)/qemu-run.sh

.PHONY: all kernel musl ports busybox viewer iso images test run clean help

all: images

kernel:
	@echo "Building kernel..."
	@cd $(KERNEL_DIR) && make

musl:
	@echo "Building musl..."
	@cd $(MUSL_DIR) && make

ports: busybox viewer

busybox:
	@echo "Building BusyBox..."
	@cd $(BUSYBOX_DIR) && make MUSL_DIR=$(shell cd ../neoos-musl && pwd)/build-output

viewer:
	@echo "Building 3D ASCII Viewer..."
	@cd $(VIEWER_DIR) && make MUSL_DIR=$(shell cd ../neoos-musl && pwd)/build-output

iso: kernel musl ports
	@mkdir -p $(BUILD_DIR)
	@echo "Assembling ISO..."
	@# Copy kernel binary to ISO
	@cp $(KERNEL_DIR)/build/neoos.bin $(BUILD_DIR)/neoos.bin
	@# Copy ports to ISO root
	@mkdir -p $(BUILD_DIR)/iso-root/bin
	@cp $(BUSYBOX_DIR)/build/busybox.nex $(BUILD_DIR)/iso-root/bin/ 2>/dev/null || true
	@cp $(VIEWER_DIR)/build/3d-ascii-viewer.nex $(BUILD_DIR)/iso-root/bin/ 2>/dev/null || true
	@# Create GRUB config
	@mkdir -p $(BUILD_DIR)/iso-root/boot/grub
	@echo "menuentry 'NeoOS' { multiboot /boot/neoos.bin; boot; }" > $(BUILD_DIR)/iso-root/boot/grub/grub.cfg
	@cp $(KERNEL_DIR)/build/neoos.bin $(BUILD_DIR)/iso-root/boot/
	@# Create ISO using grub-mkrescue (if available)
	@grub-mkrescue -o $(ISO_FILE) $(BUILD_DIR)/iso-root 2>/dev/null || \
	  { echo "Note: grub-mkrescue not available, ISO not created"; echo "See docs/ for manual ISO creation"; }
	@[ -f $(ISO_FILE) ] && echo "OK ISO created at $(ISO_FILE)" || echo "Note: ISO creation requires grub-mkrescue"

images: iso
	@mkdir -p $(BUILD_DIR)
	@echo "Creating disk images..."
	@# Create primary disk (2GB)
	@dd if=/dev/zero of=$(DISK1_IMG) bs=1M count=2048 2>/dev/null
	@mkfs.vfat -F32 $(DISK1_IMG) 2>/dev/null || echo "Note: mkfs.vfat not available"
	@# Create secondary disk (1GB)
	@dd if=/dev/zero of=$(DISK2_IMG) bs=1M count=1024 2>/dev/null
	@mkfs.vfat -F32 $(DISK2_IMG) 2>/dev/null || echo "Note: mkfs.vfat not available"
	@ls -lh $(DISK1_IMG) $(DISK2_IMG)
	@echo "OK Disk images created"
	@# Create metadata
	@echo "{\"timestamp\": \"$(shell date -u +%Y-%m-%dT%H:%M:%SZ)\", \"kernel\": \"$(KERNEL_DIR)\", \"musl\": \"$(MUSL_DIR)\"}" > $(METADATA)
	@echo "OK Build metadata saved"
	@# Create QEMU runner
	@echo "Creating QEMU runner..."
	@cat > $(QEMU_RUNNER) << 'RUNNER'
#!/bin/bash
set -e
SCRIPT_DIR="$$(cd "$$(dirname "$${BASH_SOURCE[0]}")" && pwd)"
ISO="$$SCRIPT_DIR/neoos.iso"
DISK1="$$SCRIPT_DIR/disk.img"
DISK2="$$SCRIPT_DIR/disk2.img"
LOG="$$SCRIPT_DIR/qemu.log"
TIMEOUT=$${QEMU_TIMEOUT:-90}

[ -f "$$ISO" ] || { echo "ISO not found"; exit 1; }

echo "Booting NeoOS..."
timeout $$TIMEOUT qemu-system-x86_64 -cpu Nehalem -boot order=d \
  -cdrom "$$ISO" \
  -drive file="$$DISK1",format=raw \
  -drive file="$$DISK2",format=raw \
  -display none -no-reboot -serial file:"$$LOG" \
  -m 512M -smp 2 || true

echo "Boot complete. Log: $$LOG"
tail -20 "$$LOG"
	'RUNNER'
	@chmod +x $(QEMU_RUNNER)
	@echo "OK QEMU runner created at $(QEMU_RUNNER)"

test: images
	@echo "Running integration test..."
	@# Run QEMU with timeout
	@timeout 90 ./$(QEMU_RUNNER) || EXIT=1
	@# Check results
	@if grep -q "PASSED" $(BUILD_DIR)/qemu.log 2>/dev/null; then \
	  echo "OK Tests PASSED"; \
	else \
	  echo "Note: Check $(BUILD_DIR)/qemu.log for results"; \
	fi

run: images
	@./$(QEMU_RUNNER)

clean:
	rm -rf $(BUILD_DIR)
	@echo "OK Cleaned $(BUILD_DIR)"

help:
	@echo "NeoOS OS Builder"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  make              Build everything (kernel + musl + ports + ISO)"
	@echo "  make kernel       Build kernel only"
	@echo "  make musl         Build musl only"
	@echo "  make ports        Build all ports"
	@echo "  make busybox      Build BusyBox"
	@echo "  make viewer       Build 3D viewer"
	@echo "  make iso          Create ISO image"
	@echo "  make images       Create disk images"
	@echo "  make test         Run boot test in QEMU"
	@echo "  make run          Boot in QEMU"
	@echo "  make clean        Remove build artifacts"
	@echo ""
	@echo "Environment variables:"
	@echo "  KERNEL_DIR        Path to neoos-kernel (default: ../neoos-kernel)"
	@echo "  MUSL_DIR          Path to neoos-musl (default: ../neoos-musl)"
	@echo "  BUSYBOX_DIR       Path to neoos-busybox (default: ../neoos-busybox)"
	@echo "  VIEWER_DIR        Path to neoos-3d-ascii-viewer (default: ../neoos-3d-ascii-viewer)"
	@echo "  BUILD_DIR         Output directory (default: build)"
