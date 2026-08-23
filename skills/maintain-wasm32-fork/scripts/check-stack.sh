#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "FAIL: $*" >&2
  exit 1
}

if (( $# < 1 )); then
  echo "usage: $0 <upstream-tag> [--complete] [--release-tag <fork-tag>]" >&2
  exit 2
fi

upstream_tag=$1
shift
require_complete=false
release_tag=
while (( $# > 0 )); do
  case $1 in
    --complete)
      require_complete=true
      shift
      ;;
    --release-tag)
      (( $# >= 2 )) || die "--release-tag requires a value"
      release_tag=$2
      shift 2
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

repo=$(git rev-parse --show-toplevel 2>/dev/null) || die "not inside a Git repository"
cd "$repo"
upstream_sha=$(git rev-parse --verify "${upstream_tag}^{commit}" 2>/dev/null) ||
  die "upstream tag not found: ${upstream_tag}"

canonical=(semantics tests build automation docs governance)
mapfile -t commits < <(git rev-list --reverse "${upstream_sha}..HEAD")
(( ${#commits[@]} > 0 )) || die "no wasm32 patches found above ${upstream_tag}"
(( ${#commits[@]} <= ${#canonical[@]} )) ||
  die "expected at most ${#canonical[@]} patches, found ${#commits[@]}"

if $require_complete && (( ${#commits[@]} != ${#canonical[@]} )); then
  die "complete stack requires ${#canonical[@]} patches, found ${#commits[@]}"
fi

if git rev-list --min-parents=2 "${upstream_sha}..HEAD" | grep -q .; then
  die "merge commits are not allowed in the wasm32 patch stack"
fi

declare -A path_owner=()
for index in "${!commits[@]}"; do
  commit=${commits[$index]}
  short=$(git rev-parse --short "$commit")
  subject=$(git log -1 --format=%s "$commit")
  body=$(git log -1 --format=%B "$commit")
  mapfile -t patch_values < <(sed -n 's/^Wasm32-Patch:[[:space:]]*//p' <<<"$body")
  mapfile -t upstream_values < <(sed -n 's/^Wasm32-Upstream:[[:space:]]*//p' <<<"$body")

  (( ${#patch_values[@]} == 1 )) || die "${short} must have exactly one Wasm32-Patch trailer"
  (( ${#upstream_values[@]} == 1 )) || die "${short} must have exactly one Wasm32-Upstream trailer"
  [[ ${patch_values[0]} == "${canonical[$index]}" ]] ||
    die "${short} layer is ${patch_values[0]}, expected ${canonical[$index]}"
  [[ ${upstream_values[0]} == "$upstream_tag" ]] ||
    die "${short} upstream is ${upstream_values[0]}, expected ${upstream_tag}"
  [[ ! $subject =~ ^(fixup!|squash!|WIP|wip) ]] || die "${short} has temporary subject: ${subject}"

  mapfile -t paths < <(git diff-tree --root --no-commit-id --name-only -r "$commit")
  (( ${#paths[@]} > 0 )) || die "${short} is empty"
  for path in "${paths[@]}"; do
    if [[ -n ${path_owner[$path]:-} ]]; then
      die "path ${path} is owned by both ${path_owner[$path]} and ${short}"
    fi
    path_owner[$path]=$short
  done

  printf 'PASS %-10s %s %s\n' "${patch_values[0]}" "$short" "$subject"
done

git diff --check "${upstream_sha}..HEAD"

if git cat-file -e HEAD:.github/workflows/wasm32-release-assets.yml 2>/dev/null; then
  workflow=.github/workflows/wasm32-release-assets.yml
  grep -qF 'GH_REPO: ${{ github.repository }}' "$workflow" ||
    die "release workflow does not bind GH_REPO to github.repository"
  grep -qF 'test "$GH_REPO" = "$GITHUB_REPOSITORY"' "$workflow" ||
    die "release workflow does not assert its repository binding"
  for command in view edit create upload; do
    grep -Eq "gh release ${command} .*--repo \"?\\\$GH_REPO\"?" "$workflow" ||
      die "gh release ${command} does not pass --repo explicitly"
  done
fi

if $require_complete; then
  [[ -f AGENTS.md ]] || die "AGENTS.md is missing"
  [[ -f skills/maintain-wasm32-fork/SKILL.md ]] || die "repository skill is missing"
  [[ -f WASM32.md ]] || die "WASM32.md is missing"
  grep -qF '## How to use the wasm artifacts' WASM32.md || die "artifact usage guide is missing"
fi

if [[ -n $release_tag ]]; then
  [[ $release_tag == "${upstream_tag}-wasm32."* ]] ||
    die "release tag ${release_tag} does not track upstream ${upstream_tag}"
  [[ -f "wasm32-release-notes/${release_tag}.md" ]] ||
    die "curated release note is missing for ${release_tag}"
  grep -qF "gh release download ${release_tag}" WASM32.md ||
    die "download example does not pin ${release_tag}"
  grep -qF "tag: ${release_tag}" WASM32.md ||
    die "Cabal source dependency does not pin ${release_tag}"
  grep -qF "git clone -b ${release_tag}" WASM32.md ||
    die "reproduction clone does not pin ${release_tag}"
  grep -qF "github:lambdasistemi/plutus/${release_tag}#wasm-plutus-core-test" WASM32.md ||
    die "Nix reproduction example does not pin ${release_tag}"
fi

echo "PASS: wasm32 patch stack is clear above ${upstream_tag} (${#commits[@]} patches)"
