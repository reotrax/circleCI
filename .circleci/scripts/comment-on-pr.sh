#!/bin/bash
set -e

# PRの場合のみ実行
if [ -n "$CIRCLE_PULL_REQUEST" ]; then
  # PR番号を抽出
  PR_NUMBER=$(echo $CIRCLE_PULL_REQUEST | sed 's/.*\/pull\///')

  echo "=== PR #$PR_NUMBER にコメントを投稿中 ==="
  echo "認証方法: $AUTH_METHOD"

  # カバレッジ情報を読み込む
  if [ -f "coverage/coverage-summary.json" ]; then
    echo "=== カバレッジ情報を読み込み中 ==="

    # Python3の存在チェック
    if ! command -v python3 > /dev/null 2>&1; then
      echo "❌ エラー: カバレッジ解析にはPython3が必要ですが、見つかりませんでした"
      echo "CircleCI環境にPython3がインストールされていることを確認してください"
      exit 1
    fi

    # Python3でカバレッジをパース
    echo "Python3でカバレッジを解析中..."
    COVERAGE_DATA=$(python3 .circleci/scripts/parse-coverage.py)

    if [ -z "$COVERAGE_DATA" ]; then
      echo "❌ エラー: カバレッジデータの解析に失敗しました"
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
