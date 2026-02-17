PROJECT := The Trash.xcodeproj
SCHEME := The Trash
SIMULATOR ?= iPhone 16
DEST_SIM := platform=iOS Simulator,name=$(SIMULATOR)
DEST_DEVICE := generic/platform=iOS

.PHONY: open build build-device test contracts contracts-strict migrations-check migrations-check-strict migrations-sync doctor

open:
	open "$(PROJECT)"

build:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DEST_SIM)' build

build-device:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DEST_DEVICE)' build

test:
	xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" -destination '$(DEST_SIM)' test

contracts:
	bash scripts/check_backend_contracts.sh

contracts-strict:
	bash scripts/check_backend_contracts.sh --strict

migrations-check:
	bash scripts/check_migration_mirror.sh

migrations-check-strict:
	bash scripts/check_migration_mirror.sh --strict

migrations-sync:
	bash scripts/sync_migration_mirror.sh

doctor:
	bash scripts/check_backend_contracts.sh --strict
	bash scripts/check_migration_mirror.sh --strict
