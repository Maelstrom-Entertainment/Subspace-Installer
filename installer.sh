#!/bin/bash

set -euo pipefail

install_package() {
  if ! command -v "$1" &>/dev/null; then
    echo "Installing $1 ..."
    sudo apt-get update -y
    sudo apt-get install -y "$1"
  fi
}

readonly dotenv="github.env"
readonly branch="main"
readonly files=(app.sh auth.sh build.sh deploy.sh install.sh project.sh pull.sh restart.sh server.sh)
readonly repo="Subspace-Scripts"

readonly org="Maelstrom-Entertainment"
readonly base_url="https://raw.githubusercontent.com/$org/$repo/$branch"

readonly project_root="$(pwd)"
readonly scripts_dir="$project_root/scripts"
readonly modules_dir="$scripts_dir/modules"

echo "📦 Bootstrapping Subspace environment ..."

echo "📁 Installing into: $project_root"

# Step 2: Install base dependencies
echo "🔧 Checking required packages ..."

install_package curl
install_package direnv

# Set up direnv hook in user's shell
shell_rc="$HOME/.bashrc"
shell_name="$(basename "$SHELL")"

if [[ "$shell_name" == "zsh" ]]; then
  shell_rc="$HOME/.zshrc"
fi

if ! grep -q 'direnv hook' "$shell_rc"; then
  echo "🔧 Adding direnv hook to $shell_rc"
  echo 'eval "$(direnv hook bash)"' >> "$shell_rc"
fi

# Create .envrc for local PATH
if [ ! -f "$project_root/.envrc" ]; then
  echo 'export PATH="./scripts:$PATH"' > "$project_root/.envrc"
  echo "🔐 Created .envrc and added local scripts to PATH"
else
  echo "📄 .envrc already exists — not overwriting"
fi

direnv allow

# Prompt for GitHub username
read -rp "👤 Enter your GitHub username: " expected_user

# Ask for GitHub token
read -rsp "🔐 Enter GitHub Fine-Grained Personal Access Token: " TOKEN
echo

# Validate token
echo "🔍 Validating token ..."
user_response=$(curl -s -H "Authorization: token $TOKEN" https://api.github.com/user)
github_login=$(echo "$user_response" | grep '"login"' | cut -d '"' -f4)

if [[ "$github_login" != "$expected_user" ]]; then
  echo "❌ Token does not match the username provided."
  echo "    Expected: $expected_user"
  echo "    Found:    ${github_login:-none}"
  exit 1
fi

echo "✅ Authenticated as $github_login"

# Save token to github.env
echo "💾 Saving credentials to $dotenv"

{
  echo "TOKEN=\"$TOKEN\""
  echo "GITHUB_LOGIN=\"$github_login\""
} > "$dotenv"

echo "📁 Downloading Subspace modules from $repo@$branch ..."

# Create output folder
mkdir -p "$modules_dir"

# Download each file
for file in "${files[@]}"; do
  out_path="$modules_dir/$file"

  echo "⬇️  Fetching $file ..."
  
  curl -sSfL -H "Authorization: token $TOKEN" "$base_url/modules/$file" -o "$out_path"
  chmod +x "$out_path"
done

curl -sSfL -H "Authorization: token $TOKEN" "$base_url/subspace.sh" -o "$scripts_dir/subspace.sh"
chmod +x "$scripts_dir/subspace.sh"

echo
echo "✅ Modules downloaded to $modules_dir"

echo
echo "✅ Subspace scripts installed to ./scripts"
echo "🧠 'subspace' is now available to use while in this folder"

# Reload shell config silently
exec bash

