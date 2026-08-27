#!/usr/bin/env bash
set -euo pipefail

# 複数worktreeで並行して動くClaude Codeセッションのうち、
# 「どのworktree/ブランチが、どのセッションIDに対応するか」を記録する。
# SessionStart（登録）とStop（要約タイトルの更新）の両方から同じスクリプトを呼ぶ。
#
# 出力先はworktree間で共有される git common dir 配下（`git worktree list`と同様、
# どのworktreeから見ても同じ場所に行き着く）。リポジトリのGit管理下には置かない
# （ローカルマシン固有のセッション情報であり、IaCの対象ではないため）。

# stdinのJSONから単純な文字列フィールドを取り出す。jqが未導入の環境でも動くように
# sedで済ませているため、値にダブルクォートやバックスラッシュを含む場合は考慮しない。
json_field() {
  sed -n "s/.*\"$1\":\"\\([^\"]*\\)\".*/\\1/p" | head -n1
}

# JSON文字列として埋め込む前にエスケープする（バックスラッシュ・ダブルクォートのみ）。
json_escape() {
  sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

payload="$(cat)"
cwd="$(printf '%s' "$payload" | json_field cwd)"
session_id="$(printf '%s' "$payload" | json_field session_id)"
transcript_path="$(printf '%s' "$payload" | json_field transcript_path)"

# cwdかsession_idが取れなければ何もしない（フック入力の形式が変わった場合のフェイルソフト）。
[ -n "$cwd" ] && [ -n "$session_id" ] || exit 0

# worktree間で共有される実体ディレクトリ。gitリポジトリでなければ何もしない。
common_dir="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || exit 0
out_dir="${common_dir}/claude-worktree-sessions"
mkdir -p "$out_dir"

branch="$(git -C "$cwd" branch --show-current 2>/dev/null || true)"

# タイトルは会話が進むにつれて生成される。ユーザーが `/rename` 等で名前を変えていれば
# custom-titleを優先し、なければ最新のai-titleを使う（`claude --resume`の表示と同じ優先順位）。
# transcriptは1セッション分でも数MBになりうるが、tacで末尾から探すため実用上問題にならない。
title=""
if [ -n "${transcript_path:-}" ] && [ -f "$transcript_path" ]; then
  title="$(tac "$transcript_path" | grep -m1 '"type":"custom-title"' | json_field customTitle || true)"
  if [ -z "$title" ]; then
    title="$(tac "$transcript_path" | grep -m1 '"type":"ai-title"' | json_field aiTitle || true)"
  fi
fi

cwd_esc="$(printf '%s' "$cwd" | json_escape)"
branch_esc="$(printf '%s' "$branch" | json_escape)"
session_id_esc="$(printf '%s' "$session_id" | json_escape)"
title_esc="$(printf '%s' "$title" | json_escape)"

# worktreeごとに1ファイル。他worktreeのファイルとは独立しているため、
# マージ処理や排他制御なしに mktemp+mv だけで安全に更新できる。
slug="$(printf '%s' "$cwd" | sed 's#[^A-Za-z0-9]#_#g')"
out_file="${out_dir}/${slug}.json"
tmp_file="$(mktemp "${out_dir}/.${slug}.XXXXXX")"

cat > "$tmp_file" <<EOF
{
  "cwd": "${cwd_esc}",
  "branch": "${branch_esc}",
  "session_id": "${session_id_esc}",
  "title": "${title_esc}",
  "updated_at": "$(date -Iseconds)"
}
EOF

mv -f "$tmp_file" "$out_file"
