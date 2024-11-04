BUILDMODE ?= fast

.PHONY: build
build:
	zig build --release=$(BUILDMODE)
