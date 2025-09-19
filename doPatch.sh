#!/bin/bash

# Script to create patches for composer packages
# Usage: ./doPatch.sh <package_name> [description]
# Example: ./doPatch.sh drupal/symfony_mailer "add Token replacement to legacy"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create <package_name> [description]  - Create a new patch for a package"
    echo "  remove <package_name> [description]  - Remove a patch from composer.json"
    echo "  list [package_name]                  - List all patches or patches for a specific package"
    echo ""
    echo "Examples:"
    echo "  $0 create drupal/symfony_mailer \"add Token replacement to legacy\""
    echo "  $0 remove drupal/symfony_mailer \"add Token replacement to legacy\""
    echo "  $0 list"
    echo "  $0 list drupal/symfony_mailer"
}

# Check if command is provided
if [ $# -lt 1 ]; then
    show_usage
    exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
    "create")
        if [ $# -lt 1 ]; then
            print_error "Usage: $0 create <package_name> [description]"
            print_error "Example: $0 create drupal/symfony_mailer \"add Token replacement to legacy\""
            exit 1
        fi
        ;;
    "remove")
        if [ $# -lt 1 ]; then
            print_error "Usage: $0 remove <package_name> [description]"
            print_error "Example: $0 remove drupal/symfony_mailer \"add Token replacement to legacy\""
            exit 1
        fi
        ;;
    "list")
        # Set up paths for list command
        DRUPAL_DIR="$(pwd)"
        COMPOSER_JSON="$DRUPAL_DIR/composer.json"

        # Handle list command
        if [ $# -eq 0 ]; then
            # List all patches
            print_status "All patches in composer.json:"
            if command -v jq >/dev/null 2>&1; then
                jq -r '.extra.patches // {} | to_entries[] | "\(.key):\n" + (.value | to_entries[] | "  - \(.key): \(.value)")' "$COMPOSER_JSON" 2>/dev/null || echo "No patches found or jq not available"
            else
                grep -A 20 '"patches"' "$COMPOSER_JSON" | grep -E '^\s*"[^"]+"' | head -20
            fi
            exit 0
        else
            # List patches for specific package
            PACKAGE_NAME="$1"
            print_status "Patches for $PACKAGE_NAME:"
            if command -v jq >/dev/null 2>&1; then
                jq -r ".extra.patches.\"$PACKAGE_NAME\" // {} | to_entries[] | \"  - \(.key): \(.value)\"" "$COMPOSER_JSON" 2>/dev/null || echo "No patches found for $PACKAGE_NAME"
            else
                grep -A 10 "\"$PACKAGE_NAME\"" "$COMPOSER_JSON" | grep -E '^\s*"[^"]+"' | head -10
            fi
            exit 0
        fi
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac

# For create and remove commands, get the package name and description
PACKAGE_NAME="$1"
DESCRIPTION="${2:-Custom patch for $PACKAGE_NAME}"
DRUPAL_DIR="$(pwd)"
PATCHES_DIR="$DRUPAL_DIR/patches"
COMPOSER_JSON="$DRUPAL_DIR/composer.json"

# Check if we're in the right directory
if [ ! -f "$COMPOSER_JSON" ]; then
    print_error "composer.json not found at $COMPOSER_JSON"
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Handle remove command
if [ "$COMMAND" = "remove" ]; then
    print_status "Removing patch for package: $PACKAGE_NAME"

    # Create backup of composer.json
    cp "$COMPOSER_JSON" "$COMPOSER_JSON.backup"

    # Check if jq is available
    if command -v jq >/dev/null 2>&1; then
        # Use jq to remove the patch
        if jq -e ".extra.patches.\"$PACKAGE_NAME\"" "$COMPOSER_JSON" >/dev/null 2>&1; then
            if [ -n "$DESCRIPTION" ] && [ "$DESCRIPTION" != "Custom patch for $PACKAGE_NAME" ]; then
                # Remove specific patch
                jq "del(.extra.patches.\"$PACKAGE_NAME\".\"$DESCRIPTION\")" "$COMPOSER_JSON" > "$COMPOSER_JSON.tmp" && mv "$COMPOSER_JSON.tmp" "$COMPOSER_JSON"
                print_success "Removed patch '$DESCRIPTION' for package $PACKAGE_NAME"
            else
                # Remove all patches for the package
                jq "del(.extra.patches.\"$PACKAGE_NAME\")" "$COMPOSER_JSON" > "$COMPOSER_JSON.tmp" && mv "$COMPOSER_JSON.tmp" "$COMPOSER_JSON"
                print_success "Removed all patches for package $PACKAGE_NAME"
            fi
        else
            print_warning "No patches found for package $PACKAGE_NAME"
        fi
    else
        print_error "jq is required for removing patches. Please install jq or manually edit composer.json"
        exit 1
    fi

    print_success "Patch removal completed!"
    exit 0
fi

# Handle create command
if [ "$COMMAND" = "create" ]; then
    print_status "Starting patch creation for package: $PACKAGE_NAME"
else
    print_error "Unknown command: $COMMAND"
    exit 1
fi

# Step 1: Find package location in current project
print_status "Step 1: Finding package location in current project..."

# Check if package is in vendor directory
VENDOR_PATH="$DRUPAL_DIR/vendor/$PACKAGE_NAME"
if [ -d "$VENDOR_PATH" ]; then
    LOCAL_PACKAGE_PATH="$VENDOR_PATH"
    print_success "Found package in vendor directory: $LOCAL_PACKAGE_PATH"
else
    # Check if it's a Drupal module/theme in web directory
    PACKAGE_BASENAME=$(basename "$PACKAGE_NAME")
    WEB_MODULE_PATH="$DRUPAL_DIR/web/modules/contrib/$PACKAGE_BASENAME"
    WEB_THEME_PATH="$DRUPAL_DIR/web/themes/contrib/$PACKAGE_BASENAME"

    if [ -d "$WEB_MODULE_PATH" ]; then
        LOCAL_PACKAGE_PATH="$WEB_MODULE_PATH"
        print_success "Found Drupal module in web directory: $LOCAL_PACKAGE_PATH"
    elif [ -d "$WEB_THEME_PATH" ]; then
        LOCAL_PACKAGE_PATH="$WEB_THEME_PATH"
        print_success "Found Drupal theme in web directory: $LOCAL_PACKAGE_PATH"
    else
        print_error "Package $PACKAGE_NAME not found in vendor, modules/contrib, or themes/contrib directories"
        exit 1
    fi
fi

# Step 2: Create temporary composer project
print_status "Step 2: Creating temporary composer project..."

TEMP_DIR="/tmp/composer-patch-$$"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Create minimal composer.json for temporary project
cat > composer.json << EOF
{
    "name": "temp/patch-project",
    "type": "project",
    "repositories": [
        {
            "type": "composer",
            "url": "https://packages.drupal.org/8"
        }
    ],
    "require": {
        "composer/installers": "^1.9",
        "drupal/core": "^10",
        "$PACKAGE_NAME": "*"
    },
    "minimum-stability": "dev",
    "prefer-stable": true,
    "config": {
        "allow-plugins": {
            "composer/installers": true,
            "drupal/core-composer-scaffold": true
        }
    }
}
EOF

print_status "Installing package in temporary project..."
composer install --no-dev --no-scripts --quiet

# Find the installed package path in temp project
TEMP_PACKAGE_PATH=""
if [ -d "vendor/$PACKAGE_NAME" ]; then
    TEMP_PACKAGE_PATH="vendor/$PACKAGE_NAME"
elif [ -d "web/modules/contrib/$(basename "$PACKAGE_NAME")" ]; then
    TEMP_PACKAGE_PATH="web/modules/contrib/$(basename "$PACKAGE_NAME")"
elif [ -d "web/themes/contrib/$(basename "$PACKAGE_NAME")" ]; then
    TEMP_PACKAGE_PATH="web/themes/contrib/$(basename "$PACKAGE_NAME")"
elif [ -d "modules/$(basename "$PACKAGE_NAME")" ]; then
    TEMP_PACKAGE_PATH="modules/$(basename "$PACKAGE_NAME")"
elif [ -d "themes/$(basename "$PACKAGE_NAME")" ]; then
    TEMP_PACKAGE_PATH="themes/$(basename "$PACKAGE_NAME")"
else
    # Try to find the package anywhere in the project
    FOUND_PATH=$(find . -name "$(basename "$PACKAGE_NAME")" -type d 2>/dev/null | head -1)
    if [ -n "$FOUND_PATH" ]; then
        TEMP_PACKAGE_PATH="$FOUND_PATH"
    else
        print_error "Could not find installed package in temporary project"
        print_status "Checking what was actually installed..."
        find . -name "$(basename "$PACKAGE_NAME")" -type d 2>/dev/null | head -5
        print_status "Contents of vendor directory:"
        ls -la vendor/ 2>/dev/null | head -10
        print_status "Contents of web directory:"
        ls -la web/ 2>/dev/null | head -10
        rm -rf "$TEMP_DIR"
        exit 1
    fi
fi

print_success "Package installed in temporary project at: $TEMP_PACKAGE_PATH"

# Apply existing patches to the temporary project to ensure we only capture new changes
print_status "Applying existing patches to temporary project..."

# Check if the package has existing patches in the original composer.json
if command -v jq >/dev/null 2>&1; then
    # Get existing patches for this package
    EXISTING_PATCHES=$(jq -r ".extra.patches.\"$PACKAGE_NAME\" // {} | to_entries[] | .value" "$DRUPAL_DIR/composer.json" 2>/dev/null)

    if [ -n "$EXISTING_PATCHES" ]; then
        print_status "Found existing patches for $PACKAGE_NAME, applying them to temporary project..."

        # Apply each existing patch
        echo "$EXISTING_PATCHES" | while read -r patch_file; do
            if [ -n "$patch_file" ]; then
                # Convert relative path to absolute path
                if [[ "$patch_file" == ./* ]]; then
                    patch_file="$DRUPAL_DIR/$patch_file"
                fi

                if [ -f "$patch_file" ]; then
                    print_status "Applying existing patch: $(basename "$patch_file")"

                    # Create a temporary patch file with corrected paths
                    TEMP_PATCH_FILE="/tmp/temp_patch_$$"

                    # Read the patch and fix the paths to match the temporary project structure
                    # The patch has paths like "a/symfony_mailer/src/..." but we need "a/src/..."
                    sed "s|^--- a/symfony_mailer/|--- a/|g; s|^+++ b/symfony_mailer/|+++ b/|g" "$patch_file" > "$TEMP_PATCH_FILE"

                    # Try different patch levels (p0, p1, p2)
                    PATCH_APPLIED=false
                    for patch_level in 0 1 2; do
                        if patch -p$patch_level -d "$TEMP_PACKAGE_PATH" < "$TEMP_PATCH_FILE" >/dev/null 2>&1; then
                            print_success "Applied patch: $(basename "$patch_file") (with -p$patch_level)"
                            PATCH_APPLIED=true
                            break
                        fi
                    done

                    # Clean up temporary patch file
                    rm -f "$TEMP_PATCH_FILE"

                    if [ "$PATCH_APPLIED" = false ]; then
                        print_warning "Failed to apply patch: $(basename "$patch_file") (tried -p0, -p1, -p2)"
                        # Show the first few lines of the patch for debugging
                        print_status "Patch content preview:"
                        head -5 "$patch_file" | sed 's/^/  /'
                        print_status "Temporary project structure:"
                        find "$TEMP_PACKAGE_PATH" -name "*.php" | head -3 | sed 's/^/  /'
                    fi
                else
                    print_warning "Patch file not found: $patch_file"
                fi
            fi
        done
    else
        print_status "No existing patches found for $PACKAGE_NAME"
    fi
else
    print_warning "jq not available, cannot check for existing patches"
fi

# Step 3: Create patch file
print_status "Step 3: Creating patch file..."

# Create patches directory if it doesn't exist
mkdir -p "$PATCHES_DIR"

# Generate unique patch filename based on package name and description
PACKAGE_BASENAME=$(echo "$PACKAGE_NAME" | sed 's/[\/\\]/_/g')
DESCRIPTION_HASH=$(echo "$DESCRIPTION" | md5sum | cut -c1-8)
PATCH_FILENAME="${PACKAGE_BASENAME}_${DESCRIPTION_HASH}.patch"
PATCH_FILE="$PATCHES_DIR/$PATCH_FILENAME"

# Create the patch using diff with proper options for composer-patches
print_status "Generating diff between original and modified versions..."

# Change to temp directory to get relative paths
cd "$TEMP_DIR"

# Create patch with relative paths and exclude unwanted files
if diff -u -r --exclude="*.rej" --exclude="PATCHES.txt" --exclude=".git*" "$TEMP_PACKAGE_PATH" "$LOCAL_PACKAGE_PATH" > "$PATCH_FILE" 2>/dev/null; then
    print_warning "No differences found between original and modified versions"
    rm -f "$PATCH_FILE"
    rm -rf "$TEMP_DIR"
    exit 0
fi

# Go back to original directory
cd "$DRUPAL_DIR"

# Post-process the patch to make it compatible with composer-patches
# Create a temporary file for processing
TEMP_PATCH="/tmp/patch_$$"

# Remove lines that start with "Only in" as they're not needed for patches
grep -v "^Only in" "$PATCH_FILE" > "$TEMP_PATCH"

# Remove the first line if it contains diff command arguments
sed -i '1d' "$TEMP_PATCH"

# Replace absolute paths with relative paths that work with composer-patches
# The pattern should be: a/package/path/file and b/package/path/file
PACKAGE_BASENAME=$(basename "$TEMP_PACKAGE_PATH")

# Extract the relative path from the original paths and create proper patch headers
sed -i "s|^--- .*$PACKAGE_BASENAME/|--- a/$PACKAGE_BASENAME/|g" "$TEMP_PATCH"
sed -i "s|^+++ .*$PACKAGE_BASENAME/|+++ b/$PACKAGE_BASENAME/|g" "$TEMP_PATCH"

# Replace the original patch file
mv "$TEMP_PATCH" "$PATCH_FILE"

print_success "Patch file created: $PATCH_FILE"

# Step 4: Add patch to composer.json
print_status "Step 4: Adding patch to composer.json..."

# Create backup of composer.json
cp "$COMPOSER_JSON" "$COMPOSER_JSON.backup"

# Check if jq is available for better JSON manipulation
if command -v jq >/dev/null 2>&1; then
    print_status "Using jq for JSON manipulation"
    USE_JQ=true
else
    print_warning "jq not found, using sed for JSON manipulation (less reliable)"
    USE_JQ=false
fi

if [ "$USE_JQ" = true ]; then
    # Use jq for robust JSON manipulation
    # Check if patches section exists
    if ! jq -e '.extra.patches' "$COMPOSER_JSON" >/dev/null 2>&1; then
        print_status "Creating patches section in composer.json"
        # Create the patches section
        jq '.extra.patches = {}' "$COMPOSER_JSON" > "$COMPOSER_JSON.tmp" && mv "$COMPOSER_JSON.tmp" "$COMPOSER_JSON"
    fi

    # Check if package already has patches
    if jq -e ".extra.patches.\"$PACKAGE_NAME\"" "$COMPOSER_JSON" >/dev/null 2>&1; then
        # Check if this exact description already exists
        if jq -e ".extra.patches.\"$PACKAGE_NAME\".\"$DESCRIPTION\"" "$COMPOSER_JSON" >/dev/null 2>&1; then
            print_warning "Patch with description '$DESCRIPTION' already exists for package $PACKAGE_NAME"
            print_warning "Use a different description or remove the existing patch first"
            rm -rf "$TEMP_DIR"
            exit 1
        fi
        print_status "Package $PACKAGE_NAME already has patches, adding new patch"
        # Add new patch to existing package
        jq ".extra.patches.\"$PACKAGE_NAME\".\"$DESCRIPTION\" = \"./patches/$PATCH_FILENAME\"" "$COMPOSER_JSON" > "$COMPOSER_JSON.tmp" && mv "$COMPOSER_JSON.tmp" "$COMPOSER_JSON"
    else
        print_status "Adding new package entry to patches"
        # Add new package with patch
        jq ".extra.patches.\"$PACKAGE_NAME\" = {\"$DESCRIPTION\": \"./patches/$PATCH_FILENAME\"}" "$COMPOSER_JSON" > "$COMPOSER_JSON.tmp" && mv "$COMPOSER_JSON.tmp" "$COMPOSER_JSON"
    fi
else
    # Fallback to sed-based approach
    # Check if patches section exists
    if ! grep -q '"patches"' "$COMPOSER_JSON"; then
        print_status "Creating patches section in composer.json"
        # Add patches section before the closing brace of extra
        sed -i '/"extra": {/,/}/ {
            /}/ i\
        "patches": {}
        }' "$COMPOSER_JSON"
    fi

    # Check if package already has patches
    if grep -q "\"$PACKAGE_NAME\"" "$COMPOSER_JSON"; then
        print_status "Package $PACKAGE_NAME already has patches, adding new patch"
        # Add new patch to existing package - this is complex with sed, so we'll use a different approach
        # Create a temporary file with the new patch entry
        TEMP_JSON="/tmp/composer_$$.json"
        python3 -c "
import json
import sys

# Read the composer.json
with open('$COMPOSER_JSON', 'r') as f:
    data = json.load(f)

# Ensure patches section exists
if 'extra' not in data:
    data['extra'] = {}
if 'patches' not in data['extra']:
    data['extra']['patches'] = {}

# Add the patch
package_name = '$PACKAGE_NAME'
description = '$DESCRIPTION'
patch_file = './patches/$PATCH_FILENAME'

if package_name not in data['extra']['patches']:
    data['extra']['patches'][package_name] = {}

data['extra']['patches'][package_name][description] = patch_file

# Write back to file
with open('$TEMP_JSON', 'w') as f:
    json.dump(data, f, indent=4)
" 2>/dev/null

        if [ -f "$TEMP_JSON" ]; then
            mv "$TEMP_JSON" "$COMPOSER_JSON"
            print_success "Patch added to composer.json using Python"
        else
            print_warning "Failed to add patch using Python, manual addition required"
            print_warning "Add this entry to the patches section:"
            print_warning "    \"$PACKAGE_NAME\": {"
            print_warning "        \"$DESCRIPTION\": \"./patches/$PATCH_FILENAME\""
            print_warning "    }"
        fi
    else
        print_status "Adding new package entry to patches"
        # Add new package with patch using sed
        PATCH_ENTRY="            \"$PACKAGE_NAME\": {
                \"$DESCRIPTION\": \"./patches/$PATCH_FILENAME\"
            },"

        # Find the patches section and add the entry
        sed -i "/\"patches\": {/,/}/ {
            /}/ i\\
$PATCH_ENTRY
        }" "$COMPOSER_JSON"
    fi
fi

print_success "Patch added to composer.json"

# Cleanup
rm -rf "$TEMP_DIR"

print_success "Patch creation completed successfully!"
print_status "Patch file: $PATCH_FILE"
print_status "Description: $DESCRIPTION"
print_warning "Remember to run 'composer install' to apply the patch"
