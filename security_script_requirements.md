# Security Script Requirements & Mac Compatibility

## Script Overview
The `security_script.sh` is a bash script that automatically checks for security vulnerabilities in Composer packages and suggests safe upgrades.

## System Requirements

### Core Dependencies

#### 1. **Bash Shell**
- **Requirement**: Bash 4.0 or higher
- **Mac Compatibility**: ✅ Compatible
- **Installation**: Pre-installed on macOS (version 3.2+), can be upgraded via Homebrew
- **Check**: `bash --version`

#### 2. **Git**
- **Requirement**: Git for repository operations
- **Mac Compatibility**: ✅ Compatible
- **Installation**:
  - Pre-installed on macOS (Xcode Command Line Tools)
  - Or install via Homebrew: `brew install git`
- **Check**: `git --version`

#### 3. **Composer**
- **Requirement**: Composer for PHP package management
- **Mac Compatibility**: ✅ Compatible
- **Installation**:
  - Download from https://getcomposer.org/
  - Or install via Homebrew: `brew install composer`
- **Check**: `composer --version`

#### 4. **PHP**
- **Requirement**: PHP 7.4+ for running the semver checker
- **Mac Compatibility**: ✅ Compatible
- **Installation**:
  - Pre-installed on macOS (version 7.3+)
  - Or install via Homebrew: `brew install php`
- **Check**: `php --version`

#### 5. **jq (JSON Processor)**
- **Requirement**: jq for parsing JSON output from composer audit
- **Mac Compatibility**: ✅ Compatible
- **Installation**: `brew install jq`
- **Check**: `jq --version`

#### 6. **GNU Sed**
- **Requirement**: sed for string manipulation
- **Mac Compatibility**: ⚠️ Potential Issue
- **Issue**: macOS uses BSD sed, script uses GNU sed syntax
- **Solution**: Install GNU sed via Homebrew: `brew install gnu-sed`
- **Check**: `sed --version` (should show GNU sed)

#### 7. **GNU Grep**
- **Requirement**: grep for regex pattern matching
- **Mac Compatibility**: ⚠️ Potential Issue
- **Issue**: macOS uses BSD grep, script uses GNU grep regex syntax
- **Solution**: Install GNU grep via Homebrew: `brew install grep`
- **Check**: `grep --version` (should show GNU grep)

## Mac-Specific Considerations

### 1. **Path Issues**
- **Problem**: Homebrew-installed GNU tools may not be in PATH
- **Solution**: Add to PATH in `~/.zshrc` or `~/.bash_profile`:
  ```bash
  export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
  export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
  ```

### 2. **File Permissions**
- **Problem**: macOS file permissions might be restrictive
- **Solution**: Ensure script is executable: `chmod +x security_script.sh`

### 3. **Temporary Directory**
- **Compatibility**: ✅ `mktemp -d` works identically on macOS

### 4. **Array Handling**
- **Compatibility**: ✅ Bash arrays work the same on macOS

## Installation Guide for Mac

### Option 1: Using Homebrew (Recommended)
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required dependencies
brew install composer php jq gnu-sed gnu-grep git

# Add GNU tools to PATH
echo 'export PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"' >> ~/.zshrc
echo 'export PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Option 2: Manual Installation
```bash
# Install Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install jq
curl -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-osx-amd64 -o /usr/local/bin/jq
chmod +x /usr/local/bin/jq

# Install GNU sed and grep via Homebrew
brew install gnu-sed gnu-grep
```

## Testing Mac Compatibility

### Pre-flight Check Script
Create a test script to verify all dependencies:

```bash
#!/bin/bash
echo "🔍 Checking dependencies..."

# Check bash version
bash_version=$(bash --version | head -n1 | cut -d' ' -f4 | cut -d'.' -f1)
if [[ $bash_version -ge 4 ]]; then
    echo "✅ Bash version: $(bash --version | head -n1)"
else
    echo "❌ Bash version too old: $(bash --version | head -n1)"
fi

# Check other dependencies
deps=("git" "composer" "php" "jq" "sed" "grep")
for dep in "${deps[@]}"; do
    if command -v "$dep" &> /dev/null; then
        version=$("$dep" --version 2>/dev/null | head -n1)
        echo "✅ $dep: $version"
    else
        echo "❌ $dep: Not found"
    fi
done

# Check if using GNU versions
if sed --version 2>/dev/null | grep -q "GNU"; then
    echo "✅ Using GNU sed"
else
    echo "⚠️  Using BSD sed - consider installing GNU sed"
fi

if grep --version 2>/dev/null | grep -q "GNU"; then
    echo "✅ Using GNU grep"
else
    echo "⚠️  Using BSD grep - consider installing GNU grep"
fi
```

## Potential Issues & Solutions

### 1. **Sed Regex Compatibility**
- **Issue**: BSD sed doesn't support `\s` for whitespace
- **Current Fix**: Script uses `[[:space:]]` which is POSIX-compliant ✅

### 2. **Grep Regex Compatibility**
- **Issue**: BSD grep doesn't support `\d` for digits
- **Current Fix**: Script uses `[0-9]` which is POSIX-compliant ✅

### 3. **Path Separators**
- **Issue**: macOS uses `/` for paths (same as Linux) ✅

### 4. **Line Endings**
- **Issue**: Git might change line endings on macOS
- **Solution**: Configure Git: `git config --global core.autocrlf input`

## Conclusion

The script is **highly compatible with macOS** with the following considerations:

✅ **Fully Compatible**:
- Bash scripting
- Git operations
- Composer commands
- PHP execution
- jq JSON processing
- Temporary directory creation
- Array operations

⚠️ **Requires Attention**:
- Install GNU sed and grep via Homebrew
- Add GNU tools to PATH
- Ensure proper file permissions

The script should work seamlessly on macOS after installing the required dependencies via Homebrew.
