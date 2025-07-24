# How to Run Claude Code in GitPod

Think about it like CI/CD. You don't sit around waiting for a test suite to finish. You run jobs, let them cook in the background, and review the results when you're ready. Claude Code needs the same kind of orchestration.

There are emerging workarounds—tools like Claude Squad uses tmux to split terminals; Vibe Kanban overlays a kanban UI on top of agents; others isolate agents in containers.

But they all share the same flaw: they're all just workarounds.

## Why current parallel solutions fall short

Claude Code is a CLI tool. It's not an orchestrator, not a runtime, not an environment. It doesn't manage state, handle concurrency, or isolate compute.

That means most community-built solutions end up fragile, manual, or both:

- Git worktrees isolate your source code, but agents still fight over the same resources.
- Kanban UIs give you visibility but not full isolation between agents.
- Tmux gives you multiple windows, not multiple environments. You're still constrained by your local machine.
- SSH to another machine works, for one or two agents. But what about ten? Do you spin up VMs manually? What about teardown, state, and recovery?

## Run each Claude Code in its own environment

This is where GitPod comes in. Instead of hacking around limitations, you get purpose-built infrastructure that supports real agent parallelism:

- **Each Claude Code agent runs in its own environment**
- **Environments start, stop, and persist** (even when you close your laptop)
- **Dev Container ensures that every agent has identical tools and configuration**
- **Jump into any environment with VS Code, JetBrains, or your preferred editor**
- **Each environment gets its own CPU, memory, file system, git state, and services**

GitPod is crafted for parallel development as each development environment can run tests, compile code, and manage dependencies.

![claude-code-parallel](https://github.com/user-attachments/assets/claude-code-parallel)

## Setting up Claude Code in GitPod

Here's how to run parallel Claude Code agents:

1. **Configure your Dev Container with Claude Code**
2. **Create a file secret for credentials**
3. **Set up authentication with dotfiles**
4. **Launch multiple environments**

### Step 1: Configure your Dev Container

Claudia includes a pre-configured `.devcontainer/devcontainer.json` that includes the Claude Code Dev Container feature:

```json
{
	"name": "Claude Code Development",
	"image": "mcr.microsoft.com/devcontainers/base:ubuntu",
	"features": {
		"ghcr.io/devcontainers-contrib/features/claude-cli:1": {}
	}
}
```

The `ghcr.io/devcontainers-contrib/features/claude-cli:1` feature automatically installs Claude Code and its dependencies.

#### Rebuilding your environment

After creating or modifying your `.devcontainer/devcontainer.json`, you'll need to rebuild the environment to apply the changes:

**Using VS Code command palette:**
1. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
2. Type and select `GitPod: Rebuild Container`
3. The environment will rebuild and reconnect automatically

**Alternatively:**
Run `gitpod environment devcontainer rebuild` from inside or outside the environment.

### Step 2: Create a File Secret for authentication

Now that Claude Code is installed in your environment through the Dev Container feature, you need to authenticate it:

1. **Open a GitPod environment** with your configured Dev Container
2. **Connect with a local editor** (VS Code, JetBrains, or Cursor) - not the browser-based editor as the auth flow redirects to localhost, which requires port forwarding
3. **Run `claude login`** in the terminal
4. **Complete authentication** in your browser
5. **Copy your authentication file** `~/.claude.json` from the environment
6. **Create the GitPod secret:**
   - Go to [gitpod.io/user/secrets](https://gitpod.io/user/secrets)
   - Create a new **File Secret**
   - **Name:** `CLAUDE_AUTH` (or any name you prefer)
   - **File location:** `/root/.claude.json`
   - **Paste your entire `.claude.json` file**

### Step 3: Set up authentication with dotfiles

In ephemeral environments, you need to ensure each environment is authenticated. With GitPod, you do this through dotfiles–scripts that run personally for you in every environment.

1. **Create a dotfiles repository** (e.g., `github.com/yourusername/dotfiles`)
2. **Add Claude setup script** at `claude/.run`:

```bash
#!/bin/bash

# Check if Claude is already installed
if command -v claude &> /dev/null; then
    echo "✨ Claude Code is already installed"
else
    if ! command -v npm &> /dev/null; then
        echo "⚠️  Skipping claude code install, npm not found"
        return 0
    else
        echo "🚀 Installing Claude Code..."
        npm install -g @anthropic-ai/claude-code
    fi
fi

# Set theme preference
claude config set -g theme dark

# Copy Claude config from mounted secret
DEST="$HOME/.claude.json"
if [ ! -f "$DEST" ]; then
    echo "📋 Copying Claude config from root..."
    sudo cp /root/.claude.json "$DEST" 2>/dev/null || {
        echo "ℹ️  No Claude config found in root, skipping copy"
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
  }
}
EOF
fi

echo "✅ Claude Code setup complete!"
```

3. **Set your dotfiles repository** in GitPod settings:
   - Go to [gitpod.io/preferences](https://gitpod.io/preferences)
   - Under "Dotfiles," add your repository URL: `https://github.com/yourusername/dotfiles`

### Step 4: Launch multiple environments

Once everything is configured, creating parallel Claude Code environments is simple:

```bash
# Get workspace IDs before creating new ones
BEFORE_IDS=$(gitpod environment list --field id | sort)

# Create a new environment
gitpod environment new https://github.com/<your-org>/<your-repository>

# Get the new environment ID
AFTER_IDS=$(gitpod environment list --field id | sort)
ENV_ID=$(comm -13 <(echo "$BEFORE_IDS") <(echo "$AFTER_IDS"))

# SSH into the new environment
gitpod environment ssh $ENV_ID -- -t claude exec bash
```

## The future

Runs in parallel. The draw of agents is real, but so are the limits of our current tools. Claude Code is powerful, but it wasn't built for concurrency. GitPod gives Claude Code the scaffolding it needs to grow.

Each agent gets its own CPU, memory, and git state. No conflicts. No collisions. Just execution at scale.

If you love Claude Code, you'll love Claudia too. Claudia is an software engineering agent. It has shared context of all your repos and works in full environments.

---

*Ready to try parallel Claude Code development? [Open in GitPod](https://gitpod.io/#https://github.com/getAsterisk/claudia)*