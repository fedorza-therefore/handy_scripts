#!/bin/bash

set -euo pipefail

PROJECT_DIR=${1:-}
WORKDIR="/tmp/d11check"
RESULTS_FILE="d11-branch-compatible.csv"
UPGRADABLE="$WORKDIR/d11-upgradable.csv"
INCOMPATIBLE="$WORKDIR/d11-incompatible.csv"

if [[ -z "$PROJECT_DIR" || ! -d "$PROJECT_DIR" ]]; then
  echo "❌ Usage: $0 /path/to/your/drupal/project"
  exit 1
fi

# Reset test environment
echo "🧹 Resetting test Composer project..."
rm -rf "$WORKDIR"
mkdir -p "$WORKDIR"

composer create-project drupal/recommended-project:^11 $WORKDIR --no-interaction --no-install

# Allow RC/beta/alpha versions
composer config minimum-stability rc
composer config prefer-stable true

composer install --no-scripts --no-plugins

INPUT_FILE="$WORKDIR/why-not.csv"

echo "📥 Generating input from $PROJECT_DIR..."
cd "$PROJECT_DIR" || exit 1
PROJECT_DIR="$PWD"

set +e
composer why-not drupal/core 11 | \
  grep -vE '^drupal/core|^drupal-composer/drupal-project|^Not finding' | \
  awk '{$1=$1; print}' | \
  awk -F'\t' 'NF {gsub(/[[:space:]]+/, ","); print}' \
  > "$INPUT_FILE"
set -e

echo "📄 Parsed package constraints saved to $INPUT_FILE"

cd "$WORKDIR" || exit 1

# Clear previous output files
> "$UPGRADABLE"
> "$INCOMPATIBLE"

echo "🔍 Starting compatibility checks..."

while IFS=, read -r pkg current_version relation constraint; do
  # Skip empty lines or header lines if any
  [[ -z "$pkg" || "$pkg" == "package" ]] && continue

  echo "📦 Checking $pkg..."

  versions=$(composer show "$pkg" --all 2>/dev/null | \
    awk -F ':' '/^versions[[:space:]]*:/ {
      gsub(/\*/, "", $2); gsub(/^[[:space:]]+/, "", $2); gsub(/[[:space:]]+/, " ", $2);
      print $2
    }')

  if [[ -z "$versions" ]]; then
    echo "⚠️ Could not fetch versions for $pkg"
    echo "$pkg" >> "$INCOMPATIBLE"
    continue
  fi

  # Extract unique major versions, sorted ascending
  majors=$(echo "$versions" | tr ' ' '\n' \
    | sed -E 's/^([0-9]+)\..*/\1/' \
    | grep -E '^[0-9]+$' | sort -nu)

  found=""
  for major in $majors; do
    echo -n "  🔄 Testing $pkg:^$major... "
    if composer require "$pkg:^$major" --dry-run > /dev/null 2>&1; then
      echo "✅ compatible"
      found="^$major"
      echo "$pkg:$found" >> "$UPGRADABLE"
      break
    else
      echo "❌ not compatible"
    fi
  done

  if [[ -z "$found" ]]; then
    echo "$pkg" >> "$INCOMPATIBLE"
  fi

done < "$INPUT_FILE"

echo
echo "✅ Done."
echo "Upgradable packages saved to: $UPGRADABLE"
echo "Incompatible packages saved to: $INCOMPATIBLE"

UPGRADE_SCRIPT="$PROJECT_DIR/upgrade-packages.sh"

echo "#!/bin/bash" > "$UPGRADE_SCRIPT"
echo "set -e" >> "$UPGRADE_SCRIPT"
echo "# This script runs composer require for upgradable packages" >> "$UPGRADE_SCRIPT"
echo -n "composer require" >> "$UPGRADE_SCRIPT"
awk -F: '{ printf " \"%s:%s\"", $1, $2 }' "$UPGRADABLE" >> "$UPGRADE_SCRIPT"
echo " -W" >> "$UPGRADE_SCRIPT"

chmod +x "$UPGRADE_SCRIPT"

echo "Generated upgrade script at $UPGRADE_SCRIPT"

