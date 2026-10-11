.DEFAULT_GOAL := help
.PHONY: help build run launch test revoke reset-cache clean install dmg release release-dry-run

## help: Display this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@awk '/^##/ { printf "  \033[36m%-20s\033[0m %s\n", substr($$2, 1, length($$2)-1), substr($$0, index($$0, $$3)) }' $(MAKEFILE_LIST)

## build: Compile AutoCliX.app and sign binary
build:
	@./scripts/build.sh

## run: Launch compiled AutoCliX.app
run: build
	@echo "==> Launching AutoCliX.app..."
	@open "build/AutoCliX.app"

## launch: Open AutoCliX.app without rebuilding (preserves TCC CDHash)
launch:
	@echo "==> Launching AutoCliX.app (no rebuild)..."
	@open "build/AutoCliX.app"

## test: Run Swift unit test suite
test:
	@./scripts/test.sh

## revoke: Reset macOS Accessibility TCC permissions for com.citizen.autoclix
revoke:
	@echo "==> Resetting TCC permissions..."
	@tccutil reset Accessibility com.citizen.autoclix 2>/dev/null || true
	@echo "✅ All permissions revoked."

## reset-cache: Clear macOS LaunchServices and IconServices caches
reset-cache:
	@echo "==> Resetting macOS Icon and LaunchServices caches..."
	@touch build/AutoCliX.app 2>/dev/null || true
	@/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f -R build/AutoCliX.app 2>/dev/null || true
	@qlmanage -r 2>/dev/null || true
	@qlmanage -r cache 2>/dev/null || true
	@killall Dock 2>/dev/null || true
	@echo "✅ Cache reset complete."

## clean: Remove build artifacts
clean:
	@echo "==> Cleaning build artifacts..."
	@rm -rf build /tmp/RunSwiftTests
	@echo "✅ Clean complete."

## install: Install AutoCliX.app to /Applications
install: build
	@echo "==> Installing AutoCliX.app to /Applications..."
	@rm -rf "/Applications/AutoCliX.app"
	@cp -R "build/AutoCliX.app" /Applications/
	@echo "✅ Installed to /Applications/AutoCliX.app"

## dmg: Create DMG installer package with custom styled background
dmg: build
	@./scripts/build_dmg.sh

# Capture positional version argument for release targets (e.g. make release 1.1.0)
ifeq ($(firstword $(MAKECMDGOALS)),$(filter $(firstword $(MAKECMDGOALS)),release release-dry-run))
  RELEASE_TARGET_VERSION := $(word 2,$(MAKECMDGOALS))
  ifneq ($(RELEASE_TARGET_VERSION),)
    $(eval $(RELEASE_TARGET_VERSION):;@:)
  endif
endif

## release-dry-run: Preview release tagging and publishing without making remote changes (e.g. make release-dry-run [version])
release-dry-run:
	@./scripts/release.sh --dry-run $(if $(VERSION),$(VERSION),$(RELEASE_TARGET_VERSION))

## release: Bump version (auto or specified: make release [version]), build DMG, tag & push, and publish release
release:
	@./scripts/release.sh $(if $(VERSION),$(VERSION),$(RELEASE_TARGET_VERSION))
