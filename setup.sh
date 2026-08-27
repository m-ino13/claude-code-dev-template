#!/usr/bin/env bash
set -euo pipefail

# このテンプレートを clone した直後に一度だけ実行するセットアップスクリプト。
# - __PROJECT_NAME__ プレースホルダをリポジトリ内の全ファイルの中身に反映
# - リモートリポジトリの有無に応じて、実プロジェクト用ディレクトリを未作成のまま
#   残す（後で git clone する）か、その場で git init するかを分ける
# - Claude 専用 SSH 鍵を .ssh/ に生成
# - 完了後、このスクリプト自身を削除する

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

echo
read -rp "実プロジェクトのリモートリポジトリは既にありますか？ (y/N): " HAS_REMOTE
if [[ "$HAS_REMOTE" =~ ^[Yy]$ ]]; then
  # git clone は対象ディレクトリが存在しないか空であることを要求するため、
  # ディレクトリ自体をここでは作らない（次の手順で git clone がディレクトリを作る）。
  echo "=> ${PROJECT_NAME}/ はまだ作成しません。この後 'git clone <URL> ${PROJECT_NAME}' を実行してください。"
else
  # まだリモートがない＝これが最初のリポジトリになるケース。
  git init "${PROJECT_NAME}" >/dev/null
  echo "=> ${PROJECT_NAME}/ を新しい Git リポジトリとして初期化しました（リモートは未設定）。"
  echo "   後で 'git remote add origin <URL>' を実行してください。"
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
if [[ "$HAS_REMOTE" =~ ^[Yy]$ ]]; then
  echo "   2. git clone <実際のプロジェクトのリポジトリURL> ${PROJECT_NAME}"
else
  echo "   2. ${PROJECT_NAME}/ 内で作業を始め、コミットしたら git remote add origin <URL> で紐付ける"
fi
echo "   3. docker compose up -d"
echo
echo "このスクリプト自身を削除します。再実行はできません。"
rm -- "$0"
