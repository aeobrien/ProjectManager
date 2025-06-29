# Keychain Token Persistence Fix

## The Issue
Tokens saved to the Keychain are not persisting between app launches or after saving.

## Potential Causes and Solutions

### 1. App Sandboxing
The app is sandboxed, which can affect Keychain access. The current implementation should work, but you may need to:

- Ensure the app has a proper bundle identifier set in Xcode project settings
- The app is properly code-signed

### 2. Running the Debug Version
When you run the app from Xcode, check the Console output. You should see messages like:
```
=== Keychain Test ===
Service Name: ProjectManager
Testing GitHub token...
✅ Saved test GitHub token
✅ Retrieved GitHub token: test-github-token-123
✅ Tokens match: true
```

If you see error messages, they will help diagnose the issue.

### 3. Manual Testing
You can test the Keychain functionality by:

1. Run the app
2. Open Preferences (⌘,)
3. Go to GitHub or OpenAI tab
4. Save a token
5. Check Console.app for any error messages
6. Quit and restart the app
7. Check if the token persists

### 4. Alternative Fix - UserDefaults (Less Secure)
If Keychain continues to have issues, we could fall back to UserDefaults with encryption, though this is less secure.

### 5. Command Line Test
You can also test Keychain access from Terminal:
```bash
# Add a test item
security add-generic-password -s "ProjectManager" -a "test-account" -w "test-password"

# Retrieve it
security find-generic-password -s "ProjectManager" -a "test-account" -w

# Delete it
security delete-generic-password -s "ProjectManager" -a "test-account"
```

## What to Check

1. **Console Output**: Run the app and check Xcode's console for the Keychain test output
2. **Keychain Access App**: Open Keychain Access.app and search for "ProjectManager" to see if items are being created
3. **Permissions**: Ensure the app has proper permissions and is code-signed
4. **Bundle ID**: Check that your app has a bundle identifier set in the project settings

## Next Steps

Based on the console output when you run the app, we can determine:
- If saving is failing (permissions issue)
- If retrieval is failing (query mismatch)
- If tokens are being saved but with different parameters

Please run the app and share any error messages from the console.