#!/bin/sh
set -eu

release_tag="${1:?release tag required}"

case "$release_tag" in
  *[!A-Za-z0-9._-]*)
    echo "ERROR: release tag contains unsupported characters: $release_tag" >&2
    exit 20
    ;;
esac

head_commit="$(git rev-parse --verify HEAD^{commit})"
remote_commit="$(git ls-remote --tags origin "refs/tags/$release_tag^{}" | awk '{print $1; exit}')"
if [ -z "$remote_commit" ]; then
  remote_commit="$(git ls-remote --tags origin "refs/tags/$release_tag" | awk '{print $1; exit}')"
fi

if [ -n "$remote_commit" ]; then
  if [ "$remote_commit" != "$head_commit" ]; then
    echo "ERROR: release tag $release_tag already points at $remote_commit, not current HEAD $head_commit" >&2
    echo "Create a new immutable release tag instead of moving an existing public tag." >&2
    exit 21
  fi

  needs_fetch=true
  if git show-ref --verify --quiet "refs/tags/$release_tag"; then
    local_commit="$(git rev-parse --verify "refs/tags/$release_tag^{commit}")"
    if [ "$local_commit" != "$head_commit" ]; then
      git tag -d "$release_tag"
    else
      needs_fetch=false
    fi
  fi
  if [ "$needs_fetch" = true ]; then
    git fetch --no-tags origin "refs/tags/$release_tag:refs/tags/$release_tag"
  fi
else
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git tag "$release_tag" "$head_commit"
  git push origin "refs/tags/$release_tag"
fi

tag_commit="$(git rev-parse --verify "refs/tags/$release_tag^{commit}")"
if [ "$tag_commit" != "$head_commit" ]; then
  echo "ERROR: release tag $release_tag resolved to $tag_commit, expected $head_commit" >&2
  exit 22
fi

echo "release_tag=$release_tag"
echo "tag_commit=$tag_commit"
