#!/usr/bin/env bash
# Prove a stock apt accepts a signed flat repository: the signature verifies
# against the public key and the packages are offered. Private apt directories,
# so no root is needed.
#
#   test-apt-repo.sh <repo-dir> <public-key.asc> [package...]   local; also proves a tampered copy is rejected
#   test-apt-repo.sh <https://base/url> <public-key.asc> <package...>   live URL (package names required)
#
# With no package names, every package listed in the local Packages file is checked.
set -euo pipefail

repo=${1:?usage: test-apt-repo.sh <repo-dir|url> <public-key.asc> [package...]}
key=$(realpath "${2:?usage: test-apt-repo.sh <repo-dir|url> <public-key.asc> [package...]}")
shift 2
pkgs=("$@")
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

run_apt() { # <tool> <sources.list> <state-dir> args...
	local tool=$1 list=$2 state=$3
	shift 3
	mkdir -p "$state/lists/partial" "$work/cache/archives/partial"
	"$tool" -o "Dir::Etc::sourcelist=$list" -o "Dir::Etc::sourceparts=/dev/null" \
		-o "Dir::State=$state" -o "Dir::Cache=$work/cache" \
		-o "Dir::State::status=/var/lib/dpkg/status" -o "Debug::NoLocking=1" \
		-o "APT::Sandbox::User=" "$@"
}

if [[ $repo == http://* || $repo == https://* ]]; then
	live=1
	source_line="deb [signed-by=$key] ${repo%/}/ ./"
else
	live=0
	repo=$(realpath "$repo")
	source_line="deb [signed-by=$key] file:$repo ./"
	if ((${#pkgs[@]} == 0)); then
		mapfile -t pkgs < <(awk '/^Package: /{print $2}' <(zcat "$repo/Packages.gz") | sort -u)
	fi
fi
((${#pkgs[@]})) || {
	echo "No packages to check" >&2
	exit 2
}

echo "$source_line" >"$work/good.list"
run_apt apt-get "$work/good.list" "$work/state-good" update
for p in "${pkgs[@]}"; do
	run_apt apt-cache "$work/good.list" "$work/state-good" policy "$p" >"$work/policy.txt"
	grep -Eq 'Candidate: [0-9]' "$work/policy.txt" || {
		echo "FAIL: apt does not offer $p" >&2
		cat "$work/policy.txt" >&2
		exit 1
	}
	echo "OK: apt verified the signature and offers $p"
done

((live)) && exit 0
# A repository whose Packages file was altered after signing must be refused.
cp -r -- "$repo" "$work/tampered"
echo "# tampered" >>"$work/tampered/Packages"
gzip -9nkf "$work/tampered/Packages"
echo "deb [signed-by=$key] file:$work/tampered ./" >"$work/bad.list"
if run_apt apt-get "$work/bad.list" "$work/state-bad" update >"$work/bad.out" 2>&1; then
	if ! grep -Eqi 'hash sum mismatch|failed|error' "$work/bad.out"; then
		echo "FAIL: a tampered repository was accepted" >&2
		cat "$work/bad.out" >&2
		exit 1
	fi
fi
echo "OK: a tampered repository is rejected"
