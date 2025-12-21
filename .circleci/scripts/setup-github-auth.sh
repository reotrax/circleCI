#!/bin/bash
set -e

echo "=== GitHub Authentication Setup ==="

# まずOIDC/GitHub App統合による認証を確認
if gh auth status > /dev/null 2>&1; then
  echo "✅ Using OIDC/GitHub App Integration"
  echo "Authentication method: CircleCI GitHub App (OIDC-based)"
  AUTH_METHOD="OIDC"
else
  echo "⚠️  OIDC authentication not available"

  # GITHUB_TOKENが設定されているか確認
  if [ -n "$GITHUB_TOKEN" ]; then
    echo "✅ Using GITHUB_TOKEN from environment variables"
    echo "$GITHUB_TOKEN" | gh auth login --with-token
    echo "Authentication method: Personal Access Token (GITHUB_TOKEN)"
    AUTH_METHOD="PAT"
  else
    echo "❌ ERROR: No authentication method available"
    echo "Please set GITHUB_TOKEN in CircleCI project settings or enable GitHub App integration"
    exit 1
  fi
fi

# 認証状態を確認
echo ""
echo "=== Authentication Status ==="
gh auth status

# 使用した認証方法を環境変数として保存
echo "export AUTH_METHOD=$AUTH_METHOD" >> $BASH_ENV
