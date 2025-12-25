#!/usr/bin/env bash
set -euo pipefail

# jq のインストールチェックとインストール
if ! command -v jq &> /dev/null; then
    echo "jq がインストールされていません。インストールを試みます..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
            sudo apt-get update && sudo apt-get install -y jq
        elif [ "$ID" = "alpine" ]; then
            apk add --no-cache jq
        elif [ "$ID" = "centos" ] || [ "$ID" = "rhel" ]; then
            sudo yum install -y jq
        else
            echo "❌ サポートされていないOSです。手動でjqをインストールしてください。"
            exit 1
        fi
    else
        echo "❌ OSのバージョンを特定できませんでした。手動でjqをインストールしてください。"
        exit 1
    fi
fi

# エラーが発生した場合にスクリプトを終了する
handle_error() {
  local line_number=$1
  local exit_code=${2:-1}
  echo "❌ エラーが発生しました: 行 $line_number でエラーが発生しました。終了コード: $exit_code"
  echo "=== デバッグ情報 ==="
  echo "スクリプト: $0"
  echo "行番号: $line_number"
  echo "終了コード: $exit_code"
  echo "現在のディレクトリ: $(pwd)"
  echo "環境変数:"
  env | sort
  exit $exit_code
}

trap 'handle_error $LINENO $?' ERR

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
# パーサースクリプトの実行をデバッグ
set -x
COVERAGE_DATA=$("$PARSER_PATH" "$COVERAGE_FILE" 2>&1)
PARSER_EXIT_CODE=$?
set +x

if [ $PARSER_EXIT_CODE -ne 0 ] || [ -z "$COVERAGE_DATA" ]; then
  echo "❌ エラー: カバレッジデータの解析に失敗しました (終了コード: $PARSER_EXIT_CODE)"
  echo "=== パーサー出力開始 ==="
  echo "$COVERAGE_DATA"
  echo "=== パーサー出力終了 ==="
  
  # カバレッジファイルの内容を表示（デバッグ用）
  echo "\n=== カバレッジファイルの先頭100行 ==="
  head -n 100 "$COVERAGE_FILE"
  echo "\n=== カバレッジファイルの最終10行 ==="
  tail -n 10 "$COVERAGE_FILE"
  
  exit 1
fi

# カバレッジデータをパース
echo "=== カバレッジデータのパースを開始します ==="
echo "Raw COVERAGE_DATA first line: $(echo "$COVERAGE_DATA" | head -n 1)"
  
# カバレッジデータの最初の行を処理
IFS='|' read -r statements branches functions lines <<< "$(echo "$COVERAGE_DATA" | head -n 1)"
  
# デバッグ用に各変数の値を表示
echo "Parsed values - statements: $statements, branches: $branches, functions: $functions, lines: $lines"
  
get_coverage_color() {
    local value=${1%%%}  # パーセント記号を削除
    local coverage=$(printf "%.0f" "$value" 2>/dev/null || echo "0")
    if [ "$coverage" -lt 80 ]; then
      echo "#e05d44"  # 赤
    elif [ "$coverage" -lt 90 ]; then
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
  
  # 前回のカバレッジデータを取得（存在する場合）
  PREV_COVERAGE_FILE="${PROJECT_ROOT}/coverage/previous-coverage-summary.json"
  PREV_COVERAGE_ARTIFACT="${PROJECT_ROOT}/coverage/coverage-summary.json"
  PREV_COVERAGE=""
  
  echo "=== 前回のカバレッジデータを検索中 ==="
  echo "🔍 検索パス1: $PREV_COVERAGE_FILE"
  echo "🔍 検索パス2: $PREV_COVERAGE_ARTIFACT"
  
  if [ -f "$PREV_COVERAGE_FILE" ]; then
    echo "✅ 前回のカバレッジデータを検出しました: $PREV_COVERAGE_FILE"
    PREV_COVERAGE=$(cat "$PREV_COVERAGE_FILE" 2>/dev/null || echo "")
    echo "📄 前回のカバレッジデータのサイズ: ${#PREV_COVERAGE} バイト"
  elif [ -f "$PREV_COVERAGE_ARTIFACT" ]; then
    echo "ℹ️ アーティファクトからカバレッジデータを検出しました"
    echo "📊 アーティファクトの内容（先頭50文字）: $(head -c 50 "$PREV_COVERAGE_ARTIFACT")..."
    PREV_COVERAGE=$(cat "$PREV_COVERAGE_ARTIFACT" 2>/dev/null || echo "")
    echo "📄 アーティファクトデータのサイズ: ${#PREV_COVERAGE} バイト"
  else
    echo "ℹ️ 前回のカバレッジデータが見つかりません。初回実行の可能性があります。"
    # 空のカバレッジデータを作成
    PREV_COVERAGE='{"total":{"statements":{"total":0,"covered":0,"skipped":0,"pct":0},"branches":{"total":0,"covered":0,"skipped":0,"pct":0},"functions":{"total":0,"covered":0,"skipped":0,"pct":0},"lines":{"total":0,"covered":0,"skipped":0,"pct":0}}}'
    echo "🔄 空のカバレッジデータを初期化しました"
  fi
  
  # カバレッジデータの検証
  if [ -z "$PREV_COVERAGE" ]; then
    echo "⚠️ 警告: カバレッジデータが空です。空のデータで続行します。"
    PREV_COVERAGE='{"total":{"statements":{"total":0,"covered":0,"skipped":0,"pct":0},"branches":{"total":0,"covered":0,"skipped":0,"pct":0},"functions":{"total":0,"covered":0,"skipped":0,"pct":0},"lines":{"total":0,"covered":0,"skipped":0,"pct":0}}}'
  fi

  # カバレッジの差分を計算する関数
  get_coverage_diff() {
    local current=$1
    local metric=$2
    echo "🔍 カバレッジ差分を計算中..."
    echo "  - 現在の値: $current"
    echo "  - メトリクス: $metric"
    
    local prev="0"
    if [ -n "$PREV_COVERAGE" ]; then
      echo "  - 前回のカバレッジデータを検出しました"
      prev=$(echo "$PREV_COVERAGE" | jq -r ".$metric.pct" 2>/dev/null || echo "0")
      echo "  - 前回の値: $prev"
    else
      echo "⚠️ 前回のカバレッジデータがありません"
    fi

    # 差分の計算（bcの代わりにawkを使用）
    local diff=$(awk -v c="$current" -v p="$prev" 'BEGIN {printf "%.1f", c - p}' 2>/dev/null || echo "0")
    echo "  - 差分: $diff"
    
    # 差分に基づいたアイコンとメッセージを返す
    if [ "$(awk -v d="$diff" 'BEGIN {print (d > 0) ? "true" : "false"}')" = "true" ]; then
      echo "🟢 +${diff}%"
    elif [ "$(awk -v d="$diff" 'BEGIN {print (d < 0) ? "true" : "false"}')" = "true" ]; then
      echo "🔴 ${diff}%"
    else
      echo "➖ 0%"
    fi
  }

  # カバレッジが低下したファイルを検出
  DECREASED_FILES=""
  if [ -n "$PREV_COVERAGE" ]; then
    while IFS='|' read -r file s_curr b_curr f_curr l_curr; do
      # ファイル名から相対パスを取得し、正規化
      rel_file=$(echo "$file" | sed "s|^$PROJECT_ROOT/||" | sed 's|//|/|g')
      echo "  - 相対パス: $rel_file"
      
      # 前回のカバレッジを取得（エラーハンドリング付き）
      prev_data=$(echo "$PREV_COVERAGE" | jq -c ".\"$rel_file\"" 2>/dev/null || echo "null")
      echo "  - 前回データの取得結果: $([ "$prev_data" = "null" ] && echo "見つかりません" || echo "見つかりました")"
      
      if [ "$prev_data" != "null" ] && [ "$prev_data" != "" ]; then
        s_prev=$(echo "$prev_data" | jq -r '.statements.pct // 0' 2>/dev/null)
        b_prev=$(echo "$prev_data" | jq -r '.branches.pct // 0' 2>/dev/null)
        f_prev=$(echo "$prev_data" | jq -r '.functions.pct // 0' 2>/dev/null)
        l_prev=$(echo "$prev_data" | jq -r '.lines.pct // 0' 2>/dev/null)
        
        # カバレッジが低下したかチェック（bcの代わりにawkを使用）
        if [ "$(awk -v s="$s_curr" -v sp="$s_prev" -v b="$b_curr" -v bp="$b_prev" -v f="$f_curr" -v fp="$f_prev" -v l="$l_curr" -v lp="$l_prev" 'BEGIN {if (s < sp || b < bp || f < fp || l < lp) print "true"; else print "false"}')" = "true" ]; then
          DECREASED_FILES+="- **${rel_file}**\n"
          DECREASED_FILES+="  - ステートメント: ${s_prev}% → ${s_curr}%\n"
          DECREASED_FILES+="  - ブランチ: ${b_prev}% → ${b_curr}%\n"
          DECREASED_FILES+="  - 関数: ${f_prev}% → ${f_curr}%\n"
          DECREASED_FILES+="  - 行: ${l_prev}% → ${l_curr}%\n\n"
        fi
      fi
    done < <(echo "$COVERAGE_DATA" | tail -n +2)
  fi

  # 現在のカバレッジデータを取得
  CURRENT_COVERAGE=$(cat "$COVERAGE_FILE" 2>/dev/null || echo "{}")
  
  # カバレッジの傾向を生成
  COVERAGE_TREND=""
  if [ -n "$PREV_COVERAGE" ] && [ "$PREV_COVERAGE" != '{"total":{"statements":{"total":0,"covered":0,"skipped":0,"pct":0},"branches":{"total":0,"covered":0,"skipped":0,"pct":0},"functions":{"total":0,"covered":0,"skipped":0,"pct":0},"lines":{"total":0,"covered":0,"skipped":0,"pct":0}}}' ]; then
    COVERAGE_TREND="✅ 前回のカバレッジデータと比較しています"
  else
    COVERAGE_TREND="ℹ️ 前回のカバレッジデータが見つかりませんでした"
  fi

  # カバレッジが低下したファイルのメッセージを生成
  DECREASED_FILES_MSG=""
  if [ -n "$DECREASED_FILES" ]; then
    DECREASED_FILES_MSG="### ⚠️ カバレッジが低下したファイル\n\n$DECREASED_FILES"
  else
    DECREASED_FILES_MSG="✅ カバレッジの低下は検出されませんでした"
  fi

  # ファイルごとの詳細を生成
  FILE_DETAILS=$(
    echo "$COVERAGE_DATA" | tail -n +2 | head -n 10 | while IFS='|' read -r file s b f l; do
      echo "| ${file##*/} | ${s}% | ${b}% | ${f}% | ${l}% |"
    done
  )

  # コメントファイルに書き込み
  cat > "${PROJECT_ROOT}/pr-comment.md" << EOM
## 🧪 Jest テスト結果

### カバレッジサマリー

| カテゴリ | 現在のカバレッジ | 前回からの差分 | バッジ |
|----------|------------------|----------------|--------|
| ステートメント | ${statements}% | $(get_coverage_diff "$statements" "total.statements") | ![]($(get_badge "Statements" "$statements")) |
| ブランチ | ${branches}% | $(get_coverage_diff "$branches" "total.branches") | ![]($(get_badge "Branches" "$branches")) |
| 関数 | ${functions}% | $(get_coverage_diff "$functions" "total.functions") | ![]($(get_badge "Functions" "$functions")) |
| 行 | ${lines}% | $(get_coverage_diff "$lines" "total.lines") | ![]($(get_badge "Lines" "$lines")) |

### カバレッジの傾向

${COVERAGE_TREND}

${DECREASED_FILES_MSG}

<details>
<summary>📊 ファイルごとの詳細（上位10件）</summary>

| ファイル | ステートメント | ブランチ | 関数 | 行 |
|----------|----------------|----------|------|----|
${FILE_DETAILS}
</details>

<details>
<summary>📦 カバレッジデータのサマリー (Raw JSON)</summary>

```json
$(cat "${COVERAGE_FILE}" | jq -c .)
```
</details>

*このコメントは自動的に投稿されました*  
*Build: ${CIRCLE_BUILD_NUM} | Workflow: ${CIRCLE_WORKFLOW_ID}*

<details>
<summary>🔍 デバッグ情報</summary>

```
$(env | sort)
```
</details>
EOM
  
  # コメントファイルの内容を確認
  echo "=== 生成されたコメントファイルの内容 ==="
  cat "${PROJECT_ROOT}/pr-comment.md"
  echo -e "\nコメントファイルのサイズ: $(wc -c < "${PROJECT_ROOT}/pr-comment.md") バイト"

  # コメント本文を変数に読み込む
  COMMENT_BODY=$(cat "${PROJECT_ROOT}/pr-comment.md")
  
  # GitHubにコメントを投稿する関数を呼び出す
  if [ -n "$GITHUB_TOKEN" ] && [ -n "$PR_NUMBER" ]; then
    if ! post_comment "$COMMENT_BODY"; then
      echo "⚠️ コメントの投稿に失敗しましたが、処理は続行します"
      exit 0
    fi
  else
    echo "⚠️ GitHubトークンまたはPR番号が設定されていないため、コメントをスキップします"
    echo "GITHUB_TOKEN: ${GITHUB_TOKEN:+[設定済み]}"
    echo "PR_NUMBER: ${PR_NUMBER:-[未設定]}"
    exit 0
  fi
}

# コメントを投稿する関数
post_comment() {
    local comment_body="$1"
    local api_url="https://api.github.com/repos/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/issues/${PR_NUMBER}/comments"
    
    echo "=== GitHub PRにコメントを投稿中 ==="
    echo "API URL: $api_url"
    echo "コメントボディの長さ: ${#comment_body} 文字"
    
    # JSONペイロードを作成
    local json_payload
    json_payload=$(jq -n --arg body "$comment_body" '{body: $body}')
    
    # 一時ファイルに保存
    local temp_file
    temp_file=$(mktemp)
    echo "$json_payload" > "$temp_file"
    
    # デバッグ用にJSONを表示
    echo -e "\n=== デバッグ: コメント本文（投稿前） ==="
    cat "$temp_file" | jq .
    
    # curlでリクエストを送信
    echo -e "\n=== コメントを投稿中... ==="
    local response
    response=$(curl -s -S -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -H "Content-Type: application/json" \
        -d "@$temp_file" \
        "$api_url" 2>&1)
    
    local exit_code=$?
    
    # 一時ファイルを削除
    rm -f "$temp_file"
    
    if [ $exit_code -eq 0 ]; then
        echo "✅ コメントを投稿しました"
        return 0
    else
        echo "❌ コメントの投稿に失敗しました"
        echo "終了コード: $exit_code"
        echo "エラー詳細: $response"
        return 1
    fi
}
fi

