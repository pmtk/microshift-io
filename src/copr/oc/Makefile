COPR_CONFIG ?= $(HOME)/.config/copr
COPR_REPO_NAME ?= "@microshift-io/microshift-nightly"

COPR_SECRET_NAME := copr-cfg
OKD_RELEASE_IMAGE_X86_64 ?= quay.io/okd/scos-release
OKD_VERSION_TAG ?= $$(../../okd/get_version.sh latest-amd64)

.PHONY: oc-builder-image
oc-builder-image:
	@echo "Building builder image"
	sudo podman build \
        -t oc-copr-builder-image \
        --file oc.Containerfile .

.PHONY: build-oc
build-oc: oc-builder-image
	@echo "Ensuring the COPR secret is available and is up to date"
	if sudo podman secret exists "${COPR_SECRET_NAME}"; then \
		sudo podman secret rm "${COPR_SECRET_NAME}" ; \
	fi ; \
	sudo podman secret create "${COPR_SECRET_NAME}" "${COPR_CONFIG}"

	@echo "Building openshift-clients SRPM"
	sudo podman run \
        --rm \
        --secret copr-cfg,target=/root/.config/copr \
        oc-copr-builder-image \
        "${OKD_RELEASE_IMAGE_X86_64}" "${OKD_VERSION_TAG}" "${COPR_REPO_NAME}"
