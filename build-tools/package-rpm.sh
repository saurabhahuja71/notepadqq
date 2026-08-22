#!/bin/bash
set -euo pipefail

# Builds Notepadqq RPMs inside an Oracle Linux 8 / 9 / 10 container.
#
# Usage (run from the repo root):
#   build-tools/package-rpm.sh <version> [dist-dir]
#
#     version   release version without the leading "v" (e.g. 2.2.0)
#     dist-dir  directory that collects *.rpm and *.src.rpm (default: dist)
#
# Called by .github/workflows/release.yml (job `package-rpm`) but works
# standalone: docker run --rm -v "$PWD":/src -w /src oraclelinux:9 \
#   build-tools/package-rpm.sh 2.2.0

version="${1:?usage: package-rpm.sh <version> [dist-dir]}"
dist_dir="${2:-dist}"

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: version '${version}' is not in X.Y.Z form" >&2
    exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: must run as root (container default)" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Identify the target EL version
# ---------------------------------------------------------------------------
. /etc/os-release
el_ver="${VERSION_ID%%.*}"
case "${el_ver}" in
    8|9|10) ;;
    *)
        echo "ERROR: unsupported EL version '${el_ver}' (need Oracle Linux 8, 9 or 10)" >&2
        exit 1
        ;;
esac
echo "==> Building notepadqq ${version} for el${el_ver} on $(uname -m)"

# ---------------------------------------------------------------------------
# Enable repos: CodeReady Builder (devel headers) + EPEL
# ---------------------------------------------------------------------------

# Works with both dnf4 (--set-enabled) and dnf5 (setopt) syntax.
dnf_enable_repo() {
    local repo="$1"
    dnf config-manager --set-enabled "${repo}" 2>/dev/null ||
        dnf config-manager setopt "${repo}".enabled=1
}

dnf install -y -q dnf-plugins-core

echo "==> Enabling ol${el_ver}_codeready_builder"
dnf_enable_repo "ol${el_ver}_codeready_builder"

echo "==> Enabling EPEL"
if ! rpm -q "oracle-epel-release-el${el_ver}" >/dev/null 2>&1; then
    dnf install -y -q "oracle-epel-release-el${el_ver}" ||
        dnf install -y -q epel-release || {
            echo "ERROR: could not enable EPEL on el${el_ver}" >&2
            exit 1
        }
fi

# ---------------------------------------------------------------------------
# Install build dependencies
#
# qt6-qttools-devel provides Qt6LinguistTools (lrelease), which the CMake
# build requires. On OL9 its recommended companion qt6-doctools conflicts
# with Mesa's llvm-libs (LLVM 20 vs 21, see README); weak deps are disabled,
# with a hard exclusion as fallback, so doctools never enters the transaction.
# ---------------------------------------------------------------------------
base_pkgs=(
    gcc-c++
    make
    ninja-build
    rpm-build
    tar
    gzip
    desktop-file-utils
    dejavu-sans-fonts
    liberation-sans-fonts
)
qt_pkgs=(
    uchardet-devel
    qt6-qtbase-devel
    qt6-qt5compat-devel
    qt6-qtsvg-devel
    qt6-qttools-devel
    qt6-qtwebchannel-devel
    qt6-qtwebengine-devel
    qt6-qtwebsockets-devel
)

echo "==> Installing build dependencies"
dnf install -y --setopt=install_weak_deps=False "${base_pkgs[@]}" "${qt_pkgs[@]}" ||
    dnf install -y --setopt=install_weak_deps=False --exclude='qt6-doctools*' \
        "${base_pkgs[@]}" "${qt_pkgs[@]}"

if ! find /usr/bin /usr/lib64/qt6/bin -maxdepth 1 -name 'lrelease*' 2>/dev/null | grep -q .; then
    echo "ERROR: Qt6 LinguistTools (lrelease) missing after dependency install." >&2
    echo "       The el${el_ver} Qt packaging may have moved it; adjust qt_pkgs above." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Guarantee cmake >= 3.24 (OL8 AppStream ships 3.20). Uses the official
# Kitware binary tarball; both x86_64 and aarch64 builds are published.
# ---------------------------------------------------------------------------
cmake_satisfies=false
if command -v cmake >/dev/null 2>&1; then
    cmake_v="$(cmake --version | head -n1 | awk '{print $NF}')"
    if [[ "$(printf '%s\n3.24\n' "${cmake_v}" | sort -V | head -n1)" == "3.24" ]]; then
        cmake_satisfies=true
    fi
fi

if [[ "${cmake_satisfies}" != true ]]; then
    kitware_ver="3.29.6"
    kit_arch="$(uname -m)"
    url="https://github.com/Kitware/CMake/releases/download/v${kitware_ver}/cmake-${kitware_ver}-linux-${kit_arch}.tar.gz"
    echo "==> Distro cmake too old; installing ${url}"
    curl -fsSL --retry 3 -o /tmp/cmake-bin.tar.gz "${url}"
    mkdir -p /opt/cmake
    tar xzf /tmp/cmake-bin.tar.gz --strip-components=1 -C /opt/cmake
    export PATH="/opt/cmake/bin:${PATH}"
fi
cmake --version | head -n1

# ---------------------------------------------------------------------------
# rpmbuild
# ---------------------------------------------------------------------------
topdir="${PWD}/rpmbuild"
rm -rf "${topdir}"
mkdir -p "${topdir}/BUILD" "${topdir}/RPMS" "${topdir}/SOURCES" "${topdir}/SPECS" "${topdir}/SRPMS"

echo "==> Creating source tarball"
tar czf "${topdir}/SOURCES/notepadqq-${version}.tar.gz" \
    --transform "s,^\.,notepadqq-${version}," \
    --exclude='./.git' \
    --exclude='./build' \
    --exclude='./rpmbuild' \
    --exclude='./dist' \
    .

echo "==> rpmbuild -ba"
rpmbuild -ba \
    --define "_topdir ${topdir}" \
    --define "_sourcedir ${topdir}/SOURCES" \
    --define "nqq_version ${version}" \
    --define "dist .ol${el_ver}" \
    packaging/rpm/notepadqq.spec

# ---------------------------------------------------------------------------
# Collect artifacts
# ---------------------------------------------------------------------------
mkdir -p "${dist_dir}"
cp -a "${topdir}"/RPMS/*/*.rpm "${topdir}"/SRPMS/*.src.rpm "${dist_dir}/"

echo "==> Artifacts in ${dist_dir}:"
ls -lh "${dist_dir}"
for rpm in "${dist_dir}"/*.rpm; do
    rpm -qp --qf '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' "${rpm}"
done
