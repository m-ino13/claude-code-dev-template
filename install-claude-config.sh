#!/usr/bin/env bash
set -euo pipefail

# 実プロジェクトを clone した後に一度実行し、テンプレート同梱の
# claude-config/ 一式を <project>/.claude/ へコピーする。
#
# setup.sh とは別スクリプトにしている理由：
#   setup.sh はプロジェクト名を決める段階（実プロジェクトを clone する前）に動くため、
#   コピー先の <project>/ がまだ存在しない。実プロジェクト clone 後に改めて実行する。
#
# 使い方:
#   ./install-claude-config.sh <project-dir>
#   例: ./install-claude-config.sh myapp

cd "$(dirname "$0")"

PROJECT_DIR="${1:-}"
if [ -z "$PROJECT_DIR" ]; then
  echo "使い方: $0 <project-dir>" >&2
  echo "例: $0 myapp" >&2
  exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
  echo "エラー: ディレクトリ '$PROJECT_DIR' が見つかりません。先に実プロジェクトを clone してください。" >&2
  exit 1
fi

DEST="${PROJECT_DIR}/.claude"

if [ -e "$DEST" ]; then
  echo "エラー: '${DEST}' は既に存在します。上書きしません。" >&2
  echo "        既存の設定と手動でマージするか、コピー先を確認してから再実行してください。" >&2
  exit 1
fi

echo "=> claude-config/ を ${DEST} へコピーします"
cp -r claude-config "$DEST"
chmod +x "${DEST}/hooks/"*.sh 2>/dev/null || true

echo "=> ${PROJECT_DIR}/.gitignore に .claude/worktrees/ を追記します"
GITIGNORE="${PROJECT_DIR}/.gitignore"
if ! grep -qxF '.claude/worktrees/' "$GITIGNORE" 2>/dev/null; then
  echo '.claude/worktrees/' >> "$GITIGNORE"
fi

echo
echo "=> 完了。${DEST} に以下が配置されました:"
find "$DEST" -type f | sed 's/^/   /'
echo
echo "プロジェクト側で確認・コミットしてください（git add ${DEST} .gitignore）。"
