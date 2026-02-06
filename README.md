# Note Article Publisher

Automated publishing workflow for Note.com using GitHub Actions.

## Warning

This project uses **unofficial Note.com API endpoints**. These endpoints are not publicly documented and may change without notice. Use at your own risk.

- The API may break at any time without warning
- Your account could potentially be affected by Terms of Service violations
- There is no official support for these endpoints

## Setup

### 1. Repository Secrets

Configure the following secrets in your GitHub repository settings (`Settings > Secrets and variables > Actions`):

| Secret | Description |
|--------|-------------|
| `NOTE_TOKEN` | Cookie authentication tokens (see below) |
| `DISCORD_WEBHOOK_URL` | (Optional) Discord webhook for notifications |

### 2. Getting NOTE_TOKEN

The `NOTE_TOKEN` secret contains authentication cookies extracted from your browser. Follow these steps:

#### Step 1: Login to Note.com
1. Open your browser and go to [note.com](https://note.com)
2. Login to your account

#### Step 2: Open Developer Tools
1. Press `F12` or right-click and select "Inspect"
2. Go to the **Application** tab (Chrome/Edge) or **Storage** tab (Firefox)

#### Step 3: Extract Cookies
1. In the left sidebar, expand **Cookies**
2. Click on `https://note.com`
3. Find these two cookies:
   - `note_gql_auth_token`
   - `_note_session_v5`

#### Step 4: Format the Token
Copy the values and format them as:
```
note_gql_auth_token=YOUR_AUTH_TOKEN_VALUE; _note_session_v5=YOUR_SESSION_VALUE
```

#### Step 5: Add to GitHub Secrets
1. Go to your repository's `Settings > Secrets and variables > Actions`
2. Click `New repository secret`
3. Name: `NOTE_TOKEN`
4. Value: The formatted cookie string from Step 4

### Important Notes on NOTE_TOKEN

- **Session Expiration**: The `_note_session_v5` cookie may expire. If publishing starts failing, you'll need to extract fresh cookies.
- **Security**: Never commit these tokens to the repository. Always use GitHub Secrets.
- **Single Session**: Using these cookies in multiple places may invalidate your session.

## Usage

### Writing Articles

1. Create markdown files in the `posts/` directory
2. Use `# Title` as the first line for the article title
3. Everything after the title becomes the article body

Example (`posts/my-first-article.md`):
```markdown
# My First Article

This is the content of my article.

## Section 1

More content here...
```

### Publishing Workflow

1. **Draft Mode (Pull Request)**
   - Create a branch and add/modify markdown files in `posts/`
   - Open a Pull Request
   - The workflow automatically creates/updates drafts on Note.com

2. **Publish Mode (Merge to main)**
   - Merge the Pull Request to `main`
   - The workflow automatically publishes the drafts

### Manual Publishing

You can also run the publish script locally:

```bash
# Set the token
export NOTE_TOKEN="note_gql_auth_token=xxx; _note_session_v5=yyy"

# Create/update a draft
./scripts/publish.sh draft posts/my-article.md

# Publish a draft
./scripts/publish.sh publish posts/my-article.md
```

## File Structure

```
note-article/
├── .github/
│   └── workflows/
│       ├── publish-draft.yml      # PR trigger -> create draft
│       └── publish-production.yml # main push -> publish
├── posts/
│   └── *.md                       # Your articles
├── scripts/
│   └── publish.sh                 # Publishing script
├── note_article_ids.json          # Tracks article IDs (auto-generated)
├── .gitignore
└── README.md
```

## Article ID Tracking

The `note_article_ids.json` file tracks the mapping between local markdown files and Note.com article IDs:

```json
{
  "my-article": {
    "draft_id": "abc123",
    "note_key": "xyz789"
  }
}
```

This file is automatically updated by the workflows and should be committed to the repository.

## Discord Notifications

If `DISCORD_WEBHOOK_URL` is configured, you'll receive notifications:
- Success: Draft created or article published
- Failure: When any step fails

## Troubleshooting

### Authentication Failed
- Re-extract your cookies from the browser
- Make sure both cookies are included in the correct format
- Check if you're still logged in to Note.com

### Draft Not Found
- Ensure the draft was created before attempting to publish
- Check `note_article_ids.json` for the article mapping

### API Errors
- The unofficial API may have changed
- Check Note.com for any service disruptions
- Review the error response in GitHub Actions logs

## License

MIT
