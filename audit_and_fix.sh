#!/bin/bash
set -euo pipefail

# Initialize variables
UPGRADE_MAJOR=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u)
            UPGRADE_MAJOR=true
            shift
            ;;
        -*)
            echo "❌ Error: Unknown option $1"
            echo "Usage: $0 [-u] <project_folder>"
            echo "Options:"
            echo "  -u    Enable major version upgrades"
            echo "Example: $0 -u /var/www/php_project"
            exit 1
            ;;
        *)
            PROJECT_FOLDER="$1"
            shift
            ;;
    esac
done

# Configuration
if [[ -z "${PROJECT_FOLDER:-}" ]]; then
    echo "❌ Error: Project folder argument is required"
    echo "Usage: $0 [-u] <project_folder>"
    echo "Options:"
    echo "  -u    Enable major version upgrades"
    echo "Example: $0 -u /var/www/php_project"
    exit 1
fi

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
composer install -q

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
    echo "⚠️  Continuing with other operations despite audit failure..."
    # Don't exit, continue with the script
fi

if ! echo "$AUDIT_JSON" | jq -e .advisories >/dev/null; then
    echo "✅ No advisories found or invalid audit output."
    echo "🎉 Script completed successfully!"
    exit 0
fi

VULNERABLE_PACKAGES=$(echo "$AUDIT_JSON" | jq -r '.advisories | keys[]')

echo "🔒 Checking for safe security upgrades..."

for PACKAGE in $VULNERABLE_PACKAGES; do
    echo "🔍 $PACKAGE"

    # Get current version with error handling
    CURRENT_VERSION=$(composer show "$PACKAGE" --format=json 2>/dev/null | jq -r '.versions[0]' 2>/dev/null || echo "unknown")
    if [[ "$CURRENT_VERSION" == "null" || "$CURRENT_VERSION" == "unknown" ]]; then
        echo "   ⚠️  Could not determine current version for $PACKAGE, skipping..."
        echo
        continue
    fi
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
    AVAILABLE_VERSIONS=$(composer show "$PACKAGE" --all --format=json 2>/dev/null | jq -r '.versions[]' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' || echo "")

    if [[ -z "$AVAILABLE_VERSIONS" ]]; then
        echo "   ⚠️  Could not retrieve available versions for $PACKAGE, skipping..."
        echo
        continue
    fi

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
            # echo "   🔴 $VER satisfies $RANGE (VULNERABLE)"
            VULNERABLE=true
            break
          fi
        fi
      done

      # If version is not vulnerable to any range, it's safe
      if [[ "$VULNERABLE" == false ]]; then
        # Determine if we allow major upgrade
        if [[ "$UPGRADE_MAJOR" == "true" ]]; then
          echo "      ✅ $VER is SAFE (not in any affected range, major upgrade allowed)"
          IS_SAFE=true
          SAFE_VERSION="$VER"
          break
        else
          # Compare major version (first part before dot)
          CURRENT_MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
          VER_MAJOR=$(echo "$VER" | cut -d. -f1)
          if [[ "$CURRENT_MAJOR" == "$VER_MAJOR" ]]; then
            echo "      ✅ $VER is SAFE (not in any affected range, same major version)"
            IS_SAFE=true
            SAFE_VERSION="$VER"
            break
          else
            echo "      ⏩ $VER is SAFE but major version differs ($CURRENT_MAJOR vs $VER_MAJOR), skipping"
          fi
        fi
      fi
    done


    if [[ "$IS_SAFE" == true && -n "$SAFE_VERSION" ]]; then
        echo "   ✅ Safe version found: $SAFE_VERSION"
        echo "   🚀 Running: composer require $PACKAGE:$SAFE_VERSION --with-all-dependencies"
        if composer require "$PACKAGE:$SAFE_VERSION" -w; then
            echo "   ✅ Successfully upgraded $PACKAGE to $SAFE_VERSION"
        else
            echo "   ⚠️  Failed to upgrade $PACKAGE to $SAFE_VERSION, continuing with other packages..."
        fi
    else
        echo "   ⚠️  No safe upgrade available for $PACKAGE in current branch."
    fi

    echo
done

echo "🎉 Security audit and upgrade process completed!"
