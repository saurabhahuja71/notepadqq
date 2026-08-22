# Notepadqq RPM spec — targets Oracle Linux / RHEL / EL clones 8, 9 and 10.
#
# This spec is built by build-tools/package-rpm.sh inside oraclelinux:8/9/10
# containers (see .github/workflows/release.yml, job `package-rpm`). The
# wrapper script:
#   * enables ol<N>_codeready_builder and EPEL,
#   * installs the BuildRequires below against that distro's Qt6 stack,
#   * supplies a cmake >= 3.24 when the distro ships an older one (OL8),
#   * passes the released version via `--define 'nqq_version X.Y.Z'`.
#
# Building outside the wrapper requires satisfying those prerequisites
# yourself; see README.md ("Building on Oracle Linux") for the manual path.

# ui-tests need a working offscreen WebEngine (GL stack); CI containers run
# with --without ui_tests because OpenGL context creation is unreliable there.
%bcond_without ui_tests

Name:           notepadqq
Version:        %{?nqq_version}%{!?nqq_version:2.2.0}
Release:        1%{?dist}
Summary:        A Notepad++-like source code editor for Linux

License:        GPL-3.0-or-later
URL:            https://github.com/notepadqq/notepadqq
Source0:        %{name}-%{version}.tar.gz

ExclusiveArch:  x86_64 aarch64

BuildRequires:  gcc-c++
BuildRequires:  make
BuildRequires:  ninja-build
BuildRequires:  cmake >= 3.24
BuildRequires:  desktop-file-utils
BuildRequires:  uchardet-devel
BuildRequires:  qt6-qtbase-devel
BuildRequires:  qt6-qt5compat-devel
BuildRequires:  qt6-qtsvg-devel
BuildRequires:  qt6-qttools-devel
BuildRequires:  qt6-qtwebchannel-devel
BuildRequires:  qt6-qtwebengine-devel
BuildRequires:  qt6-qtwebsockets-devel

%description
Notepadqq is a Notepad++-like text editor for Linux. It offers syntax
highlighting for many languages, session restore, search and replace across
files, and a JavaScript extension API.

# Distro flag sets (incl. LTO on newer EL) slow the WebEngine link down for no
# benefit here; the app is packaged as shipped upstream.
%global _lto_cflags %{nil}

# Debuginfo would roughly double the size of every published repo mirror for
# little value in an application package; keep the dnf repo lean.
%global debug_package %{nil}


%prep
%setup -q -n %{name}-%{version}


%build
cmake -S . -B redhat-linux-build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=%{_prefix} \
    -DNQQ_BUILD_TESTS=ON
cmake --build redhat-linux-build %{?_smp_mflags}


%install
DESTDIR=%{buildroot} cmake --install redhat-linux-build


%check
export QT_QPA_PLATFORM=offscreen
export QTWEBENGINE_DISABLE_SANDBOX=1
export QTWEBENGINE_CHROMIUM_FLAGS=%{?nqq_chromium_flags}--no-sandbox
ctest --test-dir redhat-linux-build --output-on-failure -R cpp-correctness-tests
%if %{with ui_tests}
ctest --test-dir redhat-linux-build --output-on-failure -R ui-tests
%endif
desktop-file-validate %{buildroot}%{_datadir}/applications/notepadqq.desktop


%files
%license COPYING
%doc README.md
%{_bindir}/notepadqq
%{_datadir}/applications/notepadqq.desktop
%{_datadir}/metainfo/com.notepadqq.Notepadqq.metainfo.xml
%dir %{_datadir}/notepadqq
%{_datadir}/notepadqq/editor/
%{_datadir}/notepadqq/extension_tools/
%{_mandir}/man1/notepadqq.1*
%{_datadir}/icons/hicolor/*/apps/notepadqq.png
%{_datadir}/icons/hicolor/scalable/apps/notepadqq.svg


%changelog
* Fri Aug 21 2026 Notepadqq Release Automation <release@notepadqq.invalid> - 2.2.0-1
- Automated EL8/EL9/EL10 packaging via CMake/Qt6 build; see release notes for
  per-version changes.
