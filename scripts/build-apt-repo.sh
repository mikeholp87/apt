#!/usr/bin/env bash
# Turn a directory of .deb files into a signed *flat* apt repository, plus the
# public key and a landing page.
#
#   GNUPGHOME=... APT_BASE_URL=https://owner.github.io/apt APT_KEYNAME=owner-apt \
#     bash scripts/build-apt-repo.sh <dir> <public-key.asc>
#
# The signing key is the first secret key in GNUPGHOME. After signing, the result
# is checked against <public-key.asc>, so publishing fails if the secret and the
# public key users trust ever disagree. Optional: APT_LABEL (Release Origin/Label).
set -euo pipefail

dir=${1:?usage: build-apt-repo.sh <dir> <public-key.asc>}
pubkey=$(realpath "${2:?usage: build-apt-repo.sh <dir> <public-key.asc>}")
here=$(dirname -- "$(realpath "$0")")
base=${APT_BASE_URL:?set APT_BASE_URL, e.g. https://owner.github.io/apt}
keyname=${APT_KEYNAME:-apt-repo}
label=${APT_LABEL:-apt repository}
# The template sits at the repo root in the central repo, in assets/central/ in the skill.
page_tpl=$here/../index.html.tpl
[[ -f $page_tpl ]] || page_tpl=$here/../assets/central/index.html.tpl

cd -- "$dir"
mapfile -d '' debs < <(find . -name '*.deb' -print0) # releases live in per-project/per-tag folders
if ((${#debs[@]} == 0)); then
	echo "No .deb files in $dir" >&2
	exit 1
fi

dpkg-scanpackages --multiversion . >Packages
gzip -9nkf Packages
archs=$(for d in "${debs[@]}"; do dpkg-deb -f "$d" Architecture; done | sort -u | tr '\n' ' ')
apt-ftparchive \
	-o APT::FTPArchive::Release::Origin="$label" \
	-o APT::FTPArchive::Release::Label="$label" \
	-o APT::FTPArchive::Release::Suite=stable \
	-o APT::FTPArchive::Release::Architectures="$archs" \
	-o APT::FTPArchive::Release::Description="$label" \
	release . >Release.new
mv Release.new Release

fingerprint=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr:/ { print $10; exit }')
test -n "$fingerprint" || {
	echo "No secret signing key found in GNUPGHOME" >&2
	exit 1
}
gpg --batch --yes --pinentry-mode loopback --default-key "$fingerprint" --clearsign -o InRelease Release
gpg --batch --yes --pinentry-mode loopback --default-key "$fingerprint" --armor --detach-sign -o Release.gpg Release

# Verify with only the public key users will trust.
verify=$(mktemp -d)
trap 'rm -rf -- "$verify"' EXIT
gpg --batch --no-default-keyring --keyring "$verify/trusted.gpg" --import "$pubkey" 2>/dev/null
gpgv --keyring "$verify/trusted.gpg" Release.gpg Release
gpgv --keyring "$verify/trusted.gpg" InRelease >/dev/null

cp -- "$pubkey" apt.asc

# Landing page: install snippet plus the packages actually in the repository.
esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
list=$(awk -F': ' '/^Package: /{p=$2} /^Description: /{print p "\t" $2}' Packages | sort -u |
	while IFS=$'\t' read -r p d; do printf '<li><code>%s</code> &mdash; %s</li>\n' "$p" "$(printf '%s' "$d" | esc)"; done)
shopt -u patsub_replacement 2>/dev/null || true # bash 5.2 would treat & in replacements as the match
page=$(<"$page_tpl")
page=${page//@BASE_URL@/$base}
page=${page//@KEYNAME@/$keyname}
page=${page//@LABEL@/$label}
page=${page//@PACKAGES@/$list}
printf '%s\n' "$page" >index.html
echo "Built signed apt repository: ${#debs[@]} package file(s), architectures: $archs"
