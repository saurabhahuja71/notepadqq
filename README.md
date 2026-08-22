# <img src="https://user-images.githubusercontent.com/4319621/36906314-e3f99680-1e35-11e8-90fd-f959c9641f36.png" alt="Notepadqq" width="32" height="32" /> Notepadqq on Oracle Linux 8 / 9 / 10

> [!WARNING]
> Upstream Notepadqq is not actively maintained anymore. New maintainers are welcome.
> It has been reported that with the most recent OS/Qt versions, the program can crash unexpectedly. Use this at your own risk.
>  -- Daniele

This repository contains the **Notepadqq source code** (from [github.com/notepadqq/notepadqq](https://github.com/notepadqq/notepadqq), merged on 2026) plus **RPM packaging for Oracle Linux 8, 9 and 10**. Every tagged release is built automatically by GitHub Actions inside official `oraclelinux` containers (x86_64 + aarch64), published as release assets, and shipped through a hosted **dnf/yum repository** so installs and updates are a one-liner.

### Links

* [Install via dnf (OL8 / OL9 / OL10)](#install-via-dnf-ol8--ol9--ol10)
* [Building on Oracle Linux](#building-on-oracle-linux)
* [Upstream build instructions](#upstream-build-instructions)
* [Distribution packages](#distribution-packages)

### What is it?

Notepadqq is a text editor designed by developers, for developers. Notepad++-like editor for Linux.

![screenshot_20180302_163505](https://notepadqq.com/s/images/snapshot1.png)

Please visit our [Wiki](https://github.com/notepadqq/notepadqq/wiki) for more screenshots and details.

---

## Install via dnf (OL8 / OL9 / OL10)

Add this repository's dnf repo definition once, then install and receive updates through normal `dnf upgrade`.

```bash
# OL10 ships dnf5:
sudo dnf config-manager addrepo --from-repofile=https://saurabhahuja71.github.io/notepadqq/notepadqq.repo

# OL8 / OL9 ship dnf4:
sudo yum-config-manager --add-repo=https://saurabhahuja71.github.io/notepadqq/notepadqq.repo

sudo dnf install -y notepadqq
```

The `.repo` file uses `$releasever`/`$basearch`, so the same definition serves el8/el9/el10 on x86_64 and aarch64 automatically. Packages are currently **unsigned** (`gpgcheck=0`); dnf prints a warning on first install.

Prefer grabbing the RPM by hand? Download `notepadqq-*.ol<N>.<arch>.rpm` from the project's [Releases](../../releases) page and `sudo dnf install ./notepadqp*.rpm` it.

---

## Building on Oracle Linux

Build Notepadqq from source on Oracle Linux 8 / 9 / 10. RPM packaging itself is automated (see [Packaging](#packaging-an-rpm)); this section covers local source builds and development.

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

### Packaging an RPM

RPMs are built automatically for **OL8 / OL9 / OL10 (x86_64 + aarch64)** on every tagged release by [`.github/workflows/release.yml`](.github/workflows/release.yml): GitHub-hosted runners execute each build inside official `oraclelinux:<8|9|10>` containers, `rpmbuild` compiles from source against that distro's Qt6 stack, artifacts are attached to the release, and repodata is republished to gh-pages so `dnf upgrade` picks up new versions.

Key files:

* [`packaging/rpm/notepadqq.spec`](packaging/rpm/notepadqq.spec) — EL8/9/10 spec (CMake + Qt6, runs tests in `%check`)
* [`build-tools/package-rpm.sh`](build-tools/package-rpm.sh) — container-side wrapper: enables CRB/EPEL, installs BuildRequires, works around the OL9 LLVM/qt6-doctools clash, supplies cmake ≥ 3.24 where missing

To reproduce a release build locally (no proxy needed, direct network):

```bash
docker run --rm -v "$PWD":/src -w /src oraclelinux:9 \
    build-tools/package-rpm.sh 2.2.0 dist
```

The produced RPM installs to the canonical upstream layout (`/usr/bin/notepadqq`, `/usr/share/notepadqq`, desktop file, metainfo, icons, man page) — see [PACKAGING.md](PACKAGING.md).

### 6. Troubleshooting

| Problem | Cause | Fix |
|---------|--------|-----|
| `./configure: No such file` | Not Autotools | Use CMake presets |
| `No makefile found` | Not configured yet | `cmake --preset release` first |
| dnf fails on `qt6-qttools-devel` / LLVM 20 vs 21 | EPEL tools vs Mesa | **Omit tools package**; use `$HOME/Qt` via aqt (sections 1–2). The CI wrapper handles this automatically with `install_weak_deps=False` |
| CMake cannot find LinguistTools / Qt6 | Tools not on system | Set `CMAKE_PREFIX_PATH=$HOME/Qt/6.6.3/gcc_64` |
| App starts then fails on `.so` | Runtime libs | `export LD_LIBRARY_PATH=$HOME/Qt/6.6.3/gcc_64/lib` |
| You only want to **run** Notepadqq | No need to build | Use the [dnf repository](#install-via-dnf-ol8--ol9--ol10) or `sudo snap install notepadqq` |
| `cmake` below 3.24 (OL8) | Old AppStream cmake | The CI wrapper installs Kitware's binary tarball; locally use the same or any cmake ≥ 3.24 |

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

- **Oracle Linux 8 / 9 / 10 (and RHEL-compatible EL):** this project's dnf repository — see [Install via dnf](#install-via-dnf-ol8--ol9--ol10)
- **Ubuntu, Debian, and others:** `sudo apt install notepadqq`
- **Snap:** `sudo snap install notepadqq`
- **Arch Linux:** `sudo pacman -S notepadqq` (community), or AUR [notepadqq-git](https://aur.archlinux.org/packages/notepadqq-git/)
- **OpenSUSE:** `sudo zypper in notepadqq`
- **Solus:** `sudo eopkg it notepadqq`
- **Others:** use a package for a compatible distribution, or build from source.
  If you want to submit a package: https://github.com/notepadqq/notepadqq-packaging
