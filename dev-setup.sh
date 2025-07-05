#!/bin/bash
set -e # Exit immediately if a command fails

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
  exit 1
fi

# Check Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
print_status "Detected Ubuntu version: $UBUNTU_VERSION"

# 1. System updates
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# 2. Core development tools
print_status "Installing essential build tools..."
sudo apt install -y git curl wget build-essential software-properties-common apt-transport-https ca-certificates gnupg lsb-release

# 3. Java 21 (Check if available, fallback to Java 17)
print_status "Installing OpenJDK..."
if apt list --installed openjdk-21-jdk 2>/dev/null | grep -q openjdk-21-jdk; then
  print_status "OpenJDK 21 already installed"
elif sudo apt install -y openjdk-21-jdk 2>/dev/null; then
  print_status "OpenJDK 21 installed successfully"
else
  print_warning "OpenJDK 21 not available, installing OpenJDK 17 instead"
  sudo apt install -y openjdk-17-jdk
fi

# Set JAVA_HOME
JAVA_HOME_PATH=$(update-java-alternatives -l | head -n1 | awk '{print $3}')
if [ -n "$JAVA_HOME_PATH" ]; then
  echo "export JAVA_HOME=$JAVA_HOME_PATH" >>~/.bashrc
  echo "export PATH=\$JAVA_HOME/bin:\$PATH" >>~/.bashrc
  export JAVA_HOME=$JAVA_HOME_PATH
  export PATH=$JAVA_HOME/bin:$PATH
  print_status "JAVA_HOME set to: $JAVA_HOME_PATH"
fi

# Verify Java installation
print_status "Java version:"
java -version

# 4. Python 3 and pip
print_status "Installing Python 3 and pip..."
sudo apt install -y python3 python3-pip python3-venv python3-dev

# Create python symlink only if it doesn't exist
if ! command -v python &>/dev/null; then
  sudo ln -sf /usr/bin/python3 /usr/bin/python
  print_status "Created python -> python3 symlink"
fi

# 5. MySQL Server
print_status "Installing MySQL Server..."
sudo apt install -y mysql-server

# Start and enable MySQL service
sudo systemctl start mysql
sudo systemctl enable mysql

print_warning "MySQL installed but not secured. Run 'sudo mysql_secure_installation' after script completion."

# 6. Docker and Docker Compose
print_status "Installing Docker..."

# Remove old Docker packages
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

print_status "Docker installed. You may need to log out and back in for docker group membership to take effect."

# 7. Neovim (Install latest from snap or build from source if needed)
print_status "Installing Neovim..."
if command -v snap &>/dev/null; then
  sudo snap install nvim --classic
  print_status "Neovim installed via snap"
else
  sudo apt install -y neovim
  print_status "Neovim installed via apt"
fi

# Install LazyVim (with backup of existing config)
print_status "Setting up LazyVim..."
if [ -d ~/.config/nvim ]; then
  print_warning "Existing nvim config found. Backing up to ~/.config/nvim.backup"
  mv ~/.config/nvim ~/.config/nvim.backup
fi

# Clone LazyVim starter
git clone https://github.com/LazyVim/starter ~/.config/nvim
rm -rf ~/.config/nvim/.git

# Install LazyVim dependencies
print_status "Installing LazyVim dependencies..."
sudo apt install -y ripgrep fd-find

# Create symlink for fd if needed
if ! command -v fd &>/dev/null && command -v fdfind &>/dev/null; then
  sudo ln -sf /usr/bin/fdfind /usr/bin/fd
fi

print_status "LazyVim setup complete. Run 'nvim' to complete plugin installation."

# 8. Tmux
print_status "Installing Tmux..."
sudo apt install -y tmux

# 9. Additional useful tools
print_status "Installing additional development tools..."
sudo apt install -y \
  tree \
  htop \
  unzip \
  zip \
  jq \
  vim \
  nano \
  zsh \
  fish

# 10. Node.js (using NodeSource repository for latest LTS)
print_status "Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# 11. Development environment verification
print_status "Verifying installations..."
echo "=== Installation Summary ==="
echo "Java version:"
java -version 2>&1 | head -1

echo "Python version:"
python3 --version

echo "MySQL version:"
mysql --version

echo "Docker version:"
docker --version

echo "Neovim version:"
nvim --version | head -1

echo "Tmux version:"
tmux -V

echo "Node.js version:"
node --version

echo "npm version:"
npm --version

print_status "Development environment setup complete!"
echo
echo "=== Next Steps ==="
echo "1. Log out and back in (or run 'newgrp docker') to use Docker without sudo"
echo "2. Run 'sudo mysql_secure_installation' to secure your MySQL installation"
echo "3. Open Neovim with 'nvim' to complete LazyVim plugin installation"
echo "4. Consider customizing ~/.config/nvim/lua/config/ files for your preferences"
echo "5. Create ~/.tmux.conf for tmux customizations"
echo "6. Set up your preferred shell (zsh with oh-my-zsh, fish, etc.)"
echo
echo "=== Optional Commands ==="
echo "- Install oh-my-zsh: sh -c \"\$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
echo "- Configure git: git config --global user.name 'Your Name' && git config --global user.email 'your.email@example.com'"
