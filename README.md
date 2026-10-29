# release-please-maintenance-branch-lab

release-please で保守ブランチ（`release/vX.Y`）を運用し、hotfix を出せるかの検証。
比較対象は [tagpr-maintenance-branch-lab](https://github.com/yuta-ishii-cm/tagpr-maintenance-branch-lab)（tagpr ＋ 自前の HOTFIX_RELEASE）。

- main: 機能リリース。release-please が minor を上げる（`release-please-config.json`）
- `release/vX.Y`: 保守ブランチ。release-please が patch を上げる（`release-please-config-maintenance.json`）
- `deploy/*/image-tag.jsonnet`: デプロイするイメージのタグ（versionFile 相当）
