ARG BOOTC_IMAGE_URL=quay.io/centos-bootc/centos-bootc
ARG BOOTC_IMAGE_TAG=stream10

FROM ${BOOTC_IMAGE_URL}:${BOOTC_IMAGE_TAG}

COPY ./packaging/nightly/rhocp.repo /tmp/rhocp.repo

# hadolint ignore=DL4006,SC2016
RUN dnf copr enable -y pmtk0/microshift-io-nightly && \
    dnf update -y && \
    XY="$(dnf repoquery microshift  --quiet --queryformat '%{version}-%{release}'  --latest-limit 1 | cut -d'.' -f1-2)" && \
    export XY && \
    basearch='$basearch' envsubst < /tmp/rhocp.repo > "/etc/yum.repos.d/rhocp-${XY}.repo" && \
    rm -vf /tmp/rhocp.repo && \
    dnf install -y \
        --setopt=install_weak_deps=False \
        microshift microshift-kindnet \
        'greenboot-0.15.*' && \
    dnf clean all

ARG USHIFT_POSTINSTALL_SCRIPT=/tmp/postinstall.sh
COPY --chmod=755 ./src/rpm/postinstall.sh ${USHIFT_POSTINSTALL_SCRIPT}
RUN ${USHIFT_POSTINSTALL_SCRIPT} && rm -vf "${USHIFT_POSTINSTALL_SCRIPT}"

# The /var directory is shared with the container as an anonymous volume to enable
# idmap mounts under /var/lib/kubelet for containers using 'hostUsers: false'
VOLUME ["/var"]
