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
    STATEMENTS=$(cat coverage/coverage-summary.json | grep -o '"statements":{"total":[0-9]*,"covered":[0-9]*,"skipped":[0-9]*,"pct":[0-9.]*' | grep -o '"pct":[0-9.]*' | cut -d':' -f2)
    BRANCHES=$(cat coverage/coverage-summary.json | grep -o '"branches":{"total":[0-9]*,"covered":[0-9]*,"skipped":[0-9]*,"pct":[0-9.]*' | grep -o '"pct":[0-9.]*' | cut -d':' -f2)
    FUNCTIONS=$(cat coverage/coverage-summary.json | grep -o '"functions":{"total":[0-9]*,"covered":[0-9]*,"skipped":[0-9]*,"pct":[0-9.]*' | grep -o '"pct":[0-9.]*' | cut -d':' -f2)
    LINES=$(cat coverage/coverage-summary.json | grep -o '"lines":{"total":[0-9]*,"covered":[0-9]*,"skipped":[0-9]*,"pct":[0-9.]*' | grep -o '"pct":[0-9.]*' | cut -d':' -f2)

    COVERAGE_SECTION=$(cat <<EOF

**Test Coverage (C1 - Statement Coverage):**
- **Statements:** ${STATEMENTS}%
- **Branches:** ${BRANCHES}%
- **Functions:** ${FUNCTIONS}%
- **Lines:** ${LINES}%

[View detailed coverage report]($CIRCLE_BUILD_URL/artifacts)
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

**Artifacts:**
- [View build artifacts]($CIRCLE_BUILD_URL/artifacts)

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
