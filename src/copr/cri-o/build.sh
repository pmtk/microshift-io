#!/usr/bin/env bash

set -euo pipefail
set -x

#COPR_REPO_NAME="${COPR_REPO_NAME:-@microshift-io/microshift-nightly}"
COPR_REPO_NAME=pmtk0/test123

# TODO: Get max version based on Kubernetes version in the OKD release info

existing_crio_versions=$(copr-cli get-package --name cri-o --with-all-builds "${COPR_REPO_NAME}" \
                        | jq -r '.builds[].source_package.version')

existing_critools_versions=$(copr-cli get-package --name cri-tools --with-all-builds "${COPR_REPO_NAME}" \
                            | jq -r '.builds[].source_package.version')

urls=()

trap "rm -fv /etc/yum.repos.d/cri-o.repo /etc/yum.repos.d/kubernetes.repo" EXIT

for minor in $(seq 32 35) ; do
    version="1.${minor}"
    cat <<EOF > /etc/yum.repos.d/cri-o.repo
[cri-o]
name=CRI-O
baseurl=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v${version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v${version}/rpm/repodata/repomd.xml.key
EOF

    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${version}/rpm/repodata/repomd.xml.key
EOF

    # Get versions
    crio_verrel=$(dnf --disablerepo='*' --enablerepo='cri-o' repoquery --qf '%{VERSION}-%{RELEASE}' --latest-limit=1 cri-o)
    critools_verrel=$(dnf --disablerepo='*' --enablerepo='kubernetes' repoquery --qf '%{VERSION}-%{RELEASE}' --latest-limit=1 cri-tools)

    crio_srpm_url="https://download.opensuse.org/repositories/isv:/cri-o:/stable:/v${version}/rpm/src/cri-o-${crio_verrel}.src.rpm"
    critools_srpm_url="https://download.opensuse.org/repositories/isv:/kubernetes:/core:/stable:/v${version}/rpm/src/cri-tools-${critools_verrel}.src.rpm"

    if ! grep -q "${crio_verrel}" <<< "${existing_crio_versions}"; then
        urls+=("${crio_srpm_url}")
    fi

    if ! grep -q "${critools_verrel}" <<< "${existing_critools_versions}"; then
        urls+=("${critools_srpm_url}")
    fi
done

if [[ ${#urls[@]} -gt 0 ]]; then
    if copr-cli build "${COPR_REPO_NAME}" "${urls[@]}"; then
        copr-cli regenerate-repos "${COPR_REPO_NAME}"
    else
        exit 1
    fi
fi
