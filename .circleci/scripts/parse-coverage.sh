#!/bin/bash
set -e

# カバレッジファイルのパスを引数から取得、またはデフォルト値を設定
COVERAGE_FILE="${1:-coverage/coverage-summary.json}"

# カバレッジファイルの存在確認
if [ ! -f "$COVERAGE_FILE" ]; then
  echo "❌ エラー: カバレッジファイルが見つかりません: $COVERAGE_FILE" >&2
  exit 1
fi

# jqの存在確認
if ! command -v jq &> /dev/null; then
  echo "❌ エラー: jq コマンドが必要ですが見つかりません" >&2
  exit 1
fi

# 全体カバレッジを抽出
TOTAL_STATEMENTS=$(jq -r '.total.statements.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_BRANCHES=$(jq -r '.total.branches.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_FUNCTIONS=$(jq -r '.total.functions.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_LINES=$(jq -r '.total.lines.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")

# 数値チェック（nullや不正な値を0に置換）
re='^[0-9]+([.][0-9]+)?$'
[[ $TOTAL_STATEMENTS =~ $re ]] || TOTAL_STATEMENTS=0
[[ $TOTAL_BRANCHES =~ $re ]] || TOTAL_BRANCHES=0
[[ $TOTAL_FUNCTIONS =~ $re ]] || TOTAL_FUNCTIONS=0
[[ $TOTAL_LINES =~ $re ]] || TOTAL_LINES=0

# 全体カバレッジを出力（フォーマットを固定）
printf "%s|%s|%s|%s\n" "$TOTAL_STATEMENTS" "$TOTAL_BRANCHES" "$TOTAL_FUNCTIONS" "$TOTAL_LINES"

# ファイルごとのカバレッジを抽出（最大10ファイル）
jq -r 'to_entries[] | 
  select(.key != "total" and (.key | contains("src/") or contains("test/"))) | 
  "\(.key)|\(.value.statements.pct // 0)|\(.value.branches.pct // 0)|\(.value.functions.pct // 0)|\(.value.lines.pct // 0)"' \
  "$COVERAGE_FILE" 2>/dev/null | head -n 10
