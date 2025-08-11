#!/usr/bin/env bash
# ---- Runtime requirement guard (Bash >= 4) ----
if [[ -z "${BASH_VERSINFO[0]:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "ERROR: This script requires Bash >= 4.0 (found ${BASH_VERSION:-unknown})." >&2
  echo "Install a newer bash and run with: /usr/local/bin/bash init-sparc-project.sh" >&2
  exit 2
fi

# Enhanced SPARC Project Initialization Script
# Version: 2.0.0
# Description: Production-ready SPARC methodology project bootstrapping tool
# Author: SPARC40 Project
# License: MIT

set -euo pipefail

# =============================================================================
# CONFIGURATION AND GLOBALS
# =============================================================================

# Script metadata
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATE_VERSION="2.0.0"

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
    ["basic"]="Basic security controls and access patterns"
    ["medium"]="Standard security with enhanced monitoring"
    ["high"]="High security with strict access controls"
    ["enterprise"]="Enterprise-grade security with compliance"
)

declare -A CLOUD_PROVIDERS=(
    ["aws"]="Amazon Web Services"
    ["gcp"]="Google Cloud Platform"
    ["azure"]="Microsoft Azure"
    ["digitalocean"]="DigitalOcean"
    ["none"]="No cloud provider templates"
)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Enhanced output functions with better formatting
print_info() {
    printf "${BLUE}[INFO]${NC} $1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    printf "${RED}[ERROR]${NC} $1" >&2
}

print_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        printf "${PURPLE}[DEBUG]${NC} $1"
    fi
}

print_step() {
    printf "${CYAN}[STEP]${NC} $1"
}

# Progress bar function
show_progress() {
  local current=$1 total=$2 task="$3"
  local percent=$(( total>0 ? (current * 100 / total) : 100 ))
  local filled=$((percent / 2)); ((filled<0)) && filled=0
  local empty=$((50 - filled)); ((empty<0)) && empty=0
  local bar_filled=""; ((filled)) && bar_filled=$(printf "▓%.0s" $(seq 1 $filled))
  local bar_empty=""; ((empty)) && bar_empty=$(printf "░%.0s" $(seq 1 $empty))
  printf "
🚀 [%s%s] %d%% - %s" "$bar_filled" "$bar_empty" "$percent" "$task"
  (( current >= total )) && echo
}# Spinner for long operations
show_spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'
    
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf "\r%s [%c] %s" "$message" "$spinstr" ""
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%s ✅ %s\n" "$message" "Complete"
}

# =============================================================================
# ERROR HANDLING AND CLEANUP
# =============================================================================

# Enhanced cleanup function
cleanup_on_error() {
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        print_warning "🧹 Cleaning up partially created project..."
        
        # Remove created files (in reverse order)
        for ((i=${#CREATED_FILES[@]}-1; i>=0; i--)); do
            if [[ -f "${CREATED_FILES[i]}" ]]; then
                rm -f "${CREATED_FILES[i]}"
                print_debug "Removed file: ${CREATED_FILES[i]}"
            fi
        done
        
        # Remove created directories (in reverse order, only if empty)
        for ((i=${#CREATED_DIRS[@]}-1; i>=0; i--)); do
            if [[ -d "${CREATED_DIRS[i]}" ]]; then
                if rmdir "${CREATED_DIRS[i]}" 2>/dev/null; then
                    print_debug "Removed directory: ${CREATED_DIRS[i]}"
                fi
            fi
        done
        
        print_success "Cleanup completed"
    fi
}

# Trap for cleanup on script exit
trap cleanup_on_error EXIT INT TERM

# Enhanced directory creation with tracking
create_directory_safe() {
    local dir_path="$1"
    local description="${2:-""}"
    
    print_debug "Creating directory: $dir_path"
    
    if mkdir -p "$dir_path" 2>/dev/null; then
        CREATED_DIRS+=("$dir_path")
        if [[ -n "$description" ]]; then
            print_debug "✅ $description: $dir_path"
        fi
        return 0
    else
        print_error "Failed to create directory: $dir_path"
        return 1
    fi
}

# Enhanced file creation with tracking and validation
create_file_safe() {
  local file_path="$1" content="$2" description="${3:-""}"
  local parent_dir; parent_dir="$(dirname "$file_path")"
  [[ -d "$parent_dir" ]] || mkdir -p "$parent_dir"
  if [[ ! -w "$parent_dir" ]]; then
    print_error "No write permission for directory: $parent_dir"; return 1
  fi
  if printf "%s" "$content" > "$file_path"; then
    CREATED_FILES+=("$file_path")
    [[ -n "$description" ]] && print_debug "✅ $description: $file_path"
  else
    print_error "Failed to create file: $file_path"; return 1
  fi
}# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Pre-flight environment validation
validate_environment() {
    local target_dir="${PWD}/${PROJECT_ID}"
    local errors=()
    
    print_step "🔍 Validating environment..."
    
    # Check if target directory already exists
    if [[ -d "$target_dir" ]]; then
        if [[ "$BACKUP_EXISTING" == "true" ]]; then
            print_warning "Directory exists but backup mode enabled"
        else
            errors+=("Directory already exists: $target_dir")
        fi
    fi
    
    # Check disk space (at least 100MB)
    local available_space
    if command -v df >/dev/null 2>&1; then
        available_space=$(df -BM . 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/M//' || echo "1000")
        if [[ "$available_space" -lt 100 ]]; then
            errors+=("Insufficient disk space. Need at least 100MB, have ${available_space}MB")
        fi
    fi
    
    # Check write permissions
    if [[ ! -w "." ]]; then
        errors+=("No write permission in current directory")
    fi
    
    # Validate project name
    if [[ ! "$PROJECT_NAME" =~ ^[a-zA-Z0-9\ \-_\.]+$ ]]; then
        errors+=("Project name contains invalid characters. Use only letters, numbers, spaces, hyphens, underscores, and periods.")
    fi
    
    # Validate project ID
    if [[ ! "$PROJECT_ID" =~ ^[a-z0-9\-_]+$ ]]; then
        errors+=("Project ID contains invalid characters. Use only lowercase letters, numbers, hyphens, and underscores.")
    fi
    
    # Check for restricted project IDs
    local restricted_names=("bin" "etc" "usr" "var" "tmp" "root" "home" "proc" "sys" "dev" "boot" "lib" "opt" "sbin" "srv")
    for name in "${restricted_names[@]}"; do
        if [[ "$PROJECT_ID" == "$name" ]]; then
            errors+=("Project ID '$PROJECT_ID' conflicts with system directory")
        fi
    done
    
    # Validate selected template
    if [[ -z "${PROJECT_TEMPLATES[$SELECTED_TEMPLATE]:-}" ]]; then
        errors+=("Invalid template: $SELECTED_TEMPLATE")
    fi
    
    # Validate team size
    if [[ -z "${TEAM_CONFIGS[$TEAM_SIZE]:-}" ]]; then
        errors+=("Invalid team size: $TEAM_SIZE")
    fi
    
    # Validate security level
    if [[ -z "${SECURITY_LEVELS[$SECURITY_LEVEL]:-}" ]]; then
        errors+=("Invalid security level: $SECURITY_LEVEL")
    fi
    
    # Check for required tools
    local required_tools=("git")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_warning "Recommended tool not found: $tool"
        fi
    done
    
    # Report errors
    if [[ ${#errors[@]} -gt 0 ]]; then
        print_error "Environment validation failed:"
        for error in "${errors[@]}"; do
            printf "  ${RED}•${NC} $error"
        done
        return 1
    fi
    
    print_success "Environment validation passed"
    return 0
  if [[ "$INIT_GIT" =~ ^[Yy] ]]; then
    if ! command -v git >/dev/null 2>&1; then
      print_error "Git is required when initializing a repository (INIT_GIT=Y)."
      return 1
    fi
  fi
}
# Validate custom_modes.yaml structure
validate_custom_modes_yaml() {
  local yaml_file="$1"
  [[ -f "$yaml_file" ]] || { print_warning "custom_modes.yaml not found - will use built-in configuration"; return 0; }
  print_debug "Validating custom_modes.yaml structure..."

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$yaml_file" <<'PY'
import sys, json
p = sys.argv[1]
try:
  import yaml
except Exception:
  sys.exit(0)  # PyYAML not installed -> skip strict validation
with open(p, 'r', encoding='utf-8') as f:
  yaml.safe_load(f)
PY
    status=$?
    if [[ $status -ne 0 ]]; then
      print_error "Invalid YAML syntax in $yaml_file"
      return 1
    fi
  else
    print_warning "python3 not found; skipping YAML validation"
  fi
  local file_size; file_size=$(wc -c < "$yaml_file")
  (( file_size > 1048576 )) && print_warning "custom_modes.yaml is very large (${file_size} bytes)"
  print_success "custom_modes.yaml validation passed"
  return 0
}# Security policy validation
validate_security_policies() {
    print_debug "Validating security policies..."
    
    # Check for potentially sensitive project names
    local sensitive_terms=("admin" "root" "system" "config" "secret" "password" "key" "token" "auth" "login")
    for term in "${sensitive_terms[@]}"; do
        if [[ "${PROJECT_NAME,,}" =~ $term ]]; then
            print_warning "Project name contains potentially sensitive term: '$term'"
            if [[ "$INTERACTIVE_MODE" == "true" ]]; then
                read -p "⚠️  Continue anyway? [y/N]: " CONTINUE_RISKY
                if [[ ! "$CONTINUE_RISKY" =~ ^[Yy] ]]; then
                    return 1
                fi
            fi
            break
        fi
    done
    
    # Validate security level requirements
    if [[ "$SECURITY_LEVEL" == "enterprise" ]] && [[ "$INCLUDE_SECURITY" != "Y" ]]; then
        print_warning "Enterprise security level recommended with security templates"
    fi
    
    print_success "Security policy validation passed"
    return 0
}

# =============================================================================
# INTERACTIVE MODE
# =============================================================================

# Main interactive setup function
interactive_setup() {
    clear
    printf "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                    SPARC PROJECT SETUP v2.0                 ║
║              Interactive Project Configuration               ║
╚══════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}"
    
    print_info "🎯 Welcome to Enhanced SPARC Project Interactive Setup"
    echo
    
    # Project name input with validation
    while true; do
        read -p "📋 Project Name: " PROJECT_NAME
        if [[ -n "$PROJECT_NAME" && "$PROJECT_NAME" =~ ^[a-zA-Z0-9\ \-_\.]+$ ]]; then
            break
        else
            print_warning "Please enter a valid project name (letters, numbers, spaces, hyphens, underscores, periods only)"
        fi
    done
    
    # Auto-generate project ID with option to customize
    DEFAULT_PROJECT_ID=$(generate_project_id "$PROJECT_NAME")
    read -p "🏷️  Project ID [$DEFAULT_PROJECT_ID]: " PROJECT_ID
    PROJECT_ID=${PROJECT_ID:-$DEFAULT_PROJECT_ID}
    
    # Project template selection
    echo
    print_info "📦 Available Project Templates:"
    local i=1
    for template in "${!PROJECT_TEMPLATES[@]}"; do
        echo "   $i. $template - ${PROJECT_TEMPLATES[$template]}"
        ((i++))
    done
    echo
    
    while true; do
        read -p "🎨 Select template [web-app]: " template_input
        template_input=${template_input:-"web-app"}
        
        # Handle numeric input
        if [[ "$template_input" =~ ^[0-9]+$ ]]; then
            local templates_array=($(printf '%s\n' "${!PROJECT_TEMPLATES[@]}" | sort))
            local index=$((template_input - 1))
            if [[ $index -ge 0 && $index -lt ${#templates_array[@]} ]]; then
                SELECTED_TEMPLATE="${templates_array[$index]}"
                break
            fi
        # Handle string input
        elif [[ -n "${PROJECT_TEMPLATES[$template_input]}" ]]; then
            SELECTED_TEMPLATE="$template_input"
            break
        fi
        
        print_warning "Invalid selection. Please choose a valid template."
    done
    
    # Team size selection
    echo
    print_info "👥 Team Size Configuration:"
    i=1
    for size in "${!TEAM_CONFIGS[@]}"; do
        echo "   $i. $size - ${TEAM_CONFIGS[$size]}"
        ((i++))
    done
    echo
    
    while true; do
        read -p "👥 Team size [small]: " team_input
        team_input=${team_input:-"small"}
        
        if [[ "$team_input" =~ ^[0-9]+$ ]]; then
            local teams_array=($(printf '%s\n' "${!TEAM_CONFIGS[@]}" | sort))
            local index=$((team_input - 1))
            if [[ $index -ge 0 && $index -lt ${#teams_array[@]} ]]; then
                TEAM_SIZE="${teams_array[$index]}"
                break
            fi
        elif [[ -n "${TEAM_CONFIGS[$team_input]}" ]]; then
            TEAM_SIZE="$team_input"
            break
        fi
        
        print_warning "Invalid team size. Please choose a valid option."
    done
    
    # Security level selection
    echo
    print_info "🔒 Security Level:"
    i=1
    for level in "${!SECURITY_LEVELS[@]}"; do
        echo "   $i. $level - ${SECURITY_LEVELS[$level]}"
        ((i++))
    done
    echo
    
    while true; do
        read -p "🔒 Security level [medium]: " security_input
        security_input=${security_input:-"medium"}
        
        if [[ "$security_input" =~ ^[0-9]+$ ]]; then
            local security_array=($(printf '%s\n' "${!SECURITY_LEVELS[@]}" | sort))
            local index=$((security_input - 1))
            if [[ $index -ge 0 && $index -lt ${#security_array[@]} ]]; then
                SECURITY_LEVEL="${security_array[$index]}"
                break
            fi
        elif [[ -n "${SECURITY_LEVELS[$security_input]}" ]]; then
            SECURITY_LEVEL="$security_input"
            break
        fi
        
        print_warning "Invalid security level. Please choose a valid option."
    done
    
    # Additional options
    echo
    print_info "🔧 Additional Configuration:"
    
    read -p "🔧 Initialize Git repository? [Y/n]: " INIT_GIT
    INIT_GIT=${INIT_GIT:-"Y"}
    
    if [[ "$INIT_GIT" =~ ^[Yy] ]]; then
        read -p "🌿 Create development branches (develop, staging)? [Y/n]: " CREATE_BRANCHES
        CREATE_BRANCHES=${CREATE_BRANCHES:-"Y"}
    fi
    
    read -p "☁️  Include cloud deployment templates? [y/N]: " INCLUDE_CLOUD
    INCLUDE_CLOUD=${INCLUDE_CLOUD:-"N"}
    
    if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then
        echo
        print_info "☁️  Available Cloud Providers:"
        i=1
        for provider in "${!CLOUD_PROVIDERS[@]}"; do
            echo "   $i. $provider - ${CLOUD_PROVIDERS[$provider]}"
            ((i++))
        done
        
        while true; do
            read -p "☁️  Select cloud provider [aws]: " cloud_input
            cloud_input=${cloud_input:-"aws"}
            
            if [[ -n "${CLOUD_PROVIDERS[$cloud_input]}" ]]; then
                CLOUD_PROVIDER="$cloud_input"
                break
            fi
            
            print_warning "Invalid cloud provider. Please choose a valid option."
        done
    fi
    
    read -p "🔒 Include enterprise security templates? [y/N]: " INCLUDE_SECURITY
    INCLUDE_SECURITY=${INCLUDE_SECURITY:-"N"}
    
    read -p "🧪 Include testing framework setup? [Y/n]: " INCLUDE_TESTING
    INCLUDE_TESTING=${INCLUDE_TESTING:-"Y"}
    
    read -p "📊 Include monitoring and observability? [y/N]: " INCLUDE_MONITORING
    INCLUDE_MONITORING=${INCLUDE_MONITORING:-"N"}
    
    # Configuration summary
    echo
    print_step "📋 Configuration Summary"
    echo "┌─────────────────────────────────────────────────────────────┐"
    printf "│ Project Name: %-45s │\n" "$PROJECT_NAME"
    printf "│ Project ID: %-47s │\n" "$PROJECT_ID"
    printf "│ Template: %-49s │\n" "$SELECTED_TEMPLATE"
    printf "│ Team Size: %-48s │\n" "$TEAM_SIZE"
    printf "│ Security Level: %-43s │\n" "$SECURITY_LEVEL"
    printf "│ Git Repository: %-43s │\n" "$INIT_GIT"
    printf "│ Cloud Templates: %-42s │\n" "$INCLUDE_CLOUD"
    if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then
        printf "│ Cloud Provider: %-43s │\n" "$CLOUD_PROVIDER"
    fi
    printf "│ Security Templates: %-39s │\n" "$INCLUDE_SECURITY"
    printf "│ Testing Framework: %-42s │\n" "$INCLUDE_TESTING"
    printf "│ Monitoring: %-47s │\n" "$INCLUDE_MONITORING"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo
    
    read -p "🚀 Proceed with project creation? [Y/n]: " CONFIRM
    CONFIRM=${CONFIRM:-"Y"}
    
    if [[ ! "$CONFIRM" =~ ^[Yy] ]]; then
        print_info "Project creation cancelled"
        exit 0
    fi
    
    # Ask about dry run
    read -p "🔍 Run in dry-run mode first (preview only)? [y/N]: " DRY_RUN_CONFIRM
    if [[ "$DRY_RUN_CONFIRM" =~ ^[Yy] ]]; then
        DRY_RUN=true
        dry_run_mode
    fi
}

# Dry run mode
dry_run_mode() {
    clear
    print_step "🔍 DRY RUN MODE - Preview of Project Creation"
    echo
    
    echo "📁 Directory Structure to be Created:"
    echo "   $(pwd)/$PROJECT_ID/"
    echo "   ├── 📁 memory-bank/"
    echo "   │   ├── activeContext.md"
    echo "   │   ├── decisionLog.md"
    echo "   │   ├── productContext.md"
    echo "   │   ├── progress.md"
    echo "   │   └── systemPatterns.md"
    echo "   ├── 📁 project/$PROJECT_ID/"
    echo "   ├── 📁 docs/"
    echo "   ├── 📁 reports/"
    echo "   ├── 📁 infrastructure/"
    
    # Template-specific directories
    case "$SELECTED_TEMPLATE" in
        "web-app")
            echo "   ├── 📁 src/components/"
            echo "   ├── 📁 src/pages/"
            echo "   ├── 📁 src/hooks/"
            echo "   ├── 📁 public/"
            echo "   └── 📁 styles/"
            ;;
        "api-service")
            echo "   ├── 📁 src/controllers/"
            echo "   ├── 📁 src/services/"
            echo "   ├── 📁 src/models/"
            echo "   ├── 📁 src/middleware/"
            echo "   └── 📁 src/routes/"
            ;;
        "ml-project")
            echo "   ├── 📁 notebooks/"
            echo "   ├── 📁 data/raw/"
            echo "   ├── 📁 data/processed/"
            echo "   ├── 📁 models/"
            echo "   └── 📁 experiments/"
            ;;
    esac
    
    echo
    echo "📄 Key Files to be Created:"
    echo "   ├── .roomodes (40+ AI mode configuration)"
    echo "   ├── .rooignore (security controls)"
    echo "   ├── .roo/mcp.json (MCP configuration)"
    echo "   ├── specification.md"
    echo "   ├── architecture.md"
    echo "   ├── pseudocode.md"
    echo "   ├── README.md"
    echo "   └── package.json (if applicable)"
    echo
    
    if [[ "$INIT_GIT" =~ ^[Yy] ]]; then
        echo "🔧 Git repository would be initialized"
        if [[ "$CREATE_BRANCHES" =~ ^[Yy] ]]; then
            echo "🌿 Branches: main, develop, staging"
        fi
    fi
    
    if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then
        echo "☁️  Cloud deployment templates for $CLOUD_PROVIDER would be included"
    fi
    
    if [[ "$INCLUDE_SECURITY" =~ ^[Yy] ]]; then
        echo "🔒 Enterprise security templates would be included"
    fi
    
    if [[ "$INCLUDE_TESTING" =~ ^[Yy] ]]; then
        echo "🧪 Testing framework templates would be included"
    fi
    
    if [[ "$INCLUDE_MONITORING" =~ ^[Yy] ]]; then
        echo "📊 Monitoring and observability templates would be included"
    fi
    
    echo
    print_info "💾 Estimated disk usage: ~50-100MB"
    print_info "⏱️  Estimated creation time: 30-60 seconds"
    echo
    
    read -p "💡 Proceed with actual creation? [Y/n]: " PROCEED
    PROCEED=${PROCEED:-"Y"}
    
    if [[ ! "$PROCEED" =~ ^[Yy] ]]; then
        print_info "Dry run completed - no files created"
        exit 0
    fi
    
    # Disable dry run mode for actual creation
    DRY_RUN=false
}

# =============================================================================
# PROJECT GENERATION FUNCTIONS
# =============================================================================

# Function to generate project ID from name
generate_project_id() {
    local name="$1"
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Enhanced directory structure creation with progress tracking
create_directory_structure() {
    print_step "📁 Creating directory structure..."
    
    local total_dirs=25
    local current_dir=0
    
    # Core SPARC directories
    local core_dirs=(
        "memory-bank"
        "project/${PROJECT_ID}/control/conclave"
        "project/${PROJECT_ID}/control/orchestration"
        "project/${PROJECT_ID}/control/planning"
        "project/${PROJECT_ID}/sections"
        "project/${PROJECT_ID}/synthesis"
        "project/${PROJECT_ID}/evidence/research"
        "project/${PROJECT_ID}/evidence/security"
        "project/${PROJECT_ID}/evidence/domain"
        "project/${PROJECT_ID}/evidence/technology"
        "docs"
        "reports"
        "infrastructure"
        "security"
        "tests"
        ".roo/rules"
        ".roo/commands"
    )
    
    for dir in "${core_dirs[@]}"; do
        show_progress $((++current_dir)) $total_dirs "Creating $dir"
        create_directory_safe "$dir" "Core directory"
    done
    
    # Template-specific directories
    create_template_directories "$SELECTED_TEMPLATE"
    
    # Cloud-specific directories
    if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then
        show_progress $((++current_dir)) $total_dirs "Creating cloud infrastructure"
        create_directory_safe "infrastructure/$CLOUD_PROVIDER"
        create_directory_safe "infrastructure/terraform"
        create_directory_safe "infrastructure/k8s"
    fi
    
    # Security-specific directories
    if [[ "$INCLUDE_SECURITY" =~ ^[Yy] ]]; then
        show_progress $((++current_dir)) $total_dirs "Creating security structure"
        create_directory_safe "security/policies"
        create_directory_safe "security/compliance"
        create_directory_safe "security/audit"
    fi
    
    show_progress $total_dirs $total_dirs "Directory structure complete"
    print_success "Directory structure created successfully"
}

# Template-specific directory creation
create_template_directories() {
    local template="$1"
    
    print_debug "Creating template-specific directories for: $template"
    
    case "$template" in
        "web-app")
            create_directory_safe "src/components" "React components"
            create_directory_safe "src/pages" "Page components"
            create_directory_safe "src/hooks" "Custom hooks"
            create_directory_safe "src/utils" "Utility functions"
            create_directory_safe "src/services" "API services"
            create_directory_safe "src/store" "State management"
            create_directory_safe "public" "Static assets"
            create_directory_safe "styles" "CSS/styling"
            ;;
        "api-service")
            create_directory_safe "src/controllers" "API controllers"
            create_directory_safe "src/services" "Business logic"
            create_directory_safe "src/models" "Data models"
            create_directory_safe "src/middleware" "Express middleware"
            create_directory_safe "src/routes" "API routes"
            create_directory_safe "src/config" "Configuration"
            create_directory_safe "src/utils" "Utility functions"
            create_directory_safe "migrations" "Database migrations"
            ;;
        "mobile-app")
            create_directory_safe "src/screens" "Mobile screens"
            create_directory_safe "src/components" "Reusable components"
            create_directory_safe "src/navigation" "Navigation setup"
            create_directory_safe "src/services" "API services"
            create_directory_safe "src/store" "State management"
            create_directory_safe "assets" "Images and assets"
            ;;
        "ml-project")
            create_directory_safe "notebooks" "Jupyter notebooks"
            create_directory_safe "data/raw" "Raw datasets"
            create_directory_safe "data/processed" "Processed data"
            create_directory_safe "data/external" "External datasets"
            create_directory_safe "models" "Trained models"
            create_directory_safe "experiments" "ML experiments"
            create_directory_safe "src/features" "Feature engineering"
            create_directory_safe "src/models" "Model definitions"
            ;;
        "microservices")
            create_directory_safe "services" "Individual services"
            create_directory_safe "shared/libs" "Shared libraries"
            create_directory_safe "shared/types" "Shared types"
            create_directory_safe "gateway" "API gateway"
            create_directory_safe "monitoring" "Service monitoring"
            ;;
        "enterprise")
            create_directory_safe "compliance" "Compliance docs"
            create_directory_safe "governance" "Governance policies"
            create_directory_safe "audit-trails" "Audit documentation"
            create_directory_safe "policies" "Company policies"
            create_directory_safe "reporting" "Business reporting"
            ;;
        "fullstack")
            create_directory_safe "frontend/src" "Frontend source"
            create_directory_safe "backend/src" "Backend source"
            create_directory_safe "shared/types" "Shared types"
            create_directory_safe "database" "Database scripts"
            ;;
    esac
}

# Enhanced Memory Bank creation
create_memory_bank() {
    print_step "🧠 Creating Memory Bank files..."
    
    local files_created=0
    local total_files=5
    
    # activeContext.md
    show_progress $((++files_created)) $total_files "Creating activeContext.md"
    create_file_safe "memory-bank/activeContext.md" "$(generate_active_context)" "Active context tracking"
    
    # decisionLog.md
    show_progress $((++files_created)) $total_files "Creating decisionLog.md"
    create_file_safe "memory-bank/decisionLog.md" "$(generate_decision_log)" "Decision tracking"
    
    # productContext.md
    show_progress $((++files_created)) $total_files "Creating productContext.md"
    create_file_safe "memory-bank/productContext.md" "$(generate_product_context)" "Product context"
    
    # progress.md
    show_progress $((++files_created)) $total_files "Creating progress.md"
    create_file_safe "memory-bank/progress.md" "$(generate_progress_tracking)" "Progress tracking"
    
    # systemPatterns.md
    show_progress $((++files_created)) $total_files "Creating systemPatterns.md"
    create_file_safe "memory-bank/systemPatterns.md" "$(generate_system_patterns)" "System patterns"
    
    print_success "Memory Bank files created"
}

# Enhanced configuration files creation
create_configuration_files() {
    print_step "⚙️  Creating configuration files..."
    
    # Custom modes configuration - use the comprehensive built-in config
    if [[ -f "${SCRIPT_DIR}/custom_modes.yaml" ]]; then
        print_debug "Using custom_modes.yaml from script directory"
        cp "${SCRIPT_DIR}/custom_modes.yaml" .roomodes
        print_success "Comprehensive AI modes configuration installed (40+ modes)"
    else
        print_debug "Creating comprehensive built-in AI modes configuration"
        create_file_safe ".roomodes" "$(generate_comprehensive_roomodes)" "AI modes configuration"
    fi
    
    # Enhanced .rooignore with template and security-specific rules
    create_file_safe ".rooignore" "$(generate_enhanced_rooignore)" "Security access controls"
    
    # Enhanced MCP configuration
    create_file_safe ".roo/mcp.json" "$(generate_mcp_config)" "MCP server configuration"
    
    # Project-specific rules
    create_file_safe ".roo/rules/project.md" "$(generate_project_rules)" "Project rules"
    
    # Team-specific configuration
    if [[ "$TEAM_SIZE" != "solo" ]]; then
        create_file_safe ".roo/rules/team-collaboration.md" "$(generate_team_rules)" "Team collaboration rules"
    fi
    
    print_success "Configuration files created"
}

# Template document creation
create_template_documents() {
    print_step "📄 Creating template documents..."
    
    local docs_created=0
    local total_docs=6
    
    # Enhanced specification template
    show_progress $((++docs_created)) $total_docs "Creating specification.md"
    create_file_safe "specification.md" "$(generate_specification_template)" "Requirements template"
    
    # Enhanced architecture template
    show_progress $((++docs_created)) $total_docs "Creating architecture.md"
    create_file_safe "architecture.md" "$(generate_architecture_template)" "Architecture template"
    
    # Enhanced pseudocode template
    show_progress $((++docs_created)) $total_docs "Creating pseudocode.md"
    create_file_safe "pseudocode.md" "$(generate_pseudocode_template)" "Algorithm template"
    
    # Template-specific additional documents
    show_progress $((++docs_created)) $total_docs "Creating template-specific docs"
    create_template_specific_docs
    
    # Testing documentation if requested
    if [[ "$INCLUDE_TESTING" =~ ^[Yy] ]]; then
        show_progress $((++docs_created)) $total_docs "Creating testing documentation"
        create_file_safe "docs/testing-strategy.md" "$(generate_testing_docs)" "Testing strategy"
    fi
    
    # Package.json for applicable templates
    if [[ "$SELECTED_TEMPLATE" =~ ^(web-app|api-service|fullstack)$ ]]; then
        show_progress $((++docs_created)) $total_docs "Creating package.json"
        create_file_safe "package.json" "$(generate_package_json)" "Node.js configuration"
    fi
    
    show_progress $total_docs $total_docs "Template documents complete"
    print_success "Template documents created"
}

# Project documentation creation
create_project_documentation() {
    print_step "📚 Creating project documentation..."
    
    # Enhanced README with template-specific content
    create_file_safe "README.md" "$(generate_enhanced_readme)" "Project README"
    
    # Getting started guide
    create_file_safe "docs/getting-started.md" "$(generate_getting_started)" "Getting started guide"
    
    # Contributing guide
    create_file_safe "CONTRIBUTING.md" "$(generate_contributing_guide)" "Contributing guidelines"
    
    # Template-specific documentation
    case "$SELECTED_TEMPLATE" in
        "api-service")
            create_file_safe "docs/api-documentation.md" "$(generate_api_docs)" "API documentation"
            ;;
        "ml-project")
            create_file_safe "docs/data-science-workflow.md" "$(generate_ml_docs)" "ML workflow docs"
            ;;
        "enterprise")
            create_file_safe "docs/compliance-guide.md" "$(generate_compliance_docs)" "Compliance guide"
            ;;
    esac
    
    print_success "Project documentation created"
}

# =============================================================================
# CONTENT GENERATION FUNCTIONS
# =============================================================================

# Generate active context with current configuration
generate_active_context() {
    cat << EOF
# Active Context

> **Purpose**: Current working context and immediate handoffs between modes
> **Updated by**: All modes as they complete work and hand off to others
> **Used by**: All modes to understand current state and next actions

## Current Project State

### **Active Phase**
- [x] Project Initialization
- [ ] Specification
- [ ] Pseudocode  
- [ ] Architecture
- [ ] Refinement
- [ ] Completion

### **Current Mode Context**
- **Active Mode**: Project Setup (Enhanced v${SCRIPT_VERSION})
- **Last Updated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- **Current Focus**: Enhanced project structure and template setup
- **Completion Status**: 10% (Project structure created with $SELECTED_TEMPLATE template)

### **Project Configuration**
- **Template**: $SELECTED_TEMPLATE
- **Team Size**: $TEAM_SIZE
- **Security Level**: $SECURITY_LEVEL
- **Git Integration**: $INIT_GIT
- **Cloud Provider**: ${INCLUDE_CLOUD}${INCLUDE_CLOUD:+ ($CLOUD_PROVIDER)}

### **Immediate Next Actions**
1. Review generated project structure and configuration
2. Begin specification phase with SPARC Specification Writer
3. Conduct stakeholder interviews and requirements gathering
4. Define project scope and success criteria

### **Handoff State**
- **From Mode**: Enhanced Project Initialization Script v${SCRIPT_VERSION}
- **To Mode**: SPARC Specification Writer
- **Context**: Complete project structure created with $SELECTED_TEMPLATE template, ready for requirements gathering
- **Blockers**: None - ready to proceed with specification phase

## Current Working Files

### **Primary Deliverables**
- \`specification.md\` - Template created, ready for completion
- \`architecture.md\` - Template created, awaiting specification
- \`pseudocode.md\` - Template created, awaiting requirements

### **Active Research Areas**
- Requirements gathering approach for $SELECTED_TEMPLATE projects
- ${TEAM_SIZE^} team workflow optimization
- $SECURITY_LEVEL security implementation patterns

## Quality Gates Status

### **Initialization Gates**
- [x] Project structure created
- [x] Memory Bank initialized
- [x] Configuration files created (.roomodes, .rooignore, .roo/)
- [x] Template documents created
- [x] Security controls implemented ($SECURITY_LEVEL level)

### **Next Phase Gates**
- [ ] Stakeholder identification complete
- [ ] Requirements gathering methodology defined
- [ ] Acceptance criteria framework established
- [ ] Domain knowledge documented

## Template-Specific Context

### **$SELECTED_TEMPLATE Template Configuration**
${PROJECT_TEMPLATES[$SELECTED_TEMPLATE]}

### **Team Size Considerations**
${TEAM_CONFIGS[$TEAM_SIZE]}

### **Security Level Implementation**
${SECURITY_LEVELS[$SECURITY_LEVEL]}

---

*Generated by Enhanced SPARC Project Initialization Script v${SCRIPT_VERSION}*
*Project: $PROJECT_NAME ($PROJECT_ID)*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Generate enhanced decision log
generate_decision_log() {
    cat << EOF
# Decision Log

> **Purpose**: Record all architectural and strategic decisions with full rationale
> **Updated by**: Architect, Security Architect, Orchestrator, Conclave, and other decision-making modes
> **Used by**: All modes to understand the reasoning behind current choices and maintain consistency

## Project Initialization Decisions

### [INIT-001] - Enhanced SPARC Methodology Adoption

**Date**: $(date -u +"%Y-%m-%d")
**Status**: Accepted
**Deciders**: Project Stakeholders, Enhanced Setup Script v${SCRIPT_VERSION}
**Context**: Need to select development methodology and tooling for new project

### Problem Statement
How to structure development process to ensure quality, security, and maintainability while enabling autonomous development capabilities with modern tooling and templates.

### Decision
Adopt Enhanced SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) methodology with 40+ specialized AI modes, template-based initialization, and comprehensive security controls.

### Rationale
- Systematic approach ensures comprehensive requirements and architecture
- Template system provides optimized starting points for different project types
- 40+ specialized modes provide expert knowledge for all development aspects
- Enhanced security controls protect against common vulnerabilities
- Autonomous development capabilities reduce manual overhead
- Built-in quality gates and comprehensive documentation
- Team-size aware configuration optimizes collaboration patterns

### Alternatives Considered
1. **Traditional Agile/Scrum**: Good for iterative development but lacks systematic architecture phase and AI assistance
2. **Basic SPARC v1.x**: Functional but limited template support and security hardening
3. **Custom Process**: Would require significant time to develop and refine
4. **Standard Project Generators**: Lack AI integration and comprehensive methodology

### Consequences
- **Positive**: Higher quality output, better documentation, systematic approach, AI-assisted development, template optimization
- **Negative**: Initial learning curve, more comprehensive setup process
- **Neutral**: Different workflow from traditional development approaches

### Implementation Notes
- Used $SELECTED_TEMPLATE template for optimized project structure
- Configured for $TEAM_SIZE team with $SECURITY_LEVEL security
- Set up 40+ specialized AI modes for comprehensive development support
- Established quality gates and review processes
- Implemented template-specific best practices

### Success Metrics
- Faster development velocity after initial ramp-up
- Higher code quality and fewer post-deployment issues
- Better architectural consistency and documentation
- Improved team satisfaction with development process
- Reduced security vulnerabilities through built-in controls

### Review Date
Quarterly review scheduled for $(date -u -d "+3 months" +"%Y-%m-%d")

---

### [INIT-002] - Template and Technology Selection

**Date**: $(date -u +"%Y-%m-%d")
**Status**: Accepted
**Deciders**: Technical Lead, Project Stakeholders
**Context**: Need to select project template and technology configuration

### Problem Statement
How to optimize project structure and technology choices for $SELECTED_TEMPLATE development with $TEAM_SIZE team constraints.

### Decision
Implement $SELECTED_TEMPLATE template with ${SECURITY_LEVEL} security level and team-optimized configuration.

### Rationale
- Template provides proven patterns for this project type
- Security level appropriate for project requirements and team capabilities
- Configuration optimized for team size and collaboration needs
- Includes modern tooling and best practices

### Template Benefits
${PROJECT_TEMPLATES[$SELECTED_TEMPLATE]}

### Implementation Notes
- Created template-specific directory structure
- Configured appropriate security controls
- Set up team collaboration patterns
- Included relevant tooling and documentation

---

*Project: $PROJECT_NAME ($PROJECT_ID)*
*Template: $SELECTED_TEMPLATE*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Generate enhanced product context
generate_product_context() {
    cat << EOF
# Product Context

> **Purpose**: Complete business and domain knowledge foundation for autonomous development
> **Updated by**: SPARC Domain Intelligence, SPARC Requirements Architect, SPARC Specification Writer
> **Used by**: All modes to understand business context and make domain-aware decisions

## Executive Summary

### **Product Vision**
[To be defined during specification phase - placeholder for product vision and ultimate goals]

### **Key Value Proposition**
[To be defined - what unique value does this product provide to users/customers?]

### **Target Market**
[To be defined - who are we building this for? Market size, segments, growth potential]

### **Success Metrics**
- **Business KPIs**: [To be defined during requirements gathering]
- **User KPIs**: [To be defined during user research]
- **Technical KPIs**: [To be defined during architecture phase]

## Project Information

### **Project Details**
- **Project Name**: $PROJECT_NAME
- **Project ID**: $PROJECT_ID
- **Template**: $SELECTED_TEMPLATE
- **Initialization Date**: $(date -u +"%Y-%m-%d")
- **SPARC Version**: Enhanced v${TEMPLATE_VERSION}

### **Configuration Summary**
- **Team Size**: $TEAM_SIZE (${TEAM_CONFIGS[$TEAM_SIZE]})
- **Security Level**: $SECURITY_LEVEL (${SECURITY_LEVELS[$SECURITY_LEVEL]})
- **Git Integration**: $INIT_GIT
- **Cloud Provider**: ${INCLUDE_CLOUD:+$CLOUD_PROVIDER}${INCLUDE_CLOUD:-"None"}
- **Security Templates**: $INCLUDE_SECURITY
- **Testing Framework**: ${INCLUDE_TESTING:-"N"}
- **Monitoring**: ${INCLUDE_MONITORING:-"N"}

### **Current Status**
- **Phase**: Project Initialization (Complete)
- **Next Phase**: Specification
- **Estimated Timeline**: [To be defined during planning]

## Template-Specific Context

### **$SELECTED_TEMPLATE Project Characteristics**
${PROJECT_TEMPLATES[$SELECTED_TEMPLATE]}

### **Template Implications**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- Focus on user experience and responsive design
- Component-based architecture with reusable UI elements
- State management and data flow optimization
- Browser compatibility and performance considerations
- SEO and accessibility requirements"
        ;;
    "api-service")
        echo "- RESTful API design principles and best practices
- Database integration and data modeling
- Authentication and authorization patterns
- API versioning and documentation strategies
- Scalability and performance optimization"
        ;;
    "mobile-app")
        echo "- Cross-platform development considerations
- Mobile-specific UX patterns and navigation
- Device capabilities and platform constraints
- App store deployment and distribution
- Performance optimization for mobile devices"
        ;;
    "ml-project")
        echo "- Data science workflow and methodology
- Model development and validation processes
- Data pipeline and processing strategies
- Model deployment and monitoring
- Compliance with data privacy regulations"
        ;;
    "enterprise")
        echo "- Enterprise security and compliance requirements
- Governance and audit trail maintenance
- Integration with existing enterprise systems
- Scalability for large user bases
- Regulatory compliance and reporting"
        ;;
    "microservices")
        echo "- Service decomposition and boundaries
- Inter-service communication patterns
- Distributed system challenges and solutions
- Service discovery and configuration management
- Monitoring and observability across services"
        ;;
    "fullstack")
        echo "- Frontend and backend integration patterns
- Full application lifecycle management
- Database design and API development
- User authentication and session management
- Deployment and infrastructure considerations"
        ;;
    *)
        echo "- Minimal setup with core SPARC methodology
- Flexible foundation for custom requirements
- Essential documentation and structure
- Basic security and quality controls"
        ;;
esac)

## Team Context

### **Team Size Implications**
${TEAM_CONFIGS[$TEAM_SIZE]}

### **Collaboration Patterns**
$(case "$TEAM_SIZE" in
    "solo")
        echo "- Individual workflow optimization
- Self-review and quality control processes
- Personal productivity and tool selection
- Documentation for future maintainability"
        ;;
    "small")
        echo "- Informal communication and collaboration
- Shared responsibility and cross-training
- Agile development with minimal process overhead
- Pair programming and code review practices"
        ;;
    "medium")
        echo "- Structured team roles and responsibilities
- Regular meetings and progress tracking
- Code review processes and quality gates
- Documentation and knowledge sharing"
        ;;
    "large")
        echo "- Formal project management and governance
- Multiple specialized roles and teams
- Comprehensive documentation and processes
- Advanced tooling and automation"
        ;;
    "enterprise")
        echo "- Complex organizational structure
- Multiple stakeholder groups and dependencies
- Formal governance and compliance processes
- Enterprise-grade tooling and infrastructure"
        ;;
esac)

## Security Context

### **Security Level Implementation**
${SECURITY_LEVELS[$SECURITY_LEVEL]}

### **Security Considerations**
$(case "$SECURITY_LEVEL" in
    "basic")
        echo "- Standard security practices and controls
- Basic access controls and authentication
- Common vulnerability protection
- Regular security updates and patches"
        ;;
    "medium")
        echo "- Enhanced security monitoring and logging
- Multi-factor authentication implementation
- Regular security assessments and testing
- Comprehensive access control policies"
        ;;
    "high")
        echo "- Advanced threat detection and response
- Zero-trust security architecture
- Comprehensive audit trails and compliance
- Regular penetration testing and assessments"
        ;;
    "enterprise")
        echo "- Enterprise-grade security infrastructure
- Compliance with industry regulations
- Advanced threat intelligence and monitoring
- Formal security governance and processes"
        ;;
esac)

## Technology Context

### **Technology Stack Considerations**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- Modern JavaScript/TypeScript framework
- Component-based UI library (React, Vue, Angular)
- State management solution
- Build tools and bundlers
- Testing frameworks and tools"
        ;;
    "api-service")
        echo "- Backend runtime (Node.js, Python, Java, etc.)
- Web framework (Express, FastAPI, Spring, etc.)
- Database technology (SQL, NoSQL)
- API documentation tools
- Monitoring and logging solutions"
        ;;
    "mobile-app")
        echo "- Cross-platform framework (React Native, Flutter)
- Native development tools and SDKs
- Device-specific APIs and capabilities
- App store deployment tools
- Mobile-specific testing frameworks"
        ;;
    "ml-project")
        echo "- Data science libraries and frameworks
- Machine learning platforms and tools
- Data processing and pipeline tools
- Model deployment and serving infrastructure
- Experiment tracking and versioning"
        ;;
esac)

## Next Steps

1. **Stakeholder Identification**: Identify all key stakeholders and their roles
2. **Market Research**: Conduct comprehensive market and competitive analysis
3. **User Research**: Define user personas and journey mapping
4. **Business Rules**: Document core business logic and constraints
5. **Domain Modeling**: Create comprehensive domain model and glossary
6. **Technical Architecture**: Design system architecture based on template patterns

---

*This file will be comprehensively updated during the Specification phase*
*Project: $PROJECT_NAME ($PROJECT_ID)*
*Template: $SELECTED_TEMPLATE*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Generate comprehensive progress tracking
generate_progress_tracking() {
    cat << EOF
# Progress Tracking

> **Purpose**: Comprehensive status tracking and roadmap for SPARC methodology implementation
> **Updated by**: All modes as they complete work and reach milestones
> **Used by**: Project Manager, Orchestrator, and all modes to understand overall progress

## Project Overview

### **Project Information**
- **Project Name**: $PROJECT_NAME
- **Project ID**: $PROJECT_ID
- **Template**: $SELECTED_TEMPLATE
- **Team Size**: $TEAM_SIZE
- **Security Level**: $SECURITY_LEVEL
- **Start Date**: $(date -u +"%Y-%m-%d")
- **Target Completion**: [To be defined during planning]
- **Current Phase**: Project Initialization (Complete)
- **Overall Progress**: 5% Complete

### **Enhanced Configuration**
- **Script Version**: Enhanced v${SCRIPT_VERSION}
- **Git Integration**: $INIT_GIT
- **Cloud Provider**: ${INCLUDE_CLOUD:+$CLOUD_PROVIDER}${INCLUDE_CLOUD:-"None"}
- **Security Templates**: $INCLUDE_SECURITY
- **Testing Framework**: ${INCLUDE_TESTING:-"N"}
- **Monitoring**: ${INCLUDE_MONITORING:-"N"}

### **Key Milestones**
| Milestone | Target Date | Status | Completion Date | Notes |
|-----------|-------------|--------|-----------------|-------|
| Enhanced Project Setup | $(date -u +"%Y-%m-%d") | Complete | $(date -u +"%Y-%m-%d") | Advanced structure with $SELECTED_TEMPLATE template |
| Specification Complete | [TBD] | Not Started | | Waiting for stakeholder input |
| Architecture Approved | [TBD] | Not Started | | Depends on specification |
| Implementation Started | [TBD] | Not Started | | Depends on architecture |
| Testing Complete | [TBD] | Not Started | | Depends on implementation |
| Deployment Ready | [TBD] | Not Started | | Depends on testing |

## SPARC Phase Progress

### **Phase 0: Enhanced Project Initialization** 
**Status**: Complete  
**Progress**: 100% Complete  
**Completion Date**: $(date -u +"%Y-%m-%d")

#### **Deliverables Status**
- [x] Enhanced project directory structure created ($SELECTED_TEMPLATE template)
- [x] Memory Bank initialized with template-specific context
- [x] Comprehensive configuration files created (.roomodes with 40+ modes, .rooignore, .roo/)
- [x] Template-specific documents and structure created
- [x] Security controls implemented ($SECURITY_LEVEL level)
- [x] Team collaboration setup ($TEAM_SIZE team optimization)
$(if [[ "$INIT_GIT" =~ ^[Yy] ]]; then echo "- [x] Git repository initialized"; fi)
$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then echo "- [x] Cloud deployment templates prepared ($CLOUD_PROVIDER)"; fi)
$(if [[ "$INCLUDE_SECURITY" =~ ^[Yy] ]]; then echo "- [x] Enterprise security templates included"; fi)

### **Phase 1: Specification** 
**Status**: Not Started  
**Progress**: 0% Complete  
**Target Completion**: [TBD]

#### **Deliverables Status**
- [ ] \`specification.md\` - Requirements and scope definition (template ready)
- [ ] \`acceptance-criteria.md\` - Testable acceptance criteria
- [ ] \`user-scenarios.md\` - User journey documentation
- [ ] \`personas.md\` - User persona definitions
- [ ] Business requirements validated
- [ ] Stakeholder sign-off obtained

#### **Template-Specific Requirements**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- [ ] User interface and experience requirements
- [ ] Browser compatibility specifications
- [ ] Performance and accessibility standards
- [ ] Component library requirements"
        ;;
    "api-service")
        echo "- [ ] API specification and endpoint definitions
- [ ] Data model and schema requirements
- [ ] Integration and authentication specifications
- [ ] Performance and scalability requirements"
        ;;
    "mobile-app")
        echo "- [ ] Mobile platform requirements (iOS/Android)
- [ ] Device compatibility and capabilities
- [ ] App store requirements and guidelines
- [ ] Mobile-specific UX patterns"
        ;;
    "ml-project")
        echo "- [ ] Data requirements and sources
- [ ] Model performance and accuracy targets
- [ ] Compliance and ethical AI requirements
- [ ] Infrastructure and deployment specifications"
        ;;
esac)

#### **Next Actions**
1. **Engage SPARC Specification Writer** - Begin requirements gathering
2. **Schedule stakeholder interviews** - Identify key stakeholders and their needs
3. **Conduct market research** - Understand competitive landscape for $SELECTED_TEMPLATE projects
4. **Define success criteria** - Establish measurable outcomes

### **Phase 2: Pseudocode**
**Status**: Not Started  
**Progress**: 0% Complete  
**Target Completion**: [TBD]

### **Phase 3: Architecture**
**Status**: Not Started  
**Progress**: 0% Complete  
**Target Completion**: [TBD]

### **Phase 4: Refinement**
**Status**: Not Started  
**Progress**: 0% Complete  
**Target Completion**: [TBD]

### **Phase 5: Completion**
**Status**: Not Started  
**Progress**: 0% Complete  
**Target Completion**: [TBD]

## Enhanced Initialization Checklist

### **Core Project Setup**
- [x] Create enhanced project directory structure with $SELECTED_TEMPLATE template
- [x] Initialize Memory Bank files with template-specific context
- [x] Create comprehensive .roomodes configuration (40+ AI modes)
- [x] Create enhanced .rooignore security controls ($SECURITY_LEVEL)
- [x] Set up .roo/ configuration directory with team optimization
- [x] Create template-specific documents and structure
- [x] Set up development environment templates

### **Template-Specific Setup**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- [x] React/frontend development structure
- [x] Component and styling directories
- [x] Modern build tool configuration"
        ;;
    "api-service")
        echo "- [x] API development structure
- [x] Service and middleware organization
- [x] Database integration setup"
        ;;
    "mobile-app")
        echo "- [x] Mobile development structure
- [x] Platform-specific configurations
- [x] Asset and resource organization"
        ;;
    "ml-project")
        echo "- [x] Data science workflow structure
- [x] Experiment and model organization
- [x] Data pipeline setup"
        ;;
esac)

### **Advanced Features**
$(if [[ "$INIT_GIT" =~ ^[Yy] ]]; then echo "- [x] Git repository initialized with best practices"; fi)
$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then echo "- [x] Cloud deployment templates ($CLOUD_PROVIDER)"; fi)
$(if [[ "$INCLUDE_SECURITY" =~ ^[Yy] ]]; then echo "- [x] Enterprise security templates and policies"; fi)
$(if [[ "$INCLUDE_TESTING" =~ ^[Yy] ]]; then echo "- [x] Testing framework and strategy setup"; fi)
$(if [[ "$INCLUDE_MONITORING" =~ ^[Yy] ]]; then echo "- [x] Monitoring and observability templates"; fi)

### **Next Steps**
- [ ] Review generated project structure and configuration
- [ ] Define project timeline and milestones
- [ ] Identify and engage stakeholders
- [ ] Begin specification phase with appropriate AI modes
- [ ] Set up development team access and training
- [ ] Configure CI/CD pipeline templates
- [ ] Establish communication channels and workflows

## Team Readiness Assessment

### **Development Environment**
- **Project Structure**: ✅ Complete with $SELECTED_TEMPLATE optimization
- **Documentation Templates**: ✅ Ready with template-specific guides
- **Configuration Files**: ✅ Created with $SECURITY_LEVEL security
- **Security Controls**: ✅ Implemented and configured

### **Team Capabilities**
- **SPARC Methodology**: 📚 Templates and guides ready
- **AI Mode System**: 🤖 40+ specialized modes configured
- **Quality Gates**: 🎯 Framework established
- **Knowledge Management**: 🧠 Memory Bank initialized
- **Collaboration**: 👥 Optimized for $TEAM_SIZE team

### **Tool Integration**
$(if [[ "$INIT_GIT" =~ ^[Yy] ]]; then echo "- **Version Control**: ✅ Git repository ready"; fi)
$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then echo "- **Cloud Platform**: ✅ $CLOUD_PROVIDER templates ready"; fi)
$(if [[ "$INCLUDE_TESTING" =~ ^[Yy] ]]; then echo "- **Testing Framework**: ✅ Strategy and tools configured"; fi)
$(if [[ "$INCLUDE_MONITORING" =~ ^[Yy] ]]; then echo "- **Monitoring**: ✅ Observability templates ready"; fi)

## Resource Allocation

### **Team Configuration for $TEAM_SIZE Team**
$(case "$TEAM_SIZE" in
    "solo")
        echo "- **Individual Focus**: Optimized for single developer workflow
- **AI Assistance**: Maximum AI mode utilization for productivity
- **Documentation**: Simplified but comprehensive for future reference"
        ;;
    "small")
        echo "- **Collaborative Setup**: 2-5 person team optimization
- **Shared Responsibilities**: Cross-functional team member support
- **Communication**: Lightweight processes with regular check-ins"
        ;;
    "medium")
        echo "- **Role Specialization**: 6-15 person team with defined roles
- **Process Structure**: Balanced process overhead with flexibility
- **Coordination**: Regular team meetings and progress tracking"
        ;;
    "large")
        echo "- **Team Coordination**: 16+ person team management
- **Formal Processes**: Comprehensive project management approach
- **Specialization**: Multiple specialized roles and responsibilities"
        ;;
    "enterprise")
        echo "- **Multi-Team Coordination**: Enterprise-scale organization
- **Governance**: Formal governance and compliance processes
- **Integration**: Enterprise system and process integration"
        ;;
esac)

## Success Metrics Framework

### **Template-Specific KPIs**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- **User Experience**: Page load times, user engagement metrics
- **Performance**: Core Web Vitals, accessibility scores
- **Development**: Component reusability, test coverage"
        ;;
    "api-service")
        echo "- **API Performance**: Response times, throughput, error rates
- **Reliability**: Uptime, availability, recovery times
- **Integration**: API adoption, documentation quality"
        ;;
    "mobile-app")
        echo "- **User Adoption**: Download rates, user retention
- **Performance**: App responsiveness, battery usage
- **Quality**: Crash rates, user ratings"
        ;;
    "ml-project")
        echo "- **Model Performance**: Accuracy, precision, recall
- **Data Quality**: Data completeness, processing efficiency
- **Deployment**: Model deployment success, inference performance"
        ;;
esac)

---

*Project initialized using Enhanced SPARC Methodology v${SCRIPT_VERSION}*
*Template: $SELECTED_TEMPLATE*
*Next milestone: Begin Specification Phase*
*Status updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Generate system patterns with template-specific content
generate_system_patterns() {
    cat << EOF
# System Patterns

> **Purpose**: Technical patterns, standards, and reusable solutions for consistent implementation
> **Updated by**: All technical modes (Architect, Code Implementer, TDD Engineer, Security Architect, etc.)
> **Used by**: All modes to maintain consistency and avoid reinventing solutions

## Enhanced SPARC Project Structure Pattern

### **Standard Enhanced SPARC Project Organization**
\`\`\`
project-root/
├── .roomodes                     # 40+ AI mode definitions
├── .rooignore                    # Enhanced security controls ($SECURITY_LEVEL)
├── .roo/                         # Configuration directory
│   ├── mcp.json                  # MCP server configuration
│   ├── rules/                    # Global rules and guidelines
│   └── commands/                 # Custom command definitions
├── memory-bank/                  # Core knowledge management
│   ├── activeContext.md          # Current working context
│   ├── decisionLog.md            # Architectural decisions
│   ├── productContext.md         # Business and domain knowledge
│   ├── progress.md               # Status tracking
│   └── systemPatterns.md         # Technical patterns (this file)
├── project/$PROJECT_ID/          # Project-specific work areas
├── docs/                         # Documentation structure
├── reports/                      # Analysis and reporting
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "├── src/                          # Source code
│   ├── components/               # Reusable UI components
│   ├── pages/                    # Page components
│   ├── hooks/                    # Custom React hooks
│   ├── services/                 # API services
│   └── utils/                    # Utility functions
├── public/                       # Static assets
├── styles/                       # CSS and styling
└── package.json                  # Node.js dependencies"
        ;;
    "api-service")
        echo "├── src/                          # Source code
│   ├── controllers/              # API controllers
│   ├── services/                 # Business logic
│   ├── models/                   # Data models
│   ├── middleware/               # Express middleware
│   ├── routes/                   # API routes
│   └── config/                   # Configuration
├── migrations/                   # Database migrations
└── package.json                  # Node.js dependencies"
        ;;
    "ml-project")
        echo "├── notebooks/                    # Jupyter notebooks
├── data/                         # Dataset storage
│   ├── raw/                      # Raw datasets
│   ├── processed/                # Processed data
│   └── external/                 # External datasets
├── models/                       # Trained models
├── experiments/                  # ML experiments
└── src/                          # Source code
    ├── features/                 # Feature engineering
    └── models/                   # Model definitions"
        ;;
    *)
        echo "├── src/                          # Source code
└── [template-specific directories]  # Based on selected template"
        ;;
esac)
\`\`\`

### **Template-Specific Patterns**

#### **$SELECTED_TEMPLATE Template Patterns**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        cat << 'WEBAPP_PATTERNS'

**Component Organization Pattern:**
```
components/
├── ui/                          # Basic UI components
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   ├── Button.stories.tsx
│   │   └── index.ts
│   └── Input/
├── layout/                      # Layout components
│   ├── Header/
│   ├── Footer/
│   └── Sidebar/
└── feature/                     # Feature-specific components
    ├── UserProfile/
    └── Dashboard/
```

**State Management Pattern:**
```typescript
// Store structure
interface AppState {
  user: UserState;
  ui: UIState;
  data: DataState;
}

// Action pattern
type AppAction = 
  | { type: 'USER_LOGIN'; payload: User }
  | { type: 'UI_TOGGLE_SIDEBAR' }
  | { type: 'DATA_FETCH_START' };
```

**API Service Pattern:**
```typescript
class ApiService {
  private baseUrl: string;
  
  async get<T>(endpoint: string): Promise<T> {
    // Implementation with error handling
  }
  
  async post<T, R>(endpoint: string, data: T): Promise<R> {
    // Implementation with validation
  }
}
```
WEBAPP_PATTERNS
        ;;
    "api-service")
        cat << 'API_PATTERNS'

**Controller Pattern:**
```typescript
class UserController {
  constructor(private userService: UserService) {}
  
  async getUser(req: Request, res: Response): Promise<void> {
    try {
      const user = await this.userService.findById(req.params.id);
      res.json(user);
    } catch (error) {
      res.status(404).json({ error: 'User not found' });
    }
  }
}
```

**Service Layer Pattern:**
```typescript
interface IUserService {
  findById(id: string): Promise<User>;
  create(userData: CreateUserDto): Promise<User>;
  update(id: string, userData: UpdateUserDto): Promise<User>;
  delete(id: string): Promise<void>;
}

class UserService implements IUserService {
  constructor(private userRepository: IUserRepository) {}
  
  async findById(id: string): Promise<User> {
    const user = await this.userRepository.findById(id);
    if (!user) {
      throw new NotFoundError('User not found');
    }
    return user;
  }
}
```

**Middleware Pattern:**
```typescript
const authMiddleware = (req: Request, res: Response, next: NextFunction) => {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }
  
  // Token validation logic
  next();
};
```
API_PATTERNS
        ;;
    "ml-project")
        cat << 'ML_PATTERNS'

**Data Pipeline Pattern:**
```python
class DataPipeline:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.steps = []
    
    def add_step(self, step: DataProcessingStep) -> 'DataPipeline':
        self.steps.append(step)
        return self
    
    def execute(self, data: pd.DataFrame) -> pd.DataFrame:
        for step in self.steps:
            data = step.process(data)
        return data
```

**Model Training Pattern:**
```python
class ModelTrainer:
    def __init__(self, model, config):
        self.model = model
        self.config = config
        self.metrics = {}
    
    def train(self, X_train, y_train, X_val, y_val):
        # Training implementation
        pass
    
    def evaluate(self, X_test, y_test):
        # Evaluation implementation
        pass
```

**Experiment Tracking Pattern:**
```python
@track_experiment
def train_model(params: Dict[str, Any]) -> Dict[str, float]:
    model = create_model(**params)
    metrics = train_and_evaluate(model)
    return metrics
```
ML_PATTERNS
        ;;
esac)

### **Memory Bank Usage Pattern**
- **activeContext.md**: Update whenever switching between modes or completing significant work
- **decisionLog.md**: Record all architectural and strategic decisions with full rationale
- **productContext.md**: Maintain comprehensive business and domain knowledge
- **progress.md**: Track milestones, blockers, and overall project health
- **systemPatterns.md**: Document reusable technical solutions and standards

### **Mode Coordination Pattern**
1. **Check activeContext.md** before starting work to understand current state
2. **Update progress.md** when completing milestones or encountering blockers
3. **Log decisions** in decisionLog.md with full rationale and alternatives considered
4. **Document patterns** in systemPatterns.md for reuse across team
5. **Handoff context** by updating activeContext.md with clear next actions

## Development Standards

### **File Organization Standards**
- Maximum 500 lines per file for maintainability
- Single responsibility per module
- Clear naming conventions following template patterns
- Consistent directory structure as defined by template
- Separation of concerns between layers

### **Code Quality Standards**
- Comprehensive error handling with specific error types
- Input validation on all boundaries
- Consistent logging and monitoring integration
- Security-first implementation following $SECURITY_LEVEL guidelines
- Performance considerations for $SELECTED_TEMPLATE requirements

### **Testing Standards**
$(if [[ "$INCLUDE_TESTING" =~ ^[Yy] ]]; then
cat << 'TESTING_STANDARDS'
- Unit tests for all business logic components
- Integration tests for API endpoints and data flow
- End-to-end tests for critical user journeys
- Performance tests for system requirements
- Security tests for vulnerability assessment
TESTING_STANDARDS
else
echo "- Unit tests for all business logic (framework to be selected)
- Integration tests for system components
- End-to-end tests for user workflows
- Performance validation for requirements
- Security validation for $SECURITY_LEVEL compliance"
fi)

## Security Patterns

### **$SECURITY_LEVEL Security Implementation**
$(case "$SECURITY_LEVEL" in
    "basic")
        echo "- Input validation and sanitization
- Basic authentication and session management
- HTTPS enforcement and secure headers
- Error handling without information disclosure
- Regular dependency updates"
        ;;
    "medium")
        echo "- Enhanced input validation with schema validation
- Multi-factor authentication implementation
- Rate limiting and abuse prevention
- Comprehensive audit logging
- Security monitoring and alerting"
        ;;
    "high")
        echo "- Zero-trust security architecture
- Advanced threat detection and response
- Comprehensive access control policies
- Security scanning and testing integration
- Regular penetration testing"
        ;;
    "enterprise")
        echo "- Enterprise-grade security infrastructure
- Compliance with industry regulations
- Advanced threat intelligence integration
- Formal security governance processes
- Continuous security monitoring and assessment"
        ;;
esac)

### **Access Control Pattern**
- File-level permissions through .rooignore
- Mode-specific access control in .roomodes
- Team-based access patterns for $TEAM_SIZE teams
- Security boundary enforcement
- Audit trail maintenance

## Performance Patterns

### **Template-Specific Performance Considerations**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- Component lazy loading and code splitting
- Image optimization and CDN usage
- Bundle size optimization
- Browser caching strategies
- Core Web Vitals optimization"
        ;;
    "api-service")
        echo "- Database query optimization
- Connection pooling and resource management
- Caching strategies (Redis, in-memory)
- Rate limiting and throttling
- Horizontal scaling preparation"
        ;;
    "mobile-app")
        echo "- Memory management and optimization
- Battery usage optimization
- Network request optimization
- Image and asset optimization
- Platform-specific performance tuning"
        ;;
    "ml-project")
        echo "- Data loading and processing optimization
- Model inference optimization
- Memory usage for large datasets
- Parallel processing and GPU utilization
- Model serving and caching strategies"
        ;;
esac)

## Integration Patterns

### **API Design Patterns**
- RESTful principles with consistent naming
- Comprehensive error handling and status codes
- API versioning strategy
- Documentation and testing integration
- Security and rate limiting

### **Data Management Patterns**
- Repository pattern for data access abstraction
- Transaction management and consistency
- Data validation and sanitization
- Backup and recovery procedures
- Performance optimization strategies

## Deployment Patterns

### **Infrastructure Patterns**
$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then
echo "- Infrastructure as code using $CLOUD_PROVIDER templates
- Container-based deployment with orchestration
- Auto-scaling and load balancing
- Monitoring and alerting integration
- Disaster recovery and backup strategies"
else
echo "- Infrastructure as code principles
- Container-based deployment preparation
- Monitoring and alerting framework
- Automated scaling considerations
- Backup and recovery planning"
fi)

### **CI/CD Patterns**
$(if [[ "$INIT_GIT" =~ ^[Yy] ]]; then
echo "- Git-based workflow with feature branches
- Automated testing pipeline integration
- Security scanning in deployment pipeline
- Progressive deployment strategies
- Rollback and recovery procedures"
else
echo "- Version control best practices
- Automated testing integration
- Security validation in pipeline
- Deployment automation preparation
- Quality gate enforcement"
fi)

---

*This file will be expanded as technical patterns are established during development*
*Current patterns reflect enhanced project initialization and $SELECTED_TEMPLATE template*
*Project: $PROJECT_NAME ($PROJECT_ID)*
*Template: $SELECTED_TEMPLATE*
*Security Level: $SECURITY_LEVEL*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# =============================================================================
# ADDITIONAL CONTENT GENERATION FUNCTIONS
# =============================================================================

# Enhanced .rooignore generation
generate_enhanced_rooignore() {
    cat << EOF
# Enhanced .rooignore - Security and Access Control
# Project: $PROJECT_NAME ($PROJECT_ID)
# Template: $SELECTED_TEMPLATE
# Security Level: $SECURITY_LEVEL
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

# =============================================================================
# CRITICAL SECURITY FILES (NEVER ALLOW ACCESS)
# =============================================================================

# Environment and secrets
.env*
.secret*
secrets/
credentials/
keys/
certs/
*.key
*.pem
*.p12
*.crt
config/secrets/

# Database credentials
database.yml
database.json
*-secrets.*
connection-strings.*

# API keys and tokens
api-keys.*
*-token*
auth-config.*
jwt-secrets.*

# Cloud provider credentials
.aws/
.gcp/
.azure/
terraform.tfstate*
*.tfvars

# =============================================================================
# SYSTEM AND BUILD FILES
# =============================================================================

# Version control
.git/
.svn/
.hg/

# Dependencies and build outputs
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*
dist/
build/
coverage/
.nyc_output/

# Logs and temporary files
logs/
*.log
log-*.txt
debug-*.txt
error-*.txt
tmp/
temp/
*.tmp
*.temp

# IDE and editor files
.vscode/settings.json
.vscode/launch.json
.idea/
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# Package manager caches
.npm/
.yarn/
.pnpm-store/
vendor/

EOF

    # Add template-specific exclusions
    case "$SELECTED_TEMPLATE" in
        "web-app")
            cat << 'EOF'
# =============================================================================
# WEB APPLICATION SPECIFIC EXCLUSIONS
# =============================================================================

# Frontend build artifacts
.next/
.nuxt/
.vuepress/dist/
.docusaurus/
_site/
out/

# Development files
.env.local
.env.development.local
.env.test.local
.env.production.local

# Asset compilation
public/assets/
static/built/
webpack-stats.json
*.bundle.js
*.bundle.css

EOF
            ;;
        "api-service")
            cat << 'EOF'
# =============================================================================
# API SERVICE SPECIFIC EXCLUSIONS
# =============================================================================

# Database files
*.sqlite
*.sqlite3
*.db

# Upload directories
uploads/
user-uploads/
temp-uploads/

# Cache directories
cache/
.cache/

# Process files
pid/
*.pid
*.lock

EOF
            ;;
        "ml-project")
            cat << 'EOF'
# =============================================================================
# ML PROJECT SPECIFIC EXCLUSIONS
# =============================================================================

# Large datasets (keep structure, exclude data)
data/raw/*
data/sensitive/*
data/private/*
!data/raw/.gitkeep
!data/sensitive/.gitkeep
!data/private/.gitkeep

# Model artifacts
models/private/*
*.pkl
*.h5
*.model
*.joblib

# Experiment artifacts
experiments/sensitive/*
mlruns/
.mlflow/

# Jupyter notebook checkpoints
.ipynb_checkpoints/

EOF
            ;;
        "enterprise")
            cat << 'EOF'
# =============================================================================
# ENTERPRISE SPECIFIC EXCLUSIONS
# =============================================================================

# Sensitive business documents
audit-logs/
compliance/sensitive/
governance/private/
policies/internal/
legal/
contracts/
financial/

# Internal communications
internal-notes/
private-discussions/
confidential/
restricted/

EOF
            ;;
    esac

    # Add security level specific rules
    case "$SECURITY_LEVEL" in
        "high"|"enterprise")
            cat << 'EOF'
# =============================================================================
# HIGH SECURITY ADDITIONAL RESTRICTIONS
# =============================================================================

# Restrict configuration access
src/config/
internal/
private/
confidential/
restricted/

# Sensitive development files
debug/
test-data/sensitive/
mock-data/personal/

EOF
            ;;
    esac

    cat << 'EOF'
# =============================================================================
# INCLUSION OVERRIDES (Allow specific files)
# =============================================================================

# Allow templates and examples
!examples/
!templates/
!.env.example
!*-template.*
!*-sample.*
!README.md
!docs/

# Allow specific config templates
!config/template.yml
!config/example.json

# Allow sanitized data samples
!data/samples/
!data/examples/

# =============================================================================
# SPARC MODE-SPECIFIC CONTEXT
# =============================================================================

# These patterns work with file regex restrictions in .roomodes
# They provide defense-in-depth security by blocking access at multiple levels

# Usage Notes:
# - This file provides baseline security by blocking dangerous files
# - Individual modes use fileRegex in .roomodes for specific permissions
# - Modes should never need access to files listed above
# - Regular security review of access patterns recommended

# Maintenance:
# - Review quarterly for new security risks
# - Update when adding new tools or frameworks
# - Test access controls with security review mode
# - Document any security exceptions with clear rationale
EOF
}

# Generate MCP configuration
generate_mcp_config() {
  # Derived flags
  local sec_tools_enabled="false"
  [[ "$SECURITY_LEVEL" =~ ^(high|enterprise)$ ]] && sec_tools_enabled="true"

  # Derived policy values
  local retention_days=30
  case "$SECURITY_LEVEL" in
    high) retention_days=60 ;;
    enterprise) retention_days=90 ;;
  esac
  local log_level="INFO"
  [[ "$SECURITY_LEVEL" =~ ^(high|enterprise)$ ]] && log_level="DEBUG"

  # Team config
  local max_sessions=3 collab="informal"
  case "$TEAM_SIZE" in
    solo)       max_sessions=1  collab="individual" ;;
    small)      max_sessions=3  collab="informal" ;;
    medium)     max_sessions=8  collab="structured" ;;
    large)      max_sessions=16 collab="formal" ;;
    enterprise) max_sessions=50 collab="formal" ;;
  esac

  # Optional blocks
  local cloud_block=""
  if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then
    cloud_block=$(cat <<CLOUD
    ,"cloud-tools": { "name": "${CLOUD_PROVIDER} Cloud Integration", "enabled": true,
      "allowedModes": ["sparc-devops-engineer","sparc-platform-engineer"],
      "cloudProvider": "${CLOUD_PROVIDER}", "securityLevel": "${SECURITY_LEVEL}" }
CLOUD
)
  fi

  local mon_block=""
  if [[ "$INCLUDE_MONITORING" =~ ^[Yy] ]]; then
    mon_block=$(cat <<MON
    ,"monitoring-tools": { "name": "Monitoring & Observability", "enabled": true,
      "allowedModes": ["sparc-post-deployment-monitor","sparc-sre-engineer"],
      "securityLevel": "${SECURITY_LEVEL}" }
MON
)
  fi

  # Emit JSON to stdout (consumed by create_file_safe)
  cat <<JSON
{
  "description": "Enhanced MCP configuration for ${PROJECT_NAME}",
  "version": "${TEMPLATE_VERSION}",
  "template": "${SELECTED_TEMPLATE}",
  "securityLevel": "${SECURITY_LEVEL}",
  "mcpServers": {
    "research-tools": { "name": "Research & Analysis Tools", "enabled": true,
      "allowedModes": ["sparc-domain-intelligence","data-researcher","rapid-fact-checker"],
      "securityLevel": "${SECURITY_LEVEL}" },
    "development-tools": { "name": "Development & Code Analysis", "enabled": true,
      "allowedModes": ["sparc-code-implementer","sparc-architect","sparc-tdd-engineer","sparc-performance-engineer"],
      "securityLevel": "${SECURITY_LEVEL}" },
    "security-tools": { "name": "Security Analysis & Review",
      "enabled": ${sec_tools_enabled},
      "allowedModes": ["sparc-security-reviewer","sparc-security-architect","adversarial-testing-agent"],
      "securityLevel": "${SECURITY_LEVEL}" }${cloud_block}${mon_block}
  },
  "securityPolicies": {
    "dataRetention": { "enabled": true, "maxRetentionDays": ${retention_days} },
    "accessLogging": { "enabled": true, "logLevel": "${log_level}" },
    "encryptionRequired": ${sec_tools_enabled}
  },
  "teamConfiguration": {
    "teamSize": "${TEAM_SIZE}",
    "maxConcurrentSessions": ${max_sessions},
    "collaborationMode": "${collab}"
  }
}
EOF
}
# Generate project rules
generate_project_rules() {
    cat << EOF
# Enhanced Project Rules and Guidelines

## SPARC Methodology Rules

1. **Phase Sequence**: Follow SPARC phases in order (Specification → Pseudocode → Architecture → Refinement → Completion)
2. **Quality Gates**: Complete each phase before proceeding to the next
3. **Documentation**: Maintain comprehensive documentation in Memory Bank
4. **Decision Logging**: Record all architectural decisions with rationale in decisionLog.md
5. **Modular Design**: Keep all components under 500 lines for maintainability

## Template-Specific Rules ($SELECTED_TEMPLATE)

$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "### Web Application Development Rules
1. **Component Design**: Create reusable, testable components
2. **State Management**: Use consistent state management patterns
3. **Performance**: Optimize for Core Web Vitals and accessibility
4. **Responsive Design**: Support mobile, tablet, and desktop viewports
5. **SEO**: Implement proper meta tags and semantic HTML"
        ;;
    "api-service")
        echo "### API Service Development Rules
1. **RESTful Design**: Follow REST principles and HTTP standards
2. **Input Validation**: Validate all inputs with proper error responses
3. **Authentication**: Implement secure authentication and authorization
4. **Documentation**: Maintain comprehensive API documentation
5. **Error Handling**: Provide consistent error responses with helpful messages"
        ;;
    "mobile-app")
        echo "### Mobile Application Development Rules
1. **Platform Guidelines**: Follow iOS/Android platform-specific guidelines
2. **Performance**: Optimize for battery life and memory usage
3. **Offline Capability**: Design for intermittent connectivity
4. **Accessibility**: Support platform accessibility features
5. **App Store**: Comply with app store requirements and guidelines"
        ;;
    "ml-project")
        echo "### Machine Learning Project Rules
1. **Data Quality**: Implement comprehensive data validation and cleaning
2. **Experiment Tracking**: Log all experiments with parameters and results
3. **Model Versioning**: Version all models and datasets properly
4. **Reproducibility**: Ensure all experiments are reproducible
5. **Ethical AI**: Consider bias, fairness, and ethical implications"
        ;;
    "enterprise")
        echo "### Enterprise Development Rules
1. **Compliance**: Adhere to all regulatory and company compliance requirements
2. **Security**: Follow enterprise security policies and standards
3. **Governance**: Maintain proper governance and approval processes
4. **Documentation**: Comprehensive documentation for audit purposes
5. **Integration**: Consider enterprise system integration requirements"
        ;;
    *)
        echo "### General Development Rules
1. **Code Quality**: Maintain high code quality standards
2. **Testing**: Implement comprehensive testing strategies
3. **Documentation**: Keep documentation current and comprehensive
4. **Security**: Follow security best practices
5. **Performance**: Consider performance implications in all decisions"
        ;;
esac)

## Security Rules ($SECURITY_LEVEL Level)

$(case "$SECURITY_LEVEL" in
    "basic")
        echo "1. **Input Validation**: Validate all user inputs before processing
2. **Error Handling**: Handle errors without exposing sensitive information
3. **Authentication**: Implement basic authentication mechanisms
4. **HTTPS**: Use HTTPS for all communications
5. **Dependencies**: Keep dependencies updated and scan for vulnerabilities"
        ;;
    "medium")
        echo "1. **Input Validation**: Comprehensive input validation with schema validation
2. **Authentication**: Multi-factor authentication where applicable
3. **Authorization**: Role-based access control implementation
4. **Audit Logging**: Log all security-relevant events
5. **Security Headers**: Implement comprehensive security headers"
        ;;
    "high")
        echo "1. **Zero Trust**: Implement zero-trust security architecture
2. **Encryption**: Encrypt all data in transit and at rest
3. **Access Control**: Implement least-privilege access controls
4. **Security Testing**: Regular security testing and penetration testing
5. **Incident Response**: Maintain incident response procedures"
        ;;
    "enterprise")
        echo "1. **Compliance**: Full compliance with industry regulations and standards
2. **Governance**: Formal security governance and approval processes
3. **Monitoring**: Continuous security monitoring and threat detection
4. **Assessment**: Regular security assessments and audits
5. **Training**: Security awareness training for all team members"
        ;;
esac)

## Team Collaboration Rules ($TEAM_SIZE Team)

$(case "$TEAM_SIZE" in
    "solo")
        echo "1. **Self-Review**: Implement thorough self-review processes
2. **Documentation**: Document decisions for future reference
3. **Backup**: Maintain proper code and data backups
4. **Learning**: Continuous learning and skill development
5. **Planning**: Regular planning and progress assessment"
        ;;
    "small")
        echo "1. **Communication**: Regular informal communication and updates
2. **Code Review**: Peer code review for all changes
3. **Knowledge Sharing**: Share knowledge and cross-train team members
4. **Responsibility**: Shared responsibility for project success
5. **Flexibility**: Maintain flexibility in roles and responsibilities"
        ;;
    "medium")
        echo "1. **Role Definition**: Clear definition of roles and responsibilities
2. **Meetings**: Regular team meetings and progress reviews
3. **Process**: Structured development and review processes
4. **Documentation**: Comprehensive documentation and knowledge management
5. **Coordination**: Effective coordination and communication mechanisms"
        ;;
    "large")
        echo "1. **Organization**: Formal organization structure and hierarchy
2. **Process Management**: Comprehensive process management and governance
3. **Specialization**: Clear specialization and expertise areas
4. **Communication**: Formal communication channels and protocols
5. **Coordination**: Advanced coordination and project management tools"
        ;;
    "enterprise")
        echo "1. **Governance**: Enterprise governance and compliance processes
2. **Standards**: Adherence to enterprise standards and policies
3. **Integration**: Integration with enterprise systems and processes
4. **Reporting**: Regular reporting and status updates
5. **Escalation**: Clear escalation paths and procedures"
        ;;
esac)

## Code Quality Rules

1. **File Size**: Maximum 500 lines per file for maintainability
2. **Function Size**: Maximum 50 lines per function for readability
3. **Naming**: Clear, descriptive naming conventions
4. **Comments**: Self-documenting code with strategic comments
5. **Testing**: Comprehensive test coverage for all business logic
6. **Error Handling**: Consistent error handling patterns
7. **Performance**: Consider performance implications in all code
8. **Security**: Security-first coding practices

## Memory Bank Rules

1. **Updates**: Update Memory Bank files when completing significant work
2. **Context**: Provide clear context when switching between modes
3. **Decisions**: Log all architectural decisions with full rationale
4. **Progress**: Regular updates to progress.md for transparency
5. **Patterns**: Document reusable patterns in systemPatterns.md

## Documentation Standards

1. **Current**: Keep all documentation current and accurate
2. **Comprehensive**: Comprehensive coverage of all aspects
3. **Accessible**: Clear, accessible language for all audiences
4. **Structured**: Well-structured and organized information
5. **Traceable**: Maintain traceability from requirements to implementation

EOF
}

# Generate team collaboration rules
generate_team_rules() {
    cat << EOF
# Team Collaboration Rules

## Team Configuration: $TEAM_SIZE Team

${TEAM_CONFIGS[$TEAM_SIZE]}

## Collaboration Patterns

$(case "$TEAM_SIZE" in
    "small")
        echo "### Small Team Collaboration (2-5 people)

**Communication**:
- Daily informal check-ins
- Weekly planning sessions
- Open communication channels (Slack/Discord)
- Shared documentation and knowledge base

**Development Process**:
- Feature branching with peer review
- Pair programming for complex features
- Shared responsibility for code quality
- Cross-training and knowledge sharing

**Tool Usage**:
- Shared development environments
- Collaborative documentation tools
- Simple project management (GitHub issues, Trello)
- Informal code review process"
        ;;
    "medium")
        echo "### Medium Team Collaboration (6-15 people)

**Communication**:
- Daily stanups - structured communications
- Sprint planning and retrospectives
- Dedicated project management tools (Jira, Azure DevOps)
- Formal documentation requirements

**Development Process**:
- Feature teams with specialized roles
- Formal code review and approval processes
- Continuous integration and deployment pipelines
- Structured testing and quality assurance
- Regular architectural review sessions

**Tool Usage**:
- Enterprise development tools and IDEs
- Comprehensive project management platforms
- Advanced version control workflows (GitFlow)
- Automated testing and quality tools
- Performance monitoring and analytics"
        ;;
    "large")
        echo "### Large Team Collaboration (16+ people)

**Communication**:
- Multi-level communication structure
- Daily standups per team, weekly cross-team syncs
- Formal documentation and knowledge management
- Executive reporting and stakeholder updates
- Clear escalation paths and decision-making processes

**Development Process**:
- Multiple specialized development teams
- Formal architecture and design review boards
- Comprehensive testing strategy across teams
- Release management and coordination processes
- Quality gates and compliance checkpoints

**Tool Usage**:
- Enterprise-grade development platforms
- Advanced project portfolio management
- Sophisticated CI/CD orchestration
- Comprehensive monitoring and observability
- Automated security and compliance tools"
        ;;
    "enterprise")
        echo "### Enterprise Team Collaboration (Multiple Teams)

**Communication**:
- Enterprise governance and communication frameworks
- Cross-functional leadership committees
- Formal stakeholder management processes
- Regular business and technical reviews
- Comprehensive reporting and analytics

**Development Process**:
- Enterprise architecture governance
- Formal change management processes
- Multi-team coordination and dependencies
- Enterprise security and compliance integration
- Standardized development methodologies

**Tool Usage**:
- Enterprise application lifecycle management
- Advanced portfolio and resource management
- Enterprise security and governance tools
- Comprehensive analytics and business intelligence
- Integrated compliance and audit systems"
        ;;
esac)

## Workflow Integration

### AI Mode Coordination
1. **Context Handoffs**: Clear handoff procedures between AI modes
2. **Progress Tracking**: Regular updates to memory-bank/progress.md
3. **Decision Logging**: Document all decisions in memory-bank/decisionLog.md
4. **Quality Gates**: Implement quality checkpoints between phases
5. **Knowledge Sharing**: Maintain comprehensive documentation

### Development Flow
1. **Branch Strategy**: $(if [[ "$INIT_GIT" =~ ^[Yy] ]]; then echo "Git-based workflow with feature branches"; else echo "Version control workflow to be established"; fi)
2. **Code Review**: $(case "$TEAM_SIZE" in "solo") echo "Self-review with AI assistance" ;; *) echo "Peer review process with team members" ;; esac)
3. **Testing**: Comprehensive testing at all levels
4. **Integration**: Regular integration and deployment practices
5. **Documentation**: Continuous documentation updates

## Success Metrics

### Team Performance Indicators
1. **Velocity**: $(case "$TEAM_SIZE" in "solo") echo "Individual productivity tracking" ;; "small") echo "Team velocity and story points" ;; *) echo "Multi-team velocity coordination" ;; esac)
2. **Quality**: Code quality, test coverage, and defect rates
3. **Collaboration**: Team satisfaction and collaboration effectiveness
4. **Knowledge**: Knowledge sharing and team learning metrics
5. **Delivery**: On-time delivery and stakeholder satisfaction

### Continuous Improvement
1. **Retrospectives**: Regular team retrospectives and improvement planning
2. **Metrics Review**: Regular review of team performance metrics
3. **Process Evolution**: Continuous process improvement and optimization
4. **Tool Optimization**: Regular evaluation and optimization of development tools
5. **Training**: Ongoing training and skill development

EOF
}

# =============================================================================
# MISSING CONTENT GENERATION FUNCTIONS
# =============================================================================

# Generate comprehensive .roomodes configuration
generate_comprehensive_roomodes() {
  cat <<'YAML'
customModes:
  - slug: sparc-orchestrator
    name: "⚡️ SPARC Orchestrator"
    roleDefinition: >-
      You are the SPARC Orchestrator responsible for cross-phase planning and handoffs.
    groups:
      - read
      - - edit
        - fileRegex: '.*\/(memory-bank|docs|reports)\/.*\.(md|json)$'
          description: Documentation and progress tracking

  - slug: sparc-specification-writer
    name: "📋 Specification Writer"
    roleDefinition: >-
      Expert in translating stakeholder needs into precise specs and acceptance criteria.
    groups:
      - read
      - - edit
        - fileRegex: '^(specification|acceptance-criteria|user-scenarios|personas)\.md$'
          description: Specification documents
      - - edit
        - fileRegex: '.*\/(memory-bank|docs)\/.*\.md$'
          description: Documentation updates
YAML
}# Generate specification template
generate_specification_template() {
    cat << EOF
# Project Specification

> **SPARC Phase**: Specification  
> **Status**: Draft  
> **Last Updated**: $(date -u +"%Y-%m-%d")  
> **Template**: $SELECTED_TEMPLATE  
> **Version**: 1.0

## Executive Summary

### **Project Vision**
[Define the overall vision and purpose of this $SELECTED_TEMPLATE project]

### **Key Objectives**
1. **Primary Objective**: [Main goal of the project]
2. **Secondary Objectives**: 
   - [Supporting goal 1]
   - [Supporting goal 2]
   - [Supporting goal 3]

### **Success Criteria**
- [Measurable success criterion 1]
- [Measurable success criterion 2] 
- [Measurable success criterion 3]

### **Project Scope**
- **In Scope**: [What this project includes]
- **Out of Scope**: [What this project explicitly does not include]
- **Future Scope**: [What might be included in future versions]

## Template-Specific Requirements

### **$SELECTED_TEMPLATE Project Requirements**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "#### Web Application Requirements
- **User Interface**: Modern, responsive web interface
- **Browser Support**: [Define supported browsers and versions]
- **Performance**: [Define performance requirements and Core Web Vitals targets]
- **Accessibility**: [WCAG compliance level and specific requirements]
- **SEO**: [Search engine optimization requirements]
- **Progressive Web App**: [PWA features if applicable]"
        ;;
    "api-service")
        echo "#### API Service Requirements
- **API Design**: RESTful API following OpenAPI specification
- **Authentication**: [Authentication and authorization requirements]
- **Rate Limiting**: [API usage limits and throttling]
- **Documentation**: [API documentation requirements]
- **Versioning**: [API versioning strategy]
- **Integration**: [External system integration requirements]"
        ;;
    "mobile-app")
        echo "#### Mobile Application Requirements
- **Platform Support**: [iOS, Android, or cross-platform]
- **Device Support**: [Minimum device specifications]
- **Offline Functionality**: [Offline capability requirements]
- **App Store**: [App store guidelines and requirements]
- **Push Notifications**: [Notification requirements]
- **Device Features**: [Camera, GPS, biometric requirements]"
        ;;
    "ml-project")
        echo "#### Machine Learning Project Requirements
- **Data Requirements**: [Data sources, volume, and quality requirements]
- **Model Performance**: [Accuracy, precision, recall targets]
- **Inference Speed**: [Real-time or batch processing requirements]
- **Model Deployment**: [Deployment and serving requirements]
- **Monitoring**: [Model performance monitoring requirements]
- **Compliance**: [Data privacy and ethical AI requirements]"
        ;;
    "enterprise")
        echo "#### Enterprise Application Requirements
- **Compliance**: [Regulatory and company compliance requirements]
- **Security**: [Enterprise security standards and requirements]
- **Integration**: [Enterprise system integration requirements]
- **Governance**: [Approval processes and governance requirements]
- **Scalability**: [Enterprise-scale performance requirements]
- **Audit**: [Audit trail and reporting requirements]"
        ;;
    *)
        echo "#### Project-Specific Requirements
- [Define requirements specific to your project type]
- [Include performance, security, and functionality requirements]
- [Document integration and compatibility requirements]"
        ;;
esac)

## Stakeholder Analysis

### **Primary Stakeholders**
| Stakeholder | Role | Influence | Interest | Communication Needs |
|-------------|------|-----------|----------|-------------------|
| [Name/Role] | [Title] | [High/Medium/Low] | [High/Medium/Low] | [How to communicate] |

### **End Users**
- **Primary Users**: [Who will use this system most frequently]
- **Secondary Users**: [Who will use this system occasionally]
- **Administrators**: [Who will manage/maintain this system]

## Functional Requirements

### **Core Features**
[Define the main features and functionality required for the $SELECTED_TEMPLATE project]

### **User Stories**
As a [user type], I want [functionality] so that [benefit]

**Acceptance Criteria:**
- [ ] [Specific, testable criterion 1]
- [ ] [Specific, testable criterion 2]
- [ ] [Specific, testable criterion 3]

## Non-Functional Requirements

### **Performance Requirements**
- **Response Time**: [Maximum acceptable response times]
- **Throughput**: [Transactions per second or similar metrics]
- **Concurrent Users**: [Maximum number of simultaneous users]
- **Data Volume**: [Expected data storage and growth requirements]

### **Security Requirements** ($SECURITY_LEVEL Level)
$(case "$SECURITY_LEVEL" in
    "basic")
        echo "- Basic authentication and authorization
- HTTPS enforcement and secure headers
- Input validation and sanitization
- Regular security updates"
        ;;
    "medium")
        echo "- Multi-factor authentication support
- Role-based access control
- Comprehensive audit logging
- Security monitoring and alerting"
        ;;
    "high")
        echo "- Zero-trust security architecture
- Advanced threat detection
- Comprehensive access control policies
- Regular penetration testing"
        ;;
    "enterprise")
        echo "- Enterprise-grade security infrastructure
- Compliance with industry regulations
- Advanced threat intelligence
- Formal security governance processes"
        ;;
esac)

### **Compliance Requirements**
- [GDPR, HIPAA, SOX, or other regulatory requirements]
- [Industry standards and certifications]
- [Data retention and privacy requirements]

## Technical Constraints

### **Technology Stack**
- **Programming Languages**: [Required or preferred languages]
- **Frameworks**: [Required or preferred frameworks]
- **Databases**: [Database requirements or constraints]
- **Infrastructure**: [Cloud provider, on-premise, hybrid requirements]

### **Integration Constraints**
- **Legacy Systems**: [Existing systems that must be supported]
- **APIs**: [Required API integrations]
- **Data Migration**: [Existing data that must be migrated]

## Project Timeline and Milestones

### **SPARC Phase Timeline**
| Phase | Estimated Duration | Key Deliverables |
|-------|-------------------|------------------|
| Specification | [Duration] | specification.md, acceptance-criteria.md |
| Pseudocode | [Duration] | pseudocode.md, function-specs.md |
| Architecture | [Duration] | architecture.md, security-architecture.md |
| Refinement | [Duration] | Implementation and testing |
| Completion | [Duration] | Deployment and documentation |

### **Key Milestones**
- [Milestone 1]: [Date] - [Description]
- [Milestone 2]: [Date] - [Description]
- [Milestone 3]: [Date] - [Description]

## Risk Assessment

### **Technical Risks**
| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|-------------------|
| [Risk description] | [H/M/L] | [H/M/L] | [How to mitigate] |

### **Business Risks**
| Risk | Probability | Impact | Mitigation Strategy |
|------|-------------|--------|-------------------|
| [Risk description] | [H/M/L] | [H/M/L] | [How to mitigate] |

## Success Metrics

### **Key Performance Indicators**
- [Metric 1]: [Target value] - [How to measure]
- [Metric 2]: [Target value] - [How to measure]
- [Metric 3]: [Target value] - [How to measure]

## Approval and Sign-off

- [ ] Stakeholder review completed
- [ ] Technical feasibility confirmed
- [ ] Security requirements approved
- [ ] Timeline and resources approved
- [ ] Final specification sign-off

---

*Generated by Enhanced SPARC Project Initialization Script v${SCRIPT_VERSION}*
*Template: $SELECTED_TEMPLATE*
*Team: $TEAM_SIZE*
*Security: $SECURITY_LEVEL*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Generate architecture template
generate_architecture_template() {
    cat << EOF
# System Architecture

> **SPARC Phase**: Architecture  
> **Status**: Draft  
> **Last Updated**: $(date -u +"%Y-%m-%d")  
> **Template**: $SELECTED_TEMPLATE  
> **Version**: 1.0  
> **Specification Reference**: [Link to specification.md]

## Architecture Overview

### **System Context**
[High-level description of the $SELECTED_TEMPLATE system and its place in the broader ecosystem]

### **Architecture Principles**
1. **Modularity**: Components under 500 lines, clear interfaces, single responsibility
2. **Security by Design**: $SECURITY_LEVEL security level implementation
3. **Scalability**: Designed for $TEAM_SIZE team collaboration
4. **Maintainability**: Clear documentation, consistent patterns, testable components
5. **Performance**: Optimized for $SELECTED_TEMPLATE requirements

### **Key Architectural Decisions**
[Reference to memory-bank/decisionLog.md for detailed rationale]

## System Architecture Diagram

\`\`\`
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "┌─────────────────────────────────────────────────────────────┐
│                    Users/Browsers                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                 Load Balancer/CDN                          │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              Frontend Application                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ Components  │ │    Pages    │ │   Services  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                Backend API                                  │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ Controllers │ │  Services   │ │ Middleware  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                 Database                                    │
└─────────────────────────────────────────────────────────────┘"
        ;;
    "api-service")
        echo "┌─────────────────────────────────────────────────────────────┐
│                 Client Applications                        │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              API Gateway/Load Balancer                     │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                API Service Layer                           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ Controllers │ │ Middleware  │ │   Routes    │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              Business Logic Layer                          │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │  Services   │ │   Models    │ │ Validators  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              Data Access Layer                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │  Database   │ │   Cache     │ │External APIs│           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────────────────────┘"
        ;;
    "mobile-app")
        echo "┌─────────────────────────────────────────────────────────────┐
│                Mobile Devices                              │
│              (iOS/Android)                                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              Mobile Application                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │   Screens   │ │ Components  │ │ Navigation  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │   Services  │ │    Store    │ │ Local Data  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                Backend Services                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │     API     │ │ Push Notify │ │  Analytics  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────────────────────┘"
        ;;
    "ml-project")
        echo "┌─────────────────────────────────────────────────────────────┐
│              Data Sources                                  │
│     (Files, APIs, Databases, Streams)                     │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              Data Pipeline                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │   Ingestion │ │ Processing  │ │ Validation  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              ML Pipeline                                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │  Training   │ │ Validation  │ │ Deployment  │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              Serving Layer                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐           │
│  │ Model API   │ │ Monitoring  │ │   Logging   │           │
│  └─────────────┘ └─────────────┘ └─────────────┘           │
└─────────────────────────────────────────────────────────────┘"
        ;;
    *)
        echo "[Architecture diagram for $SELECTED_TEMPLATE to be defined]"
        ;;
esac)
\`\`\`

## Component Design

### **Core Components**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "1. **Frontend Application**
   - React/Vue/Angular components following atomic design
   - State management with Redux/Vuex/NgRx
   - Routing and navigation
   - API communication layer

2. **Backend API**
   - RESTful API endpoints
   - Authentication and authorization
   - Business logic services
   - Data validation and sanitization"
        ;;
    "api-service")
        echo "1. **API Gateway**
   - Request routing and load balancing
   - Authentication and rate limiting
   - Request/response transformation
   - Monitoring and analytics

2. **Service Layer**
   - Business logic implementation
   - Data validation and processing
   - External service integration
   - Error handling and logging"
        ;;
    *)
        echo "[Component design for $SELECTED_TEMPLATE to be defined]"
        ;;
esac)

## Security Architecture

### **$SECURITY_LEVEL Security Implementation**
$(case "$SECURITY_LEVEL" in
    "basic")
        echo "- HTTPS enforcement and secure headers
- Basic authentication and session management
- Input validation and sanitization
- Error handling without information disclosure"
        ;;
    "medium")
        echo "- Multi-factor authentication support
- Role-based access control (RBAC)
- Comprehensive audit logging
- Security monitoring and alerting
- Regular security scanning"
        ;;
    "high")
        echo "- Zero-trust security architecture
- Advanced threat detection and response
- Comprehensive access control policies
- Security scanning and testing integration
- Regular penetration testing"
        ;;
    "enterprise")
        echo "- Enterprise-grade security infrastructure
- Compliance with industry regulations
- Advanced threat intelligence integration
- Formal security governance processes
- Continuous security monitoring"
        ;;
esac)

### **Data Protection**
- Encryption at rest and in transit
- Secure key management
- Data privacy and GDPR compliance
- Backup and recovery security

## Performance Architecture

### **Performance Targets**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- Page load time: <3 seconds
- First Contentful Paint: <1.5 seconds
- Cumulative Layout Shift: <0.1
- Time to Interactive: <3.5 seconds"
        ;;
    "api-service")
        echo "- API response time: <200ms
- Throughput: [X] requests/second
- Availability: 99.9% uptime
- Error rate: <0.1%"
        ;;
    *)
        echo "- [Define performance targets for $SELECTED_TEMPLATE]"
        ;;
esac)

### **Scalability Strategy**
- Horizontal scaling capabilities
- Load balancing and distribution
- Caching strategies
- Database optimization

## Deployment Architecture

### **Infrastructure Design**
$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then
echo "- Cloud platform: $CLOUD_PROVIDER
- Container-based deployment
- Infrastructure as Code
- Auto-scaling and monitoring"
else
echo "- [Infrastructure approach to be defined]
- Deployment automation
- Monitoring and logging
- Backup and recovery"
fi)

### **Environment Strategy**
- Development environment setup
- Staging/testing environment
- Production environment
- Disaster recovery environment

## Technology Stack

### **Core Technologies**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- **Frontend**: React/Vue/Angular + TypeScript
- **Backend**: Node.js/Python/Java
- **Database**: PostgreSQL/MongoDB
- **Cache**: Redis
- **Build**: Webpack/Vite
- **Testing**: Jest/Cypress"
        ;;
    "api-service")
        echo "- **Runtime**: Node.js/Python/Java/Go
- **Framework**: Express/FastAPI/Spring/Gin
- **Database**: PostgreSQL/MongoDB
- **Cache**: Redis
- **Documentation**: OpenAPI/Swagger
- **Testing**: Jest/pytest/JUnit"
        ;;
    *)
        echo "- [Technology stack for $SELECTED_TEMPLATE to be defined]"
        ;;
esac)

### **Development Tools**
- Version control: Git
- CI/CD: GitHub Actions/GitLab CI
- Monitoring: Prometheus/Grafana
- Logging: ELK Stack/Fluentd

## Data Architecture

### **Data Model**
[Define data entities, relationships, and constraints]

### **Database Design**
- Schema design principles
- Indexing strategy
- Data migration approach
- Backup and recovery

## Integration Architecture

### **External Integrations**
- Third-party APIs
- Authentication providers
- Payment systems
- Analytics services

### **Internal Integrations**
- Service-to-service communication
- Data synchronization
- Event-driven architecture
- Message queuing

## Monitoring and Observability

### **Monitoring Strategy**
- Application performance monitoring
- Infrastructure monitoring
- Business metrics tracking
- Error tracking and alerting

### **Logging Strategy**
- Structured logging
- Log aggregation
- Log retention policies
- Security event logging

---

*Generated by Enhanced SPARC Project Initialization Script v${SCRIPT_VERSION}*
*Template: $SELECTED_TEMPLATE*
*Team: $TEAM_SIZE*
*Security: $SECURITY_LEVEL*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Generate pseudocode template
generate_pseudocode_template() {
    cat << EOF
# Pseudocode Design

> **SPARC Phase**: Pseudocode  
> **Status**: Draft  
> **Last Updated**: $(date -u +"%Y-%m-%d")  
> **Template**: $SELECTED_TEMPLATE  
> **Version**: 1.0  
> **Architecture Reference**: [Link to architecture.md]  
> **Specification Reference**: [Link to specification.md]

## Overview

### **Purpose**
This document translates the $SELECTED_TEMPLATE system architecture into implementable algorithms and data structures, providing clear guidance for the code implementation phase.

### **Design Principles**
- **Modularity**: Each function ≤50 lines, single responsibility
- **Clarity**: Self-documenting logic, clear variable names
- **Testability**: Functions designed for easy unit testing
- **Performance**: O(n) complexity or better where possible
- **Error Handling**: Comprehensive error cases covered

### **Implementation Readiness**
- [ ] All core algorithms defined
- [ ] Data structures specified
- [ ] Error cases identified
- [ ] Performance characteristics documented
- [ ] Integration points clarified

## Data Structures

### **Core Entities**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo '
#### **User Entity**
```pseudocode
STRUCTURE User {
    id: UUID
    email: Email               // Unique identifier
    name: String(1-100)        // Display name
    avatar: URL                // Profile image
    preferences: UserPreferences
    createdAt: Timestamp
    lastLoginAt: Timestamp
}

STRUCTURE UserPreferences {
    theme: ENUM(LIGHT, DARK, AUTO)
    language: LanguageCode
    notifications: NotificationSettings
}
```

#### **Component State**
```pseudocode
STRUCTURE ComponentState {
    loading: Boolean
    error: String OR NULL
    data: Generic<T>
    validationErrors: Map<String, String>
}
```'
        ;;
    "api-service")
        echo '
#### **Request/Response Structures**
```pseudocode
STRUCTURE ApiRequest {
    method: HTTP_METHOD
    path: String
    headers: Map<String, String>
    body: JSON OR NULL
    queryParams: Map<String, String>
    user: User OR NULL         // Authenticated user
}

STRUCTURE ApiResponse {
    statusCode: Integer
    headers: Map<String, String>
    body: JSON
    timestamp: Timestamp
}
```

#### **Business Entity**
```pseudocode
STRUCTURE Resource {
    id: UUID
    name: String(1-200)
    description: String(0-1000)
    ownerId: UUID
    status: ENUM(ACTIVE, INACTIVE, DELETED)
    metadata: Map<String, Any>
    createdAt: Timestamp
    updatedAt: Timestamp
}
```'
        ;;
    "mobile-app")
        echo '
#### **Screen State**
```pseudocode
STRUCTURE ScreenState {
    loading: Boolean
    error: String OR NULL
    data: Generic<T>
    refreshing: Boolean
    networkStatus: ENUM(ONLINE, OFFLINE, POOR)
}
```

#### **Navigation State**
```pseudocode
STRUCTURE NavigationState {
    currentScreen: String
    stack: Array<String>
    params: Map<String, Any>
    canGoBack: Boolean
}
```'
        ;;
    "ml-project")
        echo '
#### **Dataset Structure**
```pseudocode
STRUCTURE Dataset {
    id: UUID
    name: String
    source: DataSource
    schema: DataSchema
    rowCount: Integer
    features: Array<Feature>
    target: Feature OR NULL
    metadata: DatasetMetadata
}

STRUCTURE Feature {
    name: String
    type: ENUM(NUMERIC, CATEGORICAL, TEXT, DATETIME)
    nullable: Boolean
    description: String
}
```

#### **Model Structure**
```pseudocode
STRUCTURE MLModel {
    id: UUID
    name: String
    algorithm: String
    hyperparameters: Map<String, Any>
    performance: ModelMetrics
    training_data: Dataset
    created_at: Timestamp
}
```'
        ;;
    *)
        echo '[Define core data structures for your specific project]'
        ;;
esac)

## Core Algorithms

### **Authentication & Authorization**
```pseudocode
FUNCTION authenticateUser(credentials: LoginCredentials) RETURNS Result<User, AuthError>
    // Input validation
    IF NOT isValidEmail(credentials.email) THEN
        RETURN Error("Invalid email format")
    
    IF NOT isValidPassword(credentials.password) THEN
        RETURN Error("Invalid password format")
    
    // Rate limiting check
    IF rateLimiter.isExceeded(credentials.email) THEN
        RETURN Error("Too many login attempts")
    
    // Find user
    user = findUserByEmail(credentials.email)
    IF user IS NULL THEN
        rateLimiter.recordFailure(credentials.email)
        RETURN Error("Invalid credentials")
    
    // Verify password
    IF NOT verifyPassword(credentials.password, user.passwordHash) THEN
        rateLimiter.recordFailure(credentials.email)
        RETURN Error("Invalid credentials")
    
    // Generate session
    session = createSession(user)
    rateLimiter.recordSuccess(credentials.email)
    
    RETURN Success(user)
END FUNCTION
```

$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo '### **Component Lifecycle**
```pseudocode
FUNCTION initializeComponent(props: ComponentProps) RETURNS ComponentState
    // Initialize state
    state = {
        loading: true,
        error: null,
        data: null,
        validationErrors: {}
    }
    
    // Load initial data
    TRY
        data = await loadInitialData(props.id)
        state.data = data
        state.loading = false
    CATCH error
        state.error = error.message
        state.loading = false
    
    RETURN state
END FUNCTION

FUNCTION updateComponent(state: ComponentState, action: Action) RETURNS ComponentState
    SWITCH action.type
        CASE "LOAD_START":
            RETURN {...state, loading: true, error: null}
        CASE "LOAD_SUCCESS":
            RETURN {...state, loading: false, data: action.payload}
        CASE "LOAD_ERROR":
            RETURN {...state, loading: false, error: action.payload}
        DEFAULT:
            RETURN state
END FUNCTION
```'
        ;;
    "api-service")
        echo '### **Request Processing**
```pseudocode
FUNCTION processApiRequest(request: ApiRequest) RETURNS ApiResponse
    // Request validation
    IF NOT validateRequest(request) THEN
        RETURN createErrorResponse(400, "Invalid request")
    
    // Authentication
    IF requiresAuth(request.path) THEN
        user = authenticateRequest(request)
        IF user IS NULL THEN
            RETURN createErrorResponse(401, "Unauthorized")
        request.user = user
    
    // Authorization
    IF NOT authorizeRequest(request) THEN
        RETURN createErrorResponse(403, "Forbidden")
    
    // Route to handler
    handler = findHandler(request.method, request.path)
    IF handler IS NULL THEN
        RETURN createErrorResponse(404, "Not found")
    
    // Execute handler
    TRY
        result = handler.execute(request)
        RETURN createSuccessResponse(result)
    CATCH ValidationError as e
        RETURN createErrorResponse(400, e.message)
    CATCH NotFoundError as e
        RETURN createErrorResponse(404, e.message)
    CATCH ServerError as e
        logError(e)
        RETURN createErrorResponse(500, "Internal server error")
END FUNCTION
```'
        ;;
    "ml-project")
        echo '### **Model Training Pipeline**
```pseudocode
FUNCTION trainModel(config: TrainingConfig) RETURNS Result<MLModel, TrainingError>
    // Data preparation
    dataset = loadDataset(config.datasetId)
    IF dataset IS NULL THEN
        RETURN Error("Dataset not found")
    
    // Data validation
    IF NOT validateDataset(dataset) THEN
        RETURN Error("Invalid dataset")
    
    // Feature preprocessing
    processedData = preprocessFeatures(dataset, config.preprocessing)
    
    // Split data
    trainData, validationData, testData = splitData(processedData, config.splitRatio)
    
    // Initialize model
    model = createModel(config.algorithm, config.hyperparameters)
    
    // Training loop
    FOR epoch IN 1 TO config.maxEpochs DO
        // Train on batch
        FOR batch IN trainData.batches() DO
            loss = model.trainBatch(batch)
        END FOR
        
        // Validation
        validationLoss = model.evaluate(validationData)
        
        // Early stopping
        IF validationLoss > previousBest + config.patience THEN
            BREAK
        END IF
        
        previousBest = validationLoss
    END FOR
    
    // Final evaluation
    performance = model.evaluate(testData)
    
    // Save model
    modelId = saveModel(model, performance, config)
    
    RETURN Success(model)
END FUNCTION
```'
        ;;
esac)

### **Error Handling Patterns**
```pseudocode
ABSTRACT CLASS AppError {
    message: String
    code: String
    timestamp: Timestamp
}

CLASS ValidationError EXTENDS AppError {
    field: String
    value: Any
}

CLASS NotFoundError EXTENDS AppError {
    resourceType: String
    identifier: Any
}

FUNCTION handleError(error: Error) RETURNS ErrorResponse
    IF error INSTANCEOF ValidationError THEN
        RETURN {
            status: 400,
            code: "VALIDATION_ERROR",
            message: error.message,
            field: error.field
        }
    ELSE IF error INSTANCEOF NotFoundError THEN
        RETURN {
            status: 404,
            code: "NOT_FOUND",
            message: error.resourceType + " not found"
        }
    ELSE
        // Log unexpected errors
        logger.error("Unexpected error:", error)
        RETURN {
            status: 500,
            code: "INTERNAL_ERROR",
            message: "An unexpected error occurred"
        }
END FUNCTION
```

## Utility Functions

### **Validation Functions**
```pseudocode
FUNCTION isValidEmail(email: String) RETURNS Boolean
    emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    RETURN matches(email, emailRegex) AND length(email) <= 254
END FUNCTION

FUNCTION isValidPassword(password: String) RETURNS Boolean
    IF length(password) < 8 OR length(password) > 128 THEN
        RETURN False
    
    hasLowercase = matches(password, ".*[a-z].*")
    hasUppercase = matches(password, ".*[A-Z].*")
    hasDigit = matches(password, ".*[0-9].*")
    hasSpecial = matches(password, ".*[!@#$%^&*()].*")
    
    RETURN hasLowercase AND hasUppercase AND hasDigit AND hasSpecial
END FUNCTION
```

### **Security Functions**
```pseudocode
FUNCTION hashPassword(password: String) RETURNS String
    salt = generateSalt(16)
    hash = scrypt(password, salt, {N: 32768, r: 8, p: 1})
    RETURN base64encode(salt + hash)
END FUNCTION

FUNCTION verifyPassword(password: String, hash: String) RETURNS Boolean
    decoded = base64decode(hash)
    salt = substring(decoded, 0, 16)
    expectedHash = substring(decoded, 16, 48)
    actualHash = scrypt(password, salt, {N: 32768, r: 8, p: 1})
    RETURN constantTimeCompare(expectedHash, actualHash)
END FUNCTION
```

## Performance Considerations

### **Complexity Analysis**
- Authentication: O(1) - single database lookup
- Data validation: O(n) where n is input size
- Search operations: O(log n) with proper indexing
- Batch processing: O(n) where n is batch size

### **Optimization Strategies**
1. **Caching**: Implement caching for frequently accessed data
2. **Pagination**: Use pagination for large datasets
3. **Lazy Loading**: Load data on demand
4. **Connection Pooling**: Reuse database connections
5. **Async Processing**: Use async operations for I/O

## Integration Points

### **External APIs**
```pseudocode
FUNCTION callExternalAPI(endpoint: String, data: Any) RETURNS Result<Any, APIError>
    // Prepare request
    request = {
        url: endpoint,
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify(data),
        timeout: 30000
    }
    
    // Retry logic
    FOR attempt IN 1 TO 3 DO
        TRY
            response = httpClient.send(request)
            IF response.status >= 200 AND response.status < 300 THEN
                RETURN Success(JSON.parse(response.body))
            ELSE
                RETURN Error("API returned status " + response.status)
        CATCH NetworkError as e
            IF attempt == 3 THEN
                RETURN Error("Network error after 3 attempts: " + e.message)
            WAIT exponentialBackoff(attempt)
    END FOR
END FUNCTION
```

## Testing Guidelines

### **Unit Test Patterns**
```pseudocode
TEST authenticateUser_WithValidCredentials_ReturnsUser
    // Arrange
    credentials = {email: "test@example.com", password: "ValidPass123!"}
    expectedUser = createTestUser()
    mockUserRepository.findByEmail.returns(expectedUser)
    mockPasswordService.verify.returns(true)
    
    // Act
    result = authenticateUser(credentials)
    
    // Assert
    ASSERT result.isSuccess()
    ASSERT result.value.email == "test@example.com"
    ASSERT mockUserRepository.findByEmail.calledWith("test@example.com")
END TEST

TEST authenticateUser_WithInvalidPassword_ReturnsError
    // Arrange
    credentials = {email: "test@example.com", password: "wrongpassword"}
    user = createTestUser()
    mockUserRepository.findByEmail.returns(user)
    mockPasswordService.verify.returns(false)
    
    // Act
    result = authenticateUser(credentials)
    
    // Assert
    ASSERT result.isError()
    ASSERT result.error.message == "Invalid credentials"
END TEST
```

## Implementation Notes

### **Code Generation Guidance**
- Use these pseudocode functions as templates for implementation
- Maintain the same function signatures and error handling patterns
- Implement comprehensive logging at decision points
- Add input validation for all public functions
- Follow the established naming conventions

### **Security Implementation**
- Never store passwords in plain text
- Use prepared statements for database queries
- Implement rate limiting for authentication endpoints
- Log security events for audit purposes
- Validate all inputs before processing

---

*Generated by Enhanced SPARC Project Initialization Script v${SCRIPT_VERSION}*
*Template: $SELECTED_TEMPLATE*
*Team: $TEAM_SIZE*
*Security: $SECURITY_LEVEL*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Create template-specific documents
create_template_specific_docs() {
    case "$SELECTED_TEMPLATE" in
        "web-app")
            create_file_safe "docs/component-guide.md" "$(generate_component_guide)" "Component development guide"
            create_file_safe "docs/styling-guide.md" "$(generate_styling_guide)" "Styling and theming guide"
            ;;
        "api-service")
            create_file_safe "docs/api-guide.md" "$(generate_api_guide)" "API development guide"
            create_file_safe "docs/database-guide.md" "$(generate_database_guide)" "Database design guide"
            ;;
        "mobile-app")
            create_file_safe "docs/platform-guide.md" "$(generate_platform_guide)" "Platform-specific guide"
            create_file_safe "docs/navigation-guide.md" "$(generate_navigation_guide)" "Navigation patterns"
            ;;
        "ml-project")
            create_file_safe "docs/data-guide.md" "$(generate_data_guide)" "Data handling guide"
            create_file_safe "docs/model-guide.md" "$(generate_model_guide)" "Model development guide"
            ;;
    esac
}

# Generate testing documentation
generate_testing_docs() {
    cat << EOF
# Testing Strategy

## Testing Framework for $SELECTED_TEMPLATE

### **Testing Pyramid**
- **Unit Tests (70%)**: Test individual functions and components
- **Integration Tests (20%)**: Test component interactions
- **End-to-End Tests (10%)**: Test complete user workflows

### **Testing Tools**
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- **Unit Testing**: Jest + React Testing Library
- **Integration Testing**: Cypress or Playwright
- **Visual Testing**: Storybook + Chromatic
- **Performance Testing**: Lighthouse CI"
        ;;
    "api-service")
        echo "- **Unit Testing**: Jest/Mocha + Supertest
- **Integration Testing**: Postman/Newman
- **Load Testing**: Artillery or k6
- **Contract Testing**: Pact"
        ;;
    *)
        echo "- **Unit Testing**: [Framework appropriate for technology stack]
- **Integration Testing**: [Integration testing approach]
- **End-to-End Testing**: [E2E testing strategy]"
        ;;
esac)

### **Test Coverage Requirements**
- Minimum 90% code coverage for critical paths
- 100% coverage for security-related functions
- All API endpoints must have integration tests
- Critical user journeys must have E2E tests

### **Testing Best Practices**
1. Write tests before or alongside code (TDD)
2. Use descriptive test names that explain the scenario
3. Follow AAA pattern: Arrange, Act, Assert
4. Mock external dependencies
5. Test both happy path and error scenarios

### **Continuous Testing**
- Run unit tests on every commit
- Run integration tests on every PR
- Run E2E tests on deployment to staging
- Performance tests on every release

EOF
}

# Generate package.json
generate_package_json() {
    cat << EOF
{
  "name": "$PROJECT_ID",
  "version": "1.0.0",
  "description": "$PROJECT_NAME - Generated with Enhanced SPARC methodology",
  "private": true,
  "scripts": {
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo '    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:e2e": "cypress run",
    "storybook": "storybook dev -p 6006",
    "build-storybook": "storybook build"'
        ;;
    "api-service")
        echo '    "dev": "nodemon src/index.ts",
    "build": "tsc",
    "start": "node dist/index.js",
    "lint": "eslint src/**/*.ts",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:integration": "jest --config jest.integration.config.js"'
        ;;
    *)
        echo '    "dev": "npm run develop",
    "build": "npm run compile",
    "start": "npm run serve",
    "lint": "eslint src/",
    "test": "jest"'
        ;;
esac)
  },
  "dependencies": {
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo '    "next": "^14.0.0",
    "react": "^18.0.0",
    "react-dom": "^18.0.0"'
        ;;
    "api-service")
        echo '    "express": "^4.18.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "express-rate-limit": "^6.7.0"'
        ;;
    *)
        echo '    "@sparc/core": "^1.0.0"'
        ;;
esac)
  },
  "devDependencies": {
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo '    "@types/node": "^20.0.0",
    "@types/react": "^18.0.0",
    "@types/react-dom": "^18.0.0",
    "typescript": "^5.0.0",
    "eslint": "^8.0.0",
    "eslint-config-next": "^14.0.0",
    "jest": "^29.0.0",
    "@testing-library/react": "^13.0.0",
    "@testing-library/jest-dom": "^5.16.0",
    "cypress": "^12.0.0"'
        ;;
    "api-service")
        echo '    "@types/node": "^20.0.0",
    "@types/express": "^4.17.0",
    "@types/cors": "^2.8.0",
    "typescript": "^5.0.0",
    "ts-node": "^10.9.0",
    "nodemon": "^2.0.0",
    "eslint": "^8.0.0",
    "@typescript-eslint/eslint-plugin": "^5.0.0",
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0",
    "supertest": "^6.3.0",
    "@types/supertest": "^2.0.0"'
        ;;
    *)
        echo '    "typescript": "^5.0.0",
    "eslint": "^8.0.0",
    "jest": "^29.0.0",
    "@types/jest": "^29.0.0"'
        ;;
esac)
  },
  "keywords": [
    "sparc",
    "sparc-methodology",
    "$SELECTED_TEMPLATE",
    "$PROJECT_ID"
  ],
  "author": "",
  "license": "MIT",
  "engines": {
    "node": ">=16.0.0"
  }
}
EOF
}

# Generate enhanced README
generate_enhanced_readme() {
    cat << EOF
# $PROJECT_NAME

[![SPARC Methodology](https://img.shields.io/badge/methodology-SPARC-blue.svg)](https://github.com/JackSmack1971/SPARC40)
[![Template](https://img.shields.io/badge/template-$SELECTED_TEMPLATE-green.svg)]()
[![Security](https://img.shields.io/badge/security-$SECURITY_LEVEL-orange.svg)]()
[![Team](https://img.shields.io/badge/team-$TEAM_SIZE-purple.svg)]()

> **Enhanced SPARC Project** generated with comprehensive AI mode support and automated development workflows.

## Project Overview

$PROJECT_NAME is a $SELECTED_TEMPLATE project built using the enhanced SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) methodology with 40+ specialized AI modes for systematic development.

### Key Features

- 🏗️ **SPARC Methodology**: Systematic development phases with quality gates
- 🤖 **40+ AI Modes**: Specialized AI assistants for every aspect of development
- 🧠 **Memory Bank**: Persistent knowledge management across development phases
- 🔒 **$SECURITY_LEVEL Security**: Comprehensive security controls and access patterns
- 👥 **$TEAM_SIZE Team Optimized**: Configured for $(echo "${TEAM_CONFIGS[$TEAM_SIZE]}" | cut -d'(' -f1)
$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then echo "- ☁️  **$CLOUD_PROVIDER Ready**: Cloud deployment templates included"; fi)
$(if [[ "$INCLUDE_TESTING" =~ ^[Yy] ]]; then echo "- 🧪 **Testing Framework**: Comprehensive testing strategy and tools"; fi)

### Template: $SELECTED_TEMPLATE

${PROJECT_TEMPLATES[$SELECTED_TEMPLATE]}

## Quick Start

### Prerequisites

- **Roo Code**: VSCode extension with AI mode support
- **Node.js 16+**: For package management and tooling
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- **Modern Browser**: Chrome, Firefox, Safari, or Edge"
        ;;
    "api-service")
        echo "- **Database**: PostgreSQL or MongoDB
- **Redis**: For caching and sessions"
        ;;
    "mobile-app")
        echo "- **React Native CLI**: For mobile development
- **Xcode/Android Studio**: For platform-specific development"
        ;;
    "ml-project")
        echo "- **Python 3.8+**: For machine learning development
- **Jupyter**: For notebook development"
        ;;
esac)

### Installation

1. **Install Dependencies**
   \`\`\`bash
$(case "$SELECTED_TEMPLATE" in
    "web-app"|"api-service"|"fullstack")
        echo "   npm install"
        ;;
    "ml-project")
        echo "   pip install -r requirements.txt"
        ;;
    *)
        echo "   # Install dependencies according to your technology stack"
        ;;
esac)
   \`\`\`

2. **Environment Setup**
   \`\`\`bash
   cp .env.example .env
   # Edit .env with your configuration
   \`\`\`

3. **Development Server**
   \`\`\`bash
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "   npm run dev"
        ;;
    "api-service")
        echo "   npm run dev"
        ;;
    "ml-project")
        echo "   jupyter notebook"
        ;;
    *)
        echo "   npm run dev"
        ;;
esac)
   \`\`\`

## SPARC Development Phases

This project follows the enhanced SPARC methodology:

### 📋 Phase 1: Specification
- ✅ Project structure initialized
- [ ] Requirements gathering with \`@sparc-specification-writer\`
- [ ] Stakeholder interviews and user research
- [ ] Acceptance criteria definition

### 🧮 Phase 2: Pseudocode
- [ ] Algorithm design with \`@sparc-pseudocode-designer\`
- [ ] Function specifications and data structures
- [ ] Performance and complexity analysis

### 🏗️ Phase 3: Architecture
- [ ] System architecture with \`@sparc-architect\`
- [ ] Security architecture with \`@sparc-security-architect\`
- [ ] Technology stack finalization

### ⚡ Phase 4: Refinement
- [ ] Implementation with \`@sparc-code-implementer\`
- [ ] Testing with \`@sparc-tdd-engineer\`
- [ ] Security review with \`@sparc-security-reviewer\`

### ✅ Phase 5: Completion
- [ ] Integration testing with \`@sparc-integrator\`
- [ ] Deployment with \`@sparc-devops-engineer\`
- [ ] Documentation with \`@sparc-documentation-writer\`

## AI Mode System

This project includes 40+ specialized AI modes for comprehensive development support:

### Core Development Modes
- **🎭 SPARC Orchestrator**: Project coordination and workflow management
- **🏗️ SPARC Architect**: System design and architecture
- **💻 Code Implementer**: High-quality code implementation
- **🧪 TDD Engineer**: Test-driven development and quality assurance
- **🛡️ Security Architect**: Security design and threat modeling

### Specialized Modes
- **📊 Data Architect**: Data modeling and schema design
- **📱 Mobile Architect**: Mobile-specific patterns and optimization
- **⚡ Performance Engineer**: Performance analysis and optimization
- **🚀 DevOps Engineer**: Deployment and infrastructure automation
- **📚 Documentation Writer**: Comprehensive technical documentation

### Research and Analysis
- **🔍 Domain Intelligence**: Business and industry expertise
- **🧠 Requirements Architect**: Comprehensive requirements analysis
- **🔴 Adversarial Agent**: Risk assessment and threat analysis
- **✅ QA Analyst**: Quality assurance and testing coordination

## Memory Bank System

The Memory Bank maintains project knowledge and context:

- **\`memory-bank/activeContext.md\`**: Current working state and handoffs
- **\`memory-bank/decisionLog.md\`**: All architectural decisions with rationale
- **\`memory-bank/productContext.md\`**: Business and domain knowledge
- **\`memory-bank/progress.md\`**: Status tracking and milestone management
- **\`memory-bank/systemPatterns.md\`**: Reusable technical patterns

## Security Framework

### $SECURITY_LEVEL Security Level

$(case "$SECURITY_LEVEL" in
    "basic")
        echo "- Input validation and sanitization
- HTTPS enforcement and secure headers
- Basic authentication and session management
- Regular security updates and dependency scanning"
        ;;
    "medium")
        echo "- Multi-factor authentication support
- Role-based access control (RBAC)
- Comprehensive audit logging and monitoring
- Security scanning integrated in CI/CD pipeline"
        ;;
    "high")
        echo "- Zero-trust security architecture
- Advanced threat detection and response
- Comprehensive access control policies
- Regular penetration testing and security assessments"
        ;;
    "enterprise")
        echo "- Enterprise-grade security infrastructure
- Full compliance with industry regulations
- Advanced threat intelligence integration
- Formal security governance and approval processes"
        ;;
esac)

### Access Controls

- **\`.rooignore\`**: File-level security restrictions
- **\`.roomodes\`**: AI mode permissions and boundaries
- **Environment Variables**: Secure configuration management
- **Audit Logging**: Comprehensive activity tracking

## Development Workflow

### Git Workflow$(if [[ "$INIT_GIT" =~ ^[Yy] ]]; then echo " (Configured)"
else
echo ""
fi)

\`\`\`bash
# Feature development
git checkout -b feature/new-feature
# Make changes
git add .
git commit -m "feat: implement new feature"
git push origin feature/new-feature
# Create pull request
\`\`\`

### AI Mode Usage

\`\`\`bash
# Start specification phase
@sparc-specification-writer

# Begin architecture design
@sparc-architect

# Implement features
@sparc-code-implementer

# Add comprehensive tests
@sparc-tdd-engineer

# Security review
@sparc-security-reviewer
\`\`\`

### Quality Gates

Each phase includes quality gates:
- **Specification**: Requirements validation and stakeholder sign-off
- **Architecture**: Security review and performance validation
- **Implementation**: Code review, testing, and security scanning
- **Deployment**: Integration testing and production readiness

## Testing Strategy$(if [[ "$INCLUDE_TESTING" =~ ^[Yy] ]]; then echo " (Configured)"
else
echo ""
fi)

### Testing Pyramid
- **Unit Tests (70%)**: Component and function testing
- **Integration Tests (20%)**: API and service integration
- **End-to-End Tests (10%)**: Complete user workflows

### Commands
\`\`\`bash
# Run all tests
npm test

# Watch mode for development
npm run test:watch

# Integration tests
npm run test:integration

# End-to-end tests
npm run test:e2e
\`\`\`

## Deployment$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then echo " ($CLOUD_PROVIDER Ready)"
else
echo ""
fi)

$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then
cat << CLOUD_DEPLOYMENT
### Cloud Deployment ($CLOUD_PROVIDER)

Infrastructure as Code templates included for $CLOUD_PROVIDER:

\`\`\`bash
# Deploy to staging
npm run deploy:staging

# Deploy to production
npm run deploy:production
\`\`\`

### Environment Configuration
- **Development**: Local development environment
- **Staging**: Pre-production testing environment
- **Production**: Live production environment

CLOUD_DEPLOYMENT
else
echo "### Deployment Strategy

Deployment configurations and scripts are available in the \`infrastructure/\` directory.

\`\`\`bash
# Build for production
npm run build

# Start production server
npm start
\`\`\`"
fi)

## Monitoring and Observability$(if [[ "$INCLUDE_MONITORING" =~ ^[Yy] ]]; then echo " (Configured)"
else
echo ""
fi)

$(if [[ "$INCLUDE_MONITORING" =~ ^[Yy] ]]; then
echo "### Monitoring Stack

- **Application Monitoring**: Performance and error tracking
- **Infrastructure Monitoring**: System resource monitoring
- **Business Metrics**: KPI and user behavior tracking
- **Security Monitoring**: Security event detection and alerting

### Dashboards

- Application performance dashboard
- Infrastructure health dashboard
- Business metrics dashboard
- Security events dashboard"
else
echo "### Monitoring Framework

Monitoring and observability templates are available for implementation:

- Application performance monitoring
- Infrastructure health monitoring
- Business metrics tracking
- Security event monitoring"
fi)

## Team Collaboration ($TEAM_SIZE Team)

### Team Configuration
${TEAM_CONFIGS[$TEAM_SIZE]}

### Communication
$(case "$TEAM_SIZE" in
    "solo")
        echo "- Personal productivity optimization
- AI mode assistance for all development aspects
- Comprehensive documentation for future reference"
        ;;
    "small")
        echo "- Daily informal check-ins and pair programming
- Shared AI mode usage and knowledge sharing
- Collaborative decision making and cross-training"
        ;;
    "medium")
        echo "- Daily standups and weekly planning sessions
- Specialized roles with AI mode expertise
- Structured code review and quality processes"
        ;;
    "large"|"enterprise")
        echo "- Formal communication and reporting structures
- Specialized teams with AI mode coordination
- Comprehensive project management and governance"
        ;;
esac)

### Development Process
- **Branching Strategy**: Feature branches with pull request reviews
- **Code Review**: $(case "$TEAM_SIZE" in "solo") echo "AI-assisted self-review" ;; *) echo "Peer review with AI mode validation" ;; esac)
- **Quality Gates**: Automated testing and AI mode quality checks
- **Documentation**: Continuous Memory Bank updates

## Contributing

1. **Follow SPARC Methodology**: Use appropriate AI modes for each phase
2. **Update Memory Bank**: Keep context and decisions current
3. **Security First**: Follow $SECURITY_LEVEL security guidelines
4. **Test Coverage**: Maintain comprehensive test coverage
5. **Documentation**: Update documentation with changes

### Code Style

- Follow patterns in \`memory-bank/systemPatterns.md\`
- Maximum 500 lines per file for maintainability
- Comprehensive error handling and input validation
- Security-first implementation practices

## Resources

### Documentation
- **Getting Started**: \`docs/getting-started.md\`
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- **Component Guide**: \`docs/component-guide.md\`
- **Styling Guide**: \`docs/styling-guide.md\`"
        ;;
    "api-service")
        echo "- **API Guide**: \`docs/api-guide.md\`
- **Database Guide**: \`docs/database-guide.md\`"
        ;;
esac)
- **Testing Strategy**: \`docs/testing-strategy.md\`
- **Security Framework**: \`security/README.md\`

### SPARC Methodology
- [SPARC40 Repository](https://github.com/JackSmack1971/SPARC40)
- [Roo Code Extension](https://marketplace.visualstudio.com/items?itemName=roo-code)
- [AI Mode Documentation](https://docs.roocode.com/)

## Project Status

- **Phase**: Project Initialization (Complete)
- **Next Phase**: Specification
- **Progress**: 5% Complete
- **Last Updated**: $(date -u +"%Y-%m-%d")

## Support

For questions and support:
- Check Memory Bank files for project context
- Review documentation in \`docs/\` directory
- Consult AI modes for specific expertise areas
- Follow SPARC methodology best practices

---

*Generated with Enhanced SPARC Project Initialization Script v${SCRIPT_VERSION}*  
*Template: $SELECTED_TEMPLATE | Team: $TEAM_SIZE | Security: $SECURITY_LEVEL*  
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
}

# Generate getting started guide
generate_getting_started() {
    cat << EOF
# Getting Started with $PROJECT_NAME

Welcome to your enhanced SPARC methodology project! This guide will help you get up and running quickly.

## Overview

Your project is configured as a **$SELECTED_TEMPLATE** template with **$SECURITY_LEVEL** security level, optimized for a **$TEAM_SIZE** team.

## Prerequisites Checklist

- [ ] **Roo Code VSCode Extension** installed and configured
- [ ] **Node.js 16+** installed for package management
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- [ ] **Modern web browser** for development and testing"
        ;;
    "api-service")
        echo "- [ ] **Database system** (PostgreSQL/MongoDB) installed or accessible
- [ ] **Redis** for caching (optional but recommended)"
        ;;
    "mobile-app")
        echo "- [ ] **React Native CLI** or Expo CLI installed
- [ ] **iOS Simulator** or **Android Emulator** set up"
        ;;
    "ml-project")
        echo "- [ ] **Python 3.8+** with pip installed
- [ ] **Jupyter Notebook** or JupyterLab
- [ ] **Virtual environment** tool (venv, conda, etc.)"
        ;;
esac)
$(if [[ "$INIT_GIT" =~ ^[Yy] ]]; then echo "- [ ] **Git** configured with your credentials"; fi)

## Initial Setup

### 1. Environment Configuration

Copy the example environment file and configure your settings:

\`\`\`bash
cp .env.example .env
\`\`\`

Edit \`.env\` with your specific configuration:

\`\`\`bash
# Example configuration for $SELECTED_TEMPLATE
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "NEXT_PUBLIC_API_URL=http://localhost:3000/api
NEXT_PUBLIC_APP_NAME=$PROJECT_NAME"
        ;;
    "api-service")
        echo "PORT=3000
DATABASE_URL=postgresql://user:password@localhost:5432/$PROJECT_ID
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key-here"
        ;;
    "mobile-app")
        echo "API_BASE_URL=https://api.example.com
APP_ENV=development"
        ;;
    "ml-project")
        echo "DATA_PATH=./data
MODEL_PATH=./models
JUPYTER_PORT=8888"
        ;;
esac)
\`\`\`

### 2. Install Dependencies

$(case "$SELECTED_TEMPLATE" in
    "web-app"|"api-service"|"fullstack")
        echo "\`\`\`bash
npm install
\`\`\`"
        ;;
    "ml-project")
        echo "\`\`\`bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\\Scripts\\activate

# Install dependencies
pip install -r requirements.txt
\`\`\`"
        ;;
    *)
        echo "\`\`\`bash
# Install dependencies according to your technology stack
npm install
\`\`\`"
        ;;
esac)

### 3. Start Development Server

$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "\`\`\`bash
npm run dev
\`\`\`

Your application will be available at \`http://localhost:3000\`"
        ;;
    "api-service")
        echo "\`\`\`bash
npm run dev
\`\`\`

Your API will be available at \`http://localhost:3000\`"
        ;;
    "ml-project")
        echo "\`\`\`bash
jupyter notebook
\`\`\`

Jupyter will open in your browser at \`http://localhost:8888\`"
        ;;
    *)
        echo "\`\`\`bash
npm run dev
\`\`\`"
        ;;
esac)

## SPARC Methodology Workflow

### Phase 1: Specification (Current Phase)

Start by defining your requirements:

1. **Activate the Specification Writer**
   \`\`\`
   @sparc-specification-writer
   \`\`\`

2. **Begin Requirements Gathering**
   - Update \`specification.md\` with your project requirements
   - Define user personas and scenarios
   - Establish acceptance criteria

3. **Update Memory Bank**
   - Review \`memory-bank/activeContext.md\`
   - Update \`memory-bank/productContext.md\` with business knowledge

### Next Phases

1. **Pseudocode Phase**: Design algorithms with \`@sparc-pseudocode-designer\`
2. **Architecture Phase**: System design with \`@sparc-architect\`
3. **Refinement Phase**: Implementation with \`@sparc-code-implementer\`
4. **Completion Phase**: Integration with \`@sparc-integrator\`

## AI Mode System

Your project includes 40+ specialized AI modes. Here are the most important ones to start with:

### Essential Modes
- **\`@sparc-orchestrator\`**: Project coordination and workflow management
- **\`@sparc-specification-writer\`**: Requirements and scope definition
- **\`@sparc-architect\`**: System architecture and design
- **\`@sparc-security-architect\`**: Security design and threat modeling

### Development Modes
- **\`@sparc-code-implementer\`**: High-quality code implementation
- **\`@sparc-tdd-engineer\`**: Test-driven development
- **\`@sparc-debug-specialist\`**: Problem diagnosis and resolution

### Quality Assurance
- **\`@sparc-qa-analyst\`**: Quality assurance and testing
- **\`@sparc-security-reviewer\`**: Security audits and reviews
- **\`@sparc-performance-engineer\`**: Performance optimization

## Memory Bank Usage

The Memory Bank maintains project knowledge across all phases:

### Key Files to Monitor
- **\`memory-bank/activeContext.md\`**: Always check this before starting work
- **\`memory-bank/progress.md\`**: Track milestones and status
- **\`memory-bank/decisionLog.md\`**: Review architectural decisions
- **\`memory-bank/systemPatterns.md\`**: Follow established patterns

### Best Practices
1. **Read activeContext.md** before starting any work
2. **Update progress.md** when completing milestones
3. **Log decisions** in decisionLog.md with rationale
4. **Document patterns** in systemPatterns.md for reuse

## Security Guidelines ($SECURITY_LEVEL Level)

### Access Controls
- Review \`.rooignore\` for file access restrictions
- AI modes have specific permissions defined in \`.roomodes\`
- Never commit secrets or sensitive configuration

### Security Practices
$(case "$SECURITY_LEVEL" in
    "basic")
        echo "- Use HTTPS for all communications
- Validate all user inputs
- Keep dependencies updated
- Follow secure coding practices"
        ;;
    "medium")
        echo "- Implement role-based access control
- Use multi-factor authentication where applicable
- Maintain comprehensive audit logs
- Regular security scanning and monitoring"
        ;;
    "high"|"enterprise")
        echo "- Follow zero-trust security principles
- Implement advanced threat detection
- Regular penetration testing
- Formal security governance processes"
        ;;
esac)

## Team Collaboration ($TEAM_SIZE Team)

### Workflow for $(echo "${TEAM_CONFIGS[$TEAM_SIZE]}" | cut -d'(' -f1)
$(case "$TEAM_SIZE" in
    "solo")
        echo "- Use AI modes for comprehensive development support
- Maintain detailed documentation for future reference
- Regular self-review and quality checks
- Leverage Memory Bank for knowledge continuity"
        ;;
    "small")
        echo "- Daily informal check-ins and pair programming
- Shared responsibility for code quality and reviews
- Collaborative AI mode usage and knowledge sharing
- Cross-training and skill development"
        ;;
    "medium")
        echo "- Daily standups and weekly planning sessions
- Defined roles with specialized AI mode expertise
- Structured code review and approval processes
- Regular team retrospectives and improvements"
        ;;
    "large"|"enterprise")
        echo "- Formal communication and reporting structures
- Specialized teams with coordinated AI mode usage
- Comprehensive project management and governance
- Advanced tooling and process automation"
        ;;
esac)

## Common Tasks

### Running Tests$(if [[ "$INCLUDE_TESTING" =~ ^[Yy] ]]; then echo " (Configured)"
else
echo ""
fi)

\`\`\`bash
# Run all tests
npm test

# Watch mode for development
npm run test:watch

# Integration tests
npm run test:integration
\`\`\`

### Building for Production

\`\`\`bash
# Build optimized version
npm run build

# Start production server
npm start
\`\`\`

### Code Quality

\`\`\`bash
# Lint code
npm run lint

# Format code
npm run format

# Type checking (if TypeScript)
npm run type-check
\`\`\`

## Troubleshooting

### Common Issues

1. **AI Mode Not Responding**
   - Check \`.roomodes\` configuration
   - Verify mode permissions in file access patterns
   - Review \`.rooignore\` for blocked files

2. **Memory Bank Context Lost**
   - Ensure \`memory-bank/activeContext.md\` is updated
   - Check for file access permissions
   - Verify handoff procedures between modes

3. **Dependencies Issues**
$(case "$SELECTED_TEMPLATE" in
    "web-app"|"api-service")
        echo "   - Delete \`node_modules\` and run \`npm install\`
   - Clear npm cache: \`npm cache clean --force\`
   - Check Node.js version compatibility"
        ;;
    "ml-project")
        echo "   - Recreate virtual environment
   - Update pip: \`pip install --upgrade pip\`
   - Check Python version compatibility"
        ;;
esac)

### Getting Help

1. **Check Memory Bank** for project context and decisions
2. **Review Documentation** in \`docs/\` directory
3. **Consult AI Modes** for specific expertise areas
4. **Follow SPARC Methodology** guidelines and best practices

## Next Steps

1. **Complete Phase 1 Specification**
   - Work with \`@sparc-specification-writer\`
   - Define comprehensive requirements
   - Establish acceptance criteria

2. **Set Up Development Workflow**
   - Configure your development environment
   - Set up testing and quality tools
   - Establish team communication patterns

3. **Begin Implementation Planning**
   - Review architecture templates
   - Plan technology stack decisions
   - Prepare for pseudocode phase

## Resources

- **Project Documentation**: \`docs/\` directory
- **SPARC Methodology**: [SPARC40 Repository](https://github.com/JackSmack1971/SPARC40)
- **Roo Code Documentation**: [docs.roocode.com](https://docs.roocode.com/)
- **AI Mode Reference**: \`.roomodes\` configuration file

---

*Ready to build something amazing with SPARC methodology!*  
*Template: $SELECTED_TEMPLATE | Generated: $(date -u +"%Y-%m-%d")*
EOF
}

# Generate contributing guide
generate_contributing_guide() {
    cat << EOF
# Contributing to $PROJECT_NAME

Thank you for your interest in contributing to $PROJECT_NAME! This guide will help you understand our development process and contribution standards.

## Development Methodology

This project follows the **Enhanced SPARC Methodology** with AI-assisted development. Please familiarize yourself with the process before contributing.

### SPARC Phases
1. **Specification**: Requirements and scope definition
2. **Pseudocode**: Algorithm and logic design
3. **Architecture**: System design and technology selection
4. **Refinement**: Implementation and testing
5. **Completion**: Integration and deployment

## Getting Started

### Prerequisites
- **Roo Code VSCode Extension** with AI mode support
- **Node.js 16+** for package management
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- **Modern web browser** for development and testing"
        ;;
    "api-service")
        echo "- **Database access** (PostgreSQL/MongoDB)
- **Redis** for caching (development)"
        ;;
    "ml-project")
        echo "- **Python 3.8+** with scientific computing libraries
- **Jupyter Notebook** for data analysis"
        ;;
esac)
- **Git** with proper configuration

### Setup
1. **Fork the Repository**
   \`\`\`bash
   git clone https://github.com/[your-username]/$PROJECT_ID.git
   cd $PROJECT_ID
   \`\`\`

2. **Install Dependencies**
$(case "$SELECTED_TEMPLATE" in
    "web-app"|"api-service")
        echo "   \`\`\`bash
   npm install
   \`\`\`"
        ;;
    "ml-project")
        echo "   \`\`\`bash
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   \`\`\`"
        ;;
esac)

3. **Environment Configuration**
   \`\`\`bash
   cp .env.example .env
   # Configure your local environment
   \`\`\`

## AI Mode System

This project uses 40+ specialized AI modes. Contributors should use appropriate modes for their work:

### For Different Types of Contributions

#### Feature Development
- **\`@sparc-specification-writer\`**: Define feature requirements
- **\`@sparc-architect\`**: Design feature architecture
- **\`@sparc-code-implementer\`**: Implement the feature
- **\`@sparc-tdd-engineer\`**: Add comprehensive tests

#### Bug Fixes
- **\`@sparc-debug-specialist\`**: Diagnose the issue
- **\`@sparc-code-implementer\`**: Implement the fix
- **\`@sparc-tdd-engineer\`**: Add regression tests

#### Documentation
- **\`@sparc-documentation-writer\`**: Create/update documentation
- **\`@sparc-specification-writer\`**: Update specifications

#### Security
- **\`@sparc-security-architect\`**: Design security improvements
- **\`@sparc-security-reviewer\`**: Review security implications

## Code Standards

### General Guidelines
- **File Size**: Maximum 500 lines per file
- **Function Size**: Maximum 50 lines per function
- **Security**: Follow $SECURITY_LEVEL security guidelines
- **Testing**: Maintain >90% test coverage for new code
- **Documentation**: Update relevant documentation with changes

### Code Style
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- **React Components**: Use functional components with hooks
- **TypeScript**: Strict type checking enabled
- **Styling**: Use CSS modules or styled-components
- **State Management**: Follow established Redux/Context patterns"
        ;;
    "api-service")
        echo "- **API Design**: Follow RESTful principles
- **Error Handling**: Comprehensive error responses
- **Authentication**: Secure authentication patterns
- **Database**: Use parameterized queries, avoid N+1 problems"
        ;;
    "ml-project")
        echo "- **Jupyter Notebooks**: Clear markdown explanations
- **Python Code**: Follow PEP 8 standards
- **Data Processing**: Document data transformations
- **Model Training**: Reproducible experiments with logging"
        ;;
esac)

### Memory Bank Updates
Always update relevant Memory Bank files:
- **activeContext.md**: Current work state and handoffs
- **progress.md**: Milestone completion and status
- **decisionLog.md**: Architectural decisions with rationale
- **systemPatterns.md**: New reusable patterns

## Contribution Workflow

### 1. Planning Phase
- Create or find an issue describing the work
- Use \`@sparc-specification-writer\` for feature planning
- Update \`memory-bank/activeContext.md\` with your plans

### 2. Development Branch
\`\`\`bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
\`\`\`

### 3. Implementation
- Use appropriate AI modes for each aspect of development
- Follow SPARC methodology phases
- Update Memory Bank files as you progress
- Write tests alongside implementation

### 4. Quality Assurance
- Run all tests: \`npm test\`
- Check code style: \`npm run lint\`
- Security review with \`@sparc-security-reviewer\`
- Performance check if applicable

### 5. Documentation
- Update relevant documentation
- Add code comments for complex logic
- Update API documentation if applicable
- Use \`@sparc-documentation-writer\` for comprehensive docs

### 6. Pull Request
- Create descriptive pull request title and description
- Reference related issues
- Include testing notes and validation steps
- Update Memory Bank with completion status

## Pull Request Guidelines

### Title Format
\`\`\`
type(scope): brief description

Examples:
feat(auth): add multi-factor authentication
fix(api): resolve rate limiting issue
docs(readme): update installation instructions
refactor(components): optimize user interface components
\`\`\`

### Description Template
\`\`\`markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## SPARC Phase
- [ ] Specification update
- [ ] Architecture change
- [ ] Implementation
- [ ] Testing addition
- [ ] Documentation

## AI Modes Used
- [ ] @sparc-specification-writer
- [ ] @sparc-architect
- [ ] @sparc-code-implementer
- [ ] @sparc-tdd-engineer
- [ ] @sparc-security-reviewer
- [ ] Other: ____________

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] All tests passing

## Security Review
- [ ] Security implications considered
- [ ] No sensitive data exposed
- [ ] Input validation implemented
- [ ] Security review completed

## Memory Bank Updates
- [ ] activeContext.md updated
- [ ] progress.md updated
- [ ] decisionLog.md updated (if architectural changes)
- [ ] systemPatterns.md updated (if new patterns)

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added and passing
- [ ] Memory Bank files updated
\`\`\`

## Review Process

### Reviewer Guidelines
1. **Functionality**: Does the code work as intended?
2. **SPARC Compliance**: Does it follow methodology principles?
3. **Security**: Are security best practices followed?
4. **Testing**: Is test coverage adequate?
5. **Documentation**: Is documentation updated?
6. **Memory Bank**: Are context files properly updated?

### Approval Requirements
$(case "$TEAM_SIZE" in
    "solo")
        echo "- Self-review with AI mode validation
- All tests passing
- Documentation updated"
        ;;
    "small")
        echo "- At least one peer review
- All tests passing
- AI mode quality checks passed"
        ;;
    *)
        echo "- At least two peer reviews for significant changes
- Security review for security-related changes
- All tests passing
- Documentation review"
        ;;
esac)

## Issue Reporting

### Bug Reports
Include:
- **Environment**: OS, browser, Node.js version
- **Steps to Reproduce**: Detailed reproduction steps
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happens
- **AI Mode Context**: Which modes were active
- **Memory Bank State**: Relevant context from Memory Bank

### Feature Requests
Include:
- **Problem Statement**: What problem does this solve?
- **Proposed Solution**: How should it work?
- **SPARC Phase**: Which phase is this relevant to?
- **User Stories**: How will users benefit?
- **Security Considerations**: Any security implications?

## Community Guidelines

### Code of Conduct
- Be respectful and inclusive
- Provide constructive feedback
- Help others learn the SPARC methodology
- Share knowledge and best practices

### Communication
- Use clear, descriptive commit messages
- Comment your code thoughtfully
- Ask questions when uncertain
- Share your AI mode usage patterns

## Security Guidelines

### Security Requirements ($SECURITY_LEVEL Level)
$(case "$SECURITY_LEVEL" in
    "basic")
        echo "- Validate all user inputs
- Use HTTPS for all communications
- No hardcoded secrets or credentials
- Follow secure coding practices"
        ;;
    "medium")
        echo "- Implement comprehensive input validation
- Use role-based access control
- Maintain audit logs for security events
- Regular dependency security scanning"
        ;;
    "high"|"enterprise")
        echo "- Zero-trust security principles
- Advanced threat detection considerations
- Comprehensive security testing
- Formal security review process"
        ;;
esac)

### Sensitive Data
- Never commit secrets, API keys, or credentials
- Use environment variables for configuration
- Review \`.rooignore\` before committing
- Encrypt sensitive data at rest and in transit

## Development Resources

### Documentation
- **Project Docs**: \`docs/\` directory
- **Memory Bank**: \`memory-bank/\` for project context
- **API Reference**: Generated from code comments
- **Architecture**: \`architecture.md\` for system design

### Tools and Scripts
$(case "$SELECTED_TEMPLATE" in
    "web-app")
        echo "- **Development**: \`npm run dev\`
- **Testing**: \`npm test\`
- **Building**: \`npm run build\`
- **Linting**: \`npm run lint\`
- **Storybook**: \`npm run storybook\`"
        ;;
    "api-service")
        echo "- **Development**: \`npm run dev\`
- **Testing**: \`npm test\`
- **Database**: \`npm run db:migrate\`
- **API Docs**: \`npm run docs:generate\`"
        ;;
esac)

### AI Mode Reference
- **Configuration**: \`.roomodes\` file
- **Permissions**: File access patterns in mode definitions
- **Security**: \`.rooignore\` for access control
- **Context**: Memory Bank for project knowledge

## Recognition

Contributors will be:
- Listed in project contributors
- Recognized for significant contributions
- Invited to maintainer team for consistent contributions
- Featured in project documentation for major features

## Questions?

- **Check Memory Bank**: Review project context and decisions
- **Review Documentation**: Comprehensive guides in \`docs/\`
- **Ask AI Modes**: Use appropriate specialist modes for help
- **Create Issue**: For questions that need team discussion

---

Thank you for contributing to $PROJECT_NAME! Your contributions help make this project better for everyone.

*Template: $SELECTED_TEMPLATE | Team: $TEAM_SIZE | Security: $SECURITY_LEVEL*  
*Last Updated: $(date -u +"%Y-%m-%d")*
EOF
}

# Generate additional template-specific content generators
generate_component_guide() {
    cat << 'EOF'
# Component Development Guide

## Component Architecture

### Component Structure
` + "```" + `
components/
├── ui/                          # Basic UI components
│   ├── Button/
│   │   ├── Button.tsx
│   │   ├── Button.test.tsx
│   │   ├── Button.stories.tsx
│   │   └── index.ts
│   └── Input/
├── layout/                      # Layout components
└── feature/                     # Feature-specific components
` + "```" + `

### Component Template
` + "```" + `typescript
interface ButtonProps {
  variant: 'primary' | 'secondary';
  size: 'small' | 'medium' | 'large';
  onClick: () => void;
  children: React.ReactNode;
}

export const Button: React.FC<ButtonProps> = ({
  variant,
  size,
  onClick,
  children
}) => {
  return (
    <button
      className={`btn btn-${variant} btn-${size}`}
      onClick={onClick}
    >
      {children}
    </button>
  );
};
` + "```" + `

## Best Practices

1. **Single Responsibility**: Each component should have one clear purpose
2. **Prop Validation**: Use TypeScript interfaces for all props
3. **Accessibility**: Include ARIA labels and keyboard navigation
4. **Performance**: Use React.memo for expensive components
5. **Testing**: Write comprehensive unit and integration tests

EOF
}
# =============================================================================
# CLI ARGUMENT PARSING
# =============================================================================

show_help() {
    cat << EOF
Enhanced SPARC Project Initialization Script v${SCRIPT_VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -n, --name NAME              Project name (required)
    -i, --id ID                  Project identifier (auto-generated if not provided)
    -t, --template TEMPLATE      Project template (default: web-app)
    -s, --team-size SIZE         Team size configuration (default: small)
    -l, --security-level LEVEL   Security level (default: medium)
    -c, --cloud PROVIDER         Include cloud templates for provider
    -g, --git                    Initialize Git repository (default: true)
    -S, --security               Include enterprise security templates
    -T, --testing                Include testing framework setup (default: true)
    -M, --monitoring             Include monitoring and observability
    -d, --dry-run                Preview creation without making changes
    -v, --verbose                Enable verbose output
    -h, --help                   Show this help message
    --interactive                Run in interactive mode
    --config FILE                Load configuration from file
    --backup                     Backup existing directory if it exists

TEMPLATES:
    web-app         Modern web application with React/Next.js focus
    api-service     RESTful API service with database integration
    mobile-app      Cross-platform mobile application
    enterprise      Enterprise application with compliance requirements
    ml-project      Machine learning and data science project
    microservices   Microservices architecture with distributed systems
    fullstack       Full-stack application with frontend and backend
    minimal         Minimal SPARC setup with core features only

TEAM SIZES:
    solo           Individual developer (1 person)
    small          Small team (2-5 people)
    medium         Medium team (6-15 people)
    large          Large team (16+ people)
    enterprise     Enterprise organization (multiple teams)

SECURITY LEVELS:
    basic          Basic security controls and access patterns
    medium         Standard security with enhanced monitoring
    high           High security with strict access controls
    enterprise     Enterprise-grade security with compliance

CLOUD PROVIDERS:
    aws            Amazon Web Services
    gcp            Google Cloud Platform
    azure          Microsoft Azure
    digitalocean   DigitalOcean
    none           No cloud provider templates

EXAMPLES:
    # Interactive mode
    $0 --interactive

    # Quick start with defaults
    $0 --name "My Web App"

    # Full configuration
    $0 --name "E-commerce API" --template api-service --team-size medium \\
       --security-level high --cloud aws --security --monitoring

    # Dry run preview
    $0 --name "Test Project" --dry-run

    # Load from config file
    $0 --config project-config.yaml

For more information, visit: https://github.com/JackSmack1971/SPARC40

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                PROJECT_NAME="$2"
                shift 2
                ;;
            -i|--id)
                PROJECT_ID="$2"
                shift 2
                ;;
            -t|--template)
                SELECTED_TEMPLATE="$2"
                shift 2
                ;;
            -s|--team-size)
                TEAM_SIZE="$2"
                shift 2
                ;;
            -l|--security-level)
                SECURITY_LEVEL="$2"
                shift 2
                ;;
            -c|--cloud)
                INCLUDE_CLOUD="Y"
                CLOUD_PROVIDER="$2"
                shift 2
                ;;
            -g|--git)
                INIT_GIT="Y"
                shift
                ;;
            --no-git)
                INIT_GIT="N"
                shift
                ;;
            -S|--security)
                INCLUDE_SECURITY="Y"
                shift
                ;;
            -T|--testing)
                INCLUDE_TESTING="Y"
                shift
                ;;
            --no-testing)
                INCLUDE_TESTING="N"
                shift
                ;;
            -M|--monitoring)
                INCLUDE_MONITORING="Y"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --backup)
                BACKUP_EXISTING=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Load configuration from file
load_config_file() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Configuration file not found: $config_file"
        exit 1
    fi
    
    print_info "Loading configuration from: $config_file"
    
    # Source the configuration file
    if [[ "$config_file" == *.yaml || "$config_file" == *.yml ]]; then
        # Parse YAML configuration (simplified)
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*([^:]+):[[:space:]]*(.+)$ ]]; then
                local key="${BASH_REMATCH[1]// /}"
                local value="${BASH_REMATCH[2]}"
                
                case "$key" in
                    "projectName") PROJECT_NAME="$value" ;;
                    "projectId") PROJECT_ID="$value" ;;
                    "template") SELECTED_TEMPLATE="$value" ;;
                    "teamSize") TEAM_SIZE="$value" ;;
                    "securityLevel") SECURITY_LEVEL="$value" ;;
                    "cloudProvider") CLOUD_PROVIDER="$value"; INCLUDE_CLOUD="Y" ;;
                    "initGit") INIT_GIT="$value" ;;
                    "includeSecurity") INCLUDE_SECURITY="$value" ;;
                    "includeTesting") INCLUDE_TESTING="$value" ;;
                    "includeMonitoring") INCLUDE_MONITORING="$value" ;;
                esac
            fi
        done < "$config_file"
    else
        # Source shell configuration
        source "$config_file"
    fi
}

# =============================================================================
# MAIN EXECUTION FLOW
# =============================================================================

# Main function that orchestrates the entire process
main() {
    # Parse arguments first
    parse_arguments "$@"
    
    # Load config file if specified
    if [[ -n "$CONFIG_FILE" ]]; then
        load_config_file "$CONFIG_FILE"
    fi
    
    # Set up error handling and cleanup
    setup_error_handling
    
    # Interactive mode override
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        interactive_setup
    fi
    
    # Validate required parameters
    if [[ -z "$PROJECT_NAME" ]]; then
        if [[ "$INTERACTIVE_MODE" != "true" ]]; then
            print_error "Project name is required. Use --name or --interactive mode."
            echo "Use --help for usage information"
            exit 1
        fi
    fi
    
    # Generate project ID if not provided
    if [[ -z "$PROJECT_ID" ]]; then
        PROJECT_ID="$(generate_project_id "$PROJECT_NAME")"
        print_info "Generated project ID: $PROJECT_ID"
    fi
    
    # Validate environment and arguments
    print_step "🔍 Validating environment and configuration..."
    validate_environment || exit 1
    validate_security_policies || exit 1
    
    # Check if project directory already exists
    if [[ -d "$PROJECT_ID" ]]; then
        if [[ "$BACKUP_EXISTING" == "true" ]]; then
            backup_existing_project
        else
            print_error "Project directory '$PROJECT_ID' already exists"
            print_info "Use --backup to backup existing directory or choose a different name"
            exit 1
        fi
    fi
    
    # Show dry run preview if requested
    if [[ "$DRY_RUN" == "true" ]]; then
        show_dry_run_preview
    fi
    
    # Create the project
    print_step "🚀 Creating SPARC project: $PROJECT_NAME"
    create_sparc_project || {
        print_error "Project creation failed"
        cleanup_on_error
        exit 1
    }
    
    # Show success summary
    show_success_summary
    
    print_success "🎉 Project '$PROJECT_NAME' created successfully!"
    print_info "📁 Project location: $(pwd)/$PROJECT_ID"
    print_info "📖 Next steps: Review the README.md file to get started"
}

# Error handling setup
setup_error_handling() {
    # Set up exit trap for cleanup
    trap cleanup_on_error ERR EXIT
    
    # Enable cleanup on specific signals
    trap cleanup_on_signal INT TERM
}

# Cleanup function for errors
cleanup_on_error() {
    local exit_code=$?
    
    if [[ "$CLEANUP_ON_EXIT" == "true" && $exit_code -ne 0 ]]; then
        print_warning "🧹 Cleaning up due to error..."
        
        # Remove created directories
        for dir in "${CREATED_DIRS[@]}"; do
            if [[ -d "$dir" ]]; then
                print_debug "Removing directory: $dir"
                rm -rf "$dir"
            fi
        done
        
        # Remove created files
        for file in "${CREATED_FILES[@]}"; do
            if [[ -f "$file" ]]; then
                print_debug "Removing file: $file"
                rm -f "$file"
            fi
        done
        
        print_info "Cleanup completed"
    fi
    
    # Reset cleanup flag
    CLEANUP_ON_EXIT=true
}

# Cleanup function for signals
cleanup_on_signal() {
    print_warning "🛑 Operation interrupted by user"
    CLEANUP_ON_EXIT=true
    exit 1
}

# Backup existing project
backup_existing_project() {
    local backup_name="${PROJECT_ID}.backup.$(date +%Y%m%d_%H%M%S)"
    print_info "📦 Backing up existing project to: $backup_name"
    
    mv "$PROJECT_ID" "$backup_name" || {
        print_error "Failed to backup existing project"
        exit 1
    }
    
    print_success "Backup created: $backup_name"
}

list_and_choose_from_map() {
  local title="$1" mapName="$2"
  local keys; IFS=$'\n' read -r -d '' -a keys < <(eval "printf '%s\n' \"\${!$mapName[@]}\" | sort" && printf '\0')
  print_info "$title"
  local i=1 key
  for key in "${keys[@]}"; do
    eval "echo \"   $i. \$key - \${$mapName[\"\$key\"]}\""
    ((i++))
  done
  echo
  local choice
  while true; do
    read -p "Choose (number or key): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice>=1 && choice<=${#keys[@]} )); then
      echo "${keys[choice-1]}"; return 0
    elif eval "[[ -n \"\${$mapName[\"$choice\"]+x}\" ]]" ; then
      echo "$choice"; return 0
    fi
    print_warning "Invalid selection."
  done
}
