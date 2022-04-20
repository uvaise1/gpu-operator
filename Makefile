# Copyright (c) 2021, NVIDIA CORPORATION.  All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BUILD_MULTI_ARCH_IMAGES ?= no
DOCKER ?= docker
BUILDX  =
ifeq ($(BUILD_MULTI_ARCH_IMAGES),true)
BUILDX = buildx
endif

##### Global variables #####
include $(CURDIR)/versions.mk

MODULE := github.com/NVIDIA/gpu-operator
CUDA_IMAGE ?= nvidia/cuda
BUILDER_IMAGE ?= golang:$(GOLANG_VERSION)

ifeq ($(IMAGE_NAME),)
REGISTRY ?= quay.io/mgiessing
IMAGE_NAME := $(REGISTRY)/gpu-operator
endif

IMAGE_VERSION := $(VERSION)
IMAGE_TAG ?= $(IMAGE_VERSION)-$(DIST)
IMAGE = $(IMAGE_NAME):$(IMAGE_TAG)
BUILDIMAGE ?= $(IMAGE_NAME):$(IMAGE_TAG)-build

OUT_IMAGE_NAME ?= $(IMAGE_NAME)
OUT_IMAGE_VERSION ?= $(VERSION)
OUT_IMAGE_TAG = $(OUT_IMAGE_VERSION)-$(DIST)
OUT_IMAGE = $(OUT_IMAGE_NAME):$(OUT_IMAGE_TAG)

# CHANNELS define the bundle channels used in the bundle.
# Add a new line here if you would like to change its default config. (E.g CHANNELS = "preview,fast,stable")
# To re-generate a bundle for other specific channels without changing the standard setup, you can:
# - use the CHANNELS as arg of the bundle target (e.g make bundle CHANNELS=preview,fast,stable)
# - use environment variables to overwrite this value (e.g export CHANNELS="preview,fast,stable")
ifneq ($(origin CHANNELS), undefined)
BUNDLE_CHANNELS := --channels=$(CHANNELS)
endif

# DEFAULT_CHANNEL defines the default channel used in the bundle.
# Add a new line here if you would like to change its default config. (E.g DEFAULT_CHANNEL = "stable")
# To re-generate a bundle for any other default channel without changing the default setup, you can:
# - use the DEFAULT_CHANNEL as arg of the bundle target (e.g make bundle DEFAULT_CHANNEL=stable)
# - use environment variables to overwrite this value (e.g export DEFAULT_CHANNEL="stable")
ifneq ($(origin DEFAULT_CHANNEL), undefined)
BUNDLE_DEFAULT_CHANNEL := --default-channel=$(DEFAULT_CHANNEL)
endif
BUNDLE_METADATA_OPTS ?= $(BUNDLE_CHANNELS) $(BUNDLE_DEFAULT_CHANNEL)

# BUNDLE_IMAGE defines the image:tag used for the bundle.
# You can use it as an arg. (E.g make bundle-build BUNDLE_IMAGE=<some-registry>/<project-name-bundle>:<tag>)
BUNDLE_IMAGE ?= gpu-operator-bundle:$(VERSION)

# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true,preserveUnknownFields=false"

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

all: gpu-operator

# Run tests
ENVTEST_ASSETS_DIR=$(shell pwd)/testbin
test: generate fmt vet manifests
	mkdir -p ${ENVTEST_ASSETS_DIR}
	test -f ${ENVTEST_ASSETS_DIR}/setup-envtest.sh || curl -sSLo ${ENVTEST_ASSETS_DIR}/setup-envtest.sh https://raw.githubusercontent.com/kubernetes-sigs/controller-runtime/v0.7.0/hack/setup-envtest.sh
	source ${ENVTEST_ASSETS_DIR}/setup-envtest.sh; fetch_envtest_tools $(ENVTEST_ASSETS_DIR); setup_envtest_env $(ENVTEST_ASSETS_DIR); go test ./... -coverprofile cover.out

# Build gpu-operator binary
gpu-operator: generate fmt vet
	go build -o bin/gpu-operator main.go

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate fmt vet manifests
	go run ./main.go

# Install CRDs into a cluster
install: manifests kustomize
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

# Uninstall CRDs from a cluster
uninstall: manifests kustomize
	$(KUSTOMIZE) build config/crd | kubectl delete -f -

# Deploy gpu-operator in the configured Kubernetes cluster in ~/.kube/config
deploy: manifests kustomize
	cd config/manager && $(KUSTOMIZE) edit set image gpu-operator=${IMAGE}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

# UnDeploy gpu-operator from the configured Kubernetes cluster in ~/.kube/config
undeploy:
	$(KUSTOMIZE) build config/default | kubectl delete -f -

# Generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=gpu-operator-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

# Download controller-gen locally if necessary
CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen:
	$(call go-get-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.1)

# Download kustomize locally if necessary
KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize:
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v3.8.7)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go get $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef

# Generate bundle manifests and metadata, then validate generated files.
.PHONY: bundle
bundle: manifests kustomize
	operator-sdk generate kustomize manifests -q
	cd config/manager && $(KUSTOMIZE) edit set image gpu-opertor=$(IMAGE)
	$(KUSTOMIZE) build config/manifests | operator-sdk generate bundle -q --overwrite --version $(VERSION) $(BUNDLE_METADATA_OPTS)
	operator-sdk bundle validate ./bundle

# Build the bundle image.
.PHONY: bundle-build
bundle-build:
	docker build --build-arg VERSION=$(VERSION) --build-arg DEFAULT_CHANNEL=$(DEFAULT_CHANNEL) -f docker/bundle.Dockerfile -t $(BUNDLE_IMAGE) .

# Define local and dockerized golang targets

CHECK_TARGETS := assert-fmt vet lint ineffassign misspell
MAKE_TARGETS := build check coverage $(CHECK_TARGETS)
DOCKER_TARGETS := $(patsubst %,docker-%, $(MAKE_TARGETS))
.PHONY: $(MAKE_TARGETS) $(DOCKER_TARGETS)

# Generate an image for containerized builds
# Note: This image is local only
.PHONY: .build-image .pull-build-image .push-build-image
.build-image: docker/Dockerfile.devel
	if [ x"$(SKIP_IMAGE_BUILD)" = x"" ]; then \
		$(DOCKER) build \
			--progress=plain \
			--build-arg GOLANG_VERSION="$(GOLANG_VERSION)" \
			--tag $(BUILDIMAGE) \
			-f $(^) \
			docker; \
	fi

.pull-build-image:
	$(DOCKER) pull $(BUILDIMAGE)

.push-build-image:
	$(DOCKER) push $(BUILDIMAGE)

$(DOCKER_TARGETS): docker-%: .build-image
	@echo "Running 'make $(*)' in docker container $(BUILDIMAGE)"
	$(DOCKER) run \
		--rm \
		-e GOCACHE=/tmp/.cache \
		-v $(PWD):$(PWD) \
		-w $(PWD) \
		--user $$(id -u):$$(id -g) \
		$(BUILDIMAGE) \
			make $(*)

check: $(CHECK_TARGETS)

# Apply go fmt to the codebase
fmt:
	go list -f '{{.Dir}}' $(MODULE)/... \
		| xargs gofmt -s -l -w

assert-fmt:
	go list -f '{{.Dir}}' $(MODULE)/... \
		| xargs gofmt -s -l | ( grep -v /vendor/ || true ) > fmt.out
	@if [ -s fmt.out ]; then \
		echo "\nERROR: The following files are not formatted:\n"; \
		cat fmt.out; \
		rm fmt.out; \
		exit 1; \
	else \
		rm fmt.out; \
	fi

ineffassign:
	ineffassign $(MODULE)/...

lint:
# We use `go list -f '{{.Dir}}' $(MODULE)/...` to skip the `vendor` folder.
	go list -f '{{.Dir}}' $(MODULE)/... | xargs golint -set_exit_status

lint-internal:
# We use `go list -f '{{.Dir}}' $(MODULE)/...` to skip the `vendor` folder.
	go list -f '{{.Dir}}' $(MODULE)/internal/... | xargs golint -set_exit_status

misspell:
	misspell $(MODULE)/...

vet:
	go vet $(MODULE)/...

build:
	go build $(MODULE)/...

COVERAGE_FILE := coverage.out
unit-test: build
	go test -v -coverprofile=$(COVERAGE_FILE) $(MODULE)/...

coverage: unit-test
	cat $(COVERAGE_FILE) | grep -v "_mock.go" > $(COVERAGE_FILE).no-mocks
	go tool cover -func=$(COVERAGE_FILE).no-mocks

##### Public rules #####
DISTRIBUTIONS := ubi8 ubuntu20.04
DEFAULT_PUSH_TARGET := ubi8

PUSH_TARGETS := $(patsubst %,push-%, $(DISTRIBUTIONS))
BUILD_TARGETS := $(patsubst %,build-%, $(DISTRIBUTIONS))
TEST_TARGETS := $(patsubst %,test-%, $(DISTRIBUTIONS))

ifneq ($(BUILD_MULTI_ARCH_IMAGES),true)
include $(CURDIR)/native-only.mk
else
include $(CURDIR)/multi-arch.mk
endif

ALL_TARGETS := $(DISTRIBUTIONS) $(PUSH_TARGETS) $(BUILD_TARGETS) $(TEST_TARGETS) docker-image
.PHONY: $(ALL_TARGETS)

ifneq ($(SUBCOMPONENT),)
# SUBCOMPONENT is set; assume this is the target folder
$(ALL_TARGETS): %:
	make -C $(SUBCOMPONENT) $(*)
else

# For the default push target we also push a short tag equal to the version.
# We skip this for the development release
DEVEL_RELEASE_IMAGE_VERSION ?= devel
ifneq ($(strip $(VERSION)),$(DEVEL_RELEASE_IMAGE_VERSION))
push-$(DEFAULT_PUSH_TARGET): push-short
endif

push-%: DIST = $(*)
push-short: DIST = $(DEFAULT_PUSH_TARGET)

build-%: DIST = $(*)
build-%: DOCKERFILE = $(CURDIR)/docker/Dockerfile

$(DISTRIBUTIONS): %: build-%
$(BUILD_TARGETS): build-%:
	DOCKER_BUILDKIT=1 \
		$(DOCKER) $(BUILDX) build --pull \
		$(DOCKER_BUILD_OPTIONS) \
		$(DOCKER_BUILD_PLATFORM_OPTIONS) \
		--tag $(IMAGE) \
		--build-arg BASE_DIST="$(DIST)" \
		--build-arg CUDA_IMAGE="$(CUDA_IMAGE)" \
		--build-arg CUDA_VERSION="$(CUDA_VERSION)" \
		--build-arg VERSION="$(VERSION)" \
		--build-arg BUILDER_IMAGE="$(BUILDER_IMAGE)" \
		--build-arg GOLANG_VERSION="$(GOLANG_VERSION)" \
		--build-arg CVE_UPDATES="$(CVE_UPDATES)" \
		--file $(DOCKERFILE) $(CURDIR)

# Provide a utility target to build the images to allow for use in external tools.
# This includes https://github.com/openshift-psap/ci-artifacts
docker-image: OUT_IMAGE ?= $(IMAGE_NAME):$(IMAGE_TAG)
docker-image: ${DEFAULT_PUSH_TARGET}
endif