#################
# MAKEFILE SETUP:
################

# Set special shell variables

# Ensure shells use bash, not what /bin/sh links to
export SHELL := /bin/bash
# Ensure make uses bash
export MAKESHELL := ${SHELL}
# Always use these flags to shell out
.SHELLFLAGS := -c

# Set other special variables

# Use spaces for tabs
.RECIPEPREFIX +=
# Invoke help by default
.DEFAULT_GOAL := help
# Unset builtin C/C++ rules
MAKEFLAGS += --no-builtin-rules
# Don't log recursion
MAKEFLAGS += --no-print-directory

# Set special targets

# Unset builtin C/C++ suffix patterns
.SUFFIXES:
# Enable silent mode with SILENT=TRUE
ifdef SILENT
.SILENT:
endif


####
# Environment variables:
##

# User-overridable:

# Error on missing commands/targets?
STRICT ?= FALSE
# What environment to build for
BUILD_ENV ?= dev
# Which files to assume are functions
FUNCTIONS ?= $(shell find functions \
  -type f \
  -iname "*.py" \
  ! -iname "__init__.py" \
  ! -path "__pycache__" \
)
# Which files to assume are library files
LIBRARIES ?= $(shell find lib \
  -type f \
  -iname "*.py" \
  ! -path "__pycache__" \
)

# Other variables:
SCRIPTS := server run watch lint deploy
# SCRIPTS += test

#####################
# UTILITY FUNCTIONS:
####################

pwd = $(abspath $(shell pwd))
user = $(shell whoami)
uid = $(shell id -u)
gid = $(shell id -g)

swap-std-out-err = 3>&1- 1>&2- 2>&3-

# Literal space character
space:=
space+=
# Literal comma character
comma := ,
# Literal hash mark character
hash=\#

# Functional alias
head = $(firstword $1)
# Functional helper
tail = $(wordlist 2,$(words $1),$1)

# Converts comma-delimited env vars into space-delimited lists
split-list = $(strip $(subst $(comma),$(space),$1))
# Ensures local path with no leading, trailing, or repeated slashes
normalize = $(patsubst $(call pwd)/%,%,$(abspath $(join $(addsuffix /,$2),$1)))
# Joins two directories lists via cross-product
dir-merge = $(foreach dir,$(call normalize,$1),$(patsubst %,${dir}/%,$(call normalize,$2)))
# Removes undesirable files and folders from a list
file-filter = $1#$(filter-out ${IGNORABLES},$1)

# Downcases all letters of each word
downcase = $(shell echo "$1" | tr '[:upper:]' '[:lower:]')
# Upcases all letters of each word
upcase = $(shell echo "$1" | tr '[:lower:]' '[:upper:]')
# Upcases first letter of each word
titleize = $(shell STR="$(call downcase,$1)"; LIST=( $$STR ); echo "$${LIST[@]^}")
# Converts $1: pathlist into a camelcased words
camelize-path = $(subst $(space),,$(call titleize,$(subst /,$(space),$1)))


###########
# COMMANDS:
##########

####
# Command: make check
##

# Check subcommand: make check-executables
.PHONY: check-executables
SUBCOMMANDS += check-executables
CHECK_SUBCOMMANDS += check-executables

CHECK_EXECUTABLES := git zip fswatch
CHECK_EXECUTABLES += pip pylint pytest
CHECK_EXECUTABLES += docker aws sam
check-executables:
  @echo Checking for executables: ${CHECK_EXECUTABLES}
  @$(MAKE) --ignore-errors --keep-going ${CHECK_EXECUTABLES}

.PHONY: ${CHECK_EXECUTABLES}
${CHECK_EXECUTABLES}:
  @type $@ 1>/dev/null && [[ -x $$(type -p $@) ]]


# Check command: make check
.PHONY: check
COMMANDS += check
INFO_CHECK = Validates current environment can run this makefile
export define HELP_CHECK
${INFO_CHECK}.

Existing files are not overwritten, so this command
can be repeatedly re-run to ensure you have what is
necessary, without overriding what you've customized.

SUBCOMMANDS: ${CHECK_SUBCOMMANDS}
endef

check: ${CHECK_SUBCOMMANDS}


####
# Command: make setup
##

# Setup subcommand: make setup-git
.PHONY: setup-git
SUBCOMMANDS += setup-git
SETUP_SUBCOMMANDS += setup-git

SETUP_GIT := .git .gitignore
setup-git: ${SETUP_GIT}

.git: | git
  @git init

.gitignore:
  $(file > $@,${SETUP_GIT_IGNORE_FILE})


# Setup subcommand: make setup-structure
.PHONY: setup-structure
SUBCOMMANDS += setup-structure
SETUP_SUBCOMMANDS += setup-structure

SETUP_STRUCTURE := bin config functions lib tests
# SETUP_STRUCTURE += envs
setup-structure: ${SETUP_STRUCTURE}
  @echo Setup project structure.

${SETUP_STRUCTURE}:
  @mkdir -p $@


# Setup subcommand: make setup-boilerplate
.PHONY: setup-boilerplate
SUBCOMMANDS += setup-boilerplate
SETUP_SUBCOMMANDS += setup-boilerplate

setup-boilerplate: ${SETUP_BOILERPLATE}

# SETUP_BOILERPLATE += .env
# .env:
#   @touch $@

SETUP_BOILERPLATE += .pylintrc
.pylintrc:
  $(file > $@,${SETUP_PYLINTRC_FILE})

SETUP_BOILERPLATE += .python-version
.python-version:
  @echo 3.6.7 > $@

SETUP_BOILERPLATE += config/template.yml
config/template.yml: | config
  $(file > $@,${SETUP_CONFIG_TEMPLATE_YML_FILE})

SETUP_BOILERPLATE += config/resources.yml
config/resources.yml: | config
  $(file > $@,${SETUP_CONFIG_RESOURCES_YML_FILE})

SETUP_BOILERPLATE += config/function.yml
config/function.yml: | config
  $(file > $@,${SETUP_CONFIG_FUNCTION_YML_FILE})

SETUP_BOILERPLATE += README.md
README.md:
  @echo Knock Lambda App > $@
  @echo ================ >> $@

SETUP_BOILERPLATE += requirements.txt
requirements.txt:
  $(file > $@,${SETUP_REQUIREMENTS_TXT_FILE})

# SETUP_BOILERPLATE += envs/dev.env
# envs/dev.env: | envs
#   @touch $@

SETUP_BOILERPLATE += functions/__init__.py
functions/__init__.py: | functions
  @echo import sys > $@
  @echo sys.path.append("lib") >> $@

SETUP_BOILERPLATE += tests/test_helper.py
tests/test_helper.py: | tests
  @echo import pytest > $@


# Setup subcommand: make setup-binstubs
.PHONY: setup-binstubs
SUBCOMMANDS += setup-binstubs
SETUP_SUBCOMMANDS += setup-binstubs

SETUP_BINSTUBS = $(addprefix bin/,${SCRIPTS})
setup-binstubs: ${SETUP_BINSTUBS}
  @chmod +x $?

${SETUP_BINSTUBS}: bin/%: | bin
  $(file >> $@,${SETUP_BINSTUBS_$(call upcase,$*)_FILE})


# Setup command: make setup
.PHONY: setup
COMMANDS += setup
INFO_SETUP = Creates expected project files
export define HELP_SETUP
${INFO_SETUP}.

Existing files are not overwritten, so this command
can be repeatedly re-run to ensure you have what is
necessary, without overriding what you've customized.

SUBCOMMANDS: ${SETUP_SUBCOMMANDS}
endef

setup: ${SETUP_SUBCOMMANDS}


####
# Command: make build
##

FUNCTION_FILES = $(call normalize,$(call split-list,${FUNCTIONS}))
FUNCTION_PATHS = $(patsubst functions/%,%,${FUNCTION_FILES})
FUNCTION_DIRS = $(basename ${FUNCTION_PATHS})
FUNCTION_NAMES = $(foreach function_dir,${FUNCTION_DIRS}, \
  $(call camelize-path,${function_dir}) \
) \

BUILD_DIR = $(call dir-merge,build,${BUILD_ENV})
BUILD_FUNCTION_DIRS = $(call dir-merge,${BUILD_DIR},${FUNCTION_DIRS})

${BUILD_DIR}:
  @mkdir -p $@
${BUILD_FUNCTION_DIRS}: | ${BUILD_DIR}
  @mkdir -p $@

# BUILD subcommand: make build-functions
.PHONY: build-functions
SUBCOMMANDS += build-functions
BUILD_SUBCOMMANDS += build-functions

BUILD_FUNCTIONS = $(addsuffix /function.py,${BUILD_FUNCTION_DIRS})
build-functions: ${BUILD_FUNCTIONS}

${BUILD_FUNCTIONS}: ${BUILD_DIR}/%/function.py: functions/%.py | ${BUILD_DIR}/% functions
  @cp -f $< $@


# BUILD subcommand: make build-libraries
.PHONY: build-libraries
SUBCOMMANDS += build-libraries
BUILD_SUBCOMMANDS += build-libraries

LIBRARY_FILES = $(call normalize,$(call split-list,${LIBRARIES}))
LIBRARY_PATHS = $(patsubst lib/%,%,${LIBRARY_FILES})

BUILD_LIBRARIES = $(call dir-merge,${BUILD_FUNCTION_DIRS},${LIBRARY_PATHS})
build-libraries: ${BUILD_LIBRARIES}

define RULE_BUILD_FUNCTION_LIBRARIES
$1/%: lib/% | $1 lib
  @mkdir -p $$(dir $$@)
  @cp -f $$< $$@
endef
$(foreach build_function_dir,${BUILD_FUNCTION_DIRS}, \
  $(eval $(call RULE_BUILD_FUNCTION_LIBRARIES,${build_function_dir})) \
) \


# BUILD subcommand: make build-dependencies
.PHONY: build-dependencies
SUBCOMMANDS += build-dependencies
BUILD_SUBCOMMANDS += build-dependencies

BUILD_DEPENDENCIES = $(call dir-merge,${BUILD_DIR},dependencies)
BUILD_FUNCTION_DEPENDENCIES = $(call file-filter, \
  $(call dir-merge,${BUILD_FUNCTION_DIRS}, \
    $(notdir $(wildcard ${BUILD_DEPENDENCIES}/*))\
  ) \
)
build-dependencies: ${BUILD_DEPENDENCIES} ${BUILD_FUNCTION_DEPENDENCIES}

.SECONDARY: ${BUILD_DEPENDENCIES}
${BUILD_DEPENDENCIES}:: requirements.txt | pip docker ${BUILD_DIR} ${BUILD_FUNCTION_DIRS}
  @mkdir -p $@
  @docker run --rm \
    --user ${uid}:${gid} \
    --workdir /code \
    --volume $(abspath $(pwd)):/code \
    --entrypoint "pip" \
    lambci/lambda:python3.6 \
    install --no-cache-dir -r requirements.txt -t $@ --upgrade 2>&1

define RULE_CREATE_FUNCTION_DEPENDENCIES
${BUILD_DEPENDENCIES}::
  @cp -rf ${BUILD_DEPENDENCIES}/* $1
endef
$(foreach build_function_dir,${BUILD_FUNCTION_DIRS}, \
  $(eval $(call RULE_CREATE_FUNCTION_DEPENDENCIES,${build_function_dir})) \
) \

define RULE_UPDATE_FUNCTION_DEPENDENCIES
$1/%: ${BUILD_DIR}/dependencies/% | $1 ${BUILD_DIR}/dependencies
  @cp -rf $$< $$@
endef
$(foreach build_function_dir,${BUILD_FUNCTION_DIRS}, \
  $(eval $(call RULE_UPDATE_FUNCTION_DEPENDENCIES,${build_function_dir})) \
) \


# BUILD subcommand: make build-config
.PHONY: build-config
SUBCOMMANDS += build-config
BUILD_SUBCOMMANDS += build-config

BUILD_FUNCTION_CONFIGS = $(addsuffix /function.yml,${BUILD_FUNCTION_DIRS})

BUILD_CONFIG = ${BUILD_DIR}/template.yml
export TEMPLATE_FILE = ${BUILD_DIR}/template.yml
build-config: ${BUILD_CONFIG}

${BUILD_CONFIG}: config/template.yml config/resources.yml
${BUILD_CONFIG}: ${BUILD_FUNCTION_CONFIGS}
${BUILD_CONFIG}: %/template.yml: | % sam
  @echo '$(hash) config/template.yml' > $@
  @cat config/template.yml \
    | sed 's|\$${ENV}|${BUILD_ENV}|g' >> $@
  @echo '' >> $@
  @echo 'Resources:' >> $@
  @echo '' >> $@
  @echo '$(hash) Non-Lambda Resources:' \
    | sed 's|\(.*\)|  \1|' >> $@
  @echo '' >> $@
  @echo '$(hash) config/resources.yml' \
    | sed 's|\(.*\)|  \1|' >> $@
  @cat config/resources.yml \
    | sed 's|\$${ENV}|${BUILD_ENV}|g' \
    | sed 's|\(.*\)|  \1|' >> $@
  @echo '' >> $@
  @echo '$(hash) Lambda Resources:' \
    | sed 's|\(.*\)|  \1|' >> $@
  @echo '' >> $@
  @$(foreach function_dir,${FUNCTION_DIRS}, \
    echo '$(hash) functions/${function_dir}.yml' \
      | sed 's|\(.*\)|  \1|' >> $@; \
    cat ${BUILD_DIR}/${function_dir}/function.yml \
      | sed 's|\$${ENV}|${BUILD_ENV}|g' \
      | sed 's|\$${NAME}|$(call camelize-path,${function_dir})|g' \
      | sed 's|\$${PATH}|${function_dir}|g' \
      | sed 's|\(.*\)|  \1|' >> $@; \
    echo '' >> $@; \
  )
  @sam validate --template $@ 2>&1

define RULE_BUILD_FUNCTION_CONFIG
# Don't worry about actually building function configuration overrides
functions/$1.yml:
  @:
# Instead, use overrides if it exists, else use the base config
${BUILD_DIR}/$1/function.yml: ${BUILD_DIR}/%/function.yml: functions/%.yml
${BUILD_DIR}/$1/function.yml: | ${BUILD_DIR}/$1 functions config/function.yml
  @if [ -e functions/$$*.yml ]; \
  then \
    cp -f functions/$$*.yml $$@; \
  else \
    cp -f config/function.yml $$@; \
  fi
endef
$(foreach function_dir,${FUNCTION_DIRS}, \
  $(eval $(call RULE_BUILD_FUNCTION_CONFIG,${function_dir})) \
) \


# Build command: make build
.PHONY: build
COMMANDS += build
INFO_BUILD = Builds project files
export define HELP_BUILD
${INFO_BUILD}.

The local AWS SAM CLI treats each lamba function
as a separate project, which must be bundled with
all its libraries and dependencies together.

This build command surveys the state of your current
project and produces artifacts meeting its expectations.

SUBCOMMANDS: ${BUILD_SUBCOMMANDS}
endef

build: ${BUILD_SUBCOMMANDS} | ${BUILD_DIR}/dependencies


####
# Command: make clean
##

# Clean command: make clean
.PHONY: clean
COMMANDS += clean
INFO_CLEAN = Removes build artifacts
export define HELP_CLEAN
Destroys the ${BUILD_DIR} directory.
endef

clean:
  @rm -rf build


####
# Command: make template
##

# Template command: make template
.PHONY: template
COMMANDS += template
INFO_TEMPLATE = Prints path to built project template
export define HELP_TEMPLATE
Prints the path to the AWS CloudFormation template file.
endef

template:
  @echo ${BUILD_CONFIG}


####
# Command: make function
##

# Funtion command: make function
.PHONY: function
COMMANDS += function
INFO_FUNCTION = Prints function names
export define HELP_FUNCTION
Prints the AWS resource name of each lambda function,
creating a starter function if the file does not yet
exist.

Can be restricted to only certain functions by specifying:
FUNCTIONS=path/to/function.file
endef

function: ${FUNCTIONS}
  @echo ${FUNCTION_NAMES}

${FUNCTIONS}:
  @mkdir -p $(dir $@)
  $(file > $@,$(call FUNCTION_FILE))


# ####
# # Command: make update
# ##

# # Update command: make update
# .PHONY: update
# COMMANDS += update
# INFO_UPDATE = Updates the Makefile
# export define HELP_UPDATE
# Fetches the latest version of this Makefile from GitHub.
# endef

# update: REPO ?= knockrentals/lamba-builder
# update:
#   curl -L -o newfile https://raw.githubusercontent.com/${REPO}/master/Makefile


####
# Command: make help
##

# Help command: make help
.PHONY: help
COMMANDS += help
INFO_HELP = Prints this help
export define HELP_HELP
Prints a helpful listing of all commands.
endef

HELP_COMMANDS = $(addprefix help-command-,${COMMANDS})
HELP_INFO_COMMANDS = $(addprefix help-info-,${COMMANDS})

help: STRICT ?= FALSE
help: | help-commands
  @echo $$'\nFor more information on a given command, run:'
  @echo 'make help-command-<command>'

# Help subcommand: make help-commands
help-commands:
  @echo 'Available commands:'
  @echo ''
  @$(MAKE) ${HELP_INFO_COMMANDS}

.PHONY: ${HELP_INFO_COMMANDS}
${HELP_INFO_COMMANDS}: help-info-%:
  @echo make $*
  @echo "  ${INFO_$(call upcase,$*)}"

.PHONY: ${HELP_COMMANDS}
${HELP_COMMANDS}: help-command-%:
  @echo USAGE: make $*
  @echo ''
  @echo "$$HELP_$(call upcase,$*)"

####
# Catch-all commands
##

ifeq (${STRICT},TRUE)
%:
  $(error Unrecognized command or target file: $*)
else
%:
  $(warning Unrecognized command or target file: $*)
endif


#################
# FILE TEMPLATES:
################

####
# SETUP FILES:
##

define SETUP_GIT_IGNORE_FILE
# Before adding to this file,
# consider what is project-specific,
# and what belongs in your
# `git config --global core.excludesfile`

####
# Project stuff
##
bin/
build/
envs/prod.env

####
# Python stuff
##

# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$$py.class
# C extensions
*.so
# Installer logs
pip-log.txt
pip-delete-this-directory.txt
# Jupyter Notebook
.ipynb_checkpoints

endef # SETUP_GIT_IGNORE_FILE


define SETUP_PYLINT_RC_FILE
[MASTER]
ignore-patterns=build

init-hook=import sys; sys.path.append('lib')

[FORMAT]
indent-string='  '
indent-after-paren=2

[MESSAGES CONTROL]
disable=missing-docstring

endef


define SETUP_REQUIREMENTS_TXT_FILE
requests==2.18.4

endef # SETUP_REQUIREMENTS_TXT_FILE


define SETUP_CONFIG_TEMPLATE_YML_FILE
# Variables:
#  $${ENV}: the value of BUILD_ENV at build time

AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31
Description: >
  Starter Lambda Project

Globals:
  Function:
    Runtime: python3.6

# Resources: will be appended to the end of this file

endef # SETUP_CONFIG_TEMPLATE_YML_FILE


define SETUP_CONFIG_RESOURCES_YML_FILE
# Variables:
#  $${ENV}: the value of BUILD_ENV at build time

# Additional resources go here

endef # SETUP_RESOURCES_YML_FILE


define SETUP_CONFIG_FUNCTION_YML_FILE
# Variables:
#  $${ENV}: the value of BUILD_ENV at build time
#  $${NAME}: the lambda function's name
#  $${PATH}: the path to the function within the functions folder
$${NAME}: &$${NAME}
  Type: AWS::Serverless::Function
  Properties:
    CodeUri: $${PATH}
    Handler: function.handler
    Events:
      Get$${NAME}:
        Type: Api
        Properties:
          Path: /$${PATH}/{extra+}
          Method: get
      Post$${NAME}:
        Type: Api
        Properties:
          Path: /$${PATH}/{extra+}
          Method: post

endef # SETUP_CONFIG_FUNCTION_YML_FILE


define SETUP_BINSTUBS_SERVER_FILE
#!/usr/bin/env bash
export BUILD_ENV=$${BUILD_ENV:-dev}

HELP=$$(cat <<-HELP
Runs 'sam local start-api' to launch a local API Gateway server
against the current BUILD_ENV ($$BUILD_ENV).

All provided command-line options are passed on to it.
HELP
)

if [[ "$$1" == help ]]; then
  echo "$$HELP"
  exit 0
fi

(set -x; sam local start-api --template $$(make template) "$${@:1}")

endef # SETUP_BINSTUBS_SERVER_FILE


define SETUP_BINSTUBS_RUN_FILE
#!/usr/bin/env bash
export BUILD_ENV=$${BUILD_ENV:-dev}

HELP=$$(cat <<-HELP
Runs 'sam local invoke' te execute the specified function file
against the current BUILD_ENV ($$BUILD_ENV).

All other provided command-line options are passed on to it.
HELP
)

if [[ "$$1" == help ]]; then
  echo "$$HELP"
  exit 0
fi

if [ -z "$$1" ]; then
  echo "Must specify a function file to run."
  exit 1
fi
export FUNCTIONS=$$1

(set -x; sam local invoke --template $$(make template) $$(make function) "$${@:2}")

endef # SETUP_BINSTUBS_RUN_FILE


define SETUP_BINSTUBS_DEPLOY_FILE
#!/usr/bin/env bash
export BUILD_ENV=$${BUILD_ENV:-dev}

endef # SETUP_BINSTUBS_DEPLOY_FILE


define SETUP_BINSTUBS_WATCH_FILE
#!/usr/bin/env bash
export BUILD_ENV=$${BUILD_ENV:-dev}

CMD=$${CMD:-make build}
WATCH="functions lib requirements.txt config.yml"

HELP=$$(cat <<-HELP
Runs 'fswatch' against project, executing CMD ($$CMD)
against the current BUILD_ENV ($$BUILD_ENV) when files change.

It will watch the provided files and folders if any are supplied,
otherwise it will use a default list ($$WATCH).
HELP
)

if [[ "$$1" == help ]]; then
  echo "$$HELP"
  exit 0
fi

if [ $$# -ne 0 ]; then
  WATCH="$${@:1}"
fi
echo Files to watch: $$WATCH

echo $$'Watching the filesystem for changes...'
fswatch -r $$WATCH \
  --one-per-batch \
  -e pycache -e .pyc \
  --event 512 --event 516 | while read num
do
  echo ''
  echo Detected file changes, rebuilding...
  echo Executing command: "$$CMD"
  echo ''
  result=$$(TIME="%e" time $$CMD 3>&1- 1>&2- 2>&3-)
  echo ''
  echo Rebuild took "$$result" seconds.
  echo ''
done
echo ''
echo Filesystem watcher terminated.

endef # SETUP_BINSTUBS_WATCH_FILE


define SETUP_BINSTUBS_TEST_FILE
#!/usr/bin/env bash

endef # SETUP_BINSTUBS_TEST_FILE


define SETUP_BINSTUBS_LINT_FILE
#!/usr/bin/env bash

LINT="functions lib"

HELP=$$(cat <<-HELP
Runs 'pylint' against project, analyzing python files.

It will lint the provided files and folders if any are supplied,
otherwise it will use a default list ($$LINT).
HELP
)

if [[ "$$1" == help ]]; then
  echo "$$HELP"
  exit 0
fi

if [ $$# -ne 0 ]; then
  LINT="$${@:1}"
fi
echo Files to lint: $$LINT

(set -x; pylint $$LINT)
endef # SETUP_BINSTUBS_LINT_FILE


define FUNCTION_FILE
import json

# Required handler function

def handler(event=None, context=None):
  # Threading a 'body' with JSON payload keeps API Gateway happy
  return {'body': json.dumps({'result': event})}

endef # FUNCTION_FILE
