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

    # Python3の存在チェック
    if ! command -v python3 > /dev/null 2>&1; then
      echo "❌ ERROR: Python3 is required for coverage parsing but was not found"
      echo "Please ensure Python3 is installed in your CircleCI environment"
      exit 1
    fi

    # Python3でカバレッジをパース
    echo "Parsing coverage with Python3..."
    COVERAGE_DATA=$(python3 .circleci/scripts/parse-coverage.py)

    if [ -z "$COVERAGE_DATA" ]; then
      echo "❌ ERROR: Failed to parse coverage data"
      exit 1
    fi

    echo "Coverage data parsed successfully"

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

    # パース詳細セクション（オプション）
    PARSE_DETAILS=$(cat <<EOF

<details>
<summary>📋 Coverage Data (Click to expand)</summary>

**Raw Coverage Data:**
\`\`\`
${COVERAGE_DATA}
\`\`\`

</details>
EOF
)

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
${PARSE_DETAILS}
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
