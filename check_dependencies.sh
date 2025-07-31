#!/bin/bash

echo "🔍 Security Script Dependency Checker"
echo "====================================="

# Check bash version
bash_version=$(bash --version | head -n1 | cut -d' ' -f4 | cut -d'.' -f1)
if [[ $bash_version -ge 4 ]]; then
    echo "✅ Bash version: $(bash --version | head -n1)"
else
    echo "❌ Bash version too old: $(bash --version | head -n1)"
    echo "   Please upgrade bash to version 4.0 or higher"
fi

echo

# Check other dependencies
deps=("git" "composer" "php" "jq")
for dep in "${deps[@]}"; do
    if command -v "$dep" &> /dev/null; then
        version=$("$dep" --version 2>/dev/null | head -n1)
        echo "✅ $dep: $version"
    else
        echo "❌ $dep: Not found"
        case $dep in
            "git")
                echo "   Install: brew install git"
                ;;
            "composer")
                echo "   Install: brew install composer"
                ;;
            "php")
                echo "   Install: brew install php"
                ;;
            "jq")
                echo "   Install: brew install jq"
                ;;
        esac
    fi
done

echo

# Check if using GNU versions
if sed --version 2>/dev/null | grep -q "GNU"; then
    echo "✅ Using GNU sed: $(sed --version | head -n1)"
else
    echo "⚠️  Using BSD sed - consider installing GNU sed"
    echo "   Install: brew install gnu-sed"
    echo "   Add to PATH: export PATH=\"/usr/local/opt/gnu-sed/libexec/gnubin:\$PATH\""
fi

if grep --version 2>/dev/null | grep -q "GNU"; then
    echo "✅ Using GNU grep: $(grep --version | head -n1)"
else
    echo "⚠️  Using BSD grep - consider installing GNU grep"
    echo "   Install: brew install gnu-grep"
    echo "   Add to PATH: export PATH=\"/usr/local/opt/grep/libexec/gnubin:\$PATH\""
fi

echo
echo "📋 Summary:"
echo "==========="

# Count issues
issues=0
if [[ $bash_version -lt 4 ]]; then
    ((issues++))
fi

for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        ((issues++))
    fi
done

if ! sed --version 2>/dev/null | grep -q "GNU"; then
    ((issues++))
fi

if ! grep --version 2>/dev/null | grep -q "GNU"; then
    ((issues++))
fi

if [[ $issues -eq 0 ]]; then
    echo "🎉 All dependencies are satisfied! The security script should work properly."
else
    echo "⚠️  Found $issues issue(s) that need to be resolved before running the security script."
fi
