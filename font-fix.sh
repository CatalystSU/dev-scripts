#!/bin/bash

# Nerd Font Installer for LazyVim Icons
# This script installs Nerd Fonts to fix icon display issues in LazyVim

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if running on Ubuntu/Debian
if ! command -v apt &>/dev/null; then
  print_error "This script is designed for Ubuntu/Debian systems with apt package manager."
  exit 1
fi

# Create fonts directory if it doesn't exist
FONTS_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONTS_DIR"

print_status "Installing Nerd Fonts for LazyVim icon support..."

# Function to download and install a Nerd Font
install_nerd_font() {
  local font_name=$1
  local download_url=$2
  local zip_file="$font_name.zip"

  print_status "Downloading $font_name..."

  # Download the font
  if curl -fsSL "$download_url" -o "/tmp/$zip_file"; then
    print_status "Downloaded $font_name successfully"

    # Extract the font
    cd "$FONTS_DIR"
    unzip -o "/tmp/$zip_file" "*.ttf" "*.otf" 2>/dev/null || true

    # Clean up
    rm -f "/tmp/$zip_file"

    print_status "$font_name installed successfully"
  else
    print_error "Failed to download $font_name"
    return 1
  fi
}

# Install required packages
print_status "Installing required packages..."
sudo apt update
sudo apt install -y curl unzip fontconfig

# Popular Nerd Fonts for development
print_info "Installing popular Nerd Fonts..."

# JetBrains Mono - Very popular for coding
install_nerd_font "JetBrainsMono" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"

# Fira Code - Popular for programming with ligatures
install_nerd_font "FiraCode" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"

# Hack - Clean and readable
install_nerd_font "Hack" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip"

# Source Code Pro - Adobe's monospace font
install_nerd_font "SourceCodePro" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/SourceCodePro.zip"

# Meslo LG - Good for terminals
install_nerd_font "Meslo" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"

# Update font cache
print_status "Updating font cache..."
fc-cache -fv

# Verify installation
print_status "Verifying Nerd Font installation..."
if fc-list | grep -i "nerd" | head -5; then
  print_status "Nerd Fonts installed successfully!"
else
  print_warning "Nerd Fonts may not be properly installed. Please check manually."
fi

# Instructions for different terminals
print_info "=================================================="
print_info "NERD FONTS INSTALLED SUCCESSFULLY!"
print_info "=================================================="
echo
print_info "Now you need to configure your terminal to use a Nerd Font:"
echo

# Check which terminal is being used
if [[ "$TERM_PROGRAM" == "gnome-terminal" ]] || command -v gnome-terminal &>/dev/null; then
  print_info "For GNOME Terminal:"
  echo "1. Right-click in terminal → Preferences"
  echo "2. Go to your profile → Text tab"
  echo "3. Uncheck 'Use the system fixed width font'"
  echo "4. Click the font button and select a Nerd Font:"
  echo "   - JetBrainsMono Nerd Font (Recommended)"
  echo "   - FiraCode Nerd Font"
  echo "   - Hack Nerd Font"
  echo "   - SourceCodePro Nerd Font"
  echo "   - Meslo LG S Nerd Font"
  echo
fi

if command -v konsole &>/dev/null; then
  print_info "For Konsole (KDE Terminal):"
  echo "1. Settings → Edit Current Profile"
  echo "2. Go to Appearance tab"
  echo "3. Select a Nerd Font from the font dropdown"
  echo
fi

if command -v code &>/dev/null; then
  print_info "For VS Code Terminal:"
  echo "1. Open VS Code settings (Ctrl+,)"
  echo "2. Search for 'terminal.integrated.fontFamily'"
  echo "3. Set it to: 'JetBrainsMono Nerd Font', 'FiraCode Nerd Font', monospace"
  echo
fi

print_info "For other terminals:"
echo "Look for Font/Appearance settings and select any font with 'Nerd Font' in the name"
echo

print_info "Testing the font:"
echo "After changing your terminal font, test it with this command:"
echo "echo '     '"
echo
echo "You should see various icons. If you see empty boxes or question marks,"
echo "your terminal font is not properly configured."
echo

print_info "Recommended fonts for coding:"
echo "• JetBrainsMono Nerd Font - Clean, modern (Recommended)"
echo "• FiraCode Nerd Font - Has programming ligatures"
echo "• Hack Nerd Font - Very readable"
echo "• SourceCodePro Nerd Font - Adobe's design"
echo "• Meslo LG S Nerd Font - Terminal-optimized"
echo

print_status "LazyVim should now display icons correctly!"
print_warning "Remember to restart your terminal or open a new terminal window after changing the font."

# Additional LazyVim-specific information
print_info "LazyVim Icon Information:"
echo "LazyVim uses icons from Nerd Fonts for:"
echo "• File type indicators"
echo "• Git status symbols"
echo "• Diagnostic symbols (errors, warnings)"
echo "• Plugin manager interface"
echo "• Status line components"
echo
print_info "If some icons still don't appear correctly in LazyVim:"
echo "1. Make sure your terminal font is set to a Nerd Font"
echo "2. Try a different Nerd Font (JetBrainsMono is highly recommended)"
echo "3. Check that your terminal supports Unicode properly"
echo "4. You can customize icons in LazyVim config if needed"

print_status "Setup complete! Enjoy your enhanced LazyVim experience! 🎉"
