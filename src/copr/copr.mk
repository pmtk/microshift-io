COPR_CONFIG ?= $(HOME)/.config/copr
COPR_REPO_NAME ?= "@microshift-io/microshift"
COPR_BUILD_ID ?= $$(cat "${SRPM_WORKDIR}/build.txt")

COPR_SECRET_NAME := copr-cfg
COPR_BUILDER_IMAGE := microshift-okd-rpm-copr
COPR_CLI_IMAGE := localhost/copr-cli:latest
COPR_CHROOT ?= "epel-10-$(uname -m)"


.PHONY: copr-help
copr-help:
	@echo "make <rpm-copr | copr-delete-build | copr-regenerate-repos | copr-create-build | copr-watch-build>"
	@echo "   rpm-copr:                         build the MicroShift RPMs using COPR"
	@echo "   copr-delete-build:                delete the COPR build"
	@echo "   copr-regenerate-repos:            regenerate the COPR RPM repository"
	@echo "   copr-create-build:                create the COPR RPM build"
	@echo "   copr-watch-build:                 watch the COPR build"
	@echo "   copr-cfg-ensure-podman-secret:    ensure the COPR secret is available and is up to date"
	@echo "   copr-cli:                         build the COPR CLI container"
	@echo ""
	@echo "Variables:"
	@echo "   COPR_BUILD_ID:                    COPR build ID (default: read from \$$SRPM_WORKDIR/build.txt)"
	@echo "   COPR_REPO_NAME:                   COPR repository name (default: ${COPR_REPO_NAME})"
	@echo "   COPR_CONFIG:                      COPR configuration file - from https://copr.fedorainfracloud.org/api/ (default: ${COPR_CONFIG})"
	@echo ""
	@echo "Recommended flow:"
	@echo "   1. mkdir -p /tmp/microshift-srpm-copr"
	@echo "   2. make srpm SRPM_WORKDIR=/tmp/microshift-srpm-copr"
	@echo "   3. make copr-create-build COPR_REPO_NAME=USER/PROJECT SRPM_WORKDIR=/tmp/microshift-srpm-copr"
	@echo "   4. make copr-watch-build SRPM_WORKDIR=/tmp/microshift-srpm-copr"
	@echo "   5. make rpm-copr SRPM_WORKDIR=/tmp/microshift-srpm-copr"
	@echo "   6. make image RPM_IMAGE=microshift-okd-rpm-copr"
	@echo ""

.PHONY: rpm-copr
rpm-copr:
	@echo "Building MicroShift RPM image using COPR"
	sudo podman build \
        --tag "${COPR_BUILDER_IMAGE}" \
        --build-arg COPR_BUILD_ID="${COPR_BUILD_ID}" \
        --build-arg COPR_CHROOT="${COPR_CHROOT}" \
        --file packaging/rpm-copr.Containerfile .

	@outdir="$${RPM_OUTDIR:-$$(mktemp -d /tmp/microshift-rpms-XXXXXX)}" && \
	mntdir="$$(sudo podman image mount "${COPR_BUILDER_IMAGE}")" && \
	trap "sudo podman image umount '${COPR_BUILDER_IMAGE}' >/dev/null" EXIT && \
	sudo cp -r "$${mntdir}/home/microshift/microshift/_output/rpmbuild/RPMS/." "$${outdir}" && \
	echo -e "\nBuild completed successfully\nRPMs are available in '$${outdir}'"

.PHONY: copr-cfg-ensure-podman-secret
copr-cfg-ensure-podman-secret:
	@echo "Ensuring the COPR secret is available and is up to date"
	if sudo podman secret exists "${COPR_SECRET_NAME}"; then \
		sudo podman secret rm "${COPR_SECRET_NAME}" ; \
	fi ; \
	sudo podman secret create "${COPR_SECRET_NAME}" "${COPR_CONFIG}"

.PHONY: copr-cli
copr-cli:
	@echo "Building the COPR CLI container"
	sudo podman build \
		--tag "${COPR_CLI_IMAGE}" \
		--file src/copr/copr-cli.Containerfile .

.PHONY: copr-delete-build
copr-delete-build: copr-cfg-ensure-podman-secret copr-cli
	@echo "Deleting the COPR build ${COPR_BUILD_ID}"
	sudo podman run \
		--rm \
		--secret ${COPR_SECRET_NAME} \
		"${COPR_CLI_IMAGE}" \
		bash -c "copr-cli --config /run/secrets/copr-cfg delete-build ${COPR_BUILD_ID}"

.PHONY: copr-regenerate-repos
copr-regenerate-repos: copr-cfg-ensure-podman-secret copr-cli
	@echo "Regenerating the COPR repository"
	sudo podman run \
		--rm \
		--secret ${COPR_SECRET_NAME} \
		"${COPR_CLI_IMAGE}" \
		bash -c "copr-cli --config /run/secrets/copr-cfg regenerate-repos ${COPR_REPO_NAME}"

.PHONY: copr-create-build
copr-create-build: copr-cfg-ensure-podman-secret copr-cli
	@echo "Creating the COPR build"
	sudo podman run \
		--rm \
		--secret ${COPR_SECRET_NAME} \
		--env COPR_REPO_NAME="${COPR_REPO_NAME}" \
		--volume "${SRPM_WORKDIR}:/srpms:Z" \
		--volume "./src/copr/create-build.sh:/create-build.sh:Z" \
		"${COPR_CLI_IMAGE}" \
		bash -c "bash -x /create-build.sh"

.PHONY: copr-watch-build
copr-watch-build: copr-cli
	@echo "Watching the COPR build"
	sudo podman run \
		--rm \
		--volume "${SRPM_WORKDIR}:/srpms:Z" \
		"${COPR_CLI_IMAGE}" \
		bash -c "copr-cli watch-build \$$(cat /srpms/build.txt)"
