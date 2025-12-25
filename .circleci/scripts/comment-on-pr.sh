#!/usr/bin/env bash
set -euo pipefail

# エラーが発生した場合にスクリプトを終了する
handle_error() {
  echo "❌ エラーが発生しました: 行 $1 でエラーが発生しました。終了します。"
  exit 1
}

trap 'handle_error $LINENO' ERR

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# プロジェクトルートを正しく設定（.circleciの1つ上のディレクトリ）
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# デバッグ情報を表示
echo "=== デバッグ情報 ==="
echo "スクリプトの場所: $SCRIPT_DIR"
echo "プロジェクトルート: $PROJECT_ROOT"
echo "カレントディレクトリ: $(pwd)"
echo "CIRCLE_PULL_REQUEST: ${CIRCLE_PULL_REQUEST:-未設定}"

# 必要な環境変数のチェック
if [ -z "${CIRCLE_PULL_REQUEST:-}" ]; then
  echo "⚠️ CIRCLE_PULL_REQUEST が設定されていません。PRコメントはスキップされます。"
  exit 0
fi

# PR番号を抽出（GitHubのPR URLから）
if [[ "$CIRCLE_PULL_REQUEST" =~ \/([0-9]+)(\/|$) ]]; then
  PR_NUMBER="${BASH_REMATCH[1]}"
  echo "✅ PR番号を抽出しました: #$PR_NUMBER"
else
  echo "❌ エラー: PR番号を抽出できませんでした: $CIRCLE_PULL_REQUEST"
  echo "有効なPR URLを確認してください"
  exit 1
fi

# GitHub APIの認証トークン
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "❌ エラー: GITHUB_TOKEN が設定されていません"
  exit 1
fi

# カバレッジファイルのパスを検索
COVERAGE_FILE=""
POSSIBLE_PATHS=(
  "${PROJECT_ROOT}/coverage/coverage-summary.json"
  "${PROJECT_ROOT}/coverage/lcov-report/coverage-summary.json"
  "${PROJECT_ROOT}/coverage/coverage-final.json"
)

# カバレッジファイルを探す
for path in "${POSSIBLE_PATHS[@]}"; do
  if [ -f "$path" ]; then
    COVERAGE_FILE="$path"
    break
  fi
done

# カバレッジファイルが見つからない場合
if [ -z "$COVERAGE_FILE" ]; then
  echo "❌ エラー: カバレッジファイルが見つかりません。以下の場所を確認しました:"
  for path in "${POSSIBLE_PATHS[@]}"; do
    echo "  - $path"
  done
  echo "\nプロジェクトルート: $PROJECT_ROOT"
  echo "\nプロジェクトルートの内容:"
  ls -la "$PROJECT_ROOT"
  echo "\ncoverage ディレクトリの内容:"
  ls -la "${PROJECT_ROOT}/coverage/" 2>/dev/null || echo "  coverage ディレクトリが見つかりません"
  exit 1
fi

echo "✅ カバレッジファイルを見つけました: $COVERAGE_FILE"

echo "=== カバレッジ情報を読み込み中 ==="
echo "カバレッジファイル: $COVERAGE_FILE"

# jqの存在チェック
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ エラー: カバレッジ解析にはjqが必要ですが、見つかりませんでした"
  echo "jq バージョン: $(jq --version 2>/dev/null || echo 'Not found')"
  echo "パス: $(which jq 2>/dev/null || echo 'Not in PATH')"
  exit 1
fi

# パーサースクリプトのパス
PARSER_PATH="${SCRIPT_DIR}/parse-coverage.sh"

# パーサースクリプトの存在確認と実行権限の付与
if [ ! -f "$PARSER_PATH" ]; then
  echo "❌ エラー: パーサースクリプトが見つかりません: $PARSER_PATH"
  echo "スクリプトディレクトリの内容:"
  ls -la "$SCRIPT_DIR/"
  exit 1
fi
chmod +x "$PARSER_PATH"

# カレントディレクトリをプロジェクトルートに変更
cd "$PROJECT_ROOT"

# カバレッジデータを解析
echo "📊 カバレッジデータを解析中..."
COVERAGE_DATA=$("$PARSER_PATH" "$COVERAGE_FILE")

if [ -z "$COVERAGE_DATA" ]; then
  echo "❌ エラー: カバレッジデータの解析に失敗しました"
  exit 1
fi

# カバレッジデータをパース
{
  IFS='|' read -r statements branches functions lines <<< "$(echo "$COVERAGE_DATA" | head -n 1)"
  
  # カバレッジの閾値（必要に応じて調整）
  MIN_COVERAGE=80
  
  # カバレッジの色を決定（赤: < 80%, 黄: 80-89%, 緑: 90%+）
  get_coverage_color() {
    local coverage=$1
    if (( $(echo "$coverage < 80" | bc -l) )); then
      echo "#e05d44"  # 赤
    elif (( $(echo "$coverage < 90" | bc -l) )); then
      echo "#dfb317"  # 黄
    else
      echo "#4c1"     # 緑
    fi
  }
  
  # バッジを生成
  get_badge() {
    local label=$1
    local value=$2
    local color=$(get_coverage_color "${value%%.*}")
    echo "https://img.shields.io/badge/${label// /_}-${value}%25-${color:1}.svg"
  }
  
  # コメント本文を生成
  cat << EOM
## 📊 テストカバレッジレポート

| カテゴリ | カバレッジ | バッジ |
|----------|------------|--------|
| ステートメント | ${statements}% | ![]($(get_badge "Statements" "$statements")) |
| ブランチ | ${branches}% | ![]($(get_badge "Branches" "$branches")) |
| 関数 | ${functions}% | ![]($(get_badge "Functions" "$functions")) |
| 行 | ${lines}% | ![]($(get_badge "Lines" "$lines")) |

<details>
<summary>📝 ファイルごとの詳細</summary>

| ファイル | ステートメント | ブランチ | 関数 | 行 |
|----------|----------------|----------|------|----|
$(echo "$COVERAGE_DATA" | tail -n +2 | awk -F'|' '{ printf "| %s | %s%% | %s%% | %s%% | %s%% |\n", $2, $3, $4, $5, $6 }' | sort -t'|' -k3,3nr)

</details>

*このコメントは自動的に投稿されました*  
*Build: ${CIRCLE_BUILD_NUM:-N/A} | Workflow: ${CIRCLE_WORKFLOW_ID:-N/A}*
EOM
} > "${PROJECT_ROOT}/pr-comment.md"

# コメントを表示
echo "=== 生成されたコメント ==="
cat "${PROJECT_ROOT}/pr-comment.md"

# GitHub APIを使用してコメントを投稿
echo "\n=== GitHub PRにコメントを投稿中 ==="
COMMENT_URL="https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME:-${CIRCLE_PROJECT_USERNAME:-}}/${CIRCLE_PROJECT_REPONAME:-${CIRCLE_PROJECT_REPONAME:-}}/issues/${PR_NUMBER}/comments"
COMMENT_BODY=$(jq -n --arg body "$(cat "${PROJECT_ROOT}/pr-comment.md")" '{"body": $body}')

# デバッグ用にURLとボディを表示
echo "API URL: $COMMENT_URL"
echo "コメントボディの長さ: ${#COMMENT_BODY} 文字"

# コメントを投稿
RESPONSE=$(curl -sS -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "$COMMENT_BODY" \
  "$COMMENT_URL" 2>&1) || {
  echo "❌ コメントの投稿に失敗しました"
  echo "エラー詳細: $RESPONSE"
  exit 1
}

# レスポンスを確認
if echo "$RESPONSE" | jq -e '.id' >/dev/null 2>&1; then
  echo "✅ コメントを正常に投稿しました"
  echo "コメントURL: $(echo "$RESPONSE" | jq -r '.html_url')"
else
  echo "❌ コメントの投稿に失敗しました"
  echo "エラー: $RESPONSE"
  exit 1
fi

    echo "カバレッジデータの解析が完了しました"

    # Total coverage
    IFS='|' read -r TOTAL_STATEMENTS TOTAL_BRANCHES TOTAL_FUNCTIONS TOTAL_LINES <<< "$(echo "$COVERAGE_DATA" | head -1)"

    echo "全体カバレッジ - ステートメント: $TOTAL_STATEMENTS%, ブランチ: $TOTAL_BRANCHES%, 関数: $TOTAL_FUNCTIONS%, 行数: $TOTAL_LINES%"

    # ファイルごとのカバレッジ詳細
    COVERAGE_DETAILS=""
    while IFS= read -r line; do
      if [[ $line == FILE* ]]; then
        IFS='|' read -r _ FILE_PATH FILE_STATEMENTS FILE_BRANCHES FILE_FUNCTIONS FILE_LINES <<< "$line"
        COVERAGE_DETAILS="${COVERAGE_DETAILS}| ${FILE_PATH} | ${FILE_STATEMENTS}% | ${FILE_BRANCHES}% | ${FILE_FUNCTIONS}% | ${FILE_LINES}% |"$'\n'
      fi
    done <<< "$COVERAGE_DATA"

    # パース詳細セクション（オプション）
    PARSE_DETAILS=$(cat <<EOF

<details>
<summary>📋 カバレッジデータ (クリックで展開)</summary>

**生のカバレッジデータ:**
\`\`\`
${COVERAGE_DATA}
\`\`\`

</details>
EOF
)

    # Artifactsへのリンク（CircleCIの正しい形式）
    ARTIFACTS_URL="https://app.circleci.com/pipelines/github/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/${CIRCLE_BUILD_NUM}/workflows/${CIRCLE_WORKFLOW_ID}/jobs/${CIRCLE_BUILD_NUM}/artifacts"

    COVERAGE_SECTION=$(cat <<EOF

## 📊 テストカバレッジレポート

### 全体カバレッジ
| メトリクス | カバレッジ |
|--------|----------|
| **ステートメント** | ${TOTAL_STATEMENTS}% |
| **ブランチ** | ${TOTAL_BRANCHES}% |
| **関数** | ${TOTAL_FUNCTIONS}% |
| **行数** | ${TOTAL_LINES}% |

### ファイル別カバレッジ
| ファイル | ステートメント | ブランチ | 関数 | 行数 |
|------|------------|----------|-----------|-------|
${COVERAGE_DETAILS}
[📁 詳細なHTMLカバレッジレポートを表示](${ARTIFACTS_URL})
${PARSE_DETAILS}
EOF
)
  else
    COVERAGE_SECTION=""
  fi

  # ビルド結果のサマリーを作成
  COMMENT_BODY=$(cat <<EOF
## CircleCI ビルド結果

✅ ビルドが成功しました

**ビルド詳細:**
- **ワークフロー:** $CIRCLE_WORKFLOW_ID
- **ジョブ:** $CIRCLE_JOB
- **ビルド番号:** $CIRCLE_BUILD_NUM
- **ブランチ:** $CIRCLE_BRANCH
- **認証方法:** $AUTH_METHOD

**結果:**
- ✅ リンターが成功しました
- ✅ テストが成功しました
- ✅ ビルドが正常に完了しました
${COVERAGE_SECTION}

[ビルドの詳細を確認する]($CIRCLE_BUILD_URL)
EOF
)

  # GitHub CLIを使用してコメントを投稿
  echo "$COMMENT_BODY" | gh pr comment "$PR_NUMBER" --body-file -

  echo "✅ PR #$PR_NUMBER にコメントを投稿しました（認証方法: $AUTH_METHOD）"
else
  echo "プルリクエストではないため、コメントをスキップします"
fi
