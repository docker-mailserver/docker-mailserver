%global provider        github.com
%global project         bats-core
%global repo            bats-core

Name:           bats
Version:        1.3.0
Release:        1%{?dist}
Summary:        Bash Automated Testing System

Group:          Development/Libraries
License:        MIT
URL:            https://%{provider}/%{project}/%{repo}
Source0:        https://%{provider}/%{project}/%{repo}/archive/v%{version}.tar.gz

BuildArch:      noarch

Requires:       bash

%description
Bats is a TAP-compliant testing framework for Bash.
It provides a simple way to verify that the UNIX programs you write behave as expected.
Bats is most useful when testing software written in Bash, but you can use it to test any UNIX program.

%prep
%setup -q -n %{repo}-%{version}

%install
mkdir -p ${RPM_BUILD_ROOT}%{_prefix} ${RPM_BUILD_ROOT}%{_libexecdir} ${RPM_BUILD_ROOT}%{_mandir}
./install.sh ${RPM_BUILD_ROOT}%{_prefix}

%clean
rm -rf $RPM_BUILD_ROOT

%check

%files
%doc README.md LICENSE.md
%{_bindir}/%{name}
%{_libexecdir}/%{repo}
%{_mandir}/man1/%{name}.1.gz
%{_mandir}/man7/%{name}.7.gz

%changelog
* Tue Jul 08 2018 mbland <mbland@acm.org> - 1.1.0-1
- Increase version to match upstream release

* Mon Jun 18 2018 pixdrift <support@pixeldrift.net> - 1.0.2-1
- Increase version to match upstream release
- Relocate libraries to bats-core subdirectory

* Sat Jun 09 2018 pixdrift <support@pixeldrift.net> - 1.0.1-1
- Increase version to match upstream release

* Fri Jun 08 2018 pixdrift <support@pixeldrift.net> - 1.0.0-1
- Initial package build of forked (bats-core) github project
