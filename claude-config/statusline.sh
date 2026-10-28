#!/usr/bin/env bash
# Claude Code の status line。stdin に渡されるセッション情報の JSON から1行を組み立てる。
#
# 表示: <モデルID> <effort> │ <ブランチ> │ ctx <使用率>% │ 5h <使用率>% →<リセット時刻>
#   - モデルIDは先頭の "claude-" を省く
#   - 2つの使用率（ctx / 5h）だけ色を付ける: 70% 以上で黄、85% 以上で赤、それ未満は緑
#   - それ以外はすべて同じライトグレー
#   - 値が取れない項目（effort 非対応モデル、rate_limits が未到着など）は項目ごと省く
#
# 終了コードが 0 以外、または出力が空だと status line が空白になり原因が分からなくなる。
# そのため -e は付けず、どの経路でも exit 0 で終える。

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "statusline: jq が未導入です (apt-get install jq)"
  exit 0
fi

# 1項目1行で取り出す（空の項目も行として残るので、下の read と順番が対応する）。
# 時刻は jq の localtime で変換する。date -d は GNU 専用で、手元の macOS では動かないため。
fields="$(jq -r '
  (.model.id // "" | sub("^claude-"; "")),
  (.effort.level // ""),
  (.workspace.current_dir // .cwd // ""),
  (.context_window.used_percentage // "" | if . == "" then "" else round end),
  (.rate_limits.five_hour.used_percentage // "" | if . == "" then "" else round end),
  (.rate_limits.five_hour.resets_at // "" | if . == "" then "" else localtime | strftime("%H:%M") end)
' 2>/dev/null)" || {
  echo "statusline: 入力の JSON を読めませんでした"
  exit 0
}

{
  IFS= read -r model
  IFS= read -r effort
  IFS= read -r dir
  IFS= read -r ctx_pct
  IFS= read -r five_pct
  IFS= read -r five_reset
} <<<"$fields"

RESET=$'\033[0m'
GRAY=$'\033[37m'  # ライトグレー。使用率以外の全項目の色

# 使用率に応じた色。70% 以上で黄、85% 以上で赤。
pct_color() {
  if [ "$1" -ge 85 ]; then
    printf '\033[31m'
  elif [ "$1" -ge 70 ]; then
    printf '\033[33m'
  else
    printf '\033[32m'
  fi
}

sep=" │ "
out=""

append() {
  if [ -n "$out" ]; then
    out+="${sep}$1"
  else
    out="$1"
  fi
}

# モデルと effort
if [ -n "$model" ]; then
  seg="$model"
  [ -n "$effort" ] && seg+=" $effort"
  append "$seg"
fi

# ブランチ名。detached HEAD のときは短縮 SHA。git 管理外なら出さない。
if [ -n "$dir" ]; then
  branch="$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null || git -C "$dir" rev-parse --short HEAD 2>/dev/null)"
  [ -n "$branch" ] && append "$branch"
fi

# コンテキスト使用率
if [ -n "$ctx_pct" ]; then
  append "ctx $(pct_color "$ctx_pct")${ctx_pct}%${GRAY}"
fi

# 5時間枠の使用率とリセット時刻
if [ -n "$five_pct" ]; then
  seg="5h $(pct_color "$five_pct")${five_pct}%${GRAY}"
  [ -n "$five_reset" ] && seg+=" →${five_reset}"
  append "$seg"
fi

printf '%s%s%s\n' "$GRAY" "$out" "$RESET"
exit 0
