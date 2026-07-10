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

github_user_name=""
github_token=""

if [ ! -f "$project_root/github.env" ]; then
  # Prompt for GitHub username
  read -rp "👤 Enter your GitHub username: " github_user_name

  # Ask for GitHub token
  read -rsp "🔐 Enter GitHub Fine-Grained Personal Access Token: " github_token
  echo

  # Validate token
  echo "🔍 Validating token ..."

  user_response=$(curl -s -H "Authorization: token $github_token" https://api.github.com/user)
  github_login=$(echo "$user_response" | grep '"login"' | cut -d '"' -f4)

  if [[ "$github_login" != "$github_user_name" ]]; then
    echo -e "❌ ${RED}Token does not match the username provided."
    echo -e "    Expected: $github_user_name"
    echo -e "    Found:    ${github_login:-none}${NC}"
    exit 1
  fi

  echo "✅ Authenticated as $github_login"

  # Save token to github.env
  echo "💾 Saving credentials to $dotenv"

  {
    echo "TOKEN=\"$github_token\""
    echo "GITHUB_LOGIN=\"$github_login\""
  } > "$dotenv"
else
  echo -e "📄 ${YELLOW}Github credentials already exist. Will use existing credentials${NC}"

  regexp=$(grep '^GITHUB_LOGIN=' github.env)
  github_user_name="${regexp#*=}"
  github_user_name="${github_user_name//\"/}"
  
  regexp=$(grep '^TOKEN=' github.env)
  github_token="${regexp#*=}"
  github_token="${github_token//\"/}"
fi

## ONLINE vs OFFLINE MODE ##

# Ask for deployment mode
read -rp "⚙️ Is this instance of Subspace a local deployment? (y/n): " is_local

case "$is_local" in
  [Yy])
    environment="offline"
    ;;
  [Nn])
    environment="online"
    ;;
  *)
    echo "Please answer y or n."
    ;;
esac

echo -e "🌎 Selected environment: ${GREEN}$environment${NC}"

subspace_env_file="$project_root/.env.${environment}"

# Create the appropriate environment file
cat > "$subspace_env_file" <<EOF
VITE_CONSOLE_DEBUG=false
VITE_ENVIRONMENT=${environment}

EOF

echo "Created ${subspace_env_file}"

## DOWNLOAD MODULES ##

echo "📁 Downloading Subspace modules from $repo@$branch ..."

# Create output folder
mkdir -p "$modules_dir"

# Download each file
for file in "${files[@]}"; do
  out_path="$modules_dir/$file"

  echo "⬇️  Fetching $file ..."
  
  if ! curl -sSfL -H "Authorization: Bearer $github_token" \
      "$base_url/modules/$file" -o "$out_path"; then
    echo -e "❌ ${RED}Failed to fetch $file. Check your token or network.${NC}"
    exit 1
  fi

  chmod +x "$out_path"
done

# Download the main subspace script
curl -sSfL -H "Authorization: token $github_token" "$base_url/subspace.sh" -o "$scripts_dir/subspace"
chmod +x "$scripts_dir/subspace"

echo
echo "✅ Modules downloaded to $modules_dir"

echo
echo -e "✅ ${GREEN}Subspace scripts installed to ./scripts${NC}"
echo
echo "🧠 'subspace' is now available to use while in this folder"

echo
echo "To start using subspace immediate, run:"
echo
echo "  source $shell_rc"