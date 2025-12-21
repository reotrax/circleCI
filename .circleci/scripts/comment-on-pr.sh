#!/bin/bash
set -e

# PRの場合のみ実行
if [ -n "$CIRCLE_PULL_REQUEST" ]; then
  # PR番号を抽出
  PR_NUMBER=$(echo $CIRCLE_PULL_REQUEST | sed 's/.*\/pull\///')

  echo "=== Posting comment to PR #$PR_NUMBER ==="
  echo "Authentication method used: $AUTH_METHOD"

  # カバレッジ情報を読み込む
  if [ -f "coverage/coverage-summary.json" ]; then
    echo "=== Reading coverage information ==="

    # Python3が利用可能かチェック
    if command -v python3 > /dev/null 2>&1; then
      echo "Using Python3 for JSON parsing"
      COVERAGE_DATA=$(python3 .circleci/scripts/parse-coverage.py)
    else
      echo "Python3 not found, using Bash fallback for JSON parsing"
      # Bashのみでパース（フォールバック）
      COVERAGE_JSON=$(cat coverage/coverage-summary.json)

      # Total coverageを抽出（totalブロック内から各メトリクスを抽出）
      TOTAL_STATEMENTS=$(echo "$COVERAGE_JSON" | sed 's/.*"total":{//' | grep -o '"statements":{[^}]*}' | grep -o '"pct":[0-9.]*' | head -1 | cut -d':' -f2)
      TOTAL_BRANCHES=$(echo "$COVERAGE_JSON" | sed 's/.*"total":{//' | grep -o '"branches":{[^}]*}' | grep -o '"pct":[0-9.]*' | head -1 | cut -d':' -f2)
      TOTAL_FUNCTIONS=$(echo "$COVERAGE_JSON" | sed 's/.*"total":{//' | grep -o '"functions":{[^}]*}' | grep -o '"pct":[0-9.]*' | head -1 | cut -d':' -f2)
      TOTAL_LINES=$(echo "$COVERAGE_JSON" | sed 's/.*"total":{//' | grep -o '"lines":{[^}]*}' | grep -o '"pct":[0-9.]*' | head -1 | cut -d':' -f2)

      # 出力形式をPythonスクリプトと同じにする
      COVERAGE_DATA="${TOTAL_STATEMENTS}|${TOTAL_BRANCHES}|${TOTAL_FUNCTIONS}|${TOTAL_LINES}"

      # ファイルごとのカバレッジを抽出
      while IFS= read -r line; do
        if [[ $line == *"src/"* ]]; then
          # ファイルパスを抽出
          FILE_PATH=$(echo "$line" | grep -o '"/[^"]*src/[^"]*"' | tr -d '"' | sed 's|.*/src/|src/|')

          if [ -n "$FILE_PATH" ]; then
            # そのファイルのカバレッジ情報を抽出
            FILE_STATEMENTS=$(echo "$line" | grep -o '"statements":{[^}]*"pct":[0-9.]*' | grep -o '[0-9.]*$')
            FILE_BRANCHES=$(echo "$line" | grep -o '"branches":{[^}]*"pct":[0-9.]*' | grep -o '[0-9.]*$')
            FILE_FUNCTIONS=$(echo "$line" | grep -o '"functions":{[^}]*"pct":[0-9.]*' | grep -o '[0-9.]*$')
            FILE_LINES=$(echo "$line" | grep -o '"lines":{[^}]*"pct":[0-9.]*' | grep -o '[0-9.]*$')

            COVERAGE_DATA="${COVERAGE_DATA}"$'\n'"FILE|${FILE_PATH}|${FILE_STATEMENTS}|${FILE_BRANCHES}|${FILE_FUNCTIONS}|${FILE_LINES}"
          fi
        fi
      done < coverage/coverage-summary.json
    fi

    # Total coverage
    IFS='|' read -r TOTAL_STATEMENTS TOTAL_BRANCHES TOTAL_FUNCTIONS TOTAL_LINES <<< "$(echo "$COVERAGE_DATA" | head -1)"

    echo "Total Coverage - Statements: $TOTAL_STATEMENTS%, Branches: $TOTAL_BRANCHES%, Functions: $TOTAL_FUNCTIONS%, Lines: $TOTAL_LINES%"

    # ファイルごとのカバレッジ詳細
    COVERAGE_DETAILS=""
    while IFS= read -r line; do
      if [[ $line == FILE* ]]; then
        IFS='|' read -r _ FILE_PATH FILE_STATEMENTS FILE_BRANCHES FILE_FUNCTIONS FILE_LINES <<< "$line"
        COVERAGE_DETAILS="${COVERAGE_DETAILS}| ${FILE_PATH} | ${FILE_STATEMENTS}% | ${FILE_BRANCHES}% | ${FILE_FUNCTIONS}% | ${FILE_LINES}% |"$'\n'
      fi
    done <<< "$COVERAGE_DATA"

    # Artifactsへのリンク（CircleCIの正しい形式）
    ARTIFACTS_URL="https://app.circleci.com/pipelines/github/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/${CIRCLE_BUILD_NUM}/workflows/${CIRCLE_WORKFLOW_ID}/jobs/${CIRCLE_BUILD_NUM}/artifacts"

    COVERAGE_SECTION=$(cat <<EOF

## 📊 Test Coverage Report (C1 - Statement Coverage)

### Overall Coverage
| Metric | Coverage |
|--------|----------|
| **Statements** | ${TOTAL_STATEMENTS}% |
| **Branches** | ${TOTAL_BRANCHES}% |
| **Functions** | ${TOTAL_FUNCTIONS}% |
| **Lines** | ${TOTAL_LINES}% |

### Coverage by File
| File | Statements | Branches | Functions | Lines |
|------|------------|----------|-----------|-------|
${COVERAGE_DETAILS}
[📁 View detailed HTML coverage report](${ARTIFACTS_URL})
EOF
)
  else
    COVERAGE_SECTION=""
  fi

  # ビルド結果のサマリーを作成
  COMMENT_BODY=$(cat <<EOF
## CircleCI Build Report

✅ Build successful

**Build Details:**
- **Workflow:** $CIRCLE_WORKFLOW_ID
- **Job:** $CIRCLE_JOB
- **Build Number:** $CIRCLE_BUILD_NUM
- **Branch:** $CIRCLE_BRANCH
- **Auth Method:** $AUTH_METHOD

**Results:**
- ✅ Linting passed
- ✅ Tests passed
- ✅ Build completed successfully
${COVERAGE_SECTION}

[View full build details]($CIRCLE_BUILD_URL)
EOF
)

  # GitHub CLIを使用してコメントを投稿
  echo "$COMMENT_BODY" | gh pr comment "$PR_NUMBER" --body-file -

  echo "✅ Comment posted to PR #$PR_NUMBER using $AUTH_METHOD authentication"
else
  echo "Not a pull request, skipping comment"
fi
