#!/usr/bin/env bash
# マージ中のコンフリクトのうち、release-please が更新するファイルだけのものを解消して git add する。
# - バージョンが書かれたファイル: 同期先の内容のまま残す。release-please は manifest の値を、その
#   ブランチの前回のリリースとみなすため、保守ブランチのバージョンにすると main のリリースの起点がずれる
# - CHANGELOG.md: 同期先の内容に、同期先に無い節をバージョン順の位置に差し込む
#   （先頭に差し込むと、別系統の同期PRと同じ位置を書き換えるため、後からマージする側がコンフリクトする）
# それ以外のファイルがコンフリクトしていれば、そのファイル名を出力して 1 を返す（呼び出し側で merge --abort する）。
# 成功したら、残した（同期先の）バージョンを出力する。
# 使い方: resolve-release-conflicts.sh <同期先の ref> <今回のリリースのタグ>
set -euo pipefail
base_ref=$1
next_tag=$2
version_files=(.release-please-manifest.json version.txt deploy/dev/image-tag.jsonnet deploy/pro/image-tag.jsonnet)

conflicted=$(git diff --name-only --diff-filter=U)
others=$(grep -vxF -e CHANGELOG.md "${version_files[@]/#/-e}" <<< "$conflicted" || true)
if [ -n "$others" ]; then
  echo "$others"
  exit 1
fi

for f in "${version_files[@]}"; do
  git show "${base_ref}:${f}" > "$f"
done

# 同期元の CHANGELOG.md にあって同期先に無い節を、すべて差し込む。
# 同じ保守ブランチの古い同期PRを閉じて置き換えた場合、前のバージョンの節も同期先にまだ無いため
git show "${next_tag}:CHANGELOG.md" > CHANGELOG.next
git show "${base_ref}:CHANGELOG.md" > CHANGELOG.md
grep '^## \[' CHANGELOG.next | while read -r header; do
  v=${header#'## ['}
  v=${v%%]*}
  v=${v#v}
  if grep -qE "^## \[v?${v//./\\.}\]" CHANGELOG.md; then
    continue
  fi
  section=$(awk -v v="$v" '
    function ver(line,   x) { x = substr(line, 5); sub(/\].*/, "", x); sub(/^v/, "", x); return x }
    /^## / { if (p) exit; if (/^## \[/ && ver($0) == v) p = 1 }
    p { print }' CHANGELOG.next)
  # 今回より古いバージョンの最初の節の手前に差し込む（無ければ末尾）
  at=$(grep -n '^## \[' CHANGELOG.md | while IFS=: read -r n line; do
    w=${line#'## ['}
    w=${w%%]*}
    w=${w#v}
    if [ "$(printf '%s\n%s\n' "$w" "$v" | sort -V | head -n 1)" = "$w" ]; then
      echo "$n"
      break
    fi
  done)
  if [ -n "$at" ]; then
    { head -n $((at - 1)) CHANGELOG.md; printf '%s\n\n' "$section"; tail -n +"$at" CHANGELOG.md; } > CHANGELOG.tmp
  else
    { cat CHANGELOG.md; printf '\n%s\n' "$section"; } > CHANGELOG.tmp
  fi
  mv CHANGELOG.tmp CHANGELOG.md
done
rm CHANGELOG.next

git add CHANGELOG.md "${version_files[@]}"
git show "${base_ref}:version.txt"
