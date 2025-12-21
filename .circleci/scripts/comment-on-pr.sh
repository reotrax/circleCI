#!/bin/bash
set -e

# PRの場合のみ実行
if [ -n "$CIRCLE_PULL_REQUEST" ]; then
  # PR番号を抽出
  PR_NUMBER=$(echo $CIRCLE_PULL_REQUEST | sed 's/.*\/pull\///')

  echo "=== Posting comment to PR #$PR_NUMBER ==="
  echo "Authentication method used: $AUTH_METHOD"

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
- ✅ Build completed successfully

[View full build details]($CIRCLE_BUILD_URL)
EOF
)

  # GitHub CLIを使用してコメントを投稿
  echo "$COMMENT_BODY" | gh pr comment "$PR_NUMBER" --body-file -

  echo "✅ Comment posted to PR #$PR_NUMBER using $AUTH_METHOD authentication"
else
  echo "Not a pull request, skipping comment"
fi
