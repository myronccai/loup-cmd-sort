# Build, check and test commands for this Loup command-line application.
#
# On Linux x86-64 `loup` is the self-hosted driver and `loup-bootstrap` is
# Stage0; `check` and `test` need Stage0 there. On macOS, Windows and Linux
# arm64 both names run Stage0, so these targets work unchanged.

APP            ?= sort
LOUP           ?= loup
LOUP_BOOTSTRAP ?= loup-bootstrap
BUILD_DIR      ?= build
BIN            := $(BUILD_DIR)/$(APP)
SOURCES        := package.lppkg $(shell find source -name '*.loup')
ARGS           ?=
TEST_ARGS      ?=

.PHONY: all run check test build e2e ci clean

all: build

# Run from source, e.g. `make run ARGS="-t: -k3,3n /etc/passwd"`, with
# Stage0's interpreter: the self-hosted `loup run` of Loup 1.26.0 silently
# writes nothing for an -o file of about 26 KB or more (writeBytes).
run:
	$(LOUP_BOOTSTRAP) run source/main.loup -- $(ARGS)

# Type-check source/main.loup and every module it imports.
check:
	$(LOUP_BOOTSTRAP) check --no-color

# Tests import project modules by their path under source/ (`from cli.args
# import (...)`), the same way the sources do, so source/ goes on LOUPPATH.
# Narrow the run with TEST_ARGS, e.g. `make test TEST_ARGS="--filter value"`.
# --no-parallel: Stage0's parallel test threads fail at random with an empty
# `RuntimeError:` in Loup 1.26.0, and `parallel = false` in package.lppkg is
# not honoured.
test:
	LOUPPATH=source$${LOUPPATH:+:$$LOUPPATH} $(LOUP_BOOTSTRAP) test --no-parallel $(TEST_ARGS)

# Native executable (needs clang). Windows writes $(BIN).exe.
build: $(BIN)

$(BIN): $(SOURCES)
	@mkdir -p $(BUILD_DIR)
	$(LOUP) build --target native -o $@

# End-to-end tests: run the built binary and compare its output and exit
# status with the expected ones.
e2e: $(BIN)
	bash tests/e2e.sh $(BIN)

# Everything CI runs, ending with a smoke test of the built binary.
ci: check test build e2e
	$(BIN) --version

clean:
	rm -rf $(BUILD_DIR) .temp .loup-cache
