#!/usr/bin/env bash
# ---- Runtime requirement guard (Bash >= 4) ----
if [[ -z "${BASH_VERSINFO[0]:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "ERROR: This script requires Bash >= 4.0 (found ${BASH_VERSION:-unknown})." >&2
  echo "Install a newer bash and run with: /usr/local/bin/bash init-sparc-project.sh" >&2
  exit 2
fi

# Enhanced SPARC Project Initialization Script - SECURITY HARDENED
# Version: 2.1.0
# Description: Production-ready SPARC methodology project bootstrapping tool
# Author: SPARC40 Project
# License: MIT

set -euo pipefail

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================

# Input validation patterns (IMMEDIATE ACTION #1)
readonly VALID_PROJECT_NAME_PATTERN='^[a-zA-Z0-9][a-zA-Z0-9_-]{1,63}$'
readonly VALID_PROJECT_ID_PATTERN='^[a-z0-9][a-z0-9-]{1,63}$'
readonly VALID_TEMPLATE_PATTERN='^[a-z][a-z-]{1,20}$'
readonly VALID_TEAM_SIZE_PATTERN='^(solo|small|medium|large|enterprise)$'
readonly VALID_SECURITY_LEVEL_PATTERN='^(basic|medium|high|enterprise)$'
readonly VALID_CLOUD_PROVIDER_PATTERN='^(aws|azure|gcp|none)$'

# Path security configuration (IMMEDIATE ACTION #2)
readonly MAX_PATH_DEPTH=10
readonly ALLOWED_CONFIG_EXTENSIONS=("conf" "config" "yaml" "yml" "json")

# Audit logging configuration (PREVENTIVE MEASURE #3)
readonly AUDIT_LOG_FILE="${HOME}/.sparc/audit.log"
readonly AUDIT_LOG_MAX_SIZE=10485760  # 10MB

# =============================================================================
# CONFIGURATION AND GLOBALS
# =============================================================================

# Script metadata
readonly SCRIPT_VERSION="2.1.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATE_VERSION="2.1.0"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Global state variables
PROJECT_NAME=""
PROJECT_ID=""
SELECTED_TEMPLATE="web-app"
TEAM_SIZE="small"
SECURITY_LEVEL="medium"
INIT_GIT="Y"
INCLUDE_CLOUD="N"
INCLUDE_SECURITY="N"
CLOUD_PROVIDER="aws"
INTERACTIVE_MODE=false
DRY_RUN=false
VERBOSE=false
CONFIG_FILE=""
BACKUP_EXISTING=false

# Cleanup state tracking
CREATED_DIRS=()
CREATED_FILES=()
CLEANUP_ON_EXIT=true

# Template directory for external templates (PREVENTIVE MEASURE #2)
readonly TEMPLATE_DIR="${SCRIPT_DIR}/templates"

# =============================================================================
# SECURITY FUNCTIONS (IMMEDIATE ACTIONS)
# =============================================================================

# Comprehensive input validation (IMMEDIATE ACTION #1 & #4)
validate_input() {
    local input_type="$1"
    local input_value="$2"
    local pattern=""
    
    case "$input_type" in
        "project_name")
            pattern="$VALID_PROJECT_NAME_PATTERN"
            ;;
        "project_id") 
            pattern="$VALID_PROJECT_ID_PATTERN"
            ;;
        "template")
            pattern="$VALID_TEMPLATE_PATTERN"
            ;;
        "team_size")
            pattern="$VALID_TEAM_SIZE_PATTERN"
            ;;
        "security_level")
            pattern="$VALID_SECURITY_LEVEL_PATTERN"
            ;;
        "cloud_provider")
            pattern="$VALID_CLOUD_PROVIDER_PATTERN"
            ;;
        *)
            log_security_event "ERROR" "Unknown input type for validation: $input_type"
            return 1
            ;;
    esac
    
    if [[ ! "$input_value" =~ $pattern ]]; then
        log_security_event "VALIDATION_FAILED" "Invalid $input_type: $input_value"
        return 1
    fi
    
    log_security_event "VALIDATION_SUCCESS" "Valid $input_type: $input_value"
    return 0
}

# Sanitize user input
sanitize_input() {
    local input="$1"
    # Remove any shell metacharacters and control characters
    echo "$input" | tr -d '\000-\037\177' | sed 's/[;&|`$(){}[\]<>]//g'
}

# Path traversal protection (IMMEDIATE ACTION #2)
validate_path() {
    local target_path="$1"
    local base_path="$2"
    
    # Resolve absolute paths
    local resolved_target
    local resolved_base
    
    resolved_target=$(realpath -m "$target_path" 2>/dev/null) || {
        log_security_event "ERROR" "Cannot resolve path: $target_path"
        return 1
    }
    
    resolved_base=$(realpath -m "$base_path" 2>/dev/null) || {
        log_security_event "ERROR" "Cannot resolve base path: $base_path"
        return 1
    }
    
    # Check if target is within base directory
    case "$resolved_target" in
        "$resolved_base"*)
            # Check path depth to prevent deep directory attacks
            local depth
            depth=$(echo "${resolved_target#$resolved_base}" | tr -cd '/' | wc -c)
            if (( depth > MAX_PATH_DEPTH )); then
                log_security_event "PATH_TRAVERSAL_BLOCKED" "Path too deep: $target_path (depth: $depth)"
                return 1
            fi
            log_security_event "PATH_VALIDATION_SUCCESS" "Safe path: $target_path"
            return 0
            ;;
        *)
            log_security_event "PATH_TRAVERSAL_BLOCKED" "Path outside base directory: $target_path"
            return 1
            ;;
    esac
}

# Safe configuration file parsing (IMMEDIATE ACTION #3)
parse_config_file() {
    local config_file="$1"
    
    # Validate file path
    if ! validate_path "$config_file" "$PWD"; then
        print_error "Configuration file path validation failed: $config_file"
        return 1
    fi
    
    # Validate file extension
    local extension="${config_file##*.}"
    local valid_extension=false
    for allowed_ext in "${ALLOWED_CONFIG_EXTENSIONS[@]}"; do
        if [[ "$extension" == "$allowed_ext" ]]; then
            valid_extension=true
            break
        fi
    done
    
    if [[ "$valid_extension" != "true" ]]; then
        log_security_event "CONFIG_VALIDATION_FAILED" "Invalid config file extension: $extension"
        print_error "Invalid configuration file extension: $extension"
        return 1
    fi
    
    # Check file size and permissions
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        return 1
    fi
    
    if [[ ! -r "$config_file" ]]; then
        print_error "Configuration file not readable: $config_file"
        return 1
    fi
    
    local file_size
    file_size=$(stat -f%z "$config_file" 2>/dev/null || stat -c%s "$config_file" 2>/dev/null || echo 0)
    if (( file_size > 1048576 )); then  # 1MB limit
        log_security_event "CONFIG_VALIDATION_FAILED" "Config file too large: $file_size bytes"
        print_error "Configuration file too large (max 1MB): $config_file"
        return 1
    fi
    
    log_security_event "CONFIG_FILE_ACCESS" "Parsing config file: $config_file"
    
    case "$extension" in
        "yaml"|"yml")
            parse_yaml_config "$config_file"
            ;;
        "json")
            parse_json_config "$config_file" 
            ;;
        "conf"|"config")
            parse_shell_config "$config_file"
            ;;
        *)
            print_error "Unsupported configuration format: $extension"
            return 1
            ;;
    esac
}

# Safe YAML parsing without external dependencies
parse_yaml_config() {
    local config_file="$1"
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Parse key-value pairs
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z][a-zA-Z0-9_]*)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes from value
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
            
            # Sanitize and validate
            key=$(sanitize_input "$key")
            value=$(sanitize_input "$value")
            
            case "$key" in
                "projectName")
                    if validate_input "project_name" "$value"; then
                        PROJECT_NAME="$value"
                    else
                        print_error "Invalid project name in config file (line $line_num): $value"
                        return 1
                    fi
                    ;;
                "template")
                    if validate_input "template" "$value"; then
                        SELECTED_TEMPLATE="$value"
                    else
                        print_error "Invalid template in config file (line $line_num): $value"
                        return 1
                    fi
                    ;;
                "teamSize")
                    if validate_input "team_size" "$value"; then
                        TEAM_SIZE="$value"
                    else
                        print_error "Invalid team size in config file (line $line_num): $value"
                        return 1
                    fi
                    ;;
                "securityLevel")
                    if validate_input "security_level" "$value"; then
                        SECURITY_LEVEL="$value"
                    else
                        print_error "Invalid security level in config file (line $line_num): $value"
                        return 1
                    fi
                    ;;
                # Add other configuration options as needed
            esac
        fi
    done < "$config_file"
}

# Safe JSON parsing using built-in capabilities
parse_json_config() {
    local config_file="$1"
    
    # Simple JSON parsing for basic key-value pairs
    # Note: This is a simplified parser; for complex JSON, consider using jq
    local content
    content=$(cat "$config_file")
    
    # Remove whitespace and extract key-value pairs
    content=$(echo "$content" | tr -d '\n\r\t ')
    
    # Extract values using regex (simplified approach)
    if [[ "$content" =~ \"projectName\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
        local value="${BASH_REMATCH[1]}"
        value=$(sanitize_input "$value")
        if validate_input "project_name" "$value"; then
            PROJECT_NAME="$value"
        else
            print_error "Invalid project name in JSON config: $value"
            return 1
        fi
    fi
    
    # Add similar parsing for other JSON fields as needed
}

# Safe shell configuration parsing (no direct sourcing)
parse_shell_config() {
    local config_file="$1"
    local line_num=0
    
    while IFS= read -r line; do
        ((line_num++))
        
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Only allow simple variable assignments
        if [[ "$line" =~ ^[[:space:]]*([A-Z_][A-Z0-9_]*)[[:space:]]*=[[:space:]]*[\"\']*([^\"\']*)[\"\']*[[:space:]]*$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Sanitize inputs
            key=$(sanitize_input "$key")
            value=$(sanitize_input "$value")
            
            case "$key" in
                "PROJECT_NAME")
                    if validate_input "project_name" "$value"; then
                        PROJECT_NAME="$value"
                    else
                        print_error "Invalid PROJECT_NAME in config (line $line_num): $value"
                        return 1
                    fi
                    ;;
                "SELECTED_TEMPLATE")
                    if validate_input "template" "$value"; then
                        SELECTED_TEMPLATE="$value"
                    else
                        print_error "Invalid SELECTED_TEMPLATE in config (line $line_num): $value"
                        return 1
                    fi
                    ;;
                # Add other variables as needed
            esac
        else
            print_error "Invalid configuration syntax (line $line_num): $line"
            return 1
        fi
    done < "$config_file"
}

# =============================================================================
# AUDIT LOGGING FUNCTIONS (PREVENTIVE MEASURE #3)
# =============================================================================

# Initialize audit logging
init_audit_log() {
    local audit_dir
    audit_dir=$(dirname "$AUDIT_LOG_FILE")
    
    # Create audit directory if it doesn't exist
    if [[ ! -d "$audit_dir" ]]; then
        mkdir -p "$audit_dir" || {
            print_warning "Cannot create audit log directory: $audit_dir"
            return 1
        }
    fi
    
    # Rotate log if it's too large
    if [[ -f "$AUDIT_LOG_FILE" ]]; then
        local log_size
        log_size=$(stat -f%z "$AUDIT_LOG_FILE" 2>/dev/null || stat -c%s "$AUDIT_LOG_FILE" 2>/dev/null || echo 0)
        if (( log_size > AUDIT_LOG_MAX_SIZE )); then
            mv "$AUDIT_LOG_FILE" "${AUDIT_LOG_FILE}.old"
        fi
    fi
    
    return 0
}

# Log security-relevant events
log_security_event() {
    local event_type="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    local log_entry
    log_entry="$timestamp | $event_type | PID:$$ | USER:${USER:-unknown} | $message"
    
    # Log to file if possible
    if init_audit_log; then
        echo "$log_entry" >> "$AUDIT_LOG_FILE" 2>/dev/null || true
    fi
    
    # Also log to stderr in verbose mode
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[AUDIT] $log_entry" >&2
    fi
}

# =============================================================================
# UTILITY FUNCTIONS (SPLIT LARGE FUNCTIONS - PREVENTIVE MEASURE #5)
# =============================================================================

# Print functions (extracted for maintainability)
print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}" >&2
    log_security_event "ERROR" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}" >&2
    log_security_event "WARNING" "$1"
}

print_success() {
    echo -e "${GREEN}✓ SUCCESS: $1${NC}"
    log_security_event "SUCCESS" "$1"
}

print_info() {
    echo -e "${BLUE}ℹ INFO: $1${NC}"
}

print_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}🔍 DEBUG: $1${NC}" >&2
    fi
}

# Argument parsing (extracted from main function)
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                PROJECT_NAME="$2"
                if ! validate_input "project_name" "$PROJECT_NAME"; then
                    print_error "Invalid project name format: $PROJECT_NAME"
                    exit 1
                fi
                shift 2
                ;;
            --template)
                SELECTED_TEMPLATE="$2"
                if ! validate_input "template" "$SELECTED_TEMPLATE"; then
                    print_error "Invalid template format: $SELECTED_TEMPLATE"
                    exit 1
                fi
                shift 2
                ;;
            --team-size)
                TEAM_SIZE="$2"
                if ! validate_input "team_size" "$TEAM_SIZE"; then
                    print_error "Invalid team size: $TEAM_SIZE"
                    exit 1
                fi
                shift 2
                ;;
            --security-level)
                SECURITY_LEVEL="$2"
                if ! validate_input "security_level" "$SECURITY_LEVEL"; then
                    print_error "Invalid security level: $SECURITY_LEVEL"
                    exit 1
                fi
                shift 2
                ;;
            --cloud-provider)
                CLOUD_PROVIDER="$2"
                if ! validate_input "cloud_provider" "$CLOUD_PROVIDER"; then
                    print_error "Invalid cloud provider: $CLOUD_PROVIDER"
                    exit 1
                fi
                INCLUDE_CLOUD="Y"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --no-git)
                INIT_GIT="N"
                shift
                ;;
            --backup-existing)
                BACKUP_EXISTING=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            --version)
                echo "SPARC Project Initialization Script v$SCRIPT_VERSION"
                exit 0
                ;;
            *)
                print_error "Unknown argument: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    log_security_event "ARGUMENTS_PARSED" "Command line arguments processed successfully"
}

# Project validation (extracted and enhanced)
validate_project_configuration() {
    local errors=0
    
    # Validate project name
    if [[ -z "$PROJECT_NAME" ]]; then
        print_error "Project name is required"
        ((errors++))
    fi
    
    # Generate project ID from name if not set
    if [[ -z "$PROJECT_ID" ]]; then
        PROJECT_ID=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
        if ! validate_input "project_id" "$PROJECT_ID"; then
            print_error "Cannot generate valid project ID from name: $PROJECT_NAME"
            ((errors++))
        fi
    fi
    
    # Validate template exists
    if [[ ! -v PROJECT_TEMPLATES["$SELECTED_TEMPLATE"] ]]; then
        print_error "Unknown template: $SELECTED_TEMPLATE"
        ((errors++))
    fi
    
    # Check if project directory already exists
    if [[ -d "$PROJECT_ID" ]]; then
        if [[ "$BACKUP_EXISTING" == "true" ]]; then
            print_info "Existing project will be backed up"
        else
            print_error "Project directory already exists: $PROJECT_ID (use --backup-existing to backup)"
            ((errors++))
        fi
    fi
    
    if (( errors > 0 )); then
        print_error "Configuration validation failed with $errors error(s)"
        return 1
    fi
    
    log_security_event "CONFIG_VALIDATED" "Project configuration validated successfully"
    return 0
}

# Directory creation with security checks
create_secure_directory() {
    local dir_path="$1"
    local permissions="${2:-755}"
    
    # Validate path
    if ! validate_path "$dir_path" "$PWD"; then
        print_error "Invalid directory path: $dir_path"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would create directory: $dir_path"
        return 0
    fi
    
    if mkdir -p "$dir_path"; then
        chmod "$permissions" "$dir_path"
        CREATED_DIRS+=("$dir_path")
        log_security_event "DIRECTORY_CREATED" "Created directory: $dir_path (permissions: $permissions)"
        return 0
    else
        print_error "Failed to create directory: $dir_path"
        return 1
    fi
}

# File creation with security checks
create_secure_file() {
    local file_path="$1"
    local content="$2"
    local permissions="${3:-644}"
    
    # Validate path
    if ! validate_path "$file_path" "$PWD"; then
        print_error "Invalid file path: $file_path"
        return 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would create file: $file_path"
        return 0
    fi
    
    # Create parent directory if needed
    local dir_path
    dir_path=$(dirname "$file_path")
    if [[ ! -d "$dir_path" ]]; then
        create_secure_directory "$dir_path" || return 1
    fi
    
    if echo "$content" > "$file_path"; then
        chmod "$permissions" "$file_path"
        CREATED_FILES+=("$file_path")
        log_security_event "FILE_CREATED" "Created file: $file_path (permissions: $permissions)"
        return 0
    else
        print_error "Failed to create file: $file_path"
        return 1
    fi
}

# =============================================================================
# TEMPLATE LOADING FUNCTIONS (PREVENTIVE MEASURE #2)
# =============================================================================

# Load template from external file
load_template() {
    local template_name="$1"
    local template_type="$2"  # e.g., "readme", "architecture", "spec"
    
    local template_file="${TEMPLATE_DIR}/${template_name}/${template_type}.template"
    
    if [[ -f "$template_file" ]]; then
        # Validate template file path
        if validate_path "$template_file" "$SCRIPT_DIR"; then
            cat "$template_file"
            log_security_event "TEMPLATE_LOADED" "Loaded template: $template_file"
        else
            print_error "Template file path validation failed: $template_file"
            return 1
        fi
    else
        # Fallback to inline template
        print_debug "Template file not found, using inline template: $template_file"
        generate_inline_template "$template_name" "$template_type"
    fi
}

# Generate inline template (fallback)
generate_inline_template() {
    local template_name="$1"
    local template_type="$2"
    
    case "$template_type" in
        "readme")
            cat << 'EOF'
# [PROJECT_NAME]

## Overview
[PROJECT_DESCRIPTION]

## Getting Started
[GETTING_STARTED_INSTRUCTIONS]

## Security
This project follows security best practices as defined in our security documentation.

---
*Generated by SPARC Initialization Script*
EOF
            ;;
        "architecture")
            cat << 'EOF'
# Architecture Documentation

## System Overview
[SYSTEM_OVERVIEW]

## Security Architecture
[SECURITY_CONTROLS]

## Deployment Architecture
[DEPLOYMENT_DETAILS]

---
*Generated by SPARC Initialization Script*
EOF
            ;;
        *)
            print_error "Unknown template type: $template_type"
            return 1
            ;;
    esac
}

# =============================================================================
# PROJECT TEMPLATES CONFIGURATION
# =============================================================================

declare -A PROJECT_TEMPLATES=(
    ["web-app"]="Modern web application with React/Next.js focus"
    ["api-service"]="RESTful API service with database integration"
    ["mobile-app"]="Cross-platform mobile application"
    ["enterprise"]="Enterprise application with compliance requirements"
    ["ml-project"]="Machine learning and data science project"
    ["microservices"]="Microservices architecture with distributed systems"
    ["fullstack"]="Full-stack application with frontend and backend"
    ["minimal"]="Minimal SPARC setup with core features only"
)

declare -A TEAM_CONFIGS=(
    ["solo"]="Individual developer (1 person)"
    ["small"]="Small team (2-5 people)"
    ["medium"]="Medium team (6-15 people)"
    ["large"]="Large team (16+ people)"
    ["enterprise"]="Enterprise organization (multiple teams)"
)

declare -A SECURITY_LEVELS=(
    ["basic"]="Basic security controls and practices"
    ["medium"]="Enhanced security with monitoring and compliance"
    ["high"]="High security with advanced threat protection"
    ["enterprise"]="Enterprise-grade security with full compliance"
)

# =============================================================================
# MAIN EXECUTION FLOW
# =============================================================================

# Enhanced main function (PREVENTIVE MEASURE #5)
main() {
    # Initialize audit logging
    init_audit_log
    log_security_event "SCRIPT_STARTED" "SPARC initialization script v$SCRIPT_VERSION started"
    
    # Parse and validate arguments
    parse_arguments "$@"
    
    # Load configuration file if specified
    if [[ -n "$CONFIG_FILE" ]]; then
        if ! parse_config_file "$CONFIG_FILE"; then
            print_error "Failed to parse configuration file"
            exit 1
        fi
    fi
    
    # Set up error handling and cleanup
    setup_error_handling
    
    # Interactive mode override
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        interactive_setup
    fi
    
    # Validate project configuration
    if ! validate_project_configuration; then
        exit 1
    fi
    
    # Execute project creation
    if ! create_project_structure; then
        print_error "Project creation failed"
        exit 1
    fi
    
    # Finalize and report success
    finalize_project_setup
    
    log_security_event "SCRIPT_COMPLETED" "SPARC initialization completed successfully for project: $PROJECT_NAME"
}

# Project creation orchestration
create_project_structure() {
    print_info "Creating SPARC project: $PROJECT_NAME ($PROJECT_ID)"
    
    # Backup existing project if needed
    if [[ -d "$PROJECT_ID" && "$BACKUP_EXISTING" == "true" ]]; then
        backup_existing_project
    fi
    
    # Create main project directory
    if ! create_secure_directory "$PROJECT_ID"; then
        return 1
    fi
    
    # Change to project directory
    cd "$PROJECT_ID" || {
        print_error "Cannot change to project directory: $PROJECT_ID"
        return 1
    }
    
    # Create project subdirectories
    create_project_directories
    
    # Generate project files
    generate_project_files
    
    # Initialize version control if requested
    if [[ "$INIT_GIT" == "Y" ]]; then
        initialize_git_repository
    fi
    
    return 0
}

# Create project directory structure
create_project_directories() {
    local dirs=(
        "docs"
        "src"
        "tests"
        "scripts"
        ".roo"
        "config"
        "docs/architecture"
        "docs/security" 
        "docs/deployment"
    )
    
    for dir in "${dirs[@]}"; do
        create_secure_directory "$dir" || return 1
    done
}

# Generate all project files
generate_project_files() {
    # Core SPARC files
    local readme_content
    readme_content=$(load_template "$SELECTED_TEMPLATE" "readme")
    readme_content="${readme_content//\[PROJECT_NAME\]/$PROJECT_NAME}"
    readme_content="${readme_content//\[PROJECT_DESCRIPTION\]/${PROJECT_TEMPLATES[$SELECTED_TEMPLATE]}}"
    create_secure_file "README.md" "$readme_content"
    
    # Create other essential files
    create_secure_file ".gitignore" "$(generate_gitignore)"
    create_secure_file "docs/specification.md" "$(load_template "$SELECTED_TEMPLATE" "spec")"
    create_secure_file "docs/architecture.md" "$(load_template "$SELECTED_TEMPLATE" "architecture")"
    
    # Security documentation
    create_secure_file "docs/security/security-requirements.md" "$(generate_security_requirements)"
    
    # SPARC configuration files
    create_secure_file ".roo/config.yaml" "$(generate_roo_config)"
    create_secure_file ".roomodes" "$(generate_roomodes)"
    create_secure_file ".rooignore" "$(generate_rooignore)"
}

# Simplified template generation functions
generate_gitignore() {
    cat << 'EOF'
# Dependencies
node_modules/
*.log
.env
.env.local

# Build outputs
dist/
build/
*.min.*

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
EOF
}

generate_security_requirements() {
    cat << EOF
# Security Requirements

## Security Level: ${SECURITY_LEVEL^^}

### Authentication Requirements
- Multi-factor authentication required
- Password complexity requirements enforced
- Session management with secure timeouts

### Data Protection
- Encryption at rest and in transit
- PII handling procedures
- Data retention policies

### Access Control
- Role-based access control (RBAC)
- Principle of least privilege
- Regular access reviews

---
*Generated for $PROJECT_NAME*
*Security Level: $SECURITY_LEVEL*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

generate_roo_config() {
    cat << EOF
project:
  name: "$PROJECT_NAME"
  id: "$PROJECT_ID"
  template: "$SELECTED_TEMPLATE"
  version: "1.0.0"
  
team:
  size: "$TEAM_SIZE"
  
security:
  level: "$SECURITY_LEVEL"
  audit_enabled: true
  
sparc:
  version: "$SCRIPT_VERSION"
  phases:
    - specification
    - pseudocode
    - architecture
    - refinement
    - completion
EOF
}

generate_roomodes() {
    echo "sparc-spec,sparc-arch,sparc-code,sparc-test,sparc-deploy"
}

generate_rooignore() {
    cat << 'EOF'
# Temporary files
*.tmp
*.temp
.sparc-tmp/

# Sensitive data
*.key
*.pem
.env*
secrets/

# Build artifacts
build/
dist/
target/
EOF
}

# Initialize git repository
initialize_git_repository() {
    if command -v git >/dev/null 2>&1; then
        if [[ "$DRY_RUN" == "true" ]]; then
            print_info "DRY RUN: Would initialize git repository"
            return 0
        fi
        
        git init >/dev/null 2>&1
        git add . >/dev/null 2>&1
        git commit -m "Initial commit: SPARC project initialization" >/dev/null 2>&1
        
        print_success "Git repository initialized"
        log_security_event "GIT_INITIALIZED" "Git repository initialized for project: $PROJECT_NAME"
    else
        print_warning "Git not found, skipping repository initialization"
    fi
}

# Backup existing project
backup_existing_project() {
    local backup_name="${PROJECT_ID}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would backup existing project to: $backup_name"
        return 0
    fi
    
    print_info "📦 Backing up existing project to: $backup_name"
    
    if mv "$PROJECT_ID" "$backup_name"; then
        print_success "Backup created: $backup_name"
        log_security_event "PROJECT_BACKED_UP" "Existing project backed up to: $backup_name"
    else
        print_error "Failed to backup existing project"
        return 1
    fi
}

# Enhanced error handling setup
setup_error_handling() {
    # Set up exit trap for cleanup
    trap cleanup_on_error ERR EXIT
    
    # Enable cleanup on specific signals
    trap cleanup_on_signal INT TERM QUIT
}

# Enhanced cleanup function
cleanup_on_error() {
    local exit_code=$?
    
    if [[ "$CLEANUP_ON_EXIT" == "true" && $exit_code -ne 0 ]]; then
        print_warning "🧹 Cleaning up due to error (exit code: $exit_code)..."
        log_security_event "CLEANUP_STARTED" "Error cleanup initiated with exit code: $exit_code"
        
        # Remove created files first (safer)
        for file in "${CREATED_FILES[@]}"; do
            if [[ -f "$file" ]]; then
                print_debug "Removing file: $file"
                rm -f "$file" || true
            fi
        done
        
        # Remove created directories (in reverse order)
        local i
        for (( i=${#CREATED_DIRS[@]}-1; i>=0; i-- )); do
            local dir="${CREATED_DIRS[i]}"
            if [[ -d "$dir" ]]; then
                print_debug "Removing directory: $dir"
                rmdir "$dir" 2>/dev/null || true
            fi
        done
        
        log_security_event "CLEANUP_COMPLETED" "Error cleanup completed"
        print_info "Cleanup completed"
    fi
    
    # Reset cleanup flag
    CLEANUP_ON_EXIT=true
}

# Enhanced signal handling
cleanup_on_signal() {
    print_warning "🛑 Operation interrupted by user signal"
    log_security_event "SCRIPT_INTERRUPTED" "Script execution interrupted by user signal"
    CLEANUP_ON_EXIT=true
    exit 130
}

# Finalize project setup
finalize_project_setup() {
    # Disable cleanup on successful completion
    CLEANUP_ON_EXIT=false
    
    print_success "🎉 SPARC project '$PROJECT_NAME' created successfully!"
    print_info "📁 Project location: $(pwd)"
    print_info "📋 Template: $SELECTED_TEMPLATE (${PROJECT_TEMPLATES[$SELECTED_TEMPLATE]})"
    print_info "👥 Team size: $TEAM_SIZE (${TEAM_CONFIGS[$TEAM_SIZE]})"
    print_info "🔒 Security level: $SECURITY_LEVEL (${SECURITY_LEVELS[$SECURITY_LEVEL]})"
    
    echo
    print_info "📖 Next steps:"
    print_info "   1. Review README.md for project overview"
    print_info "   2. Complete docs/specification.md with requirements"
    print_info "   3. Design system architecture in docs/architecture.md"
    print_info "   4. Begin development following SPARC methodology"
    
    if [[ "$INIT_GIT" == "Y" ]]; then
        print_info "   5. Configure git remote: git remote add origin <repository-url>"
    fi
}

# Interactive setup (stub - implement based on needs)
interactive_setup() {
    print_info "🔧 Interactive setup mode"
    log_security_event "INTERACTIVE_MODE_STARTED" "Interactive setup mode initiated"
    
    # Interactive prompts would go here
    # This is a simplified version
    if [[ -z "$PROJECT_NAME" ]]; then
        while true; do
            read -p "Enter project name: " PROJECT_NAME
            if validate_input "project_name" "$PROJECT_NAME"; then
                break
            else
                print_error "Invalid project name format. Use alphanumeric characters, hyphens, and underscores only."
            fi
        done
    fi
}

# Help function
show_help() {
    cat << EOF
SPARC Project Initialization Script v$SCRIPT_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --name NAME              Project name (required)
    --template TEMPLATE      Project template (default: web-app)
    --team-size SIZE         Team size: solo|small|medium|large|enterprise
    --security-level LEVEL   Security level: basic|medium|high|enterprise
    --cloud-provider PROVIDER Cloud provider: aws|azure|gcp|none
    --config FILE            Configuration file path
    --interactive            Interactive setup mode
    --dry-run               Show what would be created without creating
    --verbose               Enable verbose output
    --no-git                Skip git repository initialization
    --backup-existing       Backup existing project directory
    --help                  Show this help message
    --version               Show version information

EXAMPLES:
    $0 --name "MyApp" --template web-app --team-size small
    $0 --interactive
    $0 --config project.yaml --verbose

SECURITY:
    This script includes comprehensive input validation, path traversal protection,
    and audit logging. All user inputs are sanitized and validated.

EOF
}

# Execute main function with all arguments
main "$@"
