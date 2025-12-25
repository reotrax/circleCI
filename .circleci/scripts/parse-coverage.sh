#!/bin/bash
set -e

# カバレッジファイルのパスを引数から取得、またはデフォルト値を設定
COVERAGE_FILE="${1:-coverage/coverage-summary.json}"

# カバレッジファイルの存在確認
if [ ! -f "$COVERAGE_FILE" ]; then
  echo "❌ エラー: カバレッジファイルが見つかりません: $COVERAGE_FILE"
  echo "現在のディレクトリ: $(pwd)"
  echo "ディレクトリの内容:"
  ls -la "$(dirname "$COVERAGE_FILE")" 2>/dev/null || echo "ディレクトリにアクセスできません"
  exit 1
fi

# jqの存在確認
if ! command -v jq &> /dev/null; then
  echo "❌ エラー: jq コマンドが必要ですが見つかりません"
  echo "jq バージョン: $(jq --version 2>/dev/null || echo 'Not found')"
  echo "パス: $(which jq 2>/dev/null || echo 'Not in PATH')"
  exit 1
fi

# デバッグ情報
echo "=== カバレッジ解析を開始します ==="
echo "カバレッジファイル: $COVERAGE_FILE"

# 全体カバレッジを抽出
TOTAL_STATEMENTS=$(jq -r '.total.statements.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_BRANCHES=$(jq -r '.total.branches.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_FUNCTIONS=$(jq -r '.total.functions.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_LINES=$(jq -r '.total.lines.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")

# 数値チェック
re='^[0-9]+([.][0-9]+)?$'
if ! [[ $TOTAL_STATEMENTS =~ $re ]]; then TOTAL_STATEMENTS=0; fi
if ! [[ $TOTAL_BRANCHES =~ $re ]]; then TOTAL_BRANCHES=0; fi
if ! [[ $TOTAL_FUNCTIONS =~ $re ]]; then TOTAL_FUNCTIONS=0; fi
if ! [[ $TOTAL_LINES =~ $re ]]; then TOTAL_LINES=0; fi

# 全体カバレッジを出力
echo "${TOTAL_STATEMENTS}|${TOTAL_BRANCHES}|${TOTAL_FUNCTIONS}|${TOTAL_LINES}"

# ファイルごとのカバレッジを抽出
jq -r 'to_entries[] | 
  select(.key != "total" and (.key | contains("src/"))) | 
  "FILE|\(.key)|\(.value.statements.pct)|\(.value.branches.pct)|\(.value.functions.pct)|\(.value.lines.pct)"' \
  "$COVERAGE_FILE" 2>/dev/null || echo "WARN: ファイルごとのカバレッジ情報を抽出できませんでした"

echo "=== カバレッジ解析が完了しました ==="
