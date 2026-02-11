COPR_CONFIG ?= $(HOME)/.config/copr
COPR_REPO_NAME ?= "@microshift-io/microshift-nightly"

COPR_SECRET_NAME := copr-cfg
OKD_RELEASE_IMAGE_X86_64 ?= quay.io/okd/scos-release
OKD_VERSION_TAG ?= $$(../../okd/get_version.sh latest-amd64)

.PHONY: crio-builder-image
crio-builder-image:
	@echo "Building builder image"
	sudo podman build \
        -t crio-copr-builder-image \
        --file crio.Containerfile .

.PHONY: build-crio
build-crio: crio-builder-image
	@echo "Ensuring the COPR secret is available and is up to date"
	if sudo podman secret exists "${COPR_SECRET_NAME}"; then \
		sudo podman secret rm "${COPR_SECRET_NAME}" ; \
	fi ; \
	sudo podman secret create "${COPR_SECRET_NAME}" "${COPR_CONFIG}"

	@echo "Building CRI-O SRPM"
	sudo podman run \
        --rm \
        --secret copr-cfg,target=/root/.config/copr \
        crio-copr-builder-image
