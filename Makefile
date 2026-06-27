.PHONY: gen build test run shot watch review secrets

secrets: ## Bootstrap Carddex/Resources/Secrets.plist from the example (then add real values)
	@if [ -f Carddex/Resources/Secrets.plist ]; then \
		echo "Carddex/Resources/Secrets.plist already exists — leaving it untouched."; \
	else \
		mkdir -p Carddex/Resources && cp Secrets.example.plist Carddex/Resources/Secrets.plist && \
		echo "Created Carddex/Resources/Secrets.plist (gitignored)."; \
		echo "-> Edit SUPABASE_PROJECT_REF + SUPABASE_ANON_KEY, then run 'make gen'."; \
		echo "   Without it the app runs on sample data (fake identify, no sync/StoreKit)."; \
	fi
gen:    ## Regenerate the Xcode project
	@bash scripts/dev.sh gen
build:  ## Build for the simulator
	@bash scripts/dev.sh build
test:   ## Run the test suite
	@bash scripts/dev.sh test
run:    ## Build, install, launch in the simulator
	@bash scripts/dev.sh run
shot:   ## Run + screenshot to /tmp/carddex.png
	@bash scripts/dev.sh shot
watch:  ## Rebuild on every change (needs fswatch)
	@bash scripts/dev.sh watch
review: ## Run the specialist agent panel + build-verify (Claude Code workflow)
	@echo "Run from Claude Code:  /workflows  → carddex-review   (or Workflow name: carddex-review)"
