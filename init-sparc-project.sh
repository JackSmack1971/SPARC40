#!/usr/bin/env bash
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
CLEANUP_ON_EXIT=false

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
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local task=$3
    local percent=$((current * 100 / total))
    local filled=$((percent / 2))
    local empty=$((50 - filled))
    
    printf "\r🚀 [%s%s] %d%% - %s" \
        "$(printf "▓%.0s" $(seq 1 $filled))" \
        "$(printf "░%.0s" $(seq 1 $empty))" \
        "$percent" "$task"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Spinner for long operations
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
    local file_path="$1"
    local content="$2"
    local description="${3:-""}"
    
    print_debug "Creating file: $file_path"
    
    # Check if parent directory is writable
    local parent_dir=$(dirname "$file_path")
    if [[ ! -w "$parent_dir" ]]; then
        print_error "No write permission for directory: $parent_dir"
        return 1
    fi
    
    # Create file with content
    if echo "$content" > "$file_path" 2>/dev/null; then
        CREATED_FILES+=("$file_path")
        if [[ -n "$description" ]]; then
            print_debug "✅ $description: $file_path"
        fi
        return 0
    else
        print_error "Failed to create file: $file_path"
        return 1
    fi
}

# =============================================================================
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
            echo -e "  ${RED}•${NC} $error"
        done
        return 1
    fi
    
    print_success "Environment validation passed"
    return 0
}

# Validate custom_modes.yaml structure
validate_custom_modes_yaml() {
    local yaml_file="$1"
    
    if [[ ! -f "$yaml_file" ]]; then
        print_warning "custom_modes.yaml not found - will use comprehensive built-in configuration"
        return 0
    fi
    
    print_debug "Validating custom_modes.yaml structure..."
    
    # Basic YAML syntax validation using Python if available
    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
            print_error "Invalid YAML syntax in $yaml_file"
            return 1
        fi
    fi
    
    # Check file size (reasonable limits)
    local file_size=$(wc -c < "$yaml_file")
    if [[ $file_size -gt 1048576 ]]; then  # 1MB limit
        print_warning "custom_modes.yaml is very large (${file_size} bytes)"
    fi
    
    print_success "custom_modes.yaml validation passed"
    return 0
}

# Security policy validation
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
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                    SPARC PROJECT SETUP v2.0                 ║
║              Interactive Project Configuration               ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
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
    cat << EOF
{
  "description": "Enhanced MCP configuration for $PROJECT_NAME",
  "version": "$TEMPLATE_VERSION",
  "template": "$SELECTED_TEMPLATE",
  "securityLevel": "$SECURITY_LEVEL",
  "mcpServers": {
    "research-tools": {
      "name": "Research & Analysis Tools",
      "enabled": true,
      "allowedModes": [
        "sparc-domain-intelligence",
        "data-researcher",
        "rapid-fact-checker"
      ],
      "securityLevel": "$SECURITY_LEVEL"
    },
    "development-tools": {
      "name": "Development & Code Analysis",
      "enabled": true,
      "allowedModes": [
        "sparc-code-implementer",
        "sparc-architect",
        "sparc-tdd-engineer",
        "sparc-performance-engineer"
      ],
      "securityLevel": "$SECURITY_LEVEL"
    },
    "security-tools": {
      "name": "Security Analysis & Review",
      "enabled": $(if [[ "$SECURITY_LEVEL" =~ ^(high|enterprise)$ ]]; then echo "true"; else echo "false"; fi),
      "allowedModes": [
        "sparc-security-reviewer",
        "sparc-security-architect",
        "adversarial-testing-agent"
      ],
      "securityLevel": "$SECURITY_LEVEL"
    }$(if [[ "$INCLUDE_CLOUD" =~ ^[Yy] ]]; then cat << CLOUD_CONFIG
,
    "cloud-tools": {
      "name": "$CLOUD_PROVIDER Cloud Integration",
      "enabled": true,
      "allowedModes": [
        "sparc-devops-engineer",
        "sparc-platform-engineer"
      ],
      "cloudProvider": "$CLOUD_PROVIDER",
      "securityLevel": "$SECURITY_LEVEL"
    }
CLOUD_CONFIG
fi)$(if [[ "$INCLUDE_MONITORING" =~ ^[Yy] ]]; then cat << MONITORING_CONFIG
,
    "monitoring-tools": {
      "name": "Monitoring & Observability",
      "enabled": true,
      "allowedModes": [
        "sparc-post-deployment-monitor",
        "sparc-sre-engineer"
      ],
      "securityLevel": "$SECURITY_LEVEL"
    }
MONITORING_CONFIG
fi)
  },
  "securityPolicies": {
    "dataRetention": {
      "enabled": true,
      "maxRetentionDays": $(case "$SECURITY_LEVEL" in "enterprise") echo "90" ;; "high") echo "60" ;; *) echo "30" ;; esac)
    },
    "accessLogging": {
      "enabled": true,
      "logLevel": "$(case "$SECURITY_LEVEL" in "enterprise"|"high") echo "DEBUG" ;; *) echo "INFO" ;; esac)"
    },
    "encryptionRequired": $(if [[ "$SECURITY_LEVEL" =~ ^(high|enterprise)$ ]]; then echo "true"; else echo "false"; fi)
  },
  "teamConfiguration": {
    "teamSize": "$TEAM_SIZE",
    "maxConcurrentSessions": $(case "$TEAM_SIZE" in "solo") echo "1" ;; "small") echo "3" ;; "medium") echo "8" ;; "large") echo "16" ;; "enterprise") echo "50" ;; esac),
    "collaborationMode": "$(case "$TEAM_SIZE" in "solo") echo "individual" ;; "small") echo "informal" ;; "medium") echo "structured" ;; "large"|"enterprise") echo "formal" ;; esac)"
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
- Daily stan
