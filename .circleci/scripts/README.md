# CircleCI Scripts

このディレクトリには、CircleCIワークフローで使用されるスクリプトが含まれています。

## スクリプト一覧

### setup-github-auth.sh
GitHub認証をセットアップするスクリプト。

**認証方法:**
1. **OIDC/GitHub App統合**（第1優先）
   - CircleCIのGitHub App統合による自動認証
   - トークン設定不要

2. **GITHUB_TOKEN環境変数**（第2優先）
   - CircleCIのプロジェクト設定で`GITHUB_TOKEN`を設定
   - Personal Access Token（PAT）を使用

### comment-on-pr.sh
PRにビルド結果とカバレッジ情報をコメントするスクリプト。

**カバレッジ情報のパース:**
- `parse-coverage.py`（Python3）を使用
- JSONの正確なパースが可能
- **要件:** Python3が必須

**環境変数:**
- `CIRCLE_PULL_REQUEST`: PR URL
- `CIRCLE_PROJECT_USERNAME`: GitHubユーザー名
- `CIRCLE_PROJECT_REPONAME`: リポジトリ名
- `CIRCLE_WORKFLOW_ID`: ワークフローID
- `CIRCLE_JOB`: ジョブ名
- `CIRCLE_BUILD_NUM`: ビルド番号
- `CIRCLE_BRANCH`: ブランチ名
- `CIRCLE_BUILD_URL`: ビルドURL
- `AUTH_METHOD`: 認証方法（OIDC or PAT）

### parse-coverage.py
カバレッジ情報をJSONからパースするPython3スクリプト。

**入力:** `coverage/coverage-summary.json`

**出力形式:**
```
<total_statements>|<total_branches>|<total_functions>|<total_lines>
FILE|<file_path>|<statements>|<branches>|<functions>|<lines>
...
```

**使用例:**
```bash
python3 .circleci/scripts/parse-coverage.py
```

## テスト方法

### カバレッジパースのテスト
```bash
# カバレッジデータを生成
cd /path/to/project
yarn test:coverage

# Python3でパース
python3 .circleci/scripts/parse-coverage.py
```

### コメント生成のテスト
```bash
# Mock環境変数でスクリプトを実行
CIRCLE_PULL_REQUEST="https://github.com/user/repo/pull/1" \
CIRCLE_WORKFLOW_ID="test-workflow" \
CIRCLE_JOB="test-job" \
CIRCLE_BUILD_NUM="123" \
CIRCLE_BRANCH="test-branch" \
AUTH_METHOD="TEST" \
CIRCLE_PROJECT_USERNAME="user" \
CIRCLE_PROJECT_REPONAME="repo" \
CIRCLE_BUILD_URL="https://test.com" \
bash .circleci/scripts/comment-on-pr.sh
```

## トラブルシューティング

### Python3が見つからないエラー
```
ERROR: Python3 is required for coverage parsing but was not found
```
- CircleCIのDockerイメージにPython3が含まれていることを確認
- 標準の`cimg/node`イメージにはPython3が含まれています

### カバレッジ情報が表示されない
- `coverage/coverage-summary.json`が存在するか確認
- Jestの`coverageReporters`に`json-summary`が含まれているか確認
- `parse-coverage.py`が正常に実行できるか確認

### Artifacts URLが404になる
- CircleCIのビルド番号とワークフローIDが正しいか確認
- ビルドが完了しているか確認
