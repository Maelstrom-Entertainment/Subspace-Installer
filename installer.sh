#!/bin/bash

set -euo pipefail

# Installer script for packages
install_package() {
  if ! command -v "$1" &>/dev/null; then
    echo "Installing $1 ..."
    sudo apt-get update -y
    sudo apt-get install -y "$1"
  fi
}

## VARIABLES ##

readonly dotenv="github.env"
readonly branch="main"
readonly files=(app.sh auth.sh build.sh deploy.sh install.sh project.sh pull.sh restart.sh server.sh)
readonly repo="Subspace-Scripts"

readonly org="Maelstrom-Entertainment"
readonly base_url="https://raw.githubusercontent.com/$org/$repo/$branch"

readonly project_root="$(pwd)"
readonly scripts_dir="$project_root/scripts"
readonly modules_dir="$scripts_dir/modules"

readonly RED="\033[0;31m"
readonly GREEN="\033[0;32m"
readonly YELLOW="\033[1;33m"
readonly BLUE="\033[0;34m"
readonly NC="\033[0m"   # No Color

## DEPENDENCIES ##

echo "📦 Bootstrapping Subspace environment ..."

echo "📁 Installing into: $project_root"

# Install base dependencies
echo "🔧 Checking required packages ..."

install_package curl
install_package direnv

shell_base="$(getent passwd "$USER" | cut -d: -f7)"
shell_name="$(basename $shell_base)"

# Detect the shell
case "$shell_name" in
  bash)
      shell_rc="$HOME/.bashrc"
      ;;
  zsh)
      shell_rc="$HOME/.zshrc"
      ;;
  # Add any other shells here
  *)
      shell_rc=""
      ;;
esac

# Ensure the shell exists
if [[ -z "$shell_rc" ]]; then
    echo -e "${RED}Could not detect shell config file."
    echo -e "Please manually add direnv hook to your shell.${NC}"
    exit 1
fi

# Adds direnv hook if not already present
if ! grep -q 'direnv hook' "$shell_rc"; then
  echo "🔧 Adding direnv hook to $shell_rc"
  echo 'eval "$(direnv hook bash)"' >> "$shell_rc"
fi

# Create .envrc for PATH
if [ ! -f "$project_root/.envrc" ]; then
  echo 'PATH_add scripts' > "$project_root/.envrc"
  echo "🔐 Created .envrc and added scripts to PATH"
else
  echo -e "📄 ${YELLOW}.envrc already exists — not overwriting${NC}"
fi

direnv allow

## GITHUB AUTHENTICATION ##

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
  echo -e "❌ ${RED}Token does not match the username provided."
  echo -e "    Expected: $expected_user"
  echo -e "    Found:    ${github_login:-none}${NC}"
  exit 1
fi

echo "✅ Authenticated as $github_login"

# Save token to github.env
echo "💾 Saving credentials to $dotenv"

{
  echo "TOKEN=\"$TOKEN\""
  echo "GITHUB_LOGIN=\"$github_login\""
} > "$dotenv"

## DOWNLOAD MODULES ##

echo "📁 Downloading Subspace modules from $repo@$branch ..."

# Create output folder
mkdir -p "$modules_dir"

# Download each file
for file in "${files[@]}"; do
  out_path="$modules_dir/$file"

  echo "⬇️  Fetching $file ..."
  
  if ! curl -sSfL -H "Authorization: token $TOKEN" \
      "$base_url/modules/$file" -o "$out_path"; then
    echo -e "❌ ${RED}Failed to fetch $file. Check your token or network.${NC}"
    exit 1
  fi

  chmod +x "$out_path"
done

# Download the main subspace script
curl -sSfL -H "Authorization: token $TOKEN" "$base_url/subspace.sh" -o "$scripts_dir/subspace"
chmod +x "$scripts_dir/subspace"

echo
echo "✅ Modules downloaded to $modules_dir"

echo
echo -e "✅ ${GREEN}Subspace scripts installed to ./scripts${NC}"
echo "🧠 'subspace' is now available to use while in this folder"

echo
echo "To start using subspace immediate, run:"
echo
echo "  source ~/$shell_type"