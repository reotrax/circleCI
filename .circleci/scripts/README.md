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

**カバレッジ情報のパース方法:**
1. **Python3を使用**（推奨）
   - `parse-coverage.py`を実行
   - JSONの正確なパースが可能

2. **Bash（フォールバック）**
   - Python3が利用できない環境での代替手段
   - sedとgrepを使用したJSONパース
   - Python3と同じ出力形式を保証

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

### Bashフォールバックのテスト
```bash
# Python3を使わずにBashのみでカバレッジをパース
cd /path/to/project
COVERAGE_JSON=$(cat coverage/coverage-summary.json)
TOTAL_STATEMENTS=$(echo "$COVERAGE_JSON" | sed 's/.*"total":{//' | grep -o '"statements":{[^}]*}' | grep -o '"pct":[0-9.]*' | head -1 | cut -d':' -f2)
echo "Statements: $TOTAL_STATEMENTS%"
```

### Python版とBash版の比較
```bash
echo "=== Python version ==="
python3 .circleci/scripts/parse-coverage.py

echo "=== Bash version ==="
# Bashフォールバックのコードを実行
```

## トラブルシューティング

### カバレッジ情報が表示されない
- `coverage/coverage-summary.json`が存在するか確認
- Jestの`coverageReporters`に`json-summary`が含まれているか確認

### Artifacts URLが404になる
- CircleCIのビルド番号とワークフローIDが正しいか確認
- ビルドが完了しているか確認
