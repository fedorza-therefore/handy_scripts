# handy_scripts
Set of scripts to handle PHP Composer projects


# Install Homebrew dependencies
brew install composer php jq gnu-sed gnu-grep

# Add GNU tools to PATH (optional but recommended)
echo 'export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"' >> ~/.zshrc
echo 'export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"' >> ~/.zshrc
source ~/.zshrc

# Make script executable
chmod +x security_script.sh

# Run dependency checker
chmod +x check_dependencies.sh
./check_dependencies.sh
