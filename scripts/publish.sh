#!/bin/bash
set -euo pipefail

# Note.com Publishing Script (Unofficial API)
# Usage: ./publish.sh <mode> <markdown_file>
#   mode: "draft" or "publish"

MODE="${1:-}"
MARKDOWN_FILE="${2:-}"
API_BASE="https://note.com"
IDS_FILE="note_article_ids.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Validate inputs
if [[ -z "$MODE" || -z "$MARKDOWN_FILE" ]]; then
    log_error "Usage: $0 <draft|publish> <markdown_file>"
    exit 1
fi

if [[ "$MODE" != "draft" && "$MODE" != "publish" ]]; then
    log_error "Mode must be 'draft' or 'publish'"
    exit 1
fi

if [[ ! -f "$MARKDOWN_FILE" ]]; then
    log_error "File not found: $MARKDOWN_FILE"
    exit 1
fi

# Check for NOTE_TOKEN
if [[ -z "${NOTE_TOKEN:-}" ]]; then
    log_error "NOTE_TOKEN environment variable is required"
    log_error "Format: note_gql_auth_token=xxx; _note_session_v5=yyy"
    exit 1
fi

# Initialize IDs file if not exists
if [[ ! -f "$IDS_FILE" ]]; then
    echo '{}' > "$IDS_FILE"
fi

# Extract title from markdown (first H1)
extract_title() {
    local file="$1"
    grep -m 1 '^# ' "$file" | sed 's/^# //' || basename "$file" .md
}

# Extract body from markdown (everything after first H1)
extract_body() {
    local file="$1"
    # Remove the first H1 line and return the rest
    sed '0,/^# /d' "$file"
}

# Get file key (used for tracking)
get_file_key() {
    local file="$1"
    basename "$file" .md
}

# Get stored draft ID
get_draft_id() {
    local key="$1"
    jq -r ".\"$key\".draft_id // empty" "$IDS_FILE"
}

# Get stored note key
get_note_key() {
    local key="$1"
    jq -r ".\"$key\".note_key // empty" "$IDS_FILE"
}

# Save draft ID
save_draft_id() {
    local key="$1"
    local draft_id="$2"
    local tmp_file=$(mktemp)
    jq ".\"$key\".draft_id = \"$draft_id\"" "$IDS_FILE" > "$tmp_file"
    mv "$tmp_file" "$IDS_FILE"
}

# Save note key
save_note_key() {
    local key="$1"
    local note_key="$2"
    local tmp_file=$(mktemp)
    jq ".\"$key\".note_key = \"$note_key\"" "$IDS_FILE" > "$tmp_file"
    mv "$tmp_file" "$IDS_FILE"
}

# Create or update draft
create_or_update_draft() {
    local markdown_file="$1"
    local file_key=$(get_file_key "$markdown_file")
    local title=$(extract_title "$markdown_file")
    local body=$(extract_body "$markdown_file")
    local draft_id=$(get_draft_id "$file_key")

    log_info "Processing: $file_key"
    log_info "Title: $title"

    # Prepare request body
    local request_body=$(jq -n \
        --arg title "$title" \
        --arg body "$body" \
        '{
            "note": {
                "name": $title,
                "body": $body,
                "type": "TextNote",
                "publish_at": null,
                "price": 0
            }
        }')

    local response
    local http_code

    if [[ -n "$draft_id" ]]; then
        log_info "Updating existing draft: $draft_id"
        # Update existing draft
        response=$(curl -s -w "\n%{http_code}" \
            -X PUT \
            -H "Content-Type: application/json" \
            -H "Cookie: $NOTE_TOKEN" \
            -d "$request_body" \
            "${API_BASE}/api/v3/drafts/${draft_id}")
    else
        log_info "Creating new draft"
        # Create new draft
        response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "Cookie: $NOTE_TOKEN" \
            -d "$request_body" \
            "${API_BASE}/api/v3/drafts")
    fi

    http_code=$(echo "$response" | tail -n 1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        # Extract and save draft ID from response
        local new_draft_id=$(echo "$response" | jq -r '.data.key // .data.id // empty')
        if [[ -n "$new_draft_id" ]]; then
            save_draft_id "$file_key" "$new_draft_id"
            log_info "Draft saved with ID: $new_draft_id"
        fi
        echo "$response"
    else
        log_error "API request failed with HTTP $http_code"
        log_error "Response: $response"
        return 1
    fi
}

# Publish draft
publish_draft() {
    local markdown_file="$1"
    local file_key=$(get_file_key "$markdown_file")
    local draft_id=$(get_draft_id "$file_key")

    if [[ -z "$draft_id" ]]; then
        log_error "No draft found for $file_key. Create a draft first."
        return 1
    fi

    log_info "Publishing draft: $draft_id"

    local response
    local http_code

    response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Cookie: $NOTE_TOKEN" \
        "${API_BASE}/api/v2/notes/${draft_id}/publish")

    http_code=$(echo "$response" | tail -n 1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
        # Extract and save note key from response
        local note_key=$(echo "$response" | jq -r '.data.key // empty')
        if [[ -n "$note_key" ]]; then
            save_note_key "$file_key" "$note_key"
            log_info "Published with key: $note_key"
            log_info "URL: https://note.com/notes/$note_key"
        fi
        echo "$response"
    else
        log_error "Publish failed with HTTP $http_code"
        log_error "Response: $response"
        return 1
    fi
}

# Main execution
case "$MODE" in
    draft)
        create_or_update_draft "$MARKDOWN_FILE"
        ;;
    publish)
        # First ensure draft is up to date
        create_or_update_draft "$MARKDOWN_FILE"
        # Then publish
        publish_draft "$MARKDOWN_FILE"
        ;;
esac

log_info "Done!"
