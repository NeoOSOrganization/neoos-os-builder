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
# test` uses, since the image IS a neoos-kernel build.
test: all
	@iso=$$(ls build/*.iso | head -1); \
	name=$$(basename "$$iso" .iso); \
	(cd build && ./qemu-run.sh); \
	grep -q "NeoOS: interrupts enabled, starting scheduler" build/qemu.log || \
	    { echo "TEST FAILED: boot marker never printed"; exit 1; }
	@echo "TEST PASSED: image booted and reached the scheduler"

run: all
	cd build && ./qemu-run.sh
