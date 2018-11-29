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
# Overridable environment variables:
##

# Makefile configuration:

# Local artifact output directory
BUILD_DIR ?= build
# Silence all output?
SILENT ?= FALSE
# Error on missing commands/targets?
STRICT ?= TRUE
# Where to curl templates from
SOURCE ?= https://raw.githubusercontent.com/knockrentals/lambda-builder/master

# Build information:

# Path-style application name
APP ?= app
APP_NAME=$(call camelize-path,${APP})
# Path-style build environment
ENV ?= dev
ENV_NAME=$(call camelize-path,${ENV})

# Who is executing this build script?
AUTHOR ?= $(shell \
  echo $$(aws iam get-user --query "User.UserName") \
  | sed -e 's/^"//' -e 's/"$$//' \
)

# Files to recognize:

# Which files to assume are functions
FUNCTIONS ?= $(shell \
  mkdir -p functions; \
  find functions \
    -type f \
    -iname "*.py" \
    ! -iname "__init__.py" \
    ! -path "__pycache__" \
    -print \
)
# Which files to assume are library files
LIBRARIES ?= $(shell \
  mkdir -p lib; \
  find lib \
    -type f \
    -iname "*.py" \
    ! -path "__pycache__" \
    -print \
)


#####################
# UTILITY FUNCTIONS:
####################

pwd = $(abspath $(shell pwd))

# Literal space character
space:=
space+=
# Literal comma character
comma := ,
# Literal hash mark character
hash-literal=\#
# Literal newline
define newline

endef

# The time, now
now = $(shell date -u '+%Y-%m-%d %T%z' | sed 's/ /T/')

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
titleize = $(shell echo "$(call downcase,$1)" | sed -e "s/\b./\u\0/g")
# Converts $1: pathlist into a camelcased words
camelize-path = $(foreach path,$(call normalize,$1),$(subst $(space),,$(call titleize,$(subst /,$(space),${path}))))
# Converts $1: pathlist into proper lambda function names
fun-name-from-dir = $(call camelize-path,$(call dir-merge,${APP},$1))

# Hashes input strinng
hash = $(shell TMP="$$(openssl sha1 <(printf '$1'))"; echo $${TMP/* })


###################
# BUILD META-DATA:
##################

BUILD_TIME=$(now)
BUILD_NAME=${AUTHOR}/${BUILD_TIME}/${ENV_NAME}/${APP_NAME}
BUILD_HASH=$(call hash,${BUILD_NAME})


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

# Builtins we can't use `type -p` on with
CHECK_BUILTINS += echo exit set pwd type 

# Portable bash commands all tooling assumes exists
CHECK_COMMANDS += cat cp curl find 
CHECK_COMMANDS += mkdir sed touch

# Installable programs used in this Makefile
CHECK_INSTALLED += git openssl zip
# Installable programs needed by bin/install
CHECK_INSTALLED += docker pip
# Installable programs needed by bin/run+bin/deploy
CHECK_INSTALLED += aws sam
 
CHECK_EXECUTABLES += ${CHECK_BUILTINS}
CHECK_EXECUTABLES += ${CHECK_COMMANDS}
CHECK_EXECUTABLES += ${CHECK_INSTALLED}
check-executables:
  @echo Checking for executables: ${CHECK_EXECUTABLES}
  $(MAKE) --ignore-errors --keep-going ${CHECK_EXECUTABLES}

.PHONY: ${CHECK_BUILTINS}
${CHECK_BUILTINS}:
  @type $@

.PHONY: ${CHECK_COMMANDS} ${CHECK_INSTALLED}
${CHECK_COMMANDS} ${CHECK_INSTALLED}:
  @type $@ && [[ -x $$(type -p $@) ]]


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
SCRIPTS += run/lambda run/server
SCRIPTS += run/watcher 

# Expected project files
PROJECT_TOOLING += .gitignore .pylintrc .python-version
PROJECT_TOOLING += $(addprefix bin/,${SCRIPTS})
PROJECT_TOOLING += config/template.yml config/resources.yml config/function.yml
PROJECT_TOOLING += functions/__init__.py
# Starter project files
PROJECT_STARTER += README.md
PROJECT_STARTER += requirements.txt
PROJECT_STARTER += functions/hello/world.py 
PROJECT_STARTER += lib/api/routes.py

PROJECT_FILES += ${PROJECT_TOOLING}
PROJECT_FILES += ${PROJECT_STARTER}

project: ${PROJECT_FILES}
  find bin -type f -exec chmod 744 {} +

${PROJECT_FILES}:
  @mkdir -p $(dir $@)
  curl ${SOURCE}/$@ --output $@ \
    --location --fail --silent --show-error


####
# Command: make build
##

# Install sample function if none exist
ifeq (,${FUNCTIONS})
FUNCTIONS=functions/hello/world.py
endif
FUNCTION_FILES = $(call normalize,$(call split-list,${FUNCTIONS}))
FUNCTION_PATHS = $(patsubst functions/%,%,${FUNCTION_FILES})
FUNCTION_DIRS = $(basename ${FUNCTION_PATHS})
FUNCTION_NAMES = $(foreach function_dir,${FUNCTION_DIRS}, \
  $(call camelize-path,${function_dir}) \
) \

BUILD_FUNCTION_DIR = $(call dir-merge,${BUILD_DIR},functions)
BUILD_FUNCTION_DIRS = $(call dir-merge,${BUILD_FUNCTION_DIR},${FUNCTION_DIRS})

${BUILD_DIR}/:
  mkdir -p $@
${BUILD_FUNCTION_DIR}: | ${BUILD_DIR}/
  mkdir -p $@
${BUILD_FUNCTION_DIRS}: | ${BUILD_FUNCTION_DIR}
  mkdir -p $@

# BUILD subcommand: make build-functions
.PHONY: build-functions
SUBCOMMANDS += build-functions
BUILD_SUBCOMMANDS += build-functions

BUILD_FUNCTIONS = $(addsuffix /function.py,${BUILD_FUNCTION_DIRS})
build-functions: ${BUILD_FUNCTIONS}

${BUILD_FUNCTIONS}: ${BUILD_FUNCTION_DIR}/%/function.py: functions/%.py | ${BUILD_FUNCTION_DIR}/% functions
  cp -f $< $@


# BUILD subcommand: make build-libraries
.PHONY: build-libraries
SUBCOMMANDS += build-libraries
BUILD_SUBCOMMANDS += build-libraries



# Install sample project libfile if none exist
ifeq (,${LIBRARIES})
LIBRARIES=lib/api/routes.py
endif
LIBRARY_FILES = $(call normalize,$(call split-list,${LIBRARIES}))
LIBRARY_PATHS = $(patsubst lib/%,%,${LIBRARY_FILES})

BUILD_FUNCTION_LIBRARIES = $(call dir-merge,${BUILD_FUNCTION_DIRS},${LIBRARY_PATHS})
build-libraries: ${BUILD_FUNCTION_LIBRARIES}

define RULE_BUILD_FUNCTION_LIBRARIES
$1/%.py: lib/%.py | $1 lib
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
build-dependencies: ${BUILD_DEPENDENCIES} ${BUILD_FUNCTION_DEPENDENCIES}

${BUILD_DEPENDENCIES}: requirements.txt | ${BUILD_DIR}/ bin/install/deps
  mkdir -p $@
  bin/install/deps -t $@ -r requirements.txt --upgrade

define RULE_UPDATE_FUNCTION_DEPENDENCIES
$1/%: ${BUILD_DEPENDENCIES}/% | $1
  cp -af $$< $$@
  touch $$@
endef

$(foreach build_function_dir,${BUILD_FUNCTION_DIRS}, \
  $(eval $(call RULE_UPDATE_FUNCTION_DEPENDENCIES,${build_function_dir})) \
) \


# BUILD subcommand: make build-packages
.PHONY: build-packages
SUBCOMMANDS += build-packages
BUILD_SUBCOMMANDS += build-packages

BUILD_PACKAGES = $(addsuffix .zip,$(call dir-merge,${BUILD_FUNCTION_DIR},$(call fun-name-from-dir,${FUNCTION_DIRS})))
build-packages: ${BUILD_PACKAGES}

define RULE_BUILD_FUNCTION_PACKAGE
# Zip func dir ($2) into functions folder, named ($1) after function 
${BUILD_FUNCTION_DIR}/$1.zip: $(wildcard ${BUILD_FUNCTION_DIR}/$2/*) | ${BUILD_FUNCTION_DIR} ${BUILD_FUNCTION_DIR}/$2
  cd ${BUILD_FUNCTION_DIR}/$2; \
  zip -rq9 $$(abspath $$@) * \
    -x **/*.pyc \
    -x **/__pycache__/ \
    -x **/__pycache__/**/*
endef

$(foreach function_dir,${FUNCTION_DIRS}, \
  $(eval $(call RULE_BUILD_FUNCTION_PACKAGE,$(call fun-name-from-dir,${function_dir}),${function_dir}, \
  )) \
) \


# BUILD subcommand: make build-config
.PHONY: build-config
SUBCOMMANDS += build-config
BUILD_SUBCOMMANDS += build-config

BUILD_FUNCTION_CONFIGS = $(addsuffix /function.yml,${BUILD_FUNCTION_DIRS})

BUILD_CONFIG = ${BUILD_FUNCTION_DIR}/template.yml
build-config: ${BUILD_CONFIG}

${BUILD_CONFIG}: ${BUILD_PACKAGES}
${BUILD_CONFIG}: config/template.yml config/resources.yml
${BUILD_CONFIG}: ${BUILD_FUNCTION_CONFIGS}
${BUILD_CONFIG}: %/template.yml: | %
  @echo '$(hash-literal) Generated at ${BUILD_TIME}' > $@
  @echo '' >> $@

  cat config/template.yml >> $@
  @echo '' >> $@

  @echo 'Resources:' >> $@
  @echo '' >> $@

  cat config/resources.yml | sed 's/\(.*\)/  \1/' >> $@
  @echo '' >> $@

# Replace function-specific variables as we append functions
  $(foreach function_dir,${FUNCTION_DIRS}, \
    cat ${BUILD_FUNCTION_DIR}/${function_dir}/function.yml \
    | sed 's|\$${FUN_NAME}|$(call fun-name-from-dir,${function_dir})Function|g' \
    | sed 's|\$${PATH}|${function_dir}|g' \
    | sed 's|\$${CODE}|$(call fun-name-from-dir,${function_dir}).zip|g' \
    | sed 's/\(.*\)/  \1/' \
    >> $@;  \
    echo '' >> $@; \
  )

# Replace template-wide variables in-place on finished file
  sed -i 's|\$${APP}|${APP}|g' $@
  sed -i 's|\$${APP_NAME}|$(call camelize-path,${APP})|g' $@
  sed -i 's|\$${ENV}|${ENV}|g' $@
  sed -i 's|\$${ENV_NAME}|$(call camelize-path,${ENV})|g' $@
  sed -i 's|\$${BUILD_TIME}|${BUILD_TIME}|g' $@
  sed -i 's|\$${BUILD_NAME}|${BUILD_NAME}|g' $@
  sed -i 's|\$${BUILD_HASH}|${BUILD_HASH}|g' $@
  sed -i 's|\$${AUTHOR}|${AUTHOR}|g' $@

define RULE_BUILD_FUNCTION_CONFIG
# If function lacks its own config, use template
ifeq (,$(wildcard functions/$1.yml))
${BUILD_FUNCTION_DIR}/$1/function.yml: config/function.yml | ${BUILD_FUNCTION_DIR}/$1
  cp -f $$< $$@
else # Otherwise use its personal one
${BUILD_FUNCTION_DIR}/$1/function.yml: functions/$1.yml | ${BUILD_FUNCTION_DIR}/$1
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


####
# Command: make function
##

# Funtion command: make function
.PHONY: function
COMMANDS += function
INFO_FUNCTION = Prints function names
export define HELP_FUNCTION
Prints the AWS resource name of each lambda function.

Can be restricted to only certain functions by specifying:
FUNCTIONS=path/to/function.file
endef

function:
  @echo ${FUNCTION_NAMES}


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

ifneq (${STRICT},TRUE)
%:
  $(warning Unrecognized command or target file: $*)
endif
