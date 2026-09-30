#!/usr/bin/env bash
set -euo pipefail

# Run as root inside a disposable Fedora container, never on the host.
if (( $# != 1 )); then
    echo "Usage: $0 /path/to/bambu-studio.rpm" >&2
    exit 2
fi
rpm_file="$(realpath "$1")"
test -f "$rpm_file"
test "$(rpm -qp --queryformat '%{NAME}' "$rpm_file")" = bambu-studio

check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT

rpm -K "$rpm_file"
rpm -qp --provides "$rpm_file" | tee "$check_dir/provides.txt"
rpm -qp --requires "$rpm_file" | tee "$check_dir/requires.txt"
if grep -E '^lib(avcodec|avutil|swresample|swscale)[.]so[.]' \
    "$check_dir/provides.txt" "$check_dir/requires.txt"; then
    echo 'Private FFmpeg libraries must not appear as public RPM dependencies.' >&2
    exit 1
fi
# Filtering private libraries must leave the system requirements intact.
grep -E '^libOSMesa[.]so[.]' "$check_dir/requires.txt"
grep -E '^libwebkit2gtk-4[.]1[.]so[.]' "$check_dir/requires.txt"

dnf install -y "$rpm_file"
rpm -V bambu-studio
test "$(readlink -f /usr/bin/bambu-studio)" = /opt/BambuStudio/bambu-studio
test -d /opt/BambuStudio/resources
test -f /usr/share/applications/BambuStudio.desktop
test -f /usr/share/licenses/bambu-studio/LICENSE
for size in 32 128 192; do
    test -f "/usr/share/icons/hicolor/${size}x${size}/apps/BambuStudio.png"
done
LD_LIBRARY_PATH=/opt/BambuStudio/bin \
    ldd /opt/BambuStudio/bin/bambu-studio | tee "$check_dir/ldd.txt"
if grep -F 'not found' "$check_dir/ldd.txt"; then
    echo 'The installed RPM has unresolved shared-library dependencies.' >&2
    exit 1
fi
bambu-studio --help

dnf remove -y bambu-studio
test ! -e /opt/BambuStudio
test ! -e /usr/bin/bambu-studio
test ! -L /usr/bin/bambu-studio
test ! -e /usr/share/applications/BambuStudio.desktop
dnf install -y "$rpm_file"
rpm -V bambu-studio
bambu-studio --help
