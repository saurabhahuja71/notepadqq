# <img src="https://user-images.githubusercontent.com/4319621/36906314-e3f99680-1e35-11e8-90fd-f959c9641f36.png" alt="Notepadqq" width="32" height="32" /> Notepadqq on Oracle Linux 9

> [!WARNING]
> Upstream Notepadqq is not actively maintained anymore. New maintainers are welcome.
> It has been reported that with the most recent OS/Qt versions, the program can crash unexpectedly. Use this at your own risk.
>  -- Daniele

This repository contains the **Notepadqq source code** (from [github.com/notepadqq/notepadqq](https://github.com/notepadqq/notepadqq), merged on 2026) plus build/package instructions for **Oracle Linux 9**, where the default EPEL packages cannot be installed side by side.

### Links

* [Build on Oracle Linux 9](#building-on-oracle-linux-9)
* [Upstream build instructions](#upstream-build-instructions)
* [Distribution packages](#distribution-packages)

### What is it?

Notepadqq is a text editor designed by developers, for developers. Notepad++-like editor for Linux.

![screenshot_20180302_163505](https://notepadqq.com/s/images/snapshot1.png)

Please visit our [Wiki](https://github.com/notepadqq/notepadqq/wiki) for more screenshots and details.

---

## Building on Oracle Linux 9

Build Notepadqq from source (and optionally package an RPM) on Oracle Linux 9.

> **Note:** Current Notepadqq uses **CMake + Qt 6**, not `./configure` / classic `make` and not Qt 5. There is no top-level `configure` script.

### Why the simple `dnf install` fails on OL9

This system has **Mesa built against LLVM 21**. EPEL's `qt6-qttools-devel` pulls `qt6-doctools`, which needs **LLVM 20**. Only one `llvm-libs` can be installed, so dnf stops with:

```text
cannot install both llvm-libs-20... and llvm-libs-21...
package qt6-doctools ... requires libLLVM.so.20.1
package mesa-compat-libxatracker ... requires libLLVM.so.21.1
```

**Do not** use `--allowerasing` — it can break graphics.

**Use the path below** (system packages without tools + Qt in your home directory).

### 1. Install system packages (skip `qt6-qttools-devel`)

```bash
sudo dnf config-manager --set-enabled ol9_codeready_builder

sudo dnf groupinstall "Development Tools" -y

# Intentionally omit qt6-qttools-devel (LLVM conflict on OL9)
sudo dnf install -y \
  cmake ninja-build git \
  qt6-qtbase-devel \
  qt6-qtwebengine-devel \
  qt6-qtwebsockets-devel \
  qt6-qtsvg-devel \
  qt6-qtwebchannel-devel \
  qt6-qt5compat-devel \
  uchardet-devel \
  pkgconf-pkg-config
```

If that still fails, drop the `qt6-*` packages from the list and rely entirely on the user-local Qt in step 2 (you still need `cmake`, `ninja-build`, `git`, `uchardet-devel`, `pkgconf-pkg-config`, and a C++ toolchain).

### 2. Install Qt 6 into `$HOME/Qt` (provides LinguistTools / lrelease)

Uses [aqtinstall](https://github.com/miurahr/aqtinstall) (no system LLVM change). Needs network and several GB of disk (WebEngine is large).

```bash
# aqt may already be installed; otherwise:
pip3 install --user aqtinstall
export PATH="$HOME/.local/bin:$PATH"

# Qt 6.6.x matches OL9 EPEL closely; includes tools + modules Notepadqq needs
aqt install-qt linux desktop 6.6.3 gcc_64 \
  -O "$HOME/Qt" \
  -m qtwebengine qtwebsockets qtsvg qtwebchannel qt5compat qtpositioning qtimageformats
```

After install you should have something like:

```text
$HOME/Qt/6.6.3/gcc_64
```

### 3. Get the source

The source lives in this repository, so a clone is already all you need:

```bash
git clone --recursive https://github.com/saurabhahuja71/notepadqq.git
cd notepadqq
```

Or use a local tree, for example:

```bash
cd ~/Downloads/notepadqq
```

### 4. Configure and build (CMake)

Point CMake at the user-local Qt:

```bash
export PATH="$HOME/.local/bin:$PATH"
export CMAKE_PREFIX_PATH="$HOME/Qt/6.6.3/gcc_64${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"

cmake --preset release
cmake --build --preset release
```

Debug build:

```bash
cmake --preset dev
cmake --build --preset dev
```

#### Run without installing

```bash
# Ensure the Qt libs from $HOME/Qt are found at runtime
export LD_LIBRARY_PATH="$HOME/Qt/6.6.3/gcc_64/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

./build/release/notepadqq
```

If the binary is nested (depends on generator layout), try:

```bash
find build/release -type f -name notepadqq -executable
```

#### Install (optional)

Default release preset installs under the build tree. For `/usr/local`:

```bash
cmake --preset release \
  -DCMAKE_PREFIX_PATH="$HOME/Qt/6.6.3/gcc_64" \
  -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build --preset release
sudo cmake --install build/release
```

You may still need `LD_LIBRARY_PATH` (or an rpath) so the app finds `$HOME/Qt` libraries when launched from the menu.

#### Tests (optional)

```bash
ctest --preset release
```

### 5. Build an RPM (optional)

#### Setup rpmbuild tree

```bash
sudo dnf install -y rpm-build rpmdevtools
rpmdev-setuptree
```

#### Stage files from CMake install

```bash
cd /path/to/notepadqq
export CMAKE_PREFIX_PATH="$HOME/Qt/6.6.3/gcc_64"

cmake --preset release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build --preset release

rm -rf ~/rpmbuild/BUILD/notepadqq-root
cmake --install build/release --prefix ~/rpmbuild/BUILD/notepadqq-root/usr
```

#### SPEC file sketch

Create `~/rpmbuild/SPECS/notepadqq.spec` and adjust `%files` after checking:

```bash
find ~/rpmbuild/BUILD/notepadqq-root -type f | head -50
```

```spec
Name:           notepadqq
Version:        2.2.0
Release:        1%{?dist}
Summary:        Notepad++-like editor for Linux

License:        GPLv3
BuildArch:      x86_64

# Prefer shipping/using the same Qt the binary was linked against.
# If linked to $HOME/Qt, package those libs or document LD_LIBRARY_PATH.

%description
Notepadqq is a text editor designed by developers, for developers.

%prep

%build

%install
mkdir -p %{buildroot}
cp -a %{_builddir}/notepadqq-root/* %{buildroot}/

%files
/usr/bin/notepadqq
/usr/share/notepadqq
/usr/share/applications/notepadqq.desktop
/usr/share/icons/hicolor/*
/usr/share/metainfo/*
/usr/share/man/man1/notepadqq.1*

%changelog
* Sun Jul 26 2026 - 2.2.0-1
- Build with CMake and Qt 6 on Oracle Linux 9
```

```bash
rpmbuild -bb ~/rpmbuild/SPECS/notepadqq.spec
sudo dnf install ~/rpmbuild/RPMS/x86_64/notepadqq-*.rpm
```

### 6. Troubleshooting

| Problem | Cause | Fix |
|---------|--------|-----|
| `./configure: No such file` | Not Autotools | Use CMake presets |
| `No makefile found` | Not configured yet | `cmake --preset release` first |
| dnf fails on `qt6-qttools-devel` / LLVM 20 vs 21 | EPEL tools vs Mesa | **Omit tools package**; use `$HOME/Qt` via aqt (sections 1–2) |
| CMake cannot find LinguistTools / Qt6 | Tools not on system | Set `CMAKE_PREFIX_PATH=$HOME/Qt/6.6.3/gcc_64` |
| App starts then fails on `.so` | Runtime libs | `export LD_LIBRARY_PATH=$HOME/Qt/6.6.3/gcc_64/lib` |
| You only want to **run** Notepadqq | No need to build | `sudo snap install notepadqq` |

### Quick reference (OL9, works around LLVM clash)

```bash
# 1) system deps without qt6-qttools-devel
sudo dnf install -y cmake ninja-build git \
  qt6-qtbase-devel qt6-qtwebengine-devel qt6-qtwebsockets-devel \
  qt6-qtsvg-devel qt6-qtwebchannel-devel qt6-qt5compat-devel \
  uchardet-devel pkgconf-pkg-config

# 2) user-local Qt (tools + webengine modules)
pip3 install --user aqtinstall
export PATH="$HOME/.local/bin:$PATH"
aqt install-qt linux desktop 6.6.3 gcc_64 -O "$HOME/Qt" \
  -m qtwebengine qtwebsockets qtsvg qtwebchannel qt5compat qtpositioning qtimageformats

# 3) build
cd ~/Downloads/notepadqq   # or your clone
export CMAKE_PREFIX_PATH="$HOME/Qt/6.6.3/gcc_64"
cmake --preset release
cmake --build --preset release

# 4) run
export LD_LIBRARY_PATH="$HOME/Qt/6.6.3/gcc_64/lib"
./build/release/notepadqq
```

---

## Upstream build instructions

| Build dependencies    | Dependencies      |
|-----------------------|-------------------|
| Qt 6.4 or higher      | Qt 6.4 or higher  |
| qt6-webengine5-dev    | qt6-webengine5    |
| qt6-websockets-dev    | qt6-websockets    |
| qt6-svg-dev           | qt6-svg           |
| qt6-tools-dev-tools   | coreutils         |
| libuchardet-dev       | libuchardet       |
| pkg-config            |                   |

```bash
cmake --preset release
cmake --build --preset release
```

Run tests:

```bash
ctest --preset release
```

Install:

```bash
sudo cmake --install build/release
```

For Ubuntu:

```bash
sudo apt-get install qt6-tools-dev qt6-tools-dev-tools qt6-webengine-dev qt6-websockets-dev libqt6svg6 libqt6svg6-dev libuchardet-dev pkg-config
```

For CentOS:

```bash
sudo dnf install -y qt6-qtbase-devel qt6-qttools-devel qt6-qtwebengine-devel qt6-qtwebsockets-devel qt6-qtsvg-devel qt6-qtwebchannel-devel uchardet pkgconfig
```

Building for **macOS**? Check [here](https://github.com/notepadqq/notepadqq/wiki/Compiling-Notepadqq-on-macOS).

#### Qt

If the newest version of Qt isn't available on your distribution, you can use the [online installer](http://www.qt.io/download-open-source) to get the latest libraries and install them into your home directory (`$HOME/Qt`). Notepadqq will automatically use them.

## Distribution packages

- **Ubuntu, Debian, and others:** `sudo apt install notepadqq`
- **Snap:** `sudo snap install notepadqq`
- **Arch Linux:** `sudo pacman -S notepadqq` (community), or AUR [notepadqq-git](https://aur.archlinux.org/packages/notepadqq-git/)
- **OpenSUSE:** `sudo zypper in notepadqq`
- **Solus:** `sudo eopkg it notepadqq`
- **Others:** use a package for a compatible distribution, or build from source.
  If you want to submit a package: https://github.com/notepadqq/notepadqq-packaging
