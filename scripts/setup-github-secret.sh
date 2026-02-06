#!/bin/bash
# setup-github-secret.sh
# note.comのCookieからNOTE_TOKENを抽出してGitHub Secretsに登録するスクリプト
#
# 使用方法:
#   ./scripts/setup-github-secret.sh "COOKIE文字列"
#
# 必要条件:
#   - GitHub CLI (gh) がインストールされていること
#   - GitHub CLIでログイン済みであること (gh auth login)
#   - リポジトリへのSecretsの書き込み権限があること

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${CYAN}=== $1 ===${NC}"
}

# Get cookies from argument or stdin
if [ -n "${1:-}" ]; then
    COOKIES="$1"
else
    echo "Cookie文字列を入力してください (Ctrl+D で終了):"
    COOKIES=$(cat)
fi

if [ -z "$COOKIES" ]; then
    log_error "Cookie文字列が空です"
    exit 1
fi

log_header "Cookie解析"

# Extract _note_session_v5
SESSION_V5=$(echo "$COOKIES" | grep -oP '_note_session_v5=[^;]+' | head -1 || echo "")
if [ -z "$SESSION_V5" ]; then
    log_error "_note_session_v5 が見つかりません"
    exit 1
fi
log_info "_note_session_v5: 見つかりました"

# Extract note_gql_auth_token
GQL_TOKEN=$(echo "$COOKIES" | grep -oP 'note_gql_auth_token=[^;]+' | head -1 || echo "")
if [ -z "$GQL_TOKEN" ]; then
    log_warn "note_gql_auth_token が見つかりません（ログイン直後のみ存在）"
    log_warn "_note_session_v5 のみで設定します"
    NOTE_TOKEN="$SESSION_V5"
else
    log_info "note_gql_auth_token: 見つかりました"
    NOTE_TOKEN="$SESSION_V5; $GQL_TOKEN"
fi

# Extract XSRF-TOKEN (optional, for reference)
XSRF=$(echo "$COOKIES" | grep -oP 'XSRF-TOKEN=[^;]+' | head -1 || echo "")
if [ -n "$XSRF" ]; then
    log_info "XSRF-TOKEN: 見つかりました"
fi

echo ""
log_header "GitHub Secretsに設定する値"
echo "NOTE_TOKEN=${NOTE_TOKEN:0:80}..."

echo ""
log_header "GitHub Secret登録"

# Check if gh is available
if ! command -v gh &> /dev/null; then
    log_error "GitHub CLI (gh) がインストールされていません"
    log_info "インストール方法: https://cli.github.com/manual/installation"
    echo ""
    log_info "手動で設定する場合:"
    echo "1. https://github.com/granizm/note-article/settings/secrets/actions にアクセス"
    echo "2. 'New repository secret' をクリック"
    echo "3. Name: NOTE_TOKEN"
    echo "4. Value: $NOTE_TOKEN"
    exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
    log_error "GitHub CLIにログインしていません"
    log_info "ログイン: gh auth login"
    exit 1
fi

# Get repository name
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "granizm/note-article")

log_info "リポジトリ: $REPO"
log_info "Secret 'NOTE_TOKEN' を設定中..."

# Set the secret
echo "$NOTE_TOKEN" | gh secret set NOTE_TOKEN --repo "$REPO"

if [ $? -eq 0 ]; then
    log_info "NOTE_TOKEN の設定が完了しました！"
else
    log_error "Secretの設定に失敗しました"
    exit 1
fi

echo ""
log_header "完了"
log_info "GitHub Actionsで NOTE_TOKEN が使用可能になりました"
log_info "ワークフローを再実行してテストしてください"
