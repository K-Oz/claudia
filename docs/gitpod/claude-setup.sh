#!/bin/bash

# Claude Code setup script for GitPod environments
# This script should be placed in your dotfiles repository at claude/.run
# See: https://www.gitpod.io/docs/configure/user-settings/dotfiles

echo "🚀 Setting up Claude Code in GitPod environment..."

# Check if Claude is already installed
if command -v claude &> /dev/null; then
    echo "✨ Claude Code is already installed"
else
    if ! command -v npm &> /dev/null; then
        echo "⚠️  Skipping claude code install, npm not found"
        return 0
    else
        echo "📦 Installing Claude Code..."
        npm install -g @anthropic-ai/claude-code
    fi
fi

# Set theme preference
echo "🎨 Setting Claude theme to dark..."
claude config set -g theme dark

# Copy Claude config from mounted secret
DEST="$HOME/.claude.json"
if [ ! -f "$DEST" ]; then
    echo "📋 Copying Claude config from root..."
    sudo cp /root/.claude.json "$DEST" 2>/dev/null || {
        echo "ℹ️  No Claude config found in root, skipping copy"
        echo "🔐 You'll need to run 'claude login' to authenticate"
        return 0
    }
fi

# Fix permissions
sudo chown "$(id -u):$(id -g)" "$DEST" 2>/dev/null

# Set up Claude settings with pre-approved permissions
echo "⚙️  Setting up Claude settings..."
mkdir -p ~/.claude
if [ ! -f ~/.claude/settings.json ]; then
    cat > ~/.claude/settings.json << 'EOF'
{
  "autoApprove": {
    "fileOperations": ["read", "write", "create"],
    "shellCommands": ["git", "npm", "cargo", "rustc"],
    "maxTokens": 10000
  },
  "security": {
    "allowedDirectories": ["/workspace", "$HOME"],
    "restrictedCommands": ["rm -rf", "sudo rm", "format", "fdisk"]
  }
}
EOF
fi

echo "✅ Claude Code setup complete!"
echo "🔄 Ready for parallel development!"
echo ""
echo "💡 Next steps:"
echo "   1. Run 'claude login' if not already authenticated"
echo "   2. Start a new session: 'claude chat'"
echo "   3. Create parallel environments: 'gitpod env new <repo-url>'"