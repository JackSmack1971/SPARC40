# System Patterns

> **Purpose**: Technical patterns, standards, and reusable solutions for consistent implementation
> **Updated by**: All technical modes (Architect, Code Implementer, TDD Engineer, Security Architect, etc.)
> **Used by**: All modes to maintain consistency and avoid reinventing solutions

## Code Organization Patterns

### **File Organization**
```
Standard Module Structure:
├── index.ts                  # Public API exports
├── types.ts                  # Type definitions
├── implementation.ts         # Core implementation (≤500 lines)
├── utils.ts                  # Utility functions
├── constants.ts              # Configuration constants
├── __tests__/               # Test files
│   ├── unit.test.ts         # Unit tests
│   ├── integration.test.ts  # Integration tests
│   └── fixtures/            # Test data
└── README.md                # Module documentation
```

### **Naming Conventions**
- **Files**: `kebab-case.ts` for implementation, `PascalCase.ts` for types/interfaces
- **Functions**: `camelCase` for functions, `PascalCase` for constructors/classes
- **Constants**: `SCREAMING_SNAKE_CASE` for constants
- **Types**: `PascalCase` with descriptive suffixes (`UserData`, `ApiResponse`)
- **Interfaces**: `PascalCase` starting with `I` if needed (`IUserRepository`)

### **Module Boundaries**
- **Single Responsibility**: Each module has one clear purpose
- **Size Limit**: Maximum 500 lines per file
- **Dependency Direction**: High-level modules don't depend on low-level modules
- **Interface Segregation**: Small, focused interfaces over large ones

---

## Architecture Patterns

### **Layered Architecture**
```
┌─────────────────────────────────────┐
│ Presentation Layer (UI/API)         │ ← User interfaces, API endpoints
├─────────────────────────────────────┤
│ Application Layer (Use Cases)       │ ← Business logic orchestration
├─────────────────────────────────────┤
│ Domain Layer (Business Logic)       │ ← Core business rules and entities
├─────────────────────────────────────┤
│ Infrastructure Layer (Data/External)│ ← Database, external services
└─────────────────────────────────────┘
```

### **Dependency Injection Pattern**
```typescript
// Service Interface
interface IUserService {
  getUser(id: string): Promise<User>;
  createUser(userData: CreateUserData): Promise<User>;
}

// Implementation
class UserService implements IUserService {
  constructor(
    private userRepository: IUserRepository,
    private logger: ILogger
  ) {}
  
  async getUser(id: string): Promise<User> {
    this.logger.info(`Fetching user ${id}`);
    return this.userRepository.findById(id);
  }
}

// Container Registration
container.register('userService', UserService, ['userRepository', 'logger']);
```

### **Repository Pattern**
```typescript
interface IUserRepository {
  findById(id: string): Promise<User | null>;
  save(user: User): Promise<User>;
  delete(id: string): Promise<void>;
}

class DatabaseUserRepository implements IUserRepository {
  constructor(private db: Database) {}
  
  async findById(id: string): Promise<User | null> {
    const result = await this.db.query('SELECT * FROM users WHERE id = ?', [id]);
    return result ? mapToUser(result) : null;
  }
}
```

---

## Error Handling Patterns

### **Result Pattern**
```typescript
type Result<T, E = Error> = 
  | { success: true; data: T }
  | { success: false; error: E };

// Usage
async function getUser(id: string): Promise<Result<User, UserError>> {
  try {
    const user = await userRepository.findById(id);
    if (!user) {
      return { success: false, error: new UserNotFoundError(id) };
    }
    return { success: true, data: user };
  } catch (error) {
    return { success: false, error: new UserRepositoryError(error) };
  }
}
```

### **Error Hierarchy**
```typescript
abstract class AppError extends Error {
  abstract readonly code: string;
  abstract readonly statusCode: number;
}

class ValidationError extends AppError {
  readonly code = 'VALIDATION_ERROR';
  readonly statusCode = 400;
}

class NotFoundError extends AppError {
  readonly code = 'NOT_FOUND';
  readonly statusCode = 404;
}
```

### **Error Handling Middleware**
```typescript
function errorHandler(error: Error, req: Request, res: Response, next: NextFunction) {
  if (error instanceof AppError) {
    return res.status(error.statusCode).json({
      code: error.code,
      message: error.message
    });
  }
  
  logger.error('Unexpected error:', error);
  return res.status(500).json({
    code: 'INTERNAL_ERROR',
    message: 'An unexpected error occurred'
  });
}
```

---

## Testing Patterns

### **Test Structure (AAA Pattern)**
```typescript
describe('UserService', () => {
  describe('getUser', () => {
    it('should return user when found', async () => {
      // Arrange
      const userId = 'user-123';
      const expectedUser = createTestUser({ id: userId });
      const mockRepository = createMockUserRepository();
      mockRepository.findById.mockResolvedValue(expectedUser);
      const userService = new UserService(mockRepository, mockLogger);
      
      // Act
      const result = await userService.getUser(userId);
      
      // Assert
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data).toEqual(expectedUser);
      }
      expect(mockRepository.findById).toHaveBeenCalledWith(userId);
    });
  });
});
```

### **Test Data Factories**
```typescript
function createTestUser(overrides: Partial<User> = {}): User {
  return {
    id: 'user-123',
    email: 'test@example.com',
    name: 'Test User',
    createdAt: new Date('2023-01-01'),
    ...overrides
  };
}

function createMockUserRepository(): jest.Mocked<IUserRepository> {
  return {
    findById: jest.fn(),
    save: jest.fn(),
    delete: jest.fn()
  };
}
```

### **Integration Test Patterns**
```typescript
describe('User API Integration', () => {
  let app: Express;
  let database: TestDatabase;
  
  beforeAll(async () => {
    database = await createTestDatabase();
    app = createApp({ database });
  });
  
  afterAll(async () => {
    await database.cleanup();
  });
  
  beforeEach(async () => {
    await database.reset();
  });
  
  it('should create and retrieve user', async () => {
    const userData = { email: 'test@example.com', name: 'Test User' };
    
    const createResponse = await request(app)
      .post('/api/users')
      .send(userData)
      .expect(201);
      
    const getResponse = await request(app)
      .get(`/api/users/${createResponse.body.id}`)
      .expect(200);
      
    expect(getResponse.body.email).toBe(userData.email);
  });
});
```

---

## Security Patterns

### **Authentication Middleware**
```typescript
interface AuthenticatedRequest extends Request {
  user: User;
}

function authenticate(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }
  
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = payload.user;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}
```

### **Input Validation**
```typescript
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
  age: z.number().min(18).max(120).optional()
});

function validateCreateUser(req: Request, res: Response, next: NextFunction) {
  try {
    const validatedData = CreateUserSchema.parse(req.body);
    req.body = validatedData;
    next();
  } catch (error) {
    if (error instanceof z.ZodError) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.errors
      });
    }
    next(error);
  }
}
```

### **SQL Injection Prevention**
```typescript
// DO: Use parameterized queries
async function getUserByEmail(email: string): Promise<User | null> {
  const result = await db.query(
    'SELECT * FROM users WHERE email = ?',
    [email]
  );
  return result ? mapToUser(result) : null;
}

// DON'T: String concatenation
// const query = `SELECT * FROM users WHERE email = '${email}'`; // VULNERABLE
```

---

## Performance Patterns

### **Caching Strategy**
```typescript
class CacheService {
  private cache = new Map<string, { data: any; expires: number }>();
  
  async get<T>(key: string, fallback: () => Promise<T>, ttl = 300): Promise<T> {
    const cached = this.cache.get(key);
    
    if (cached && cached.expires > Date.now()) {
      return cached.data;
    }
    
    const data = await fallback();
    this.cache.set(key, {
      data,
      expires: Date.now() + (ttl * 1000)
    });
    
    return data;
  }
}

// Usage
const user = await cacheService.get(
  `user:${userId}`,
  () => userRepository.findById(userId),
  600 // 10 minutes
);
```

### **Database Optimization**
```typescript
// Batch Loading Pattern
class UserLoader {
  private batchLoad = new DataLoader(async (userIds: readonly string[]) => {
    const users = await userRepository.findByIds([...userIds]);
    return userIds.map(id => users.find(user => user.id === id) || null);
  });
  
  async load(userId: string): Promise<User | null> {
    return this.batchLoad.load(userId);
  }
}

// Pagination Pattern
interface PaginationOptions {
  page: number;
  limit: number;
  sortBy?: string;
  sortOrder?: 'asc' | 'desc';
}

interface PaginatedResult<T> {
  items: T[];
  totalCount: number;
  page: number;
  totalPages: number;
  hasNext: boolean;
  hasPrev: boolean;
}
```

---

## API Design Patterns

### **RESTful API Structure**
```
GET    /api/users           # List users (with pagination/filtering)
POST   /api/users           # Create user
GET    /api/users/:id       # Get specific user
PUT    /api/users/:id       # Update user (full replacement)
PATCH  /api/users/:id       # Update user (partial)
DELETE /api/users/:id       # Delete user

GET    /api/users/:id/posts # Get user's posts (nested resource)
```

### **API Response Format**
```typescript
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: any;
  };
  meta?: {
    timestamp: string;
    requestId: string;
    pagination?: PaginationMeta;
  };
}

// Success Response
{
  "success": true,
  "data": { "id": "123", "name": "John Doe" },
  "meta": {
    "timestamp": "2023-01-01T12:00:00Z",
    "requestId": "req-123"
  }
}

// Error Response
{
  "success": false,
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "User with ID 123 not found"
  },
  "meta": {
    "timestamp": "2023-01-01T12:00:00Z",
    "requestId": "req-124"
  }
}
```

---

## State Management Patterns

### **Redux-like State Pattern**
```typescript
interface AppState {
  users: UserState;
  auth: AuthState;
  ui: UIState;
}

interface UserState {
  items: Record<string, User>;
  loading: boolean;
  error: string | null;
}

type UserAction = 
  | { type: 'FETCH_USERS_START' }
  | { type: 'FETCH_USERS_SUCCESS'; payload: User[] }
  | { type: 'FETCH_USERS_ERROR'; payload: string };

function userReducer(state: UserState = initialState, action: UserAction): UserState {
  switch (action.type) {
    case 'FETCH_USERS_START':
      return { ...state, loading: true, error: null };
    case 'FETCH_USERS_SUCCESS':
      return {
        ...state,
        loading: false,
        items: arrayToRecord(action.payload, 'id')
      };
    case 'FETCH_USERS_ERROR':
      return { ...state, loading: false, error: action.payload };
    default:
      return state;
  }
}
```

---

## Monitoring and Logging Patterns

### **Structured Logging**
```typescript
interface LogContext {
  requestId?: string;
  userId?: string;
  operation?: string;
  metadata?: Record<string, any>;
}

class Logger {
  info(message: string, context: LogContext = {}) {
    console.log(JSON.stringify({
      level: 'info',
      message,
      timestamp: new Date().toISOString(),
      ...context
    }));
  }
  
  error(message: string, error: Error, context: LogContext = {}) {
    console.error(JSON.stringify({
      level: 'error',
      message,
      timestamp: new Date().toISOString(),
      error: {
        name: error.name,
        message: error.message,
        stack: error.stack
      },
      ...context
    }));
  }
}
```

### **Metrics Collection**
```typescript
class MetricsCollector {
  private counters = new Map<string, number>();
  private histograms = new Map<string, number[]>();
  
  increment(metric: string, value = 1, tags: Record<string, string> = {}) {
    const key = this.buildKey(metric, tags);
    this.counters.set(key, (this.counters.get(key) || 0) + value);
  }
  
  time(metric: string, duration: number, tags: Record<string, string> = {}) {
    const key = this.buildKey(metric, tags);
    const values = this.histograms.get(key) || [];
    values.push(duration);
    this.histograms.set(key, values);
  }
}
```

---

## Configuration Patterns

### **Environment Configuration**
```typescript
interface Config {
  port: number;
  database: {
    host: string;
    port: number;
    name: string;
    user: string;
    password: string;
  };
  redis: {
    host: string;
    port: number;
  };
  jwt: {
    secret: string;
    expiresIn: string;
  };
}

function loadConfig(): Config {
  return {
    port: parseInt(process.env.PORT || '3000'),
    database: {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      name: process.env.DB_NAME || 'app',
      user: process.env.DB_USER || 'app',
      password: process.env.DB_PASSWORD || ''
    },
    redis: {
      host: process.env.REDIS_HOST || 'localhost',
      port: parseInt(process.env.REDIS_PORT || '6379')
    },
    jwt: {
      secret: process.env.JWT_SECRET || 'dev-secret',
      expiresIn: process.env.JWT_EXPIRES_IN || '24h'
    }
  };
}
```

---

## Documentation Patterns

### **API Documentation**
```typescript
/**
 * Creates a new user account
 * 
 * @param userData - User registration data
 * @returns Promise resolving to created user (without password)
 * @throws {ValidationError} When input data is invalid
 * @throws {ConflictError} When email already exists
 * 
 * @example
 * ```typescript
 * const user = await createUser({
 *   email: 'user@example.com',
 *   name: 'John Doe',
 *   password: 'securePassword123'
 * });
 * ```
 */
async function createUser(userData: CreateUserData): Promise<User> {
  // Implementation
}
```

### **README Template**
```markdown
# Module Name

Brief description of what this module does.

## Installation

```bash
npm install module-name
```

## Usage

```typescript
import { ModuleName } from 'module-name';

const instance = new ModuleName();
```

## API Reference

### Methods

#### `methodName(param: Type): ReturnType`

Description of what the method does.

**Parameters:**
- `param` (Type): Description of parameter

**Returns:** Description of return value

**Example:**
```typescript
const result = instance.methodName('example');
```

## Contributing

1. Follow the coding standards in systemPatterns.md
2. Add tests for new functionality
3. Update documentation for API changes
```

---

## Pattern Usage Guidelines

### **When to Create New Patterns**
1. **Repetition**: When you solve the same problem 3+ times
2. **Complexity**: When a solution needs explanation for team adoption
3. **Standards**: When consistency across team/codebase is important
4. **Best Practices**: When you discover a better approach to common problems

### **Pattern Documentation Requirements**
1. **Problem**: What problem does this pattern solve?
2. **Solution**: How does the pattern solve it?
3. **Example**: Working code example
4. **Trade-offs**: Benefits and costs of using this pattern
5. **Alternatives**: Other approaches and why this is preferred

### **Pattern Evolution**
1. **Review**: Regularly review patterns for continued relevance
2. **Update**: Update patterns when better solutions are found
3. **Deprecate**: Mark outdated patterns as deprecated with migration path
4. **Communicate**: Ensure team knows about pattern changes

---

## Template Usage Notes

**For Consistency**: 
- Reference these patterns when implementing new features
- Update patterns when you discover better approaches
- Ensure new team members understand and follow these patterns

**For Quality**:
- Use patterns to maintain code quality standards
- Leverage patterns for code review guidelines
- Apply patterns to reduce technical debt

**For Efficiency**:
- Reuse patterns instead of reinventing solutions
- Build on established patterns for new requirements
- Share patterns across teams for organization-wide consistency
