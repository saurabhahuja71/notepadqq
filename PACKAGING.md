# Packaging Notes

## Canonical install layout

- executable: `/usr/bin/notepadqq`
- application data: `/usr/share/notepadqq`
- desktop file: `/usr/share/applications/notepadqq.desktop`
- metainfo: `/usr/share/metainfo/com.notepadqq.Notepadqq.metainfo.xml`

Upstream CMake installs the real executable directly as `notepadqq` and does not install a generic launcher wrapper.

## Packager responsibilities

Distribution-specific wrappers should only be added by packagers when they are required for that package format or runtime environment.

Historically, some packages used wrappers to apply desktop-environment-specific Qt workarounds such as:

- `QT_QPA_PLATFORMTHEME=""`
- `XDG_CURRENT_DESKTOP="GNOME"`

These are not treated as upstream runtime requirements. If a downstream package still needs one of these workarounds, keep it in that package's launcher, desktop entry, or equivalent runtime configuration.

## Snap

The Snap package keeps its own launcher and Qt runtime configuration under `snap/local/`. That logic is package-specific and intentionally remains outside the upstream CMake install rules.

## RPM (Oracle Linux 8 / 9 / 10)

The spec lives at `packaging/rpm/notepadqq.spec` and is built by `build-tools/package-rpm.sh` inside `oraclelinux:8|9|10` containers from `.github/workflows/release.yml` (job `package-rpm`, x86_64 + aarch64).

- The RPM follows the canonical layout above; no distro-specific launcher wrapper is added.
- Built with `-DCMAKE_BUILD_TYPE=Release -DNQQ_BUILD_TESTS=ON`; `%check` runs the ctest suite offscreen and validates the desktop file.
- Debuginfo packages are disabled to keep the published dnf repository small.
- Version is injected via `--define 'nqq_version X.Y.Z'`; Release is `1%{?dist}` with `%dist` forced to `.ol<N>`.

## dnf repository (gh-pages)

On every release, the `publish-dnf-repo` job rebuilds the yum/dnf repository on the `gh-pages` branch:

```
rpm/el8/x86_64/*.rpm + repodata/
rpm/el8/aarch64/...
rpm/el9/...
rpm/el10/...
notepadqq.repo
index.html
```

Users point dnf at `notepadqq.repo`, which uses `$releasever`/`$basearch`. Packages are currently unsigned (`gpgcheck=0`); adding signing later means importing a GPG key in the publisher job, enabling `rpmsign` + signed `repomd.xml`, shipping the public key, and flipping `gpgcheck=1`.
