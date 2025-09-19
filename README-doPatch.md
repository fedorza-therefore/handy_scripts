# doPatch.sh - Composer Package Patch Management Tool

A comprehensive shell script for creating, managing, and applying patches to composer packages in Drupal projects. This tool integrates seamlessly with `cweagans/composer-patches` to provide a complete patch management workflow.

## 🚀 Features

- **Create Patches**: Generate patches by comparing modified packages with their original versions
- **Apply Existing Patches**: Automatically applies existing patches to temporary projects to ensure only new changes are captured
- **Patch Management**: Add, remove, and list patches in composer.json
- **Unique Patch Files**: Generates unique patch filenames to prevent conflicts
- **Composer Integration**: Full integration with `cweagans/composer-patches`
- **Smart Path Detection**: Automatically finds packages in vendor, modules/contrib, or themes/contrib directories
- **Robust JSON Handling**: Uses `jq` for reliable JSON manipulation with fallbacks
- **Comprehensive Error Handling**: Detailed error messages and warnings

## 📋 Prerequisites

- **Bash**: The script requires bash shell
- **Composer**: Must be installed and accessible
- **jq** (recommended): For robust JSON manipulation
- **Python3** (fallback): For JSON manipulation when jq is not available
- **patch**: For applying patches (usually pre-installed on Linux/macOS)

## 🛠️ Installation

1. **Download the script**:
   ```bash
   # Make the script executable
   chmod +x doPatch.sh
   ```

2. **Ensure dependencies**:
   ```bash
   # Install jq (recommended)
   sudo apt-get install jq  # Ubuntu/Debian
   brew install jq          # macOS

   # Verify composer is available
   composer --version
   ```

3. **Verify composer-patches is configured**:
   ```bash
   # Check if cweagans/composer-patches is in your composer.json
   grep -A 5 "cweagans/composer-patches" composer.json
   ```

## 📖 Usage

### Basic Syntax

```bash
./doPatch.sh <command> [options]
```

### Commands

#### 1. Create a Patch

```bash
./doPatch.sh create <package_name> [description]
```

**Examples**:
```bash
# Create a patch with auto-generated description
./doPatch.sh create drupal/symfony_mailer

# Create a patch with custom description
./doPatch.sh create drupal/symfony_mailer "add Token replacement to legacy"

# Create a patch for a vendor package
./doPatch.sh create guzzlehttp/guzzle "fix timeout issue"
```

#### 2. Remove a Patch

```bash
./doPatch.sh remove <package_name> [description]
```

**Examples**:
```bash
# Remove a specific patch
./doPatch.sh remove drupal/symfony_mailer "add Token replacement to legacy"

# Remove all patches for a package
./doPatch.sh remove drupal/symfony_mailer
```

#### 3. List Patches

```bash
./doPatch.sh list [package_name]
```

**Examples**:
```bash
# List all patches
./doPatch.sh list

# List patches for a specific package
./doPatch.sh list drupal/symfony_mailer
```

## 🔧 How It Works

### Patch Creation Process

1. **Package Discovery**: Finds the package in your project (vendor, modules/contrib, or themes/contrib)
2. **Temporary Project**: Creates a temporary composer project in `/tmp`
3. **Original Installation**: Installs the original package without modifications
4. **Existing Patches**: Applies any existing patches to the temporary project
5. **Diff Generation**: Compares the patched temporary project with your modified version
6. **Patch File**: Creates a properly formatted patch file in `./patches/`
7. **Composer Integration**: Adds the patch to composer.json

### Patch File Naming

Patches are named using the format:
```
{package_name}_{description_hash}.patch
```

Example: `drupal_symfony_mailer_e02074d6.patch`

## 📁 Directory Structure

The script expects the following structure:

```
project-root/
├── composer.json          # Must contain cweagans/composer-patches
├── patches/               # Directory for patch files
│   ├── package1_abc123.patch
│   └── package2_def456.patch
├── vendor/                # Composer packages
├── web/modules/contrib/   # Drupal modules
└── web/themes/contrib/    # Drupal themes
```

## 🎯 Use Cases

### 1. Modifying Drupal Modules

```bash
# 1. Make your changes to the module
vim web/modules/contrib/symfony_mailer/src/Plugin/EmailBuilder/LegacyEmailBuilder.php

# 2. Create a patch
./doPatch.sh create drupal/symfony_mailer "add user token support"

# 3. Apply the patch
composer install
```

### 2. Fixing Vendor Package Issues

```bash
# 1. Modify the vendor package
vim vendor/guzzlehttp/guzzle/src/Client.php

# 2. Create a patch
./doPatch.sh create guzzlehttp/guzzle "fix connection timeout"

# 3. Apply the patch
composer install
```

### 3. Managing Multiple Patches

```bash
# List all patches
./doPatch.sh list

# Remove an outdated patch
./doPatch.sh remove drupal/symfony_mailer "old fix"

# Create a new patch
./doPatch.sh create drupal/symfony_mailer "new improved fix"
```

## ⚙️ Configuration

### Composer.json Requirements

Your `composer.json` must include:

```json
{
    "require": {
        "cweagans/composer-patches": "^1.6.5"
    },
    "extra": {
        "patches": {}
    }
}
```

### Environment Variables

The script uses the current working directory as the project root. Make sure to run it from the directory containing `composer.json`.

## 🐛 Troubleshooting

### Common Issues

#### 1. "Package not found" Error

**Problem**: Script can't find the package in your project.

**Solution**:
- Ensure the package is installed via composer
- Check if it's in `vendor/`, `web/modules/contrib/`, or `web/themes/contrib/`
- Verify the package name is correct

#### 2. "Failed to apply patch" Warning

**Problem**: Existing patches fail to apply to the temporary project.

**Solution**:
- This is often expected if patches are already applied
- The script will continue and create patches for new changes only
- Check patch file format if issues persist

#### 3. "jq not found" Warning

**Problem**: JSON manipulation falls back to less reliable methods.

**Solution**:
```bash
# Install jq
sudo apt-get install jq  # Ubuntu/Debian
brew install jq          # macOS
```

#### 4. "No differences found" Message

**Problem**: No new changes detected.

**Possible Causes**:
- All changes are already covered by existing patches
- No modifications were made to the package
- Package is identical to the original version

### Debug Mode

For detailed debugging, you can modify the script to show more information:

```bash
# Add debug output by modifying the script
# Look for lines with ">/dev/null 2>&1" and remove the redirection
```

## 🔒 Security Considerations

- **Backup Creation**: The script automatically creates backups of `composer.json` before modifications
- **Temporary Files**: All temporary files are created in `/tmp` and cleaned up automatically
- **Path Validation**: Script validates paths to prevent directory traversal issues
- **Permission Checks**: Ensures proper file permissions for patch files

## 📝 Best Practices

### 1. Descriptive Patch Names

```bash
# Good
./doPatch.sh create drupal/symfony_mailer "fix token replacement in legacy emails"

# Avoid
./doPatch.sh create drupal/symfony_mailer "fix"
```

### 2. Regular Patch Cleanup

```bash
# List all patches regularly
./doPatch.sh list

# Remove outdated patches
./doPatch.sh remove package/name "outdated description"
```

### 3. Version Control

- Commit patch files to version control
- Document patch purposes in commit messages
- Keep patches minimal and focused

### 4. Testing

```bash
# Test patches after creation
composer install
# Run your application tests
```

## 🤝 Contributing

To improve the script:

1. **Report Issues**: Document any bugs or limitations
2. **Feature Requests**: Suggest new functionality
3. **Code Improvements**: Submit pull requests for enhancements

## 📄 License

This script is provided as-is for use in Drupal projects. Modify as needed for your specific requirements.

## 🆘 Support

For issues or questions:

1. Check the troubleshooting section above
2. Verify all prerequisites are met
3. Test with a simple package first
4. Review the script output for specific error messages

---

**Note**: This script is designed specifically for Drupal projects using `cweagans/composer-patches`. For other projects, modifications may be required.
