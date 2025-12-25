#!/bin/bash
set -e

# カバレッジファイルの存在確認
if [ ! -f "coverage/coverage-summary.json" ]; then
  echo "❌ エラー: カバレッジファイルが見つかりません"
  exit 1
fi

# jqの存在確認
if ! command -v jq &> /dev/null; then
  echo "❌ エラー: jq コマンドが必要ですが見つかりません"
  exit 1
fi

# 全体カバレッジを抽出
TOTAL_STATEMENTS=$(jq -r '.total.statements.pct' coverage/coverage-summary.json)
TOTAL_BRANCHES=$(jq -r '.total.branches.pct' coverage/coverage-summary.json)
TOTAL_FUNCTIONS=$(jq -r '.total.functions.pct' coverage/coverage-summary.json)
TOTAL_LINES=$(jq -r '.total.lines.pct' coverage/coverage-summary.json)

# 全体カバレッジを出力
echo "${TOTAL_STATEMENTS}|${TOTAL_BRANCHES}|${TOTAL_FUNCTIONS}|${TOTAL_LINES}"

# ファイルごとのカバレッジを抽出
jq -r 'to_entries[] | 
  select(.key != "total" and (.key | contains("src/"))) | 
  "FILE|\(.key)|\(.value.statements.pct)|\(.value.branches.pct)|\(.value.functions.pct)|\(.value.lines.pct)"' \
  coverage/coverage-summary.json
