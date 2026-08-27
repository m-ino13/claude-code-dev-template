#!/usr/bin/env bash
set -euo pipefail

# このテンプレートを clone した直後に一度だけ実行するセットアップスクリプト。
# - __PROJECT_NAME__ プレースホルダをリポジトリ内の全ファイル・ディレクトリ名に反映
# - Claude 専用 SSH 鍵を .ssh/ に生成
# - 完了後、このスクリプト自身と README.template.md を削除する

cd "$(dirname "$0")"

if [ -f .setup-done ]; then
  echo "既に setup 済みです（.setup-done が存在）。再実行するには .setup-done を削除してください。" >&2
  exit 1
fi

read -rp "プロジェクト名 (例: myapp): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
  echo "プロジェクト名が空です。中断します。" >&2
  exit 1
fi
if ! [[ "$PROJECT_NAME" =~ ^[a-z0-9_-]+$ ]]; then
  echo "プロジェクト名は英小文字・数字・ハイフン・アンダースコアのみにしてください。" >&2
  exit 1
fi

echo "=> テキスト内のプレースホルダを置換します"
grep -rl '__PROJECT_NAME__' --exclude-dir=.git . 2>/dev/null | while read -r f; do
  sed -i "s/__PROJECT_NAME__/${PROJECT_NAME}/g" "$f"
done

echo "=> ディレクトリ名を置換します"
if [ -d "__PROJECT_NAME__" ]; then
  mv "__PROJECT_NAME__" "${PROJECT_NAME}"
fi

echo "=> Claude 専用 SSH 鍵を生成します（.ssh/id_ed25519）"
if [ ! -f ".ssh/id_ed25519" ]; then
  ssh-keygen -t ed25519 -f ".ssh/id_ed25519" -N "" -C "claude@${PROJECT_NAME}"
else
  echo "   既に鍵が存在するためスキップします"
fi

cat > .setup-done <<EOF
project_name=${PROJECT_NAME}
setup_at=$(date -Iseconds)
EOF

echo
echo "=> 完了。次の手順:"
echo "   1. .ssh/id_ed25519.pub の内容を Git ホスティング側に登録する"
echo "   2. git clone <実際のプロジェクトのリポジトリURL> ${PROJECT_NAME}"
echo "   3. docker compose up -d"
echo
echo "このスクリプト自身を削除します。再実行はできません。"
rm -- "$0"
