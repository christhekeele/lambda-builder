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
# Unset builtin C/C++ variables
MAKEFLAGS += --no-builtin-variables
# Unset builtin C/C++ rules
MAKEFLAGS += --no-builtin-rules
# Don't log recursion
MAKEFLAGS += --no-print-directory

# Set special targets

# Unset builtin C/C++ suffix patterns
.SUFFIXES:
# Enable silent mode with SILENT=TRUE
ifeq (${SILENT},TRUE)
.SILENT:
endif


####
# Environment variables:
##

# User-overridable:

# What environment to build for
BUILD_ENV ?= dev
# Silence all output?
SILENT? ?= FALSE
# Error on missing commands/targets?
STRICT ?= TRUE
# Where to curl templates from
SOURCE ?= https://raw.githubusercontent.com/knockrentals/lambda-builder/master
# Which files to assume are functions
FUNCTIONS ?= $(shell bin/find/functions)
# Which files to assume are library files
LIBRARIES ?= $(shell bin/find/libraries)


#####################
# UTILITY FUNCTIONS:
####################

pwd = $(abspath $(shell pwd))

swap-std-out-err = 3>&1- 1>&2- 2>&3-

# Literal space character
space:=
space+=
# Literal comma character
comma := ,
# Literal hash mark character
hash=\#
# Literal newline
define newline

endef

# The time, now
now = $(shell date --utc --rfc-3339=seconds)

# Converts comma-delimited env vars into space-delimited lists
split-list = $(strip $(subst $(comma),$(space),$1))
# Ensures local path with no leading, trailing, or repeated slashes
normalize = $(patsubst $(call pwd)/%,%,$(abspath $(join $(addsuffix /,$2),$1)))
# Joins two directories lists via cross-product
dir-merge = $(foreach dir,$(call normalize,$1),$(patsubst %,${dir}/%,$(call normalize,$2)))

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
  echo Checking for executables: ${CHECK_EXECUTABLES}
  $(MAKE) --ignore-errors --keep-going ${CHECK_EXECUTABLES}

.PHONY: ${CHECK_EXECUTABLES}
${CHECK_EXECUTABLES}:
  type $@ 1>/dev/null && [[ -x $$(type -p $@) ]]


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
# Command: make project
##

# Project command: make project
.PHONY: project
COMMANDS += project
INFO_PROJECT = Ensures expected project files exist
export define HELP_PROJECT
${INFO_PROJECT}.

Existing files are not overwritten, so this command
can be repeatedly re-run to ensure you have the latest
missing files, without overriding what you've customized.

endef


SCRIPTS += install/deps
SCRIPTS += find/functions find/libraries
SCRIPTS += run/lambda run/server
SCRIPTS += run/watcher run/linter
# SCRIPTS += deploy test

# Expected project files
PROJECT_DOTFILES := .gitignore .pylintrc .python-version
PROJECT_DOCS := README.md
PROJECT_DEPENDENCIES := requirements.txt
PROJECT_BINSTUBS := $(addprefix bin/,${SCRIPTS})
PROJECT_CONFIG := config/template.yml config/resources.yml config/function.yml
PROJECT_SCAFFOLD += functions/__init__.py
PROJECT_SCAFFOLD += tests/test_helper.py

PROJECT_FILES += ${PROJECT_DOTFILES}
PROJECT_FILES += ${PROJECT_DOCS}
PROJECT_FILES += ${PROJECT_DEPENDENCIES}
PROJECT_FILES += ${PROJECT_CONFIG}
PROJECT_FILES += ${PROJECT_SCAFFOLD}

project: ${PROJECT_FILES}

${PROJECT_FILES}:
  @mkdir -p $(dir $@)
  curl ${SOURCE}/$@ --output $@ \
    --location --fail --silent --show-error


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
  mkdir -p $@
${BUILD_FUNCTION_DIRS}: | ${BUILD_DIR}
  mkdir -p $@

# BUILD subcommand: make build-functions
.PHONY: build-functions
SUBCOMMANDS += build-functions
BUILD_SUBCOMMANDS += build-functions

BUILD_FUNCTIONS = $(addsuffix /function.py,${BUILD_FUNCTION_DIRS})
build-functions: ${BUILD_FUNCTIONS}

${BUILD_FUNCTIONS}: ${BUILD_DIR}/%/function.py: functions/%.py | ${BUILD_DIR}/% functions
  cp -fu $< $@


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
  mkdir -p $$(dir $$@)
  cp -f $$< $$@
endef
$(foreach build_function_dir,${BUILD_FUNCTION_DIRS}, \
  $(eval $(call RULE_BUILD_FUNCTION_LIBRARIES,${build_function_dir})) \
) \


# BUILD subcommand: make build-dependencies
.PHONY: build-dependencies
SUBCOMMANDS += build-dependencies
BUILD_SUBCOMMANDS += build-dependencies

BUILD_DEPENDENCIES = $(call dir-merge,${BUILD_DIR},dependencies)
BUILD_FUNCTION_DEPENDENCIES = $(call dir-merge,${BUILD_FUNCTION_DIRS}, \
  $(notdir $(wildcard ${BUILD_DEPENDENCIES}/*))\
)
build-dependencies:: ${BUILD_DEPENDENCIES} ${BUILD_FUNCTION_DEPENDENCIES}\

${BUILD_DEPENDENCIES}: requirements.txt | ${BUILD_DIR} bin/install/deps
  mkdir -p $@
  bin/install/deps -t $@ -r requirements.txt --upgrade

define RULE_UPDATE_FUNCTION_DEPENDENCIES
$1/%: ${BUILD_DEPENDENCIES}/% | $1
  cp -afu $$< $$@
  touch $$@
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
${BUILD_CONFIG}: %/template.yml: | %
  @echo '$(hash) Generated at $(now)' > $@
  @echo '' >> $@

  cat config/template.yml \
  | sed 's|\$${ENV}|${BUILD_ENV}|g' \
  | sed 's|\$${ENV_NAME}|$(call camelize-path,${BUILD_ENV})|g' \
  >> $@
  @echo '' >> $@

  @echo 'Resources:' >> $@
  @echo '' >> $@

  cat config/resources.yml \
  | sed 's|\$${ENV}|${BUILD_ENV}|g' \
  | sed 's|\$${ENV_NAME}|$(call camelize-path,${BUILD_ENV})|g' \
  | sed 's/\(.*\)/  \1/' \
  >> $@
  @echo '' >> $@

  $(foreach function_dir,${FUNCTION_DIRS}, \
    cat ${BUILD_DIR}/${function_dir}/function.yml \
    | sed 's|\$${ENV}|${BUILD_ENV}|g' \
    | sed 's|\$${ENV_NAME}|$(call camelize-path,${BUILD_ENV})|g' \
    | sed 's|\$${NAME}|$(call camelize-path,${function_dir})|g' \
    | sed 's|\$${PATH}|${function_dir}|g' \
    | sed 's/\(.*\)/  \1/' \
    >> $@;  \
    echo '' >> $@; \
  )
ifeq (${VALIDATE},TRUE)
  sam validate --template $@ 2>&1
endif

define RULE_BUILD_FUNCTION_CONFIG
# If function lacks its own config template, use that
ifeq (,$(wildcard functions/$1.yml))
${BUILD_DIR}/$1/function.yml: config/function.yml | ${BUILD_DIR}/$1
  cp -f $$< $$@
else # Otherwise use its personal one
${BUILD_DIR}/$1/function.yml: functions/$1.yml | ${BUILD_DIR}/$1
  cp -f $$< $$@
endif
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
  rm -rf build

# Hidden clean subcommand: make clean-project
.PHONY: clean-project
clean-project:
  rm -f $(filter-out ${PROJECT_DOCS},${PROJECT_FILES})


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

function: | ${FUNCTIONS}
  @echo ${FUNCTION_NAMES}

define FUNCTION_TEMPLATE
import json

# Required handler function

def handler(event=None, context=None):
  # Threading a 'body' with JSON payload keeps API Gateway happy
  return {'body': json.dumps({'result': event})}

endef # FUNCTION_TEMPLATE

${FUNCTIONS}:
  @mkdir -p $(dir $@)
  $(file > $@,$(call FUNCTION_TEMPLATE))


####
# Command: make update
##

# Update command: make update
.PHONY: update
COMMANDS += update
INFO_UPDATE = Updates the Makefile
export define HELP_UPDATE
Fetches the latest version of this Makefile.
endef

update: REPO ?= knockrentals/lamba-builder
update:
  curl ${SOURCE}/Makefile --output Makefile \
    --location --fail --silent --show-error


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
  echo $$'\nFor more information on a given command, run:'
  echo 'make help-command-<command>'

# Help subcommand: make help-commands
help-commands:
  echo 'Available commands:'
  echo ''
  $(MAKE) ${HELP_INFO_COMMANDS}

.PHONY: ${HELP_INFO_COMMANDS}
${HELP_INFO_COMMANDS}: help-info-%:
  echo make $*
  echo "  ${INFO_$(call upcase,$*)}"

.PHONY: ${HELP_COMMANDS}
${HELP_COMMANDS}: help-command-%:
  echo USAGE: make $*
  echo ''
  echo "$$HELP_$(call upcase,$*)"

####
# Catch-all commands
##

ifneq (${STRICT},TRUE)
%:
  $(warning Unrecognized command or target file: $*)
endif
