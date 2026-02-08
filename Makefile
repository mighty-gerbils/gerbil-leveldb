# Gerbil LevelDB Makefile

.PHONY: build clean test unit-test functional-test

# Default target
all: build

# Build the library
build:
	./build.ss

# Clean build artifacts
clean:
	rm -rf .gerbil

# Run all tests
test: unit-test functional-test

# Run unit tests
unit-test: build
	@echo "=== Running Unit Tests ==="
	GERBIL_LOADPATH=.gerbil/lib gxi test/run-unit-test.ss

# Run functional integration test
functional-test: build
	@echo "=== Running Functional Test ==="
	GERBIL_LOADPATH=.gerbil/lib gxi test/functional-test.ss

# Install to GERBIL_PATH
install: build
	@GERBIL_PATH=$${GERBIL_PATH:-$$HOME/.gerbil}; \
	echo "Installing to $$GERBIL_PATH/lib ..."; \
	cp -r .gerbil/lib/clan "$$GERBIL_PATH/lib/" && \
	cp -r .gerbil/lib/static/. "$$GERBIL_PATH/lib/static/" && \
	echo "Done."
