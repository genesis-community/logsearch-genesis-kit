# Makefile for Logsearch Genesis Kit

.PHONY: test test-quick build clean spec-check fmt

# Run all tests
test:
	cd spec && ginkgo -r .

# Run tests with verbose output
test-verbose:
	cd spec && ginkgo -r -v .

# Run spec check (CI script)
spec-check:
	REPO_ROOT=$(PWD) ./ci/scripts/spec-check

# Build the kit
build:
	genesis compile-kit --name logsearch --version $(shell yq .version kit.yml) .

# Build kit with specific version
build-version:
	@if [ -z "$(VERSION)" ]; then echo "Usage: make build-version VERSION=x.y.z"; exit 1; fi
	genesis compile-kit --name logsearch --version $(VERSION) .

# Clean build artifacts
clean:
	rm -f logsearch-*.tar.gz

# Format Go code
fmt:
	cd spec && go fmt ./...

# Tidy Go modules
mod-tidy:
	cd spec && go mod tidy

# Run deployment tests
test-deployment:
	REPO_ROOT=$(PWD) ./ci/scripts/test-deployment

# Validate kit structure
validate:
	@echo "Validating kit structure..."
	@test -f kit.yml || (echo "Missing kit.yml" && exit 1)
	@test -d hooks || (echo "Missing hooks directory" && exit 1)
	@test -d manifests || (echo "Missing manifests directory" && exit 1)
	@test -d spec || (echo "Missing spec directory" && exit 1)
	@echo "Kit structure is valid"

# Show help
help:
	@echo "Available targets:"
	@echo "  test            - Run all Ginkgo tests"
	@echo "  test-verbose    - Run tests with verbose output"
	@echo "  spec-check      - Run CI spec check script"
	@echo "  build           - Build kit with version from kit.yml"
	@echo "  build-version   - Build kit with specific VERSION=x.y.z"
	@echo "  clean           - Remove build artifacts"
	@echo "  fmt             - Format Go code"
	@echo "  mod-tidy        - Tidy Go modules"
	@echo "  test-deployment - Run deployment tests"
	@echo "  validate        - Validate kit structure"
	@echo "  help            - Show this help message"