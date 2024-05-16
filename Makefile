SHELL := /bin/bash

# Directories
VSCODIUM_ROOT = $(shell git rev-parse --show-toplevel)
VSCODE_DIR = $(VSCODIUM_ROOT)/vscode
SCRIPTS_DIR = $(VSCODIUM_ROOT)/scripts
ASSETS_DIR = $(VSCODIUM_ROOT)/assets
STATUS_DIR = $(VSCODIUM_ROOT)/.status

# Variables
APP_NAME ?= VSCodium
BINARY_NAME ?= codium
VSCODE_QUALITY ?= stable
UNAME_S := $(shell uname -s)
OS_NAME ?= unknown
ifeq ($(OS_NAME),unknown)
    ifeq ($(UNAME_S),Darwin)
        OS_NAME := osx
    endif
    ifeq ($(UNAME_S),Linux)
        OS_NAME := linux
    endif
    ifeq ($(findstring CYGWIN_NT,$(UNAME_S)),CYGWIN_NT)
        OS_NAME := windows
    endif
endif

# Check if OS_NAME is one of the supported options
ifneq ($(filter $(OS_NAME),osx linux windows),$(OS_NAME))
    $(error OS_NAME "$(OS_NAME)" is not supported. Please set OS_NAME to one of the following: osx, linux, windows)
endif
export OS_NAME
export APP_NAME
export BINARY_NAME
export VSCODE_QUALITY
export VSCODIUM_ROOT

# Targets
.PHONY: all

all: clean clone build

$STATUS_DIR:
	mkdir -p $(STATUS_DIR)

build:
	$(info Building $(APP_NAME) for "$(OS_NAME)")
	$(SCRIPTS_DIR)/build.sh

clean:
	$(info Cleaning up)
	rm -rf $(VSCODE_DIR)
	rm -rf $(ASSETS_DIR)
	rm -rf $(STATUS_DIR)
	rm -rf VSCode-*

$VSCODE_DIR:
	$(info Cloning VSCode repository)
  ifneq ($(CI_BUILD),no)
		git config --global --add safe.directory "/__w/$(shell echo $(GITHUB_REPOSITORY) | awk '{print tolower($$0)}')"
	endif

	ifdef PULL_REQUEST_ID
		BRANCH_NAME=$(shell git rev-parse --abbrev-ref HEAD )
		git config --global user.email "$( shell echo "${GITHUB_USERNAME}" | awk '{print tolower($0)}' )-ci@not-real.com"
		git config --global user.name "${GITHUB_USERNAME} CI"
		git fetch --unshallow
		git fetch origin "pull/${PULL_REQUEST_ID}/head"
		git checkout FETCH_HEAD
		git merge --no-edit "origin/${BRANCH_NAME}"
	endif

	ifndef RELEASE_VERSION
		if [[ "${VSCODE_LATEST}" == "yes" ]] || [[ ! -f "${VSCODE_QUALITY}.json" ]]; then
			$(info "Retrieve lastest version")
			UPDATE_INFO=$(shell curl --silent --fail "https://update.code.visualstudio.com/api/update/darwin/${VSCODE_QUALITY}/0000000000000000000000000000000000000000" )
		else
			$(info "Get version from ${VSCODE_QUALITY}.json")
			MS_COMMIT=$(shell jq -r '.commit' "${VSCODE_QUALITY}.json" )
			MS_TAG=$(shell jq -r '.tag' "${VSCODE_QUALITY}.json" )
		fi

		ifndef MS_COMMIT
			MS_COMMIT=$(shell echo "${UPDATE_INFO}" | jq -r '.commit' )
			MS_TAG=$(shell echo "${UPDATE_INFO}" | jq -r '.name' )

			ifeq ($(VSCODE_QUALITY),insider)
				MS_TAG := $(subst -insider,,$(MS_TAG))
			endif
		endif

		DATE := $(shell date +%Y%j)
		DATE_LAST_5 := $(shell echo $(DATE) | rev | cut -c -5 | rev)

		ifeq ($(VSCODE_QUALITY),insider)
			RELEASE_VERSION := $(MS_TAG).$(DATE_LAST_5)-insider
		else
			RELEASE_VERSION := $(MS_TAG).$(DATE_LAST_5)
		endif
	else
		ifeq ($(VSCODE_QUALITY),insider)
			ifeq ($(shell echo $(RELEASE_VERSION) | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'),)
				$(error Error: Bad RELEASE_VERSION: $(RELEASE_VERSION))
			else
				MS_TAG := $(shell echo $(RELEASE_VERSION) | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
			endif
		else
			ifeq ($(shell echo $(RELEASE_VERSION) | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+'),)
				$(error Error: Bad RELEASE_VERSION: $(RELEASE_VERSION))
			else
				MS_TAG := $(shell echo $(RELEASE_VERSION) | grep -Eo '^[0-9]+\.[0-9]+\.[0-9]+' | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
			endif
		endif

		ifeq ($(MS_TAG),$(shell jq -r '.tag' "$(VSCODE_QUALITY).json"))
			MS_COMMIT := $(shell jq -r '.commit' "$(VSCODE_QUALITY).json")
		else
			$(error Error: No MS_COMMIT for $(RELEASE_VERSION))
		endif
	endif
	$(info "RELEASE_VERSION: $(RELEASE_VERSION)")

clone: $STATUS_DIR $VSCODE_DIR
