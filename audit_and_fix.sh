#!/bin/bash
set -euo pipefail

# Configuration
if [[ $# -eq 0 ]]; then
    echo "❌ Error: Project folder argument is required"
    echo "Usage: $0 <project_folder>"
    echo "Example: $0 /var/www/php_project"
    exit 1
fi

PROJECT_FOLDER="$1"

# Validate project folder exists
if [[ ! -d "$PROJECT_FOLDER" ]]; then
    echo "❌ Error: Project folder '$PROJECT_FOLDER' does not exist"
    exit 1
fi

# Change to project directory
cd "$PROJECT_FOLDER"
# Find composer.json in the current directory or any immediate subdirectory (top-most children)
COMPOSER_JSON_PATH=""
if [[ -f "composer.json" ]]; then
    COMPOSER_JSON_PATH="composer.json"
else
    for d in */ ; do
        if [[ -f "${d}composer.json" ]]; then
            COMPOSER_JSON_PATH="${d}composer.json"
            break
        fi
    done
fi

if [[ -z "$COMPOSER_JSON_PATH" ]]; then
    echo "❌ Error: No composer.json found in current directory or its immediate subdirectories."
    exit 1
fi

echo "✅ Found composer.json at: $COMPOSER_JSON_PATH"

cd $(dirname "$COMPOSER_JSON_PATH")

echo "📁 Working in: $(pwd)"

echo "🔄 Checking out 'dev' branch..."
git checkout dev

echo "⬇️  Pulling latest changes from remote..."
git pull

echo "📦 Installing/updating Composer dependencies..."
composer install

# Create temporary working dir for PHP helper
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Create PHP semver checker
cat > "$TMPDIR/semver-check.php" <<'PHP'
<?php
require __DIR__ . '/vendor/autoload.php';
use Composer\Semver\Semver;
[$_, $ver, $range] = $argv;
exit(Semver::satisfies($ver, $range) ? 0 : 1);
PHP

# Install composer/semver in isolated temp dir
composer --no-interaction --quiet --working-dir="$TMPDIR" require composer/semver

# Run audit
AUDIT_JSON=$(composer audit -f json || true)

# Debug: Check if we got valid JSON
echo "🔍 Checking audit output..."
if [[ -z "$AUDIT_JSON" ]]; then
    echo "❌ No audit output received"
    exit 1
fi

# Try to parse with jq to see the exact error
if ! echo "$AUDIT_JSON" | jq -e . >/dev/null 2>&1; then
    echo "❌ Invalid JSON received from composer audit"
    echo "First 200 characters of output:"
    echo "$AUDIT_JSON" | head -c 200
    echo "..."
    exit 1
fi

if ! echo "$AUDIT_JSON" | jq -e .advisories >/dev/null; then
    echo "✅ No advisories found or invalid audit output."
    exit 0
fi

VULNERABLE_PACKAGES=$(echo "$AUDIT_JSON" | jq -r '.advisories | keys[]')

echo "🔒 Checking for safe security upgrades..."

for PACKAGE in $VULNERABLE_PACKAGES; do
    echo "🔍 $PACKAGE"

    CURRENT_VERSION=$(composer show "$PACKAGE" --format=json | jq -r '.versions[0]')
    echo "   📦 Installed version: $CURRENT_VERSION"


    AFFECTED_RANGES=$(echo "$AUDIT_JSON" | jq -r --arg pkg "$PACKAGE" '.advisories[$pkg] | to_entries[] | .value.affectedVersions')

    # Transform AFFECTED_RANGES by splitting on "||" and filtering out empty ranges
    RANGES=()
    IFS='||' read -ra TEMP_RANGES <<< "$AFFECTED_RANGES"
    for range in "${TEMP_RANGES[@]}"; do
        trimmed_range=$(echo "$range" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -n "$trimmed_range" ]]; then
            RANGES+=("$trimmed_range")
        fi
    done

    # Debug: Show the ranges we're working with
    echo "   🎯 Affected ranges: ${RANGES[*]}"

    # Only stable versions like X.Y.Z
    AVAILABLE_VERSIONS=$(composer show "$PACKAGE" --all --format=json | jq -r '.versions[]' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$')

    SAFE_VERSION=""
    IS_SAFE=false

    # Check if we have valid ranges to process
    if [[ ${#RANGES[@]} -eq 0 ]]; then
        echo "   ⚠️  No valid affected ranges found"
        continue
    fi

    for VER in $AVAILABLE_VERSIONS; do
      VULNERABLE=false
      for RANGE in "${RANGES[@]}"; do
        if [[ -n "$RANGE" ]]; then
          if php "$TMPDIR/semver-check.php" "$VER" "$RANGE"; then
            echo "   🔴 $VER satisfies $RANGE (VULNERABLE)"
            VULNERABLE=true
            break
          fi
        fi
      done

      # If version is not vulnerable to any range, it's safe
      if [[ "$VULNERABLE" == false ]]; then
        echo "      ✅ $VER is SAFE (not in any affected range)"
        IS_SAFE=true
        SAFE_VERSION="$VER"
        break
      fi
    done


    if [[ "$IS_SAFE" == true && -n "$SAFE_VERSION" ]]; then
        echo "   ✅ Safe version found: $SAFE_VERSION"
        echo "   🚀 Running: composer require $PACKAGE:$SAFE_VERSION --with-all-dependencies"
        composer require "$PACKAGE:$SAFE_VERSION" -w
    else
        echo "   ⚠️  No safe upgrade available in current branch."
    fi

    echo
done
