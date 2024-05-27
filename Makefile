# Variables
VERSION = noetic
APPTAINER = apptainer
TARGET_DIR = /opt/ros/$(VERSION)
USER_NAME = $(shell echo $$USER)
USER_HOME = $(shell echo $$HOME)
# Parse command line arguments
ifdef ARGS
$(info Arguments provided: $(ARGS))
endif

# Use the arguments in a new target
args:
	@echo "The provided arguments are: $(ARGS)"


test:
	@echo "Hello, $(USER_NAME)!"
	@echo "Your home directory is $(USER_HOME)."
	@echo "The target directory is $(TARGET_DIR)."
	@echo "The target VERSION of ros is $(VERSION)."

	

# Default target
all: build deploy

# Build the apptainer
build:
	@echo "Building $(APPTAINER)..."
	apptainer build --sandbox --build-arg version=$(VERSION) $(VERSION).sif ros.def
	# sudo apptainer build --force $(VERSION).sif ros.def 

# Deploy the apptainer
deploy: build
	@echo "Deploying $(APPTAINER)..."
	sudo mkdir -p $(TARGET_DIR)
	sudo cp setup.sh $(TARGET_DIR)/setup.sh
	sudo sed -i 's|APPTAINER_PATH|$(shell pwd)\/$(VERSION).sif|' $(TARGET_DIR)/setup.sh

# Test the variable replacement in the setup file
test_setup:
	@echo "Testing variable replacement in setup file..."
	@echo "Before replacement:"
	@cat setup.sh
	@cp setup.sh test_setup.sh
	@echo "After replacement:"
	@sed -i 's|APPTAINER_PATH|$(shell pwd)\/$(VERSION).sif|' test_setup.sh
	@cat test_setup.sh

# Clean up
clean:
	@echo "Cleaning up..."
	# Add your clean commands here

.PHONY: all build deploy clean