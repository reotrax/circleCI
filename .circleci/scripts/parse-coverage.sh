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

# デバッグ用にカバレッジファイルの内容を表示
echo "=== カバレッジファイルの内容（先頭20行）==="
head -n 20 "$COVERAGE_FILE" || echo "ファイルの読み込みに失敗しました"
echo "======================================="

# 全体カバレッジを抽出
TOTAL_STATEMENTS=$(jq -r '.total.statements.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_BRANCHES=$(jq -r '.total.branches.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_FUNCTIONS=$(jq -r '.total.functions.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")
TOTAL_LINES=$(jq -r '.total.lines.pct' "$COVERAGE_FILE" 2>/dev/null || echo "0")

# デバッグ用に抽出した値を表示
echo "抽出した値:"
echo "STATEMENTS: $TOTAL_STATEMENTS"
echo "BRANCHES: $TOTAL_BRANCHES"
echo "FUNCTIONS: $TOTAL_FUNCTIONS"
echo "LINES: $TOTAL_LINES"

# 数値チェック（nullや不正な値を0に置換）
re='^[0-9]+([.][0-9]+)?$'
[[ $TOTAL_STATEMENTS =~ $re ]] || TOTAL_STATEMENTS=0
[[ $TOTAL_BRANCHES =~ $re ]] || TOTAL_BRANCHES=0
[[ $TOTAL_FUNCTIONS =~ $re ]] || TOTAL_FUNCTIONS=0
[[ $TOTAL_LINES =~ $re ]] || TOTAL_LINES=0

# 全体カバレッジを出力（フォーマットを固定）
printf "%s|%s|%s|%s\n" "$TOTAL_STATEMENTS" "$TOTAL_BRANCHES" "$TOTAL_FUNCTIONS" "$TOTAL_LINES"

# ファイルごとのカバレッジを抽出
jq -r 'to_entries[] | 
  select(.key != "total" and (.key | contains("src/") or contains("test/"))) | 
  "\(.key)|\(.value.statements.pct // 0)|\(.value.branches.pct // 0)|\(.value.functions.pct // 0)|\(.value.lines.pct // 0)"' \
  "$COVERAGE_FILE" 2>/dev/null || echo "WARN: ファイルごとのカバレッジ情報を抽出できませんでした"

echo "=== カバレッジ解析が完了しました ==="
