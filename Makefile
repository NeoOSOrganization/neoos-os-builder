# NeoOS OS Builder -- config-driven image assembly.
#
# Orchestration lives in scripts/build.sh, not here: it clones each
# dependency (neoos-libneoos, neoos-musl, optionally
# neoos-kernel-tests-common, the selected ports) and asks neoos-kernel
# to assemble the ISO/disk images itself via its own `make iso
# disk-image` -- this repo does not reimplement ISO/FAT assembly.
#
# A TUI front-end is an open question (see the org design spec's
# "Open Questions") -- this is the config-driven mode only.
CONFIG ?= config/example.yaml

.PHONY: all clean test run
all:
	./scripts/build.sh $(CONFIG)

clean:
	rm -rf build

# Boots the just-built image headless and checks it reached the
# scheduler -- the same PASS/FAIL contract neoos-kernel's own `make
# test` uses, since the image IS a neoos-kernel build. This does NOT
# reuse build/qemu-run.sh: that script is the INTERACTIVE launcher
# (`make run`, a real graphical window, no timeout -- see
# scripts/qemu-run.sh.template) and would hang here waiting for a
# human to close the window instead of exiting on its own.
test: all
	@iso=$$(ls build/*.iso | head -1); \
	timeout 180 qemu-system-x86_64 -cpu Nehalem -boot order=d \
	    -cdrom "$$iso" \
	    -drive file=build/disk1.img,format=raw \
	    -drive file=build/disk2.img,format=raw \
	    -display none -no-reboot -serial file:build/qemu.log; \
	grep -q "NeoOS: interrupts enabled, starting scheduler" build/qemu.log || \
	    { echo "TEST FAILED: boot marker never printed"; exit 1; }
	@echo "TEST PASSED: image booted and reached the scheduler"

# The real graphical, interactive launch -- see
# scripts/qemu-run.sh.template for why it's a separate script (and
# separate from `test`, above) rather than one shared invocation.
run: all
	cd build && ./qemu-run.sh
