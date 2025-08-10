# Pseudocode Design

> **SPARC Phase**: Pseudocode  
> **Status**: [Draft | Review | Approved | Superseded]  
> **Last Updated**: [Date]  
> **Approved By**: [Technical Lead]  
> **Version**: 1.0  
> **Architecture Reference**: [Link to architecture.md]  
> **Specification Reference**: [Link to specification.md]

## Overview

### **Purpose**
This document translates the system architecture into implementable algorithms and data structures, providing clear guidance for the code implementation phase.

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

---

## Data Structures

### **Core Entities**

#### **[Entity Name]**
```pseudocode
STRUCTURE User {
    id: UUID                    // Unique identifier
    email: Email               // Must be valid email format
    name: String(1-100)        // Required, 1-100 characters
    createdAt: Timestamp       // Auto-generated on creation
    updatedAt: Timestamp       // Auto-updated on modification
    status: ENUM(ACTIVE, INACTIVE, SUSPENDED)
    
    // Computed properties
    displayName: String        // name or email if name empty
    isActive: Boolean          // status == ACTIVE
}

VALIDATION RULES for User:
- email must be unique across system
- name cannot contain special characters: <>[]{}
- status transitions: ACTIVE ↔ INACTIVE ↔ SUSPENDED
- createdAt cannot be modified after creation
```

#### **[Another Entity]**
```pseudocode
STRUCTURE Project {
    id: UUID
    title: String(1-200)
    description: String(0-1000)
    ownerId: UUID              // References User.id
    status: ENUM(DRAFT, ACTIVE, COMPLETED, ARCHIVED)
    priority: ENUM(LOW, MEDIUM, HIGH, CRITICAL)
    dueDate: Date              // Optional
    tags: Array<String>        // Maximum 10 tags
    
    // Relationships
    owner: User                // Lazy-loaded relationship
    collaborators: Array<User> // Many-to-many relationship
    tasks: Array<Task>         // One-to-many relationship
}

VALIDATION RULES for Project:
- title must be unique per owner
- dueDate cannot be in the past
- tags limited to alphanumeric + hyphen + underscore
- owner cannot be removed if project has active tasks
```

### **Data Transfer Objects (DTOs)**

#### **API Request/Response Formats**
```pseudocode
STRUCTURE CreateUserRequest {
    email: Email              // Required, validated
    name: String(1-100)       // Required
    password: String(8-128)   // Required, will be hashed
}

STRUCTURE UserResponse {
    id: UUID
    email: Email
    name: String
    displayName: String
    createdAt: Timestamp
    status: String
    // Note: password never included in responses
}

STRUCTURE PaginatedResponse<T> {
    items: Array<T>
    totalCount: Integer
    page: Integer
    pageSize: Integer
    totalPages: Integer
    hasNextPage: Boolean
    hasPreviousPage: Boolean
}
```

---

## Core Algorithms

### **User Management**

#### **Create User Algorithm**
```pseudocode
FUNCTION createUser(request: CreateUserRequest) RETURNS Result<User, Error>
    // Input validation
    IF NOT isValidEmail(request.email) THEN
        RETURN Error("Invalid email format")
    
    IF length(request.name) < 1 OR length(request.name) > 100 THEN
        RETURN Error("Name must be 1-100 characters")
    
    IF NOT isValidPassword(request.password) THEN
        RETURN Error("Password must be 8-128 characters with mixed case and numbers")
    
    // Business rule validation
    existingUser = findUserByEmail(request.email)
    IF existingUser IS NOT NULL THEN
        RETURN Error("Email already exists")
    
    // Create user
    hashedPassword = hashPassword(request.password)
    user = User {
        id: generateUUID(),
        email: request.email,
        name: request.name,
        passwordHash: hashedPassword,
        createdAt: getCurrentTimestamp(),
        updatedAt: getCurrentTimestamp(),
        status: ACTIVE
    }
    
    // Persist user
    TRY
        savedUser = database.save(user)
        auditLog.record("USER_CREATED", savedUser.id)
        emailService.sendWelcomeEmail(savedUser.email)
        RETURN Success(savedUser)
    CATCH DatabaseError as e
        RETURN Error("Failed to create user: " + e.message)
    CATCH EmailError as e
        // User created but email failed - log but don't fail
        logger.warn("Welcome email failed for user " + savedUser.id + ": " + e.message)
        RETURN Success(savedUser)
END FUNCTION

// Complexity: O(1) - single database lookup and insert
// Error cases: Invalid input, duplicate email, database failure, email failure
```

#### **Authenticate User Algorithm**
```pseudocode
FUNCTION authenticateUser(email: Email, password: String) RETURNS Result<AuthToken, Error>
    // Rate limiting check
    IF rateLimiter.isExceeded(email) THEN
        RETURN Error("Too many login attempts. Try again later.")
    
    // Find user
    user = findUserByEmail(email)
    IF user IS NULL THEN
        rateLimiter.recordFailure(email)
        RETURN Error("Invalid credentials")  // Don't reveal user existence
    
    // Check status
    IF user.status != ACTIVE THEN
        rateLimiter.recordFailure(email)
        RETURN Error("Account not active")
    
    // Verify password
    IF NOT verifyPassword(password, user.passwordHash) THEN
        rateLimiter.recordFailure(email)
        auditLog.record("LOGIN_FAILED", user.id)
        RETURN Error("Invalid credentials")
    
    // Generate token
    token = AuthToken {
        userId: user.id,
        email: user.email,
        issuedAt: getCurrentTimestamp(),
        expiresAt: getCurrentTimestamp() + TOKEN_LIFETIME,
        permissions: getUserPermissions(user.id)
    }
    
    signedToken = jwtSign(token, JWT_SECRET)
    
    // Record successful login
    rateLimiter.recordSuccess(email)
    auditLog.record("LOGIN_SUCCESS", user.id)
    
    RETURN Success(signedToken)
END FUNCTION

// Complexity: O(1) - single database lookup
// Error cases: Rate limiting, user not found, inactive user, wrong password, token generation failure
```

### **Project Management**

#### **Create Project Algorithm**
```pseudocode
FUNCTION createProject(ownerId: UUID, request: CreateProjectRequest) RETURNS Result<Project, Error>
    // Validate owner exists and is active
    owner = findUserById(ownerId)
    IF owner IS NULL OR owner.status != ACTIVE THEN
        RETURN Error("Invalid owner")
    
    // Validate request
    IF length(request.title) < 1 OR length(request.title) > 200 THEN
        RETURN Error("Title must be 1-200 characters")
    
    IF length(request.description) > 1000 THEN
        RETURN Error("Description cannot exceed 1000 characters")
    
    IF request.dueDate IS NOT NULL AND request.dueDate < getCurrentDate() THEN
        RETURN Error("Due date cannot be in the past")
    
    // Check for duplicate titles for this owner
    existingProject = findProjectByOwnerAndTitle(ownerId, request.title)
    IF existingProject IS NOT NULL THEN
        RETURN Error("Project with this title already exists")
    
    // Create project
    project = Project {
        id: generateUUID(),
        title: request.title,
        description: request.description,
        ownerId: ownerId,
        status: DRAFT,
        priority: request.priority OR MEDIUM,
        dueDate: request.dueDate,
        tags: validateAndCleanTags(request.tags),
        createdAt: getCurrentTimestamp(),
        updatedAt: getCurrentTimestamp()
    }
    
    // Persist project
    TRY
        savedProject = database.save(project)
        auditLog.record("PROJECT_CREATED", savedProject.id, ownerId)
        RETURN Success(savedProject)
    CATCH DatabaseError as e
        RETURN Error("Failed to create project: " + e.message)
END FUNCTION

// Complexity: O(1) - constant number of database operations
// Error cases: Invalid owner, validation failures, duplicate title, database failure
```

### **Search and Filtering**

#### **Search Users Algorithm**
```pseudocode
FUNCTION searchUsers(query: SearchQuery) RETURNS Result<PaginatedResponse<User>, Error>
    // Validate pagination parameters
    page = max(1, query.page OR 1)
    pageSize = min(100, max(10, query.pageSize OR 20))
    
    // Build search criteria
    criteria = SearchCriteria {}
    
    IF query.name IS NOT EMPTY THEN
        criteria.nameFilter = "%" + sanitizeSearchTerm(query.name) + "%"
    
    IF query.email IS NOT EMPTY THEN
        criteria.emailFilter = "%" + sanitizeSearchTerm(query.email) + "%"
    
    IF query.status IS NOT EMPTY THEN
        IF query.status NOT IN [ACTIVE, INACTIVE, SUSPENDED] THEN
            RETURN Error("Invalid status filter")
        criteria.statusFilter = query.status
    
    // Execute search with pagination
    TRY
        offset = (page - 1) * pageSize
        
        // Get total count for pagination
        totalCount = database.countUsers(criteria)
        
        // Get page of results
        users = database.searchUsers(criteria, offset, pageSize)
        
        // Build paginated response
        response = PaginatedResponse<User> {
            items: users,
            totalCount: totalCount,
            page: page,
            pageSize: pageSize,
            totalPages: ceiling(totalCount / pageSize),
            hasNextPage: page * pageSize < totalCount,
            hasPreviousPage: page > 1
        }
        
        RETURN Success(response)
    CATCH DatabaseError as e
        RETURN Error("Search failed: " + e.message)
END FUNCTION

// Complexity: O(log n) for indexed searches, O(n) for full text search
// Error cases: Invalid pagination params, invalid status, database failure
```

---

## Utility Functions

### **Validation Functions**

```pseudocode
FUNCTION isValidEmail(email: String) RETURNS Boolean
    // RFC 5322 compliant email validation
    emailRegex = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    RETURN matches(email, emailRegex) AND length(email) <= 254
END FUNCTION

FUNCTION isValidPassword(password: String) RETURNS Boolean
    IF length(password) < 8 OR length(password) > 128 THEN
        RETURN False
    
    hasLowercase = matches(password, ".*[a-z].*")
    hasUppercase = matches(password, ".*[A-Z].*")
    hasDigit = matches(password, ".*[0-9].*")
    hasSpecial = matches(password, ".*[!@#$%^&*()_+\\-=\\[\\]{};':\"\\|,.<>\\/?].*")
    
    RETURN hasLowercase AND hasUppercase AND hasDigit AND hasSpecial
END FUNCTION

FUNCTION sanitizeSearchTerm(term: String) RETURNS String
    // Remove SQL injection characters and limit length
    cleaned = removeCharacters(term, ["'", "\"", ";", "--", "/*", "*/"])
    RETURN substring(cleaned, 0, 100)
END FUNCTION
```

### **Security Functions**

```pseudocode
FUNCTION hashPassword(password: String) RETURNS String
    salt = generateSalt(16)  // 16-byte random salt
    hash = scrypt(password, salt, {N: 32768, r: 8, p: 1, dkLen: 32})
    RETURN base64encode(salt + hash)
END FUNCTION

FUNCTION verifyPassword(password: String, hash: String) RETURNS Boolean
    decoded = base64decode(hash)
    salt = substring(decoded, 0, 16)
    expectedHash = substring(decoded, 16, 48)
    actualHash = scrypt(password, salt, {N: 32768, r: 8, p: 1, dkLen: 32})
    RETURN constantTimeCompare(expectedHash, actualHash)
END FUNCTION

FUNCTION generateAuthToken(user: User) RETURNS String
    payload = {
        userId: user.id,
        email: user.email,
        issuedAt: getCurrentTimestamp(),
        expiresAt: getCurrentTimestamp() + TOKEN_LIFETIME
    }
    RETURN jwtSign(payload, JWT_SECRET)
END FUNCTION
```

### **Database Functions**

```pseudocode
FUNCTION findUserByEmail(email: Email) RETURNS User OR NULL
    query = "SELECT * FROM users WHERE email = ? AND deleted_at IS NULL"
    result = database.executeQuery(query, [email])
    RETURN result.firstOrNull()
END FUNCTION

FUNCTION findUserById(id: UUID) RETURNS User OR NULL
    query = "SELECT * FROM users WHERE id = ? AND deleted_at IS NULL"
    result = database.executeQuery(query, [id])
    RETURN result.firstOrNull()
END FUNCTION

FUNCTION saveUser(user: User) RETURNS User
    IF user.id IS NULL THEN
        // Insert new user
        query = "INSERT INTO users (id, email, name, password_hash, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)"
        database.executeUpdate(query, [user.id, user.email, user.name, user.passwordHash, user.status, user.createdAt, user.updatedAt])
    ELSE
        // Update existing user
        user.updatedAt = getCurrentTimestamp()
        query = "UPDATE users SET email = ?, name = ?, status = ?, updated_at = ? WHERE id = ?"
        database.executeUpdate(query, [user.email, user.name, user.status, user.updatedAt, user.id])
    
    RETURN user
END FUNCTION
```

---

## Error Handling Patterns

### **Error Types**

```pseudocode
ABSTRACT CLASS AppError {
    message: String
    code: String
    timestamp: Timestamp
    context: Map<String, Any>
}

CLASS ValidationError EXTENDS AppError {
    field: String
    value: Any
    constraint: String
}

CLASS NotFoundError EXTENDS AppError {
    resourceType: String
    identifier: Any
}

CLASS ConflictError EXTENDS AppError {
    conflictType: String
    conflictingValue: Any
}

CLASS AuthenticationError EXTENDS AppError {
    attemptedAction: String
}

CLASS AuthorizationError EXTENDS AppError {
    requiredPermission: String
    userPermissions: Array<String>
}
```

### **Error Handling Strategy**

```pseudocode
FUNCTION handleError(error: Error) RETURNS ErrorResponse
    // Log error for debugging
    logger.error("Error occurred", {
        error: error.message,
        stack: error.stackTrace,
        timestamp: getCurrentTimestamp()
    })
    
    // Map to user-friendly response
    IF error INSTANCEOF ValidationError THEN
        RETURN ErrorResponse {
            status: 400,
            code: "VALIDATION_ERROR",
            message: error.message,
            field: error.field
        }
    ELSE IF error INSTANCEOF NotFoundError THEN
        RETURN ErrorResponse {
            status: 404,
            code: "NOT_FOUND",
            message: error.resourceType + " not found"
        }
    ELSE IF error INSTANCEOF ConflictError THEN
        RETURN ErrorResponse {
            status: 409,
            code: "CONFLICT",
            message: error.message
        }
    ELSE IF error INSTANCEOF AuthenticationError THEN
        RETURN ErrorResponse {
            status: 401,
            code: "AUTHENTICATION_REQUIRED",
            message: "Authentication required"
        }
    ELSE IF error INSTANCEOF AuthorizationError THEN
        RETURN ErrorResponse {
            status: 403,
            code: "INSUFFICIENT_PERMISSIONS",
            message: "Insufficient permissions"
        }
    ELSE
        // Unknown error - don't expose internal details
        RETURN ErrorResponse {
            status: 500,
            code: "INTERNAL_ERROR",
            message: "An unexpected error occurred"
        }
END FUNCTION
```

---

## Performance Considerations

### **Caching Strategy**

```pseudocode
FUNCTION getUserWithCache(userId: UUID) RETURNS User OR NULL
    cacheKey = "user:" + userId
    
    // Try cache first
    cachedUser = redis.get(cacheKey)
    IF cachedUser IS NOT NULL THEN
        RETURN deserialize(cachedUser)
    
    // Cache miss - get from database
    user = findUserById(userId)
    IF user IS NOT NULL THEN
        // Cache for 1 hour
        redis.setex(cacheKey, 3600, serialize(user))
    
    RETURN user
END FUNCTION

FUNCTION invalidateUserCache(userId: UUID)
    cacheKey = "user:" + userId
    redis.delete(cacheKey)
    
    // Also invalidate related caches
    redis.deletePattern("user_projects:" + userId + ":*")
END FUNCTION
```

### **Pagination Strategy**

```pseudocode
FUNCTION paginateResults(query: String, params: Array, page: Integer, pageSize: Integer) RETURNS PaginatedResponse
    // Validate pagination parameters
    page = max(1, page)
    pageSize = min(100, max(1, pageSize))
    offset = (page - 1) * pageSize
    
    // Get total count (potentially cached)
    countQuery = convertToCountQuery(query)
    totalCount = database.executeScalar(countQuery, params)
    
    // Get page of results
    paginatedQuery = query + " LIMIT ? OFFSET ?"
    paginatedParams = params + [pageSize, offset]
    items = database.executeQuery(paginatedQuery, paginatedParams)
    
    RETURN PaginatedResponse {
        items: items,
        totalCount: totalCount,
        page: page,
        pageSize: pageSize,
        totalPages: ceiling(totalCount / pageSize),
        hasNextPage: offset + pageSize < totalCount,
        hasPreviousPage: page > 1
    }
END FUNCTION
```

---

## Integration Points

### **API Endpoints**

```pseudocode
// User Management API
POST   /api/users                    → createUser(CreateUserRequest)
GET    /api/users                    → searchUsers(SearchQuery)
GET    /api/users/{id}               → getUserById(UUID)
PUT    /api/users/{id}               → updateUser(UUID, UpdateUserRequest)
DELETE /api/users/{id}               → deleteUser(UUID)

// Authentication API
POST   /api/auth/login               → authenticateUser(LoginRequest)
POST   /api/auth/logout              → logout(AuthToken)
POST   /api/auth/refresh             → refreshToken(RefreshTokenRequest)

// Project Management API
POST   /api/projects                 → createProject(CreateProjectRequest)
GET    /api/projects                 → searchProjects(SearchQuery)
GET    /api/projects/{id}            → getProjectById(UUID)
PUT    /api/projects/{id}            → updateProject(UUID, UpdateProjectRequest)
DELETE /api/projects/{id}            → deleteProject(UUID)
```

### **Database Schema**

```sql
-- Users table
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(254) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL
);

-- Projects table
CREATE TABLE projects (
    id UUID PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    owner_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
    priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    due_date DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    FOREIGN KEY (owner_id) REFERENCES users(id),
    UNIQUE KEY unique_title_per_owner (owner_id, title, deleted_at)
);

-- Indexes for performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_projects_owner ON projects(owner_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_projects_due_date ON projects(due_date);
```

---

## Testing Guidelines

### **Unit Test Structure**

```pseudocode
TEST createUser_WithValidInput_ReturnsSuccess
    // Arrange
    request = CreateUserRequest {
        email: "test@example.com",
        name: "Test User",
        password: "SecurePass123!"
    }
    
    mockDatabase = createMockDatabase()
    mockDatabase.stubFindUserByEmail(null)  // No existing user
    mockDatabase.stubSave(successfulSave)
    
    // Act
    result = createUser(request)
    
    // Assert
    ASSERT result.isSuccess()
    ASSERT result.value.email == "test@example.com"
    ASSERT mockDatabase.verifySaveCalled()
END TEST

TEST createUser_WithDuplicateEmail_ReturnsError
    // Arrange
    request = CreateUserRequest {
        email: "existing@example.com",
        name: "Test User",
        password: "SecurePass123!"
    }
    
    existingUser = User { email: "existing@example.com" }
    mockDatabase = createMockDatabase()
    mockDatabase.stubFindUserByEmail(existingUser)
    
    // Act
    result = createUser(request)
    
    // Assert
    ASSERT result.isError()
    ASSERT result.error.message CONTAINS "already exists"
    ASSERT mockDatabase.verifySaveNotCalled()
END TEST
```

### **Integration Test Patterns**

```pseudocode
TEST userLifecycle_CreateUpdateDelete_Success
    // Create user
    createRequest = CreateUserRequest {
        email: "integration@test.com",
        name: "Integration Test",
        password: "TestPass123!"
    }
    
    createResult = apiClient.post("/api/users", createRequest)
    ASSERT createResult.status == 201
    userId = createResult.body.id
    
    // Update user
    updateRequest = UpdateUserRequest {
        name: "Updated Name"
    }
    
    updateResult = apiClient.put("/api/users/" + userId, updateRequest)
    ASSERT updateResult.status == 200
    ASSERT updateResult.body.name == "Updated Name"
    
    // Delete user
    deleteResult = apiClient.delete("/api/users/" + userId)
    ASSERT deleteResult.status == 204
    
    // Verify deletion
    getResult = apiClient.get("/api/users/" + userId)
    ASSERT getResult.status == 404
END TEST
```

---

## Implementation Notes

### **Code Generation Guidance**
- Use the data structures as the foundation for entity classes
- Implement algorithms as class methods or standalone functions
- Follow the error handling patterns consistently
- Include comprehensive logging at decision points
- Add performance monitoring to critical paths

### **Database Implementation**
- Create database migrations for the schema changes
- Implement repository pattern for data access
- Use connection pooling for database connections
- Add proper indexing for search performance
- Implement soft deletes where appropriate

### **API Implementation**
- Use the endpoint definitions for route configuration
- Implement middleware for authentication and validation
- Add rate limiting to prevent abuse
- Include comprehensive API documentation
- Implement proper HTTP status codes and error responses

---

## Template Usage Notes

**For Code Implementers**:
- Use this pseudocode as the blueprint for actual implementation
- Maintain the same function signatures and error handling patterns
- Implement all validation rules and business logic as specified
- Add comprehensive unit tests for each algorithm
- Update memory-bank/systemPatterns.md with implementation patterns

**For Testing**:
- Use the test patterns as templates for comprehensive test coverage
- Ensure all error cases are tested
- Validate performance characteristics match the specifications
- Test all integration points thoroughly

**For Architecture Validation**:
- Verify the pseudocode aligns with the architecture.md design
- Ensure all requirements from specification.md are addressed
- Validate that performance targets can be met with these algorithms
- Confirm security requirements are properly implemented
