BUILDMODE ?= fast
WORDLIST ?= ./data/wordlist.txt
GENERATED_WORDLIST_ZIGFILE ?= ./src/words.zig

.PHONY: build
build:
	zig build --release=$(BUILDMODE)

.PHONY: run
run:
	zig build run

.PHONY: test
test:
	zig build test

.PHONY: codegen-wordlist
codegen-wordlist:
	./scripts/codegen-wordlist -o $(GENERATED_WORDLIST_ZIGFILE) $(WORDLIST)
