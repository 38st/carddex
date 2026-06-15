.PHONY: gen build test run shot watch review

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
