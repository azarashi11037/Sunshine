# Fork and Distribution Notice

This repository is a modified version of
[LizardByte/Sunshine](https://github.com/LizardByte/Sunshine).

- Upstream base: `v2026.516.143833` (`14ffa6fd`)
- Initial modification date: 2026-07-29
- Fork maintainer: `azarashi11037`
- Initial fork release: `macos-hdr-v0.1.0`

## Modifications

The fork adds an experimental macOS ScreenCaptureKit HDR path using P010,
BT.2020, and PQ; enables parallel VideoToolbox HEVC Main10 encoding with a
bounded asynchronous queue; preserves delayed-frame timestamps; and supports
stable macOS display UUID selectors for virtual displays whose numeric IDs
change after reconnecting. It also uses a separate bundle identifier and adds
local build-bundle packaging fixes. [Upstream change
#5186](https://github.com/LizardByte/Sunshine/pull/5186) is backported to add
the Local Network usage description needed for Bonjour registration.

The changes are recorded in this repository's Git history. The fork does not
automatically receive later upstream changes.

## Independence and support

This fork is unofficial and is not affiliated with or endorsed by LizardByte.
Issues caused by this fork should be reported to
<https://github.com/azarashi11037/Sunshine/issues>, not to the upstream
project.

## License and source availability

Upstream copyright notices remain with their respective holders. This modified
version is distributed under the GNU General Public License v3.0 only
(`GPL-3.0-only`) and without warranty. Binary releases link to the exact tagged
source and retain `LICENSE` and `NOTICE`.

To obtain the release source, including pinned submodules:

```bash
git clone --recursive --branch macos-hdr-v0.1.0 https://github.com/azarashi11037/Sunshine.git
```

The macOS binary is ad-hoc signed with the fork bundle identifier
`local.sunshine.hdr-test`; it is not signed with LizardByte's certificate and is
not Apple-notarized.
