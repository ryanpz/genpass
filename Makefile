BUILDMODE ?= fast

.PHONY: build
build:
	zig build --release=$(BUILDMODE)

.PHONY: run
run:
	zig build run

.PHONY: test
test:
	zig build test
