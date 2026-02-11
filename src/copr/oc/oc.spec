#debuginfo not supported with Go
%global debug_package %{nil}
# modifying the Go binaries breaks the DWARF debugging
%global __os_install_post %{_rpmconfigdir}/brp-compress

%global gopath      %{_datadir}/gocode
%global import_path github.com/openshift/oc

%global golang_version 1.13

%{!?version: %global version 0.0.1}
%{!?release: %global release 1}

%{!?commit:
# DO NOT MODIFY: the value on the line below is sed-like replaced by openshift/doozer
%global commit e0a5699f2049372633b18c43a98a522999b1f297
}

%if ! 0%{?os_git_vars:1}
# DO NOT MODIFY: the value on the line below is sed-like replaced by openshift/doozer
%global os_git_vars OS_GIT_VERSION='' OS_GIT_COMMIT='' OS_GIT_MAJOR='' OS_GIT_MINOR='' OS_GIT_TREE_STATE=''
%endif

%if "%{os_git_vars}" == "ignore"
%global make make
%else
%global make %{os_git_vars} && make SOURCE_GIT_TAG:="${OS_GIT_VERSION}" SOURCE_GIT_COMMIT:="${OS_GIT_COMMIT}" SOURCE_GIT_MAJOR:="${OS_GIT_MAJOR}" SOURCE_GIT_MINOR:="${OS_GIT_MINOR}" SOURCE_GIT_TREE_STATE:="${OS_GIT_TREE_STATE}"
%endif

Name:           openshift-clients
Version:        %{version}
Release:        %{release}%{dist}
Summary:        OpenShift client binaries
License:        ASL 2.0
URL:            https://%{import_path}

%if ! 0%{?local_build:1}
Source0:        https://%{import_path}/archive/%{commit}/%{name}-%{version}.tar.gz
%endif

# If go_arches not defined fall through to implicit golang archs
%if 0%{?go_arches:1}
ExclusiveArch:  %{go_arches}
%else
ExclusiveArch:  x86_64 aarch64 ppc64le s390x
%endif

BuildRequires:  golang >= %{golang_version}
BuildRequires:  krb5-devel
BuildRequires:  rsync

Provides:       atomic-openshift-clients = %{version}
Obsoletes:      atomic-openshift-clients <= %{version}
Requires:       bash-completion

%description
%{summary}

%prep
%if ! 0%{?local_build:1}
%setup -q
%endif

%build
%if ! 0%{?local_build:1}
mkdir -p "$(dirname __gopath/src/%{import_path})"
mkdir -p "$(dirname __gopath/src/%{import_path})"
ln -s "$(pwd)" "__gopath/src/%{import_path}"
export GOPATH=$(pwd)/__gopath:%{gopath}
cd "__gopath/src/%{import_path}"
%endif

%ifarch %{ix86}
GOOS=linux
GOARCH=386
%endif
%ifarch ppc64le
GOOS=linux
GOARCH=ppc64le
%endif
%ifarch %{arm} aarch64
GOOS=linux
GOARCH=arm64
%endif
%ifarch s390x
GOOS=linux
GOARCH=s390x
%endif
%{make} build GO_BUILD_PACKAGES:='./cmd/oc ./tools/genman'

%install
install -d %{buildroot}%{_bindir}

# Install for the local platform
install -p -m 755 ./oc %{buildroot}%{_bindir}/oc
ln -s ./oc %{buildroot}%{_bindir}/kubectl
[[ -e %{buildroot}%{_bindir}/kubectl ]]

# Install man1 man pages
install -d -m 0755 %{buildroot}%{_mandir}/man1
./genman %{buildroot}%{_mandir}/man1 oc

 # Install bash completions
install -d -m 755 %{buildroot}%{_sysconfdir}/bash_completion.d/
for bin in oc kubectl
do
  echo "+++ INSTALLING BASH COMPLETIONS FOR ${bin} "
  %{buildroot}%{_bindir}/${bin} completion bash > %{buildroot}%{_sysconfdir}/bash_completion.d/${bin}
  chmod 644 %{buildroot}%{_sysconfdir}/bash_completion.d/${bin}
done

%files
%license LICENSE
%{_bindir}/oc
%{_bindir}/kubectl
%{_sysconfdir}/bash_completion.d/oc
%{_sysconfdir}/bash_completion.d/kubectl
%dir %{_mandir}/man1/
%{_mandir}/man1/oc*

%changelog
* Tue Feb 10 2026 Patryk Matuszak <pmatusza@redhat.com> 4.22.0
- Make changes to oc.spec: remove windows & macos builds

* Tue Feb 10 2026 Patryk Matuszak <pmatusza@redhat.com> 4.22.0
- Take oc.spec from https://github.com/openshift/oc/blob/8b0a043216f7ae608606afb5bdb0ce451561021e/oc.spec
