# Gerbil LevelDB Makefile

.PHONY: build clean test functional-test

# Default target
all: build

# Build the library
build:
	./build.ss

# Clean build artifacts
clean:
	rm -rf .gerbil

# Run all tests (functional test covers everything)
test: functional-test

# Run functional integration test
functional-test: build
	@echo "=== Running Functional Test ==="
	GERBIL_LOADPATH=.gerbil/lib gxi test/functional-test.ss

# Install to GERBIL_PATH
install: build
	gerbil pkg install .
