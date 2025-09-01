# Makefile for building FMUs from Simulink models

# Configuration
MODELS_DIR := models
SCRIPTS_DIR := scripts
FMU_DIR := fmu
SPARK_FMU_DIR := ../spark/simulation-assets/fmu
MATLAB := matlab
XVFB := xvfb-run -a

# Optional rename for deploy
RENAME ?= 

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
CYAN := \033[0;36m
NC := \033[0m

# Find all .slx files
SLX_FILES := $(shell find $(MODELS_DIR) -name "*.slx" 2>/dev/null)
MODEL_NAMES := $(patsubst $(MODELS_DIR)/%.slx,%,$(patsubst $(MODELS_DIR)/%/%.slx,%,$(SLX_FILES)))

# Default target
.PHONY: help
help:
	@echo "FMU Build System"
	@echo "================"
	@echo "Usage:"
	@echo "  make build MODEL=<model_name>            - Build specific model"
	@echo "  make <model_name>.fmu                    - Build specific model"
	@echo "  make deploy MODEL=<model_name>           - Build and deploy to spark"
	@echo "  make deploy MODEL=<model> RENAME=<new>   - Build, rename, and deploy"
	@echo "  make list-models                         - List all available models"
	@echo "  make list-fmus                           - List built FMUs"
	@echo "  make all                                 - Build all models"
	@echo "  make clean                               - Clean build artifacts"
	@echo "  make clean-fmus                          - Remove all FMU files"
	@echo ""
	@echo "Examples:"
	@echo "  make build MODEL=train_dynamics"
	@echo "  make train_dynamics.fmu"
	@echo "  make deploy MODEL=train_dynamics RENAME=dynamics"
	@echo ""
	@echo "FMUs are stored in: $(FMU_DIR)/"
	@echo "Deploy location: $(SPARK_FMU_DIR)/"

# List available models
.PHONY: list-models
list-models:
	@echo "Available models:"
	@for model in $(MODEL_NAMES); do \
		echo "  - $$model"; \
	done

# Create directories
$(FMU_DIR):
	@mkdir -p $(FMU_DIR)

$(SPARK_FMU_DIR):
	@mkdir -p $(SPARK_FMU_DIR)

# Build specific model
.PHONY: build
build:
ifndef MODEL
	@echo -e "$(RED)Error: MODEL not specified$(NC)"
	@echo "Usage: make build MODEL=<model_name>"
	@exit 1
else
	@$(MAKE) $(FMU_DIR)/$(MODEL).fmu
endif

# Deploy target
.PHONY: deploy
deploy:
ifndef MODEL
	@echo -e "$(RED)Error: MODEL not specified$(NC)"
	@echo "Usage: make deploy MODEL=<model_name>"
	@exit 1
else
	@$(MAKE) $(FMU_DIR)/$(MODEL).fmu
	@echo -e "$(CYAN)Deploying FMU to spark...$(NC)"
	@mkdir -p $(SPARK_FMU_DIR)
	@if [ -n "$(RENAME)" ]; then \
		cp $(FMU_DIR)/$(MODEL).fmu $(SPARK_FMU_DIR)/$(RENAME).fmu; \
		echo -e "$(GREEN)✓ Deployed as: $(SPARK_FMU_DIR)/$(RENAME).fmu$(NC)"; \
	else \
		cp $(FMU_DIR)/$(MODEL).fmu $(SPARK_FMU_DIR)/$(MODEL).fmu; \
		echo -e "$(GREEN)✓ Deployed to: $(SPARK_FMU_DIR)/$(MODEL).fmu$(NC)"; \
	fi
endif

# Convenience target for model.fmu -> fmu/model.fmu
%.fmu: $(FMU_DIR)/%.fmu
	@echo -e "$(GREEN)✓ FMU available: $(FMU_DIR)/$@$(NC)"

# Main build rule for FMUs
$(FMU_DIR)/%.fmu: $(SCRIPTS_DIR)/build_fmu_generic.m | $(FMU_DIR)
	@echo -e "$(GREEN)=== Building FMU for model: $* ===$(NC)"
	@if [ -f "$(MODELS_DIR)/$*.slx" ]; then \
		MODEL_PATH="$(MODELS_DIR)/$*.slx"; \
		MODEL_DIR="$(MODELS_DIR)"; \
	elif [ -f "$(MODELS_DIR)/$*/$*.slx" ]; then \
		MODEL_PATH="$(MODELS_DIR)/$*/$*.slx"; \
		MODEL_DIR="$(MODELS_DIR)/$*"; \
	else \
		echo -e "$(RED)Error: Model $*.slx not found$(NC)"; \
		echo "Searched in:"; \
		echo "  - $(MODELS_DIR)/$*.slx"; \
		echo "  - $(MODELS_DIR)/$*/$*.slx"; \
		exit 1; \
	fi; \
	echo -e "$(CYAN)Model location: $$MODEL_PATH$(NC)"; \
	if [ -f "$${MODEL_DIR}/$*.sldd" ]; then \
		echo -e "$(GREEN)✓ Found data dictionary: $*.sldd$(NC)"; \
		HAS_DICT="true"; \
	else \
		echo -e "$(YELLOW)ℹ No data dictionary found (optional)$(NC)"; \
		HAS_DICT="false"; \
	fi; \
	ABS_MODEL_DIR=$$(cd "$${MODEL_DIR}" && pwd); \
	ABS_FMU_DIR=$$(cd "$(FMU_DIR)" && pwd); \
	echo -e "$(YELLOW)Starting MATLAB build...$(NC)"; \
	$(XVFB) $(MATLAB) -batch "model_name='$*'; model_dir='$${ABS_MODEL_DIR}'; fmu_dir='$${ABS_FMU_DIR}'; has_dict='$${HAS_DICT}'; run('$(SCRIPTS_DIR)/build_fmu_generic')" 2>&1 | tee $(FMU_DIR)/build_$*.log; \
	if [ -f "$(FMU_DIR)/$*.fmu" ]; then \
		echo -e "$(GREEN)✓ FMU successfully built: $(FMU_DIR)/$*.fmu$(NC)"; \
		echo -e "$(GREEN)  Size: $$(du -h $(FMU_DIR)/$*.fmu | cut -f1)$(NC)"; \
		echo -e "$(GREEN)  Time: $$(date)$(NC)"; \
	else \
		echo -e "$(RED)✗ FMU build failed for $*$(NC)"; \
		echo -e "$(YELLOW)Check build log: $(FMU_DIR)/build_$*.log$(NC)"; \
		exit 1; \
	fi

# Build all models
.PHONY: all
all:
	@for model in $(MODEL_NAMES); do \
		echo -e "$(CYAN)Building $$model...$(NC)"; \
		$(MAKE) $(FMU_DIR)/$$model.fmu; \
	done

# Clean build artifacts
.PHONY: clean
clean:
	@echo -e "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf slprj
	@find $(MODELS_DIR) -type d -name "*_fmu*_rtw" -exec rm -rf {} + 2>/dev/null || true
	@find $(MODELS_DIR) -type d -name "slprj" -exec rm -rf {} + 2>/dev/null || true
	@rm -f $(FMU_DIR)/*.log
	@echo -e "$(GREEN)✓ Clean complete$(NC)"

# Clean FMU files
.PHONY: clean-fmus
clean-fmus:
	@echo -e "$(YELLOW)Removing FMU files...$(NC)"
	@rm -f $(FMU_DIR)/*.fmu
	@echo -e "$(GREEN)✓ FMU files removed$(NC)"

# Install dependencies
.PHONY: install-deps
install-deps:
	@echo -e "$(YELLOW)Checking dependencies...$(NC)"
	@if ! command -v xvfb-run > /dev/null; then \
		echo -e "$(YELLOW)Installing xvfb...$(NC)"; \
		sudo apt-get update && sudo apt-get install -y xvfb; \
	else \
		echo -e "$(GREEN)✓ xvfb already installed$(NC)"; \
	fi
	@if ! command -v matlab > /dev/null; then \
		echo -e "$(RED)✗ MATLAB not found in PATH$(NC)"; \
		exit 1; \
	else \
		echo -e "$(GREEN)✓ MATLAB found$(NC)"; \
	fi

# List built FMUs
.PHONY: list-fmus
list-fmus:
	@echo -e "$(CYAN)FMUs in $(FMU_DIR)/:$(NC)"
	@if [ -d "$(FMU_DIR)" ]; then \
		ls -lh $(FMU_DIR)/*.fmu 2>/dev/null || echo "  No FMUs found"; \
	else \
		echo "  FMU directory does not exist"; \
	fi
	@echo ""
	@if [ -d "$(SPARK_FMU_DIR)" ]; then \
		echo -e "$(CYAN)FMUs in $(SPARK_FMU_DIR)/:$(NC)"; \
		ls -lh $(SPARK_FMU_DIR)/*.fmu 2>/dev/null || echo "  No FMUs found"; \
	fi