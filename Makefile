APP := dist/Caffeinum.app
INSTALL_DIR := $(HOME)/Applications

.PHONY: build test run install uninstall release clean

build: ## Build dist/Caffeinum.app (arm64)
	@./scripts/build-app.sh

test: ## Run the test suite
	@./scripts/test.sh

run: build ## Build and launch the app
	@pkill -x Caffeinum 2>/dev/null || true
	@open $(APP)

install: build ## Build and copy into ~/Applications
	@pkill -x Caffeinum 2>/dev/null || true
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_DIR)/Caffeinum.app
	@cp -R $(APP) $(INSTALL_DIR)/
	@echo "Installed to $(INSTALL_DIR)/Caffeinum.app"
	@open $(INSTALL_DIR)/Caffeinum.app

uninstall: ## Quit and remove the installed app
	@pkill -x Caffeinum 2>/dev/null || true
	@rm -rf $(INSTALL_DIR)/Caffeinum.app
	@echo "Removed $(INSTALL_DIR)/Caffeinum.app"

release: ## Tag the next version and push it - GitHub builds and publishes it
	@./scripts/release.sh $(ARGS)

clean: ## Remove build products
	@rm -rf .build dist
