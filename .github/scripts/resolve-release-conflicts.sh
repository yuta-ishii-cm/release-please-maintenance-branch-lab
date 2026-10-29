#!/usr/bin/env bash
# マージ中のコンフリクトのうち、release-please が更新するファイルだけのものを解消して git add する。
# - バージョンが書かれたファイル: 同期先と今回のリリースのうち、新しいバージョンの内容にする
# - CHANGELOG.md: 同期先の内容の、今回より古いバージョンの最初の節の手前に、今回の節を差し込む
#   （先頭に差し込むと、別系統の同期PRと同じ位置を書き換えるため、後からマージする側がコンフリクトする）
# それ以外のファイルがコンフリクトしていれば、そのファイル名を出力して 1 を返す（呼び出し側で merge --abort する）。
# 成功したら、残したバージョンを出力する。
# 使い方: resolve-release-conflicts.sh <同期先の ref> <今回のリリースのタグ>
set -euo pipefail
base_ref=$1
next_tag=$2
version="${next_tag#v}"
version_files=(.release-please-manifest.json version.txt deploy/dev/image-tag.jsonnet deploy/pro/image-tag.jsonnet)

conflicted=$(git diff --name-only --diff-filter=U)
others=$(grep -vxF -e CHANGELOG.md "${version_files[@]/#/-e}" <<< "$conflicted" || true)
if [ -n "$others" ]; then
  echo "$others"
  exit 1
fi

base_version=$(git show "${base_ref}:version.txt")
kept=$(printf '%s\n%s\n' "$base_version" "$version" | sort -V | tail -n 1)
if [ "$kept" = "$version" ]; then
  source_ref=$next_tag
else
  source_ref=$base_ref
fi
for f in "${version_files[@]}"; do
  git show "${source_ref}:${f}" > "$f"
done

# CHANGELOG.md から今回のバージョンの節（次の「## [」の手前まで）を取り出す
section=$(git show "${next_tag}:CHANGELOG.md" |
  awk -v head="## [${version}]" 'index($0, head) == 1 { p = 1 } p && /^## \[/ && index($0, head) != 1 { exit } p { print }')
git show "${base_ref}:CHANGELOG.md" > CHANGELOG.base
if grep -qF "## [${version}]" CHANGELOG.base; then
  cp CHANGELOG.base CHANGELOG.md
else
  at=$(grep -n '^## \[' CHANGELOG.base | while IFS=: read -r n header; do
    v=${header#'## ['}
    v=${v%%]*}
    v=${v#v}
    if [ "$v" != "$version" ] && [ "$(printf '%s\n%s\n' "$v" "$version" | sort -V | head -n 1)" = "$v" ]; then
      echo "$n"
      break
    fi
  done)
  if [ -n "$at" ]; then
    { head -n $((at - 1)) CHANGELOG.base; printf '%s\n\n' "$section"; tail -n +"$at" CHANGELOG.base; } > CHANGELOG.md
  else
    { cat CHANGELOG.base; printf '\n%s\n' "$section"; } > CHANGELOG.md
  fi
fi
rm CHANGELOG.base

git add CHANGELOG.md "${version_files[@]}"
echo "$kept"
