# API Keys Setup Instructions

This project uses GitHub integration to fetch commit information and OpenAI for voice transcription. Both API keys are now stored securely in the macOS Keychain instead of being hardcoded in the source code.

## Setting up your GitHub Token

### Option 1: Through the App's Preferences (Recommended)

1. Open the ProjectManager app
2. Go to **ProjectManager → Preferences** (or press `⌘,`)
3. Click on the **GitHub** tab
4. Follow the instructions to create a GitHub personal access token
5. Enter your token and click **Save**

### Option 2: Create Token Manually

1. Go to [GitHub Settings → Personal Access Tokens](https://github.com/settings/tokens)
2. Click **Generate new token** → **Generate new token (classic)**
3. Give your token a descriptive name (e.g., "ProjectManager App")
4. Select the following scopes:
   - ✅ **repo** (Full control of private repositories)
5. Click **Generate token** at the bottom
6. **Copy the token immediately** (you won't be able to see it again!)
7. Paste it into the app's preferences as described in Option 1

## Security Notes

- Your token is stored securely in the macOS Keychain
- The token is never exposed in the source code
- You can view, hide, or remove your token at any time through the app's preferences
- The app will work without a token, but GitHub integration features will be disabled

## Troubleshooting

If you're having issues with GitHub integration:

1. Check that your token has the correct permissions (repo scope)
2. Ensure your token hasn't expired
3. Try removing and re-adding the token through preferences
4. Check the Console app for any error messages related to GitHub API calls

## Setting up your OpenAI API Key

### Option 1: Through the App's Preferences (Recommended)

1. Open the ProjectManager app
2. Go to **ProjectManager → Preferences** (or press `⌘,`)
3. Click on the **OpenAI** tab
4. Follow the instructions to create an OpenAI API key
5. Enter your key and click **Save**

### Option 2: Create Key Manually

1. Go to [OpenAI API Keys](https://platform.openai.com/api-keys)
2. Sign in to your OpenAI account
3. Click **Create new secret key**
4. Give your key a descriptive name (e.g., "ProjectManager App")
5. **Copy the key immediately** (you won't be able to see it again!)
6. Paste it into the app's preferences as described in Option 1

### Important Notes for OpenAI:

- You need to have credits in your OpenAI account for transcription to work
- Voice transcription uses the Whisper API
- Costs approximately $0.006 per minute of audio
- The app will show an error if no API key is configured

## For Developers

The tokens are stored in the Keychain with:
- Service: `com.projectmanager.tokens`
- GitHub Account: `github-access-token`
- OpenAI Account: `openai-api-key`

You can manage them programmatically using the `KeychainManager` class:
- `KeychainManager.shared.saveGitHubToken(_:)`
- `KeychainManager.shared.getGitHubToken()`
- `KeychainManager.shared.saveOpenAIKey(_:)`
- `KeychainManager.shared.getOpenAIKey()`