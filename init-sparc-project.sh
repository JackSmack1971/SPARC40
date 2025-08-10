#!/bin/bash

# SPARC Project Initialization Script
# Creates a complete SPARC methodology project structure with all necessary files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME=""
PROJECT_ID=""
TEMPLATE_VERSION="1.0.0"

# Function to print colored output
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
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
SPARC Project Initialization Script

Usage: $0 [OPTIONS]

Options:
    -n, --name NAME         Project name (required)
    -i, --id ID            Project ID (auto-generated if not provided)
    -h, --help             Show this help message

Examples:
    $0 --name "E-commerce Platform"
    $0 --name "User Management API" --id "user-mgmt-api"

This script creates a complete SPARC methodology project structure including:
- Memory Bank with all core files
- Project directory structure
- Configuration files (.roomodes, .rooignore, .roo/)
- Template documents (specification.md, architecture.md, etc.)
- Development environment setup

EOF
}

# Function to generate project ID from name
generate_project_id() {
    local name="$1"
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Function to create directory structure
create_directory_structure() {
    print_info "Creating directory structure..."
    
    # Root level directories
    mkdir -p {docs,reports,memory-bank,infrastructure,scripts,tests}
    
    # .roo configuration directory
    mkdir -p .roo/{rules,commands}
    
    # Memory Bank structure
    mkdir -p memory-bank
    
    # Project-specific directories
    mkdir -p "project/${PROJECT_ID}"/{control/{conclave,planning,orchestration},sections,synthesis,evidence/{research,security,domain,technology,requirements,operations,adversarial},adversarial,risk-assessment,business-intelligence,security-intelligence,architecture-intelligence,operations-intelligence,requirements-intelligence,validation,quality-assurance,debug,logs,integration,monitoring,observability,alerts,dashboards,incidents,optimization,performance,analysis}
    
    # Documentation structure
    mkdir -p docs/{architecture,security,requirements,ux,personas,research,specification,pseudocode,algorithms,qa,quality,testing,ui,design-system,api,api-docs,openapi,ml,models,ml-ops,mobile,platform,runbooks,sre,operations,policies,audits,project,pm,planning,reports,businessIntelligence,technicalArchitecture,securityFramework,operationalProcedures,qualityAssurance}
    
    # Development structure
    mkdir -p {apps,packages,services,libs,src,tests,scripts,ops-scripts}
    
    # Infrastructure and operations
    mkdir -p {infrastructure,infra,deploy,environments,platform,k8s,charts,ci-cd,monitoring,observability,logging,alerts,operations,runbooks}
    
    # Reporting and analysis
    mkdir -p reports/{adversarial,risk,optimization,monitoring,incidents,orchestration,qa,quality,testing,security,audits,performance,integration,delivery}
    
    # Design and UI
    mkdir -p {design-system,tokens,ui,components,.storybook,stories}
    
    # Data and ML
    mkdir -p {ml,models,pipelines,experiments,data,warehouse,analytics,db,database,schemas}
    
    # Security and compliance
    mkdir -p {security,development,testing,integration,compliance}
    
    print_success "Directory structure created"
}

# Function to create Memory Bank files
create_memory_bank() {
    print_info "Creating Memory Bank files..."
    
    # activeContext.md
    cat > memory-bank/activeContext.md << 'EOF'
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
- **Active Mode**: Project Setup
- **Last Updated**: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
- **Current Focus**: Initial project structure and template setup
- **Completion Status**: 10% (Project structure created)

### **Immediate Next Actions**
1. Begin specification phase with SPARC Specification Writer
2. Conduct stakeholder interviews and requirements gathering
3. Define project scope and success criteria

### **Handoff State**
- **From Mode**: Project Initialization Script
- **To Mode**: SPARC Specification Writer
- **Context**: Project structure created, ready for requirements gathering
- **Blockers**: None - ready to proceed with specification phase

## Current Working Files

### **Primary Deliverables**
- `specification.md` - Not started
- `architecture.md` - Not started
- `pseudocode.md` - Not started

### **Active Research Areas**
- Requirements gathering approach
- Stakeholder identification
- Success criteria definition

## Next Period Planning

### **Upcoming Milestones (Next 4 Weeks)**
| Week | Key Milestones | Dependencies | Risk Level |
|------|----------------|-------------|------------|
| Week 1 | Complete specification | Stakeholder availability | M |
| Week 2 | Architecture design | Technology decisions | M |
| Week 3 | Begin implementation | Team resource allocation | L |
| Week 4 | Testing framework | Development environment | L |

---

*Generated by SPARC Project Initialization Script v${TEMPLATE_VERSION}*
*Project: ${PROJECT_NAME} (${PROJECT_ID})*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    # decisionLog.md
    cat > memory-bank/decisionLog.md << 'EOF'
# Decision Log

> **Purpose**: Record all architectural and strategic decisions with full rationale
> **Updated by**: Architect, Security Architect, Orchestrator, Conclave, and other decision-making modes
> **Used by**: All modes to understand the reasoning behind current choices and maintain consistency

## Project Initialization Decisions

### [INIT-001] - SPARC Methodology Adoption

**Date**: $(date -u +"%Y-%m-%d")
**Status**: Accepted
**Deciders**: Project Stakeholders
**Context**: Need to select development methodology for new project

### Problem Statement
How to structure development process to ensure quality, security, and maintainability while enabling autonomous development capabilities.

### Decision
Adopt SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) methodology with custom modes for specialized roles.

### Rationale
- Systematic approach ensures comprehensive requirements and architecture
- Custom modes provide specialized expertise for different aspects
- Autonomous development capabilities reduce manual overhead
- Built-in quality gates and security considerations
- Comprehensive documentation and decision tracking

### Alternatives Considered
1. **Traditional Agile/Scrum**: Good for iterative development but lacks systematic architecture phase
2. **Waterfall**: Comprehensive but inflexible and slower to deliver value
3. **Custom Process**: Would require significant time to develop and refine

### Consequences
- **Positive**: Higher quality output, better documentation, systematic approach
- **Negative**: Initial learning curve, more upfront planning required
- **Neutral**: Different workflow from traditional development approaches

### Implementation Notes
- Set up complete SPARC project structure
- Configure custom modes for specialized roles
- Train team on SPARC methodology and tool usage
- Establish quality gates and review processes

### Success Metrics
- Faster development velocity after initial ramp-up
- Higher code quality and fewer post-deployment issues
- Better architectural consistency and documentation
- Improved team satisfaction with development process

### Review Date
Quarterly review scheduled for $(date -u -d "+3 months" +"%Y-%m-%d")

---

### [INIT-002] - Project Structure and Tooling

**Date**: $(date -u +"%Y-%m-%d")
**Status**: Accepted
**Deciders**: Technical Lead, DevOps Engineer
**Context**: Need to establish project structure and development tooling

### Problem Statement
How to organize project files and configure development tools to support SPARC methodology and team collaboration.

### Decision
Implement comprehensive project structure with Memory Bank, organized documentation, and standardized tooling configuration.

### Rationale
- Clear organization improves team productivity and onboarding
- Memory Bank provides persistent knowledge management
- Standardized tooling reduces configuration overhead
- Comprehensive templates ensure consistency

### Implementation Notes
- Created complete directory structure
- Established Memory Bank with core knowledge management files
- Configured development tools and CI/CD templates
- Set up security and access controls

---

*Project: ${PROJECT_NAME} (${PROJECT_ID})*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    # productContext.md
    cat > memory-bank/productContext.md << 'EOF'
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
- **Project Name**: ${PROJECT_NAME}
- **Project ID**: ${PROJECT_ID}
- **Initialization Date**: $(date -u +"%Y-%m-%d")
- **SPARC Version**: ${TEMPLATE_VERSION}

### **Current Status**
- **Phase**: Project Initialization
- **Next Phase**: Specification
- **Estimated Timeline**: [To be defined during planning]

## Stakeholder Placeholder

### **Primary Stakeholders**
[To be identified during specification phase]

### **End Users**
[To be defined through user research and persona development]

## Domain Knowledge Placeholder

### **Industry Context**
[To be researched and documented by SPARC Domain Intelligence]

### **Business Rules**
[To be defined during requirements analysis]

### **Technical Constraints**
[To be identified during architecture planning]

## Next Steps

1. **Stakeholder Identification**: Identify all key stakeholders and their roles
2. **Market Research**: Conduct comprehensive market and competitive analysis
3. **User Research**: Define user personas and journey mapping
4. **Business Rules**: Document core business logic and constraints
5. **Domain Modeling**: Create comprehensive domain model and glossary

---

*This file will be comprehensively updated during the Specification phase*
*Project: ${PROJECT_NAME} (${PROJECT_ID})*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    # progress.md
    cat > memory-bank/progress.md << 'EOF'
# Progress Tracking

> **Purpose**: Comprehensive status tracking and roadmap for SPARC methodology implementation
> **Updated by**: All modes as they complete work and reach milestones
> **Used by**: Project Manager, Orchestrator, and all modes to understand overall progress

## Project Overview

### **Project Information**
- **Project Name**: ${PROJECT_NAME}
- **Project ID**: ${PROJECT_ID}
- **Start Date**: $(date -u +"%Y-%m-%d")
- **Target Completion**: [To be defined during planning]
- **Current Phase**: Project Initialization
- **Overall Progress**: 5% Complete

### **Key Milestones**
| Milestone | Target Date | Status | Completion Date | Notes |
|-----------|-------------|--------|-----------------|-------|
| Project Structure Setup | $(date -u +"%Y-%m-%d") | Complete | $(date -u +"%Y-%m-%d") | Initial structure created |
| Specification Complete | [TBD] | Not Started | | Waiting for stakeholder input |
| Architecture Approved | [TBD] | Not Started | | Depends on specification |
| Implementation Started | [TBD] | Not Started | | Depends on architecture |
| Testing Complete | [TBD] | Not Started | | Depends on implementation |
| Deployment Ready | [TBD] | Not Started | | Depends on testing |

## SPARC Phase Progress

### **Phase 0: Project Initialization** 
**Status**: Complete  
**Progress**: 100% Complete  
**Completion Date**: $(date -u +"%Y-%m-%d")

#### **Deliverables Status**
- [x] Project directory structure created
- [x] Memory Bank initialized
- [x] Configuration files created (.roomodes, .rooignore, .roo/)
- [x] Template documents created
- [x] Development environment templates prepared

### **Phase 1: Specification** 
**Status**: Not Started  
**Progress**: 0% Complete  
**Target Completion**: [TBD]

#### **Deliverables Status**
- [ ] `specification.md` - Requirements and scope definition
- [ ] `acceptance-criteria.md` - Testable acceptance criteria
- [ ] `user-scenarios.md` - User journey documentation
- [ ] `personas.md` - User persona definitions
- [ ] Business requirements validated
- [ ] Stakeholder sign-off obtained

#### **Next Actions**
1. **Engage SPARC Specification Writer** - Begin requirements gathering
2. **Schedule stakeholder interviews** - Identify key stakeholders and their needs
3. **Conduct market research** - Understand competitive landscape

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

## Initialization Checklist

### **Project Setup**
- [x] Create project directory structure
- [x] Initialize Memory Bank files
- [x] Create .roomodes configuration
- [x] Create .rooignore security controls
- [x] Set up .roo/ configuration directory
- [x] Create template documents
- [x] Set up development environment templates

### **Next Steps**
- [ ] Define project timeline and milestones
- [ ] Identify and engage stakeholders
- [ ] Begin specification phase
- [ ] Set up development team access
- [ ] Configure CI/CD pipeline templates
- [ ] Establish communication channels

## Resources and Setup

### **Development Environment**
- **Project Structure**: Complete
- **Documentation Templates**: Ready
- **Configuration Files**: Created
- **Security Controls**: Implemented

### **Team Readiness**
- **SPARC Methodology**: Templates and guides ready
- **Custom Modes**: Configuration complete
- **Quality Gates**: Framework established
- **Knowledge Management**: Memory Bank initialized

---

*Project initialized using SPARC Methodology v${TEMPLATE_VERSION}*
*Next milestone: Begin Specification Phase*
*Project: ${PROJECT_NAME} (${PROJECT_ID})*
*Status updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    # systemPatterns.md
    cat > memory-bank/systemPatterns.md << 'EOF'
# System Patterns

> **Purpose**: Technical patterns, standards, and reusable solutions for consistent implementation
> **Updated by**: All technical modes (Architect, Code Implementer, TDD Engineer, Security Architect, etc.)
> **Used by**: All modes to maintain consistency and avoid reinventing solutions

## Project Initialization Patterns

### **SPARC Project Structure Pattern**
The standard SPARC project follows this organization:

```
project-root/
├── .roomodes                     # Custom mode definitions
├── .rooignore                    # Security and access controls
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
├── project/{project-id}/         # Project-specific work areas
├── docs/                         # Documentation structure
├── reports/                      # Analysis and reporting
├── [development directories]     # Source code organization
└── [infrastructure directories]  # Operations and deployment
```

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

## Development Standards (Placeholder)

### **File Organization Standards**
- Maximum 500 lines per file
- Single responsibility per module
- Clear naming conventions
- Consistent directory structure

### **Code Quality Standards**
- Comprehensive error handling
- Input validation on all boundaries
- Consistent logging and monitoring
- Security-first implementation

### **Testing Standards**
- Unit tests for all business logic
- Integration tests for API endpoints
- End-to-end tests for user journeys
- Performance tests for critical paths

## Architecture Standards (Placeholder)

### **Modular Design Pattern**
- Components under 500 lines
- Clear interfaces and contracts
- Loose coupling between modules
- High cohesion within modules

### **Security Patterns**
- Zero-trust architecture
- Defense in depth
- Principle of least privilege
- Comprehensive audit logging

### **Performance Patterns**
- Caching strategies
- Database optimization
- Async processing
- Resource management

## Integration Patterns (Placeholder)

### **API Design Patterns**
- RESTful principles
- Consistent error handling
- Comprehensive validation
- Clear documentation

### **Data Management Patterns**
- Repository pattern for data access
- Transaction management
- Data validation and sanitization
- Backup and recovery procedures

## Deployment Patterns (Placeholder)

### **Infrastructure Patterns**
- Infrastructure as code
- Container-based deployment
- Monitoring and alerting
- Automated scaling

### **CI/CD Patterns**
- Automated testing pipeline
- Security scanning integration
- Progressive deployment
- Rollback procedures

---

*This file will be expanded as technical patterns are established during development*
*Current patterns reflect project initialization and SPARC methodology setup*
*Project: ${PROJECT_NAME} (${PROJECT_ID})*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    print_success "Memory Bank files created"
}

# Function to create configuration files
create_configuration_files() {
    print_info "Creating configuration files..."
    
    # Copy the custom modes from the provided YAML
    if [[ -f "${SCRIPT_DIR}/custom_modes.yaml" ]]; then
        cp "${SCRIPT_DIR}/custom_modes.yaml" .roomodes
        print_success "Custom modes configuration copied"
    else
        print_warning "custom_modes.yaml not found, creating minimal .roomodes"
        cat > .roomodes << 'EOF'
customModes:
  - slug: project-manager
    name: "📋 Project Manager"
    description: "Coordinates SPARC methodology implementations"
    roleDefinition: >-
      You coordinate SPARC methodology across complex projects: timeline planning, 
      risk management, stakeholder communication, and quality gate enforcement.
    whenToUse: "Use for project coordination, timeline management, and delivery tracking"
    groups:
      - read
      - browser
      - edit:
          fileRegex: '^(docs|reports|project|memory-bank)/.+\.(md|json|yaml)$'
          description: 'Project management documentation'
    source: project
EOF
    fi
    
    # Create .rooignore with security controls
    cat > .rooignore << 'EOF'
# .rooignore - Security and Access Control for SPARC Project

# Security-critical files
.env*
.secret*
secrets/
credentials/
keys/
*.key
*.pem
*.p12
*.crt
config/secrets/

# System and build files
node_modules/
.git/
dist/
build/
logs/
*.log
coverage/
.nyc_output/

# Development tools and caches
.vscode/settings.json
.idea/
*.swp
*.swo
.DS_Store
Thumbs.db
.npm/
.yarn/
vendor/

# Generated and temporary files
*.tmp
*.temp
public/assets/
static/built/
*.bundle.js
*.bundle.css

# Database files
*.sqlite
*.sqlite3
*.db

# Allow specific config templates
!config/template.yml
!.env.example
!examples/
!samples/
!templates/
EOF
    
    # Create basic .roo/mcp.json
    mkdir -p .roo
    cat > .roo/mcp.json << 'EOF'
{
  "description": "MCP configuration for SPARC methodology project",
  "version": "1.0.0",
  "mcpServers": {
    "research-tools": {
      "name": "Research & Analysis Tools",
      "enabled": true,
      "allowedModes": [
        "enhanced-data-researcher",
        "sparc-domain-intelligence"
      ]
    }
  },
  "securityPolicies": {
    "dataRetention": {
      "enabled": true,
      "maxRetentionDays": 30
    },
    "accessLogging": {
      "enabled": true,
      "logLevel": "INFO"
    }
  }
}
EOF

    # Create basic .roo/rules/project.md
    mkdir -p .roo/rules
    cat > .roo/rules/project.md << 'EOF'
# Project Rules and Guidelines

## SPARC Methodology Rules

1. **Phase Sequence**: Follow SPARC phases in order (Specification → Pseudocode → Architecture → Refinement → Completion)
2. **Quality Gates**: Complete each phase before proceeding to the next
3. **Documentation**: Maintain comprehensive documentation in Memory Bank
4. **Decision Logging**: Record all architectural decisions with rationale
5. **Modular Design**: Keep all components under 500 lines

## Code Quality Rules

1. **Security First**: No hardcoded secrets, comprehensive input validation
2. **Error Handling**: Consistent error handling patterns across all code
3. **Testing**: Comprehensive test coverage for all business logic
4. **Performance**: Sub-200ms response times for user-facing operations
5. **Documentation**: Clear inline documentation and API documentation

## Collaboration Rules

1. **Memory Bank Updates**: Update relevant Memory Bank files when completing work
2. **Context Handoffs**: Clear handoff context when switching between modes
3. **Progress Tracking**: Regular updates to progress.md for transparency
4. **Decision Communication**: All major decisions communicated via decisionLog.md
EOF

    print_success "Configuration files created"
}

# Function to create template documents
create_template_documents() {
    print_info "Creating template documents..."
    
    # Create specification.md template
    cat > specification.md << EOF
# ${PROJECT_NAME} - Project Specification

> **SPARC Phase**: Specification  
> **Status**: Draft  
> **Last Updated**: $(date -u +"%Y-%m-%d")  
> **Version**: 1.0  
> **Project ID**: ${PROJECT_ID}

## Executive Summary

### **Project Vision**
[To be defined - one paragraph describing the overall vision and purpose of this project]

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

## Next Steps

1. **Stakeholder Engagement**: Identify and interview key stakeholders
2. **Requirements Gathering**: Conduct comprehensive requirements analysis
3. **Market Research**: Analyze competitive landscape and user needs
4. **Success Metrics Definition**: Define measurable success criteria
5. **Risk Assessment**: Identify and plan for potential risks

---

*This template will be completed during the Specification phase using the SPARC Specification Writer mode.*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    # Create architecture.md template
    cat > architecture.md << EOF
# ${PROJECT_NAME} - System Architecture

> **SPARC Phase**: Architecture  
> **Status**: Not Started  
> **Last Updated**: $(date -u +"%Y-%m-%d")  
> **Version**: 1.0  
> **Project ID**: ${PROJECT_ID}  
> **Specification Reference**: [Link to specification.md]

## Architecture Overview

### **System Context**
[To be defined during architecture phase]

### **Architecture Principles**
1. **Modularity**: All components ≤500 lines, clear interfaces, single responsibility
2. **Security by Design**: Zero-trust architecture, defense in depth, principle of least privilege
3. **Scalability**: Horizontal scaling capabilities, stateless design where possible
4. **Maintainability**: Clear documentation, consistent patterns, testable components
5. **Performance**: Sub-200ms response times, efficient resource utilization

## Next Steps

1. **Technology Stack Selection**: Choose appropriate technologies based on requirements
2. **System Design**: Create high-level system architecture
3. **Security Architecture**: Design comprehensive security model
4. **Performance Planning**: Define performance targets and optimization strategy
5. **Integration Planning**: Plan external system integrations

---

*This template will be completed during the Architecture phase using SPARC Architect modes.*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    # Create pseudocode.md template
    cat > pseudocode.md << EOF
# ${PROJECT_NAME} - Pseudocode Design

> **SPARC Phase**: Pseudocode  
> **Status**: Not Started  
> **Last Updated**: $(date -u +"%Y-%m-%d")  
> **Version**: 1.0  
> **Project ID**: ${PROJECT_ID}  
> **Architecture Reference**: [Link to architecture.md]  
> **Specification Reference**: [Link to specification.md]

## Overview

### **Purpose**
This document will translate the system architecture into implementable algorithms and data structures, providing clear guidance for the code implementation phase.

### **Design Principles**
- **Modularity**: Each function ≤50 lines, single responsibility
- **Clarity**: Self-documenting logic, clear variable names
- **Testability**: Functions designed for easy unit testing
- **Performance**: O(n) complexity or better where possible
- **Error Handling**: Comprehensive error cases covered

## Next Steps

1. **Data Structure Definition**: Define core entities and their relationships
2. **Algorithm Design**: Create algorithms for core business operations
3. **Error Handling Design**: Plan comprehensive error handling strategies
4. **Performance Analysis**: Analyze algorithmic complexity and optimization opportunities
5. **Integration Planning**: Define integration points and data flows

---

*This template will be completed during the Pseudocode phase using the SPARC Pseudocode Designer mode.*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    print_success "Template documents created"
}

# Function to create README and getting started guide
create_project_documentation() {
    print_info "Creating project documentation..."
    
    cat > README.md << EOF
# ${PROJECT_NAME}

**Project ID**: \`${PROJECT_ID}\`  
**SPARC Version**: ${TEMPLATE_VERSION}  
**Created**: $(date -u +"%Y-%m-%d")

## Overview

This project follows the SPARC (Specification, Pseudocode, Architecture, Refinement, Completion) methodology for systematic development with built-in quality gates and comprehensive documentation.

## Project Structure

### **Memory Bank** (Core Knowledge Management)
- \`memory-bank/activeContext.md\` - Current working context and handoffs
- \`memory-bank/decisionLog.md\` - Architectural decisions with rationale
- \`memory-bank/productContext.md\` - Business and domain knowledge
- \`memory-bank/progress.md\` - Status tracking and milestones
- \`memory-bank/systemPatterns.md\` - Technical patterns and standards

### **SPARC Phase Documents**
- \`specification.md\` - Requirements and scope (Phase 1)
- \`pseudocode.md\` - Algorithms and logic design (Phase 2)
- \`architecture.md\` - System architecture (Phase 3)
- Implementation files (Phase 4)
- Integration and delivery (Phase 5)

### **Configuration**
- \`.roomodes\` - Custom mode definitions for specialized AI agents
- \`.rooignore\` - Security and access control
- \`.roo/\` - Additional configuration and rules

## Getting Started

### **Current Status**
- **Phase**: Project Initialization (Complete)
- **Next Phase**: Specification
- **Overall Progress**: 5%

### **Next Steps**
1. **Begin Specification Phase**
   - Engage SPARC Specification Writer mode
   - Conduct stakeholder interviews
   - Define requirements and scope

2. **Set Up Development Environment**
   - Configure development tools
   - Set up CI/CD pipeline
   - Establish team access

3. **Team Onboarding**
   - Review SPARC methodology
   - Understand custom modes
   - Set up communication channels

## SPARC Methodology

### **Phase Overview**
1. **Specification**: Requirements, scope, and acceptance criteria
2. **Pseudocode**: Algorithms and logic design
3. **Architecture**: System design and technology selection
4. **Refinement**: Implementation and testing
5. **Completion**: Integration and delivery

### **Quality Gates**
Each phase includes quality gates to ensure completeness before proceeding:
- Requirements validated and approved
- Architecture reviewed and approved
- Security assessment completed
- Performance validated
- Integration tested

## Custom Modes

This project uses specialized AI modes for different aspects of development:
- **SPARC Specification Writer**: Requirements and scope definition
- **SPARC Architect**: System architecture and design
- **SPARC Security Architect**: Security design and review
- **SPARC Code Implementer**: Code implementation following patterns
- **SPARC TDD Engineer**: Test-driven development
- And many more specialized modes...

See \`.roomodes\` for complete mode definitions and capabilities.

## Contributing

### **Development Guidelines**
- Follow SPARC methodology phases
- Update Memory Bank files when completing work
- Log all architectural decisions with rationale
- Maintain modular design (≤500 lines per component)
- Ensure comprehensive test coverage

### **Documentation Standards**
- Keep documentation current and comprehensive
- Use clear, specific acceptance criteria
- Document all architectural decisions
- Maintain traceability from requirements to implementation

## Support and Resources

### **Project Resources**
- **Memory Bank**: Central knowledge repository
- **Decision Log**: Architectural rationale and alternatives
- **Progress Tracking**: Current status and milestones
- **System Patterns**: Reusable technical solutions

### **SPARC Resources**
- [SPARC Methodology Guide](docs/sparc-methodology.md)
- [Custom Modes Reference](.roomodes)
- [Development Standards](memory-bank/systemPatterns.md)
- [Security Guidelines](docs/security/)

---

**Project initialized with SPARC methodology v${TEMPLATE_VERSION}**  
**Ready for Specification phase**  
*Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    # Create getting started guide
    cat > docs/getting-started.md << EOF
# Getting Started with ${PROJECT_NAME}

## Quick Start

### **1. Project Status**
- **Current Phase**: Project Initialization (Complete)
- **Next Phase**: Specification
- **Ready for**: Requirements gathering and stakeholder engagement

### **2. Immediate Actions**
1. Review this getting started guide
2. Familiarize yourself with SPARC methodology
3. Begin specification phase using SPARC Specification Writer mode
4. Set up development environment

### **3. Key Files to Review**
- \`README.md\` - Project overview and structure
- \`memory-bank/activeContext.md\` - Current working context
- \`memory-bank/progress.md\` - Status and milestones
- \`.roomodes\` - Custom mode definitions

## SPARC Workflow

### **Starting the Specification Phase**
1. **Activate Specification Mode**: Use SPARC Specification Writer
2. **Stakeholder Engagement**: Identify and interview key stakeholders
3. **Requirements Analysis**: Define functional and non-functional requirements
4. **Acceptance Criteria**: Create testable acceptance criteria
5. **Scope Definition**: Clearly define project scope and boundaries

### **Memory Bank Usage**
- **Before Starting Work**: Check \`memory-bank/activeContext.md\` for current state
- **During Work**: Update relevant Memory Bank files with progress
- **After Completing Work**: Update handoff context for next mode
- **Making Decisions**: Log all decisions in \`memory-bank/decisionLog.md\`

### **Mode Coordination**
Each specialized mode has specific responsibilities:
- Read current context from Memory Bank
- Complete assigned work following SPARC principles
- Update progress and decision logs
- Hand off clear context to next mode

## Development Environment Setup

### **Required Tools**
- Roo Code (VSCode extension)
- Node.js (for MCP servers and tooling)
- Git (for version control)
- Development environment for chosen technology stack

### **Configuration**
1. **Custom Modes**: Already configured in \`.roomodes\`
2. **Security Controls**: Already set up in \`.rooignore\`
3. **MCP Configuration**: Basic setup in \`.roo/mcp.json\`
4. **Development Rules**: Established in \`.roo/rules/\`

### **Team Setup**
1. **Access Control**: Review and adjust file access patterns in \`.roomodes\`
2. **Environment Variables**: Set up required environment variables for MCP servers
3. **Communication**: Establish team communication channels
4. **Training**: Ensure team understands SPARC methodology

## Quality Assurance

### **Quality Gates**
- **Specification Gate**: Requirements complete and stakeholder approved
- **Architecture Gate**: Architecture reviewed and security assessed
- **Implementation Gate**: Code complete with tests passing
- **Release Gate**: Integration tested and deployment ready

### **Standards**
- **Modular Design**: Maximum 500 lines per file
- **Security First**: No hardcoded secrets, comprehensive validation
- **Testing**: Unit, integration, and end-to-end test coverage
- **Documentation**: Comprehensive and current documentation

## Support and Troubleshooting

### **Common Issues**
- **Mode Access**: Check \`.roomodes\` for proper file regex patterns
- **MCP Servers**: Verify environment variables in \`.roo/mcp.json\`
- **File Access**: Review \`.rooignore\` for access restrictions
- **Context Loss**: Check \`memory-bank/activeContext.md\` for handoff state

### **Getting Help**
- Review Memory Bank files for project context
- Check decision log for architectural rationale
- Consult system patterns for technical guidance
- Review progress tracking for current status

## Next Steps

### **Immediate (This Week)**
1. Begin specification phase
2. Identify stakeholders
3. Schedule requirements gathering sessions
4. Set up development environment

### **Short Term (Next Month)**
1. Complete specification phase
2. Begin architecture design
3. Set up CI/CD pipeline
4. Establish team workflows

### **Medium Term (Next Quarter)**
1. Complete architecture and security design
2. Begin implementation phase
3. Establish monitoring and alerting
4. Plan deployment strategy

---

*This guide will be updated as the project progresses through SPARC phases.*
*For questions or issues, refer to Memory Bank files or project documentation.*
*Created: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

    print_success "Project documentation created"
}

# Function to validate project setup
validate_setup() {
    print_info "Validating project setup..."
    
    # Check required files
    local required_files=(
        ".roomodes"
        ".rooignore"
        ".roo/mcp.json"
        "memory-bank/activeContext.md"
        "memory-bank/decisionLog.md"
        "memory-bank/productContext.md"
        "memory-bank/progress.md"
        "memory-bank/systemPatterns.md"
        "specification.md"
        "architecture.md"
        "pseudocode.md"
        "README.md"
        "docs/getting-started.md"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        print_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi
    
    # Check directory structure
    local required_dirs=(
        "memory-bank"
        "docs"
        "reports"
        "project/${PROJECT_ID}"
        ".roo"
    )
    
    local missing_dirs=()
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done
    
    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        print_error "Missing required directories:"
        for dir in "${missing_dirs[@]}"; do
            echo "  - $dir"
        done
        return 1
    fi
    
    print_success "Project setup validation passed"
    return 0
}

# Function to show completion summary
show_completion_summary() {
    print_success "SPARC project initialization complete!"
    
    cat << EOF

${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}
${GREEN}║                    PROJECT CREATED SUCCESSFULLY             ║${NC}
${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}

📋 **Project Details**
   Name: ${PROJECT_NAME}
   ID: ${PROJECT_ID}
   SPARC Version: ${TEMPLATE_VERSION}
   
📁 **Structure Created**
   ✅ Complete directory structure
   ✅ Memory Bank with core knowledge files
   ✅ Configuration files (.roomodes, .rooignore, .roo/)
   ✅ Template documents (specification.md, architecture.md, etc.)
   ✅ Project documentation and guides

🚀 **Ready for Development**
   ✅ SPARC methodology structure
   ✅ Custom modes configured
   ✅ Security controls established
   ✅ Quality gates framework

📖 **Next Steps**
   1. Review README.md for project overview
   2. Read docs/getting-started.md for detailed guidance
   3. Begin specification phase with SPARC Specification Writer
   4. Set up development environment and team access

🧠 **Memory Bank Files**
   - memory-bank/activeContext.md (current working context)
   - memory-bank/decisionLog.md (architectural decisions)
   - memory-bank/productContext.md (business knowledge)
   - memory-bank/progress.md (status tracking)
   - memory-bank/systemPatterns.md (technical patterns)

⚙️  **Configuration**
   - .roomodes (custom mode definitions)
   - .rooignore (security and access control)
   - .roo/mcp.json (MCP server configuration)

${YELLOW}💡 Tip: Start by activating the SPARC Specification Writer mode to begin${NC}
${YELLOW}   requirements gathering and scope definition.${NC}

EOF
}

# Parse command line arguments
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
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PROJECT_NAME" ]]; then
    print_error "Project name is required"
    show_usage
    exit 1
fi

# Generate project ID if not provided
if [[ -z "$PROJECT_ID" ]]; then
    PROJECT_ID=$(generate_project_id "$PROJECT_NAME")
    print_info "Generated project ID: $PROJECT_ID"
fi

# Main execution
main() {
    print_info "Initializing SPARC project: $PROJECT_NAME ($PROJECT_ID)"
    
    # Create the project structure
    create_directory_structure
    create_memory_bank
    create_configuration_files
    create_template_documents
    create_project_documentation
    
    # Validate everything was created correctly
    if validate_setup; then
        show_completion_summary
    else
        print_error "Project setup validation failed"
        exit 1
    fi
}

# Run the main function
main
