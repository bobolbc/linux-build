#!/bin/bash

if [[ "$DEBUG" == 1 ]]; then
  set -x
fi

usage() {
  echo "usage: $0 <release-version> [--force] [--dry-run]"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

RELEASE="$1"
COMMIT_FLAGS=""
TAG_FLAGS=""
PUSH_FLAGS=""
NO_DIRTY=1
shift

for arg; do
  case "$arg" in
    --force)
      TAG_FLAGS="$TAG_FLAGS --force"
      PUSH_FLAGS="$PUSH_FLAGS --force"
      NO_DIRTY=0
      ;;

    --dry-run)
      PUSH_FLAGS="$PUSH_FLAGS --dry-run"
      ;;

    *)
      usage
      ;;
  esac
done

if [[ "$NO_DIRTY" == "1" ]] && ! git diff-files --quiet; then
  echo "dirty working tree, commit changes"
  exit 1
fi

set -e

echo "Reading package versions..."
show_diff() {
  PREVIOUS="${!2/-g*/}"
  source Makefile.versions.mk
  NEW="${!2/-g*/}"

  if [[ "${PREVIOUS}" != "${NEW}" ]]; then
    echo "- https://github.com/ayufan-rock64/$1/compare/${PREVIOUS}..${NEW}"
  fi
}

git checkout Makefile.versions.mk
source Makefile.versions.mk
make generate-versions > Makefile.versions.mk

echo "Differences:"
( show_diff linux-u-boot LATEST_UBOOT_VERSION )
( show_diff linux-kernel LATEST_KERNEL_VERSION )
( show_diff linux-package LATEST_PACKAGE_VERSION )

echo "OK?"
read PROMPT

echo "Edit changeset:"
if which editor &>/dev/null; then
  editor RELEASE.md
else
  vi RELEASE.md
fi

echo "OK?"
read PROMPT

echo "Adding changes..."
git add RELEASE.md Makefile.versions.mk

echo "Creating tag..."
git add Makefile.versions.mk
cat <<EOF | git commit $COMMIT_FLAGS --allow-empty -F -
v$RELEASE

$(cat Makefile.versions.mk)
EOF

git tag "$RELEASE" $TAG_FLAGS

echo "Pushing..."
git push origin "$RELEASE" $PUSH_FLAGS
git push origin master $PUSH_FLAGS

echo "Done."
