#!/usr/bin/env bash

set -euo pipefail

usage() {
    echo "Usage:"
    echo "$(basename "$0") OKD_RELEASE_IMAGE_X86_64 OKD_VERSION_TAG COPR_REPO_NAME"
    exit 1
}

if [ $# -ne 3 ] ; then
    usage
fi

OKD_RELEASE_IMAGE_X86_64="${1}"
OKD_VERSION_TAG="${2}"
COPR_REPO_NAME="${3}"

cli_sha=$(oc adm release info -o json "${OKD_RELEASE_IMAGE_X86_64}:${OKD_VERSION_TAG}" | jq -r '.references.spec.tags[] | select(.name == "cli") | .annotations."io.openshift.build.commit.id"')
cli_sha_short="${cli_sha:0:8}"

rpm_version="$(echo "${OKD_VERSION_TAG}" | cut -d'-' -f1)" # Major.Minor.0
rpm_release="g${cli_sha_short}_${OKD_VERSION_TAG}"         # E.g., g12345678_4.22.0-okd-scos.ec.5
os_git_version="${rpm_version}-${rpm_release}"
rpm_release="${rpm_release//-/_}"

major="$(echo "${OKD_VERSION_TAG}" | cut -d'.' -f1)"
minor="$(echo "${OKD_VERSION_TAG}" | cut -d'.' -f2)"

expected_pkg_version="${rpm_version}-${rpm_release}"
latest_build_version=$(copr-cli get-package --name openshift-clients --with-latest-succeeded-build "${COPR_REPO_NAME}" \
                         | jq -r '.latest_succeeded_build.source_package.version')

# Because this script is meant for building nightly packages,
# it should be enough to check latest build.
if [[ "${latest_build_version}" == "${expected_pkg_version}" ]]; then
   echo "Package ${latest_build_version} already present in the COPR repository"
   exit 0
fi

git init oc
cd oc
git remote add origin https://github.com/openshift/oc.git
git fetch origin --quiet  --filter=tree:0 --tags "${cli_sha}"
git checkout "${cli_sha}"

rpmbuild_dir="$(git rev-parse --show-toplevel)/_output/rpmbuild"
mkdir -p "${rpmbuild_dir}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

tarball="openshift-clients-${rpm_version}.tar.gz"
tar -czf "${rpmbuild_dir}/SOURCES/${tarball}" \
        --exclude='.git' \
        --exclude='_output' \
        --transform="s|^|openshift-clients-${rpm_version}/|"  \
        --exclude="${tarball}" .


cat > "${rpmbuild_dir}/SPECS/oc.spec" <<EOF
%{!?version: %global version ${rpm_version}}
%{!?release: %global release ${rpm_release}}

%{!?commit:
%global commit ${cli_sha}
}

%if ! 0%{?os_git_vars:1}
%global os_git_vars OS_GIT_VERSION='${os_git_version}' OS_GIT_COMMIT='${cli_sha}' OS_GIT_MAJOR='${major}' OS_GIT_MINOR='${minor}' OS_GIT_TREE_STATE='clean'
%endif

EOF

echo "#### oc.spec preamble"
cat "${rpmbuild_dir}/SPECS/oc.spec"
echo "####"

cat /oc.spec >> "${rpmbuild_dir}/SPECS/oc.spec"
rpmbuild  -bs --define "_topdir ${rpmbuild_dir}"  "${rpmbuild_dir}/SPECS/oc.spec"

if copr-cli build --timeout 3600 "${COPR_REPO_NAME}" "${rpmbuild_dir}"/SRPMS/openshift-clients-*.src.rpm; then
    copr-cli regenerate-repos "${COPR_REPO_NAME}"
else
    exit 1
fi
