notepadqq

Build Notepadqq RPM on Oracle Linux 9
This document describes how to build an RPM package for Notepadqq from source on Oracle Linux 9.

1. Install build dependencies

sudo dnf groupinstall "Development Tools" -y
sudo dnf install -y \
git qt5-qtbase-devel qt5-qtsvg-devel qt5-qttools-devel \
qt5-qtdeclarative-devel qt5-qtxmlpatterns-devel \
qt5-qtwebengine-devel qt5-qtwebchannel-devel \
qt5-qtwebsockets-devel uchardet-devel \
rpm-build rpmdevtools
Enable CRB repo (if packages missing):

sudo dnf config-manager --set-enabled ol9_codeready_builder

2. Clone source

git clone https://github.com/notepadqq/notepadqq.git 
cd notepadqq

3. Build

./configure
make -j$(nproc)
sudo make install
Installed to:

/usr/local/bin/notepadqq
/usr/local/share/notepadqq
/usr/local/lib/notepadqq

4. Setup rpmbuild tree

rpmdev-setuptree

Creates:

~/rpmbuild/
 ├── BUILD
 ├── RPMS
 ├── SOURCES
 ├── SPECS
 └── SRPMS

5. Create staging root

mkdir -p ~/rpmbuild/BUILD/notepadqq-root 
sudo cp -a /usr/local/* ~/rpmbuild/BUILD/notepadqq-root/

6. Create SPEC file

~/rpmbuild/SPECS/notepadqq.spec

Contents:

Name:           notepadqq
Version:        2.0.0
Release:        1%{?dist}
Summary:        Notepadqq editor

License:        GPLv3
BuildArch:      x86_64

Requires: qt5-qtbase qt5-qtwebengine qt5-qtsvg uchardet

%global __brp_mangle_shebangs_exclude_from /share/applications/mimeinfo.cache

%description
Notepadqq editor for Linux

%prep

%build

%install
mkdir -p %{buildroot}
cp -a %{_builddir}/notepadqq-root/* %{buildroot}/

%files
/bin/notepadqq
/lib/notepadqq
/share/notepadqq
/share/applications/notepadqq.desktop
%exclude /share/applications/mimeinfo.cache
/share/icons/hicolor/*
/share/metainfo/notepadqq.appdata.xml

%changelog
* Mon Apr 13 2026
- Initial build

7. Build RPM

rpmbuild -bb ~/rpmbuild/SPECS/notepadqq.spec
Output:
~/rpmbuild/RPMS/x86_64/notepadqq-2.0.0-1.el9.x86_64.rpm

8. Install RPM

sudo dnf install ~/rpmbuild/RPMS/x86_64/notepadqq-*.rpm

9. Run

notepadqq