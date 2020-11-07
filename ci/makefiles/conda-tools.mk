include ../../extras/.env
include ../.env

PLATFORM = $(shell conda info | grep platform | awk '{print $$3}')

# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## Basic help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

help-advanced: ## Advanced help.
	@awk 'BEGIN {FS = ":.*?# "} /^[a-zA-Z_-]+:.*?# / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

# cli args
ARGS = $(filter-out $@,$(MAKECMDGOALS))

CONDA_BUILD_ARGS = --quiet --numpy 1.11

MAKE_CMD = $(MAKE) -s

clean: conda-recipe-clean conda-clean-build



# CONDA

## CONDA BASICS
### update
conda-update:
	@echo -n "Updating conda... "
	@conda update -q -y -n base -c defaults conda > /dev/null
	@echo OK
### install package
conda-install-%: conda-update
	@conda install -y -c conda-forge pyyaml
### check recipe
conda-recipe-check:
	@echo -n "Checking the recipe..."
	@conda build --check $(CONDA_BUILD_ARGS) ../../recipe > /dev/null
	@echo OK
### parse recipe
conda-recipe-parse:
	@python ../${TEST_PATH}/parse_recipe.py > /dev/null
### clean recipe extracted infos
conda-recipe-clean:
	@rm -f ../${TEST_PATH}/test-environment.yml ${TEST_PATH}/test.sh
### clean build products
conda-clean-build:
	@rm -rf ${CONDA_BLD_PATH}/*
### Add channels specified in recipe
conda-add-channels:
	@for channel in `cat ../../recipe/conda_channels.txt`; do \
	  conda config --quiet --add channels $$channel > /dev/null ; \
	done


## CONDA BUILD

### build only
conda-build-only_python%: check-conda-build
	@echo -n "Building conda package... "
	@conda build --no-test $(CONDA_BUILD_ARGS) --python=$* --output-folder ${CONDA_BLD_PATH} ../../recipe > /dev/null
	@echo OK
conda-build-only: check-conda-build conda-install-pyyaml
	@for pyver in `python ../${TEST_PATH}/parse_recipe.py | grep python | awk 'BEGIN {FS = "="} ; {print $2}'` ; do \
		$(MAKE_CMD) -f conda-tools.mk conda-build-only_python$$pyver ; \
	done
	@$(MAKE_CMD) -f conda-tools.mk conda-recipe-clean

### test only
conda-test-only_python%: check-conda-build conda-add-channels
	@echo -n "Testing conda package for python$*... "
	@conda build --test $(CONDA_BUILD_ARGS) ${CONDA_BLD_PATH}/${PLATFORM}/${PACKAGE}-*py`echo $* | sed -e "s/\.//g"`*.tar.bz2 > /dev/null
	@echo OK
conda-test-only: check-conda-build conda-add-channels conda-install-pyyaml
	@for pyver in `python ../${TEST_PATH}/parse_recipe.py | grep python | awk '{print $$1}'` ; do \
		$(MAKE_CMD) -f conda-tools.mk conda-test-only_python$$pyver ;\
	done
	@$(MAKE_CMD) -f conda-tools.mk conda-recipe-clean

### build+test
conda-build: check-conda-build conda-build-test
conda-build-test_python%: check-conda-build
	@echo -n "Building and Testing conda package... "
	@conda build $(CONDA_BUILD_ARGS) --python=$* --output-folder ${CONDA_BLD_PATH} ../../recipe > /dev/null
	@echo OK
conda-build-test: check-conda-build conda-install-pyyaml
	@for pyver in `python ../${TEST_PATH}/parse_recipe.py | grep python | awk '{print $$2}'` ; do \
		$(MAKE_CMD) -f conda-tools.mk conda-build-test_python$$pyver ;\
	done
	@$(MAKE_CMD) -f conda-tools.mk conda-recipe-clean

### convert
conda-convert_python%: check-conda
	@echo -n "Converting conda package (python$*) from ${PLATFORM} to osx-64, linux-64 and win-64... "
	@conda convert \
	        --platform osx-64 \
	        --platform linux-64 \
	        --platform win-64 \
	        --output-dir ${CONDA_BLD_PATH} \
	        ${CONDA_BLD_PATH}/${PLATFORM}/${PACKAGE}-*py`echo $* | sed -e "s/\.//g"`*.tar.bz2
	@echo OK
conda-convert: check-conda
	@for pyver in `python ../${TEST_PATH}/parse_recipe.py | grep python | awk '{print $$2}'` ; do \
		$(MAKE_CMD) -f conda-tools.mk conda-convert_python$$pyver ;\
	done
	@$(MAKE_CMD) -f conda-tools.mk conda-recipe-clean

### publish
conda-publish_python%: check-anaconda-client
	@anaconda \
		--token `cat ../.secrets | grep ANACONDA_TOKEN | awk 'BEGIN {FS = "="} ; {print $$2}'` \
		upload \
		--user `cat ../.secrets | grep ANACONDA_USER | awk 'BEGIN {FS = "="} ; {print $$2}'` \
		--label ${ANACONDA_LABEL} \
		${CONDA_BLD_PATH}/*/${PACKAGE}-*py`echo $* | sed -e "s/\.//g"`*.tar.bz2
conda-publish: check-anaconda-client
	@for pyver in `python ../${TEST_PATH}/parse_recipe.py | grep python | awk '{print $$2}'` ; do \
		$(MAKE_CMD) -f conda-tools.mk conda-publish_python$$pyver ;\
	done
	@$(MAKE_CMD) -f conda-tools.mk conda-recipe-clean


# ENVIRONMENT CHECKING
## Check conda
ifeq (,$(shell which conda))
    HAS_CONDA=False
else
    HAS_CONDA=True
    ENV_DIR=$(shell conda info --base)
    MY_ENV_DIR=$(ENV_DIR)/envs/$(env)
    CONDA_ACTIVATE=source $$(conda info --base)/etc/profile.d/conda.sh ; conda activate ; conda activate
endif
check-conda:
ifeq (False,$(HAS_CONDA))
	$(error >>> Install conda first.)
endif

## Check conda-build
ifeq (,$(shell which conda-build))
    HAS_CONDA_BUILD=False
else
    HAS_CONDA_BUILD=True
endif
check-conda-build:
ifeq (False,$(HAS_CONDA_BUILD))
	$(error >>> Install conda-build first.)
endif

## Check anaconda-client
ifeq (,$(shell which anaconda))
    HAS_ANACONDA_CLIENT=False
else
    HAS_ANACONDA_CLIENT=True
endif
check-anaconda-client:
ifeq (False,$(HAS_ANACONDA_CLIENT))
	$(error >>> Install anaconda-client first.)
endif

check-environment-%: check-conda
ifneq ("$(wildcard $(MY_ENV_DIR))","") # check if the directory is there
		@echo ">>> Found '$(env)' environment in $(MY_ENV_DIR). Skipping installation..." > /dev/null
else
		@echo ">>> '$(env)' folder is missing in $(ENV_DIR). Installing ..." > /dev/null
		@$(MAKE_CMD) -f conda-env.mk conda-create-env-$* env=$(env)
endif
