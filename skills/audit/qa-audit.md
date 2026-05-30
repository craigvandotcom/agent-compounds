# QA Audit Checklist

**Purpose:** Code quality, maintainability, and architectural verification for any web/mobile application
**Domain:** Code smells, technical debt, TypeScript quality, architecture, readability, documentation
**Tech Stack:** Next.js 15, React 19, TypeScript, ESLint, Prettier

---

## Quick Reference Commands

```bash
# TypeScript strict check
pnpm type-check

# Lint with auto-fix
pnpm lint --fix

# Find any types
grep -r ": any" app/ lib/ features/ components/ --include="*.ts" --include="*.tsx" | grep -v node_modules

# Find type assertions
grep -r " as " app/ lib/ features/ components/ --include="*.ts" --include="*.tsx" | grep -v "import"

# Find long files (>300 lines)
find app/ lib/ features/ components/ -name "*.ts" -o -name "*.tsx" | xargs wc -l | sort -n | tail -20

# Find deep nesting (5+ indentation levels)
grep -rn "^                    " app/ lib/ --include="*.ts" --include="*.tsx"

# Find TODO/FIXME comments
grep -rn "TODO\|FIXME\|HACK\|XXX" app/ lib/ features/ components/ --include="*.ts" --include="*.tsx"

# Check for console.log (should be removed in production)
grep -rn "console\.\(log\|debug\|info\)" app/ lib/ features/ --include="*.ts" --include="*.tsx" | grep -v "test\|spec"

# Find duplicate code patterns
# (Use IDE or SonarQube for comprehensive detection)
```

---

## QA Audit Items

### [QA-001] Audit `any` Type Usage

**Description:** Find and evaluate all `any` type usage; prefer `unknown` or specific types
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** QA-TypeScript

**Verification:**

1. Run: `grep -rn ": any" app/ lib/ features/ components/ --include="*.ts" --include="*.tsx"`
2. Categorize: justified (external API) vs. lazy (should be typed)
3. For each `any`, determine if `unknown` or specific type is better
4. Check for implicit `any` in function parameters
5. Verify `tsconfig.json` has `noImplicitAny: true`

**Expected Output:** Zero unjustified `any` types; all have comments explaining necessity

**Deliverable:** Replace `any` with specific types or `unknown` where possible

---

### [QA-002] Verify Type Assertions vs Type Guards

**Description:** Ensure type assertions (`as Foo`) are minimized; prefer type guards
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-TypeScript

**Verification:**

1. Run: `grep -rn " as " app/ lib/ features/ components/ --include="*.ts" --include="*.tsx" | grep -v "import"`
2. For each assertion, check if type guard would be safer
3. Verify assertions have runtime checks before use
4. Look for dangerous patterns: `as any`, `as unknown as Foo`
5. Check error handling uses proper type narrowing

**Expected Output:** Type assertions justified and minimized; type guards preferred

**Deliverable:** Convert unsafe assertions to type guards

**Example Fix:**

```typescript
// Bad: Type assertion without validation
const data = response as UserData;

// Good: Type guard with runtime check
function isUserData(obj: unknown): obj is UserData {
  return obj !== null && typeof obj === 'object' && 'id' in obj;
}
if (isUserData(response)) {
  // response is now UserData
}
```

---

### [QA-003] Audit Explicit Return Types

**Description:** Verify exported functions have explicit return types for API stability
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-TypeScript

**Verification:**

1. Check exported functions: `grep -rn "export.*function\|export const.*=" app/ lib/ --include="*.ts"`
2. Verify return types are explicit (not inferred)
3. Check async functions return `Promise<T>` explicitly
4. Verify API route handlers have explicit response types
5. Check custom hooks have explicit return types

**Expected Output:** All exported functions have explicit return types

**Deliverable:** Add return types to exported functions

---

### [QA-004] Verify Catch Block Error Handling

**Description:** Ensure catch blocks properly handle `unknown` error type (TypeScript 4.4+)
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** QA-TypeScript

**Verification:**

1. Find catch blocks: `grep -rn "catch\s*(" app/ lib/ features/ --include="*.ts" --include="*.tsx"`
2. Check error parameter typed as `unknown` (not `any` or untyped)
3. Verify proper narrowing before accessing error properties
4. Check for `instanceof Error` or custom type guards
5. Verify error messages extracted safely

**Expected Output:** All catch blocks handle `unknown` type safely

**Deliverable:** Fix unsafe error handling patterns

**Example Fix:**

```typescript
// Bad: Unsafe error access
catch (error) {
  console.log(error.message); // error is unknown
}

// Good: Safe error handling
catch (error) {
  const message = error instanceof Error ? error.message : 'Unknown error';
  console.log(message);
}
```

---

### [QA-005] Audit Cyclomatic Complexity

**Description:** Identify functions with high cyclomatic complexity (>10)
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** QA-Complexity

**Verification:**

1. Use ESLint complexity rule or IDE metrics
2. Find functions with >10 decision points (if/else/switch/ternary/&&/||)
3. Identify candidates for extraction or simplification
4. Check for nested conditionals that can be flattened
5. Look for early returns that reduce complexity

**Expected Output:** All functions have cyclomatic complexity ≤10

**Deliverable:** List of high-complexity functions with refactoring suggestions

**Complexity Thresholds:**

| Score | Rating    | Action               |
| ----- | --------- | -------------------- |
| 1-5   | Low       | Good                 |
| 6-10  | Moderate  | Monitor              |
| 11-20 | High      | Refactor recommended |
| 21+   | Very High | Refactor required    |

---

### [QA-006] Verify Cognitive Complexity

**Description:** Ensure code is easy to understand (cognitive complexity ≤15)
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Complexity

**Verification:**

1. Review functions with deep nesting (>4 levels)
2. Check for complex boolean expressions
3. Look for functions mixing multiple concerns
4. Identify "clever" code that's hard to follow
5. Check for recursive calls or complex control flow

**Expected Output:** All functions have cognitive complexity ≤15

**Deliverable:** Simplify overly complex functions

---

### [QA-007] Detect Duplicated Code

**Description:** Find code duplication that violates DRY principle
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Duplication

**Verification:**

1. Use IDE duplicate detection or SonarQube
2. Search for similar patterns: `grep -rn "similar pattern" app/`
3. Look for copy-pasted code blocks (>10 lines similar)
4. Check for repeated business logic across components
5. Identify candidates for shared utilities or hooks

**Expected Output:** No significant code duplication (>10 lines)

**Deliverable:** Extract duplicated code to shared functions/hooks

---

### [QA-008] Audit Dead Code

**Description:** Find and remove unused code (functions, variables, imports)
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Duplication

**Verification:**

1. Run: `pnpm lint` (ESLint catches unused vars)
2. Check for unreachable code after returns
3. Look for commented-out code blocks
4. Find unused exports: check if imported elsewhere
5. Verify no orphaned files (not imported anywhere)

**Expected Output:** Zero dead code; all code actively used

**Deliverable:** Remove dead code, unused imports, commented blocks

---

### [QA-009] Verify Function Length Limits

**Description:** Ensure functions are appropriately sized (≤50 lines)
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Readability

**Verification:**

1. Find long functions: use IDE metrics or manual review
2. Check functions >50 lines for extraction opportunities
3. Verify each function does one thing well
4. Look for functions with multiple responsibility sections
5. Check for functions that can be split by abstraction level

**Expected Output:** Functions ≤50 lines; longer ones justified

**Deliverable:** List of long functions with split recommendations

**Function Length Guidelines:**

| Lines  | Rating    | Action             |
| ------ | --------- | ------------------ |
| 1-20   | Excellent | Ideal size         |
| 21-50  | Good      | Acceptable         |
| 51-100 | Large     | Consider splitting |
| 101+   | Too Large | Must refactor      |

---

### [QA-010] Audit File Length Limits

**Description:** Ensure files are appropriately sized (≤300 lines)
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Readability

**Verification:**

1. Run: `find app/ lib/ features/ components/ -name "*.ts" -o -name "*.tsx" | xargs wc -l | sort -n | tail -20`
2. Check files >300 lines for split opportunities
3. Verify each file has single responsibility
4. Look for God files mixing concerns
5. Check component files don't include unrelated utilities

**Expected Output:** Files ≤300 lines; longer ones have clear reason

**Deliverable:** List of large files with organization recommendations

---

### [QA-011] Verify Naming Conventions

**Description:** Ensure consistent, descriptive naming throughout codebase
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Readability

**Verification:**

1. Check variable names are descriptive (not `x`, `temp`, `data`)
2. Verify function names describe what they do (verb + noun)
3. Check component names match file names (PascalCase)
4. Verify hooks start with `use` prefix
5. Check constants use SCREAMING_SNAKE_CASE

**Expected Output:** Consistent naming conventions throughout

**Deliverable:** Fix inconsistent or unclear names

**Naming Conventions:**

| Type               | Convention      | Example                |
| ------------------ | --------------- | ---------------------- |
| Components         | PascalCase      | `UserProfileCard`      |
| Functions          | camelCase       | `calculateItemScore`   |
| Hooks              | useCamelCase    | `useItemAnalysis`      |
| Constants          | SCREAMING_SNAKE | `MAX_FILE_SIZE`        |
| Types/Interfaces   | PascalCase      | `UserProfile`          |
| Files (components) | PascalCase      | `UserProfileCard.tsx`  |
| Files (utilities)  | kebab-case      | `item-utils.ts`        |

---

### [QA-012] Audit Deep Nesting

**Description:** Find deeply nested code (>4 levels) that reduces readability
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** QA-Complexity

**Verification:**

1. Run: `grep -rn "^                    " app/ lib/ --include="*.ts" --include="*.tsx"` (5+ indentation levels)
2. Look for nested if/else chains
3. Check for nested callbacks or promises
4. Identify nested ternary operators
5. Look for nested loops

**Expected Output:** Maximum 4 levels of nesting

**Deliverable:** Flatten deeply nested code using early returns, extraction, or guard clauses

**Example Fix:**

```typescript
// Bad: Deep nesting
if (user) {
  if (user.items) {
    if (user.items.length > 0) {
      user.items.forEach(item => {
        if (item.status === 'active') {
          // process
        }
      });
    }
  }
}

// Good: Early returns + extraction
if (!user?.items?.length) return;

const activeItems = user.items.filter(i => i.status === 'active');
activeItems.forEach(processActiveItem);
```

---

### [QA-013] Verify Single Responsibility Principle

**Description:** Ensure components and functions have single, clear responsibilities
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** QA-Architecture

**Verification:**

1. Review large components for mixed concerns
2. Check if component handles both data fetching AND rendering
3. Look for functions that do multiple unrelated things
4. Verify hooks don't mix unrelated state
5. Check services don't combine business logic with data access

**Expected Output:** Each module has clear, single responsibility

**Deliverable:** Identify SRP violations with refactoring suggestions

---

### [QA-014] Audit Component Size and Complexity

**Description:** Ensure React components are appropriately sized (≤200 lines)
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-React

**Verification:**

1. Find large components: check files in `app/` and `components/`
2. Check components >200 lines for extraction opportunities
3. Look for components with >5 useState calls
4. Identify components rendering multiple distinct sections
5. Check for repeated JSX patterns that could be extracted

**Expected Output:** Components ≤200 lines; larger ones split into sub-components

**Deliverable:** List of large components with decomposition suggestions

---

### [QA-015] Verify Custom Hook Extraction

**Description:** Ensure reusable logic is extracted to custom hooks
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-React

**Verification:**

1. Find repeated hook patterns across components
2. Check for useState+useEffect combinations that could be hooks
3. Look for complex state logic that should be useReducer
4. Verify data fetching extracted to hooks (not in components)
5. Check form handling uses extracted hooks

**Expected Output:** Reusable logic in custom hooks; components focused on rendering

**Deliverable:** Extract repeated logic to shared hooks

---

### [QA-016] Audit Context Usage

**Description:** Verify Context API used appropriately (not overused)
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-React

**Verification:**

1. Find context usage: `grep -rn "createContext\|useContext" app/ lib/ --include="*.tsx"`
2. Check if context needed or if props would suffice
3. Look for single monolithic context (should be split)
4. Verify context values memoized to prevent re-renders
5. Check context providers not nested unnecessarily

**Expected Output:** Context used sparingly; properly split and memoized

**Deliverable:** Context usage audit with optimization recommendations

---

### [QA-017] Detect Prop Drilling

**Description:** Find excessive prop drilling (>3 levels) that should use context or composition
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-React

**Verification:**

1. Trace props through component hierarchy
2. Check for props passed through intermediary components unchanged
3. Look for "pass-through" props that skip multiple levels
4. Identify candidates for context or component composition
5. Check for props spread (`{...props}`) hiding prop drilling

**Expected Output:** Props passed max 3 levels; deeper uses context

**Deliverable:** Identify prop drilling with refactoring suggestions

---

### [QA-018] Verify Import Organization

**Description:** Ensure imports are organized consistently and free of circular dependencies
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Architecture

**Verification:**

1. Check import order: external → internal → relative
2. Look for circular imports (A imports B, B imports A)
3. Verify no deep relative imports (`../../../..`)
4. Check path aliases used consistently (`@/lib/`, `@/components/`)
5. Verify barrel exports (`index.ts`) don't cause bloat

**Expected Output:** Consistent import organization; no circular dependencies

**Deliverable:** Fix import organization issues

**Import Order Convention:**

```typescript
// 1. External packages
import { useState } from 'react';
import { format } from 'date-fns';

// 2. Internal absolute imports
import { Button } from '@/components/ui/button';
import { ItemService } from '@/lib/services/item';

// 3. Relative imports (same feature)
import { ItemCard } from './ItemCard';
import type { ItemEntry } from './types';
```

---

### [QA-019] Audit Feature Isolation

**Description:** Verify features are properly isolated with clear boundaries
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** QA-Architecture

**Verification:**

1. Check `/features` directory structure
2. Verify features don't import from each other's internals
3. Check shared code is in `/lib` not scattered
4. Verify each feature has its own types, hooks, components
5. Look for cross-feature dependencies that should be abstracted

**Expected Output:** Features are self-contained modules with clear APIs

**Deliverable:** Feature isolation audit with boundary recommendations

---

### [QA-020] Verify Consistent Formatting

**Description:** Ensure code formatting is consistent (Prettier compliance)
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** QA-Readability

**Verification:**

1. Run: `pnpm format --check` or `prettier --check .`
2. Check for formatting inconsistencies
3. Verify `.prettierrc` configured properly
4. Check all file types included in formatting
5. Verify format-on-save enabled in IDE config

**Expected Output:** All files pass Prettier check

**Deliverable:** Run `pnpm format` to fix formatting

---

### [QA-021] Audit TODO/FIXME Comments

**Description:** Track and address TODO/FIXME comments in codebase
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Documentation

**Verification:**

1. Run: `grep -rn "TODO\|FIXME\|HACK\|XXX" app/ lib/ features/ components/ --include="*.ts" --include="*.tsx"`
2. Categorize: actionable vs. stale
3. Check TODOs have associated issues/tickets
4. Verify FIXMEs are tracked for resolution
5. Remove stale/completed TODOs

**Expected Output:** All TODOs tracked in issue tracker; stale ones removed

**Deliverable:** TODO audit with linked issues

---

### [QA-022] Verify Comment Quality

**Description:** Ensure comments explain "why" not "what"; remove obvious comments
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** QA-Documentation

**Verification:**

1. Review comments for value-add
2. Remove comments that repeat the code (`// increment i`)
3. Check for outdated comments (don't match code)
4. Verify complex logic has explanatory comments
5. Check JSDoc comments for public APIs

**Expected Output:** Comments explain intent, not mechanics

**Deliverable:** Clean up redundant/outdated comments

---

### [QA-023] Audit Console Statement Removal

**Description:** Ensure no debug console.log statements in production code
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** QA-Cleanup

**Verification:**

1. Run: `grep -rn "console\.\(log\|debug\|info\)" app/ lib/ features/ --include="*.ts" --include="*.tsx" | grep -v "test\|spec"`
2. Check for debugging console.logs left in
3. Verify intentional logging uses proper logger
4. Check no sensitive data logged
5. Verify `console.error` used appropriately

**Expected Output:** No console.log in production code

**Deliverable:** Remove debug console statements

---

### [QA-024] Verify Error Boundary Coverage

**Description:** Ensure Error Boundaries wrap critical UI sections
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** QA-Reliability

**Verification:**

1. Find error boundaries: `grep -rn "ErrorBoundary" app/ --include="*.tsx"`
2. Verify critical sections wrapped (dashboard, forms, data display)
3. Check error UI is user-friendly
4. Verify errors logged for debugging
5. Check recovery actions available (retry, refresh)

**Expected Output:** Critical UI wrapped in error boundaries with fallback UI

**Deliverable:** Add error boundaries to unprotected critical sections

---

### [QA-025] Audit Graceful Degradation

**Description:** Verify app degrades gracefully when features fail
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Reliability

**Verification:**

1. Test: disable AI service, verify app still usable
2. Test: slow network, verify loading states show
3. Check fallback UI for failed data fetches
4. Verify error messages are user-friendly
5. Test: missing data scenarios handled

**Expected Output:** App remains usable when non-critical features fail

**Deliverable:** Graceful degradation audit with improvements

---

### [QA-026] Verify ESLint Configuration Coverage

**Description:** Ensure ESLint rules cover quality concerns
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Tooling

**Verification:**

1. Check `.eslintrc.js` or `eslint.config.js` for rule coverage
2. Verify rules enabled: no-unused-vars, no-explicit-any, complexity
3. Check React-specific rules: hooks rules, jsx-a11y
4. Verify TypeScript rules: strict-boolean-expressions, etc.
5. Test: `pnpm lint` catches expected issues

**Expected Output:** ESLint catches common quality issues

**Deliverable:** Update ESLint config with missing rules

**Recommended Rules:**

```json
{
  "rules": {
    "complexity": ["warn", 10],
    "max-depth": ["warn", 4],
    "max-lines-per-function": ["warn", 50],
    "no-console": "warn",
    "@typescript-eslint/no-explicit-any": "warn",
    "@typescript-eslint/explicit-function-return-type": "warn"
  }
}
```

---

### [QA-027] Verify TypeScript Strict Mode

**Description:** Ensure TypeScript strict mode enabled for maximum type safety
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** QA-Tooling

**Verification:**

1. Check `tsconfig.json` for `"strict": true`
2. Verify individual strict flags not disabled
3. Check `noImplicitAny`, `strictNullChecks` enabled
4. Verify `noUncheckedIndexedAccess` for array safety
5. Test: `pnpm type-check` catches expected issues

**Expected Output:** TypeScript strict mode fully enabled

**Deliverable:** Enable missing strict flags

**Required Flags:**

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noUncheckedIndexedAccess": true
  }
}
```

---

### [QA-028] Audit Magic Numbers/Strings

**Description:** Find hardcoded values that should be named constants
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Readability

**Verification:**

1. Search for unexplained numbers: `grep -rn "[^0-9][0-9]\{2,\}[^0-9]" app/ lib/ --include="*.ts"`
2. Look for hardcoded strings (URLs, messages, keys)
3. Check for repeated literal values
4. Verify constants defined for business rules (limits, thresholds)
5. Check environment-specific values in config

**Expected Output:** No magic numbers; all values named or documented

**Deliverable:** Extract magic values to named constants

**Example Fix:**

```typescript
// Bad: Magic number
if (file.size > 5242880) { ... }

// Good: Named constant
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB
if (file.size > MAX_FILE_SIZE_BYTES) { ... }
```

---

### [QA-029] Verify Null Safety Patterns

**Description:** Ensure consistent null/undefined handling throughout codebase
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** QA-TypeScript

**Verification:**

1. Check for optional chaining usage: `obj?.prop`
2. Verify nullish coalescing used: `value ?? default`
3. Look for unsafe property access without null checks
4. Check for inconsistent null vs undefined usage
5. Verify early returns for null cases

**Expected Output:** Consistent null safety patterns; no null pointer risks

**Deliverable:** Fix null safety issues

---

### [QA-030] Audit Async/Await Patterns

**Description:** Verify consistent async/await usage (not mixed with .then())
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Patterns

**Verification:**

1. Find mixed patterns: `grep -rn "\.then(" app/ lib/ --include="*.ts" --include="*.tsx"`
2. Check for unhandled promise rejections
3. Verify await used in try/catch blocks
4. Look for parallel async calls (Promise.all)
5. Check for unnecessary sequential awaits

**Expected Output:** Consistent async/await usage; proper error handling

**Deliverable:** Convert .then() to async/await where appropriate

---

### [QA-031] Verify Array Method Usage

**Description:** Ensure appropriate array methods used (map vs forEach, filter vs find)
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** QA-Patterns

**Verification:**

1. Check for forEach when map would return value
2. Look for filter + [0] when find should be used
3. Verify reduce used appropriately (not overused)
4. Check for imperative loops that could be declarative
5. Verify array methods chained efficiently

**Expected Output:** Appropriate array methods used; no unnecessary iterations

**Deliverable:** Optimize array method usage

---

### [QA-032] Audit Dependency Injection Patterns

**Description:** Verify dependencies are injectable for testing
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Architecture

**Verification:**

1. Check for hardcoded dependencies (direct imports of services)
2. Verify functions accept dependencies as parameters
3. Look for singleton patterns that hinder testing
4. Check hooks accept optional service overrides
5. Verify API clients can be mocked easily

**Expected Output:** Dependencies injectable; easy to test in isolation

**Deliverable:** Identify hard-to-test code with DI recommendations

---

### [QA-033] Verify React 19 Pattern Adoption

**Description:** Ensure modern React 19 patterns used where beneficial
**Severity:** LOW
**Auto-fixable:** YES
**Parallel Group:** QA-React

**Verification:**

1. Check for useActionState usage (form handling)
2. Look for useOptimistic opportunities (UI feedback)
3. Verify Server Components used where appropriate
4. Check use() API for resource handling
5. Verify ref handling uses new patterns

**Expected Output:** React 19 patterns adopted where beneficial

**Deliverable:** List of opportunities for React 19 pattern adoption

---

### [QA-034] Audit README and Documentation

**Description:** Verify documentation is complete and up-to-date
**Severity:** LOW
**Auto-fixable:** NO
**Parallel Group:** QA-Documentation

**Verification:**

1. Check README.md has: setup, commands, architecture overview
2. Verify environment variables documented (.env.example)
3. Check API routes have documentation/types
4. Verify complex business logic documented
5. Check CHANGELOG maintained (if used)

**Expected Output:** Documentation complete and accurate

**Deliverable:** Documentation gaps identified

---

### [QA-035] Verify Coding Standards Compliance

**Description:** Ensure codebase follows documented coding standards
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Documentation

**Verification:**

1. Review `.claude/skills/CORE/coding-practices.md`
2. Check code follows documented patterns
3. Verify new code matches existing conventions
4. Check for pattern drift from standards
5. Verify standards are still appropriate

**Expected Output:** Code follows documented standards

**Deliverable:** Standards compliance report

---

### [QA-036] Audit Boolean Trap Pattern

**Description:** Find functions using multiple boolean parameters that obscure intent
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Code-Smells

**Verification:**

1. Find functions with 2+ boolean params: `grep -rn "function.*boolean.*boolean\|(.*: boolean,.*: boolean" app/ lib/ --include="*.ts" --include="*.tsx"`
2. Check call sites for readability: `processItem(true, false, true)` is unclear
3. Suggest object parameters or enums instead
4. Check for flag parameters hiding SRP violations
5. Verify boolean names clearly describe state

**Expected Output:** No functions with multiple boolean parameters; use options objects instead

**Deliverable:** Refactor boolean trap functions to use options objects

**Example Fix:**

```typescript
// Bad: Boolean trap
function createUser(isAdmin: boolean, isActive: boolean, sendEmail: boolean) {}
createUser(true, false, true); // What does this mean?

// Good: Options object
interface CreateUserOptions {
  isAdmin?: boolean;
  isActive?: boolean;
  sendEmail?: boolean;
}
function createUser(options: CreateUserOptions) {}
createUser({ isAdmin: true, sendEmail: true }); // Clear intent
```

---

### [QA-037] Verify Enum Safety

**Description:** Ensure enums have explicit values to prevent ordering issues
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-TypeScript

**Verification:**

1. Find all enums: `grep -rn "^enum \|export enum " app/ lib/ types/ --include="*.ts"`
2. Check each enum has explicit values (not auto-numbered)
3. Verify no mixed string/number enums
4. Check if const enums could be used (better tree-shaking)
5. Consider if union types would be more appropriate

**Expected Output:** All enums have explicit values; const enums where possible

**Deliverable:** Add explicit values to enums or convert to union types

**Example Fix:**

```typescript
// Bad: Auto-numbered enum (breaks if order changes)
enum Status {
  Pending,
  Active,
  Completed,
}

// Good: Explicit values
enum Status {
  Pending = 'pending',
  Active = 'active',
  Completed = 'completed',
}

// Better: Union type (fully tree-shakeable)
type Status = 'pending' | 'active' | 'completed';
```

---

### [QA-038] Audit Primitive Obsession

**Description:** Find functions with many primitive parameters that should be grouped
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Code-Smells

**Verification:**

1. Find functions with 4+ parameters: `grep -rn "function.*,.*,.*,.*,.*," app/ lib/ --include="*.ts" --include="*.tsx"`
2. Look for related primitives that should be grouped (userId, userName, userEmail)
3. Check for "data clumps" - same params appearing together repeatedly
4. Verify domain concepts use types, not raw primitives
5. Suggest value objects for related data

**Expected Output:** Functions have ≤3 parameters; related data grouped into types

**Deliverable:** Extract parameter groups to domain types

**Example Fix:**

```typescript
// Bad: Primitive obsession
function processItem(
  name: string,
  category: string,
  score: number,
  rank: number,
  userId: string
) {}

// Good: Domain types
interface ItemData {
  name: string;
  category: Category;
  metrics: MetricsInfo;
}
function processItem(item: ItemData, userId: string) {}
```

---

### [QA-039] Verify Function Purity (Side Effects)

**Description:** Identify functions that mutate parameters or global state
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** QA-Architecture

**Verification:**

1. Find array mutations: `grep -rn "\.push(\|\.splice(\|\.pop(\|\.shift(\|\.unshift(" app/ lib/ --include="*.ts" --include="*.tsx"`
2. Find object mutations: `grep -rn "Object.assign(\|delete \w\+\.\|\.prototype\." app/ lib/ --include="*.ts"`
3. Check functions don't mutate parameters (use spread/immutable patterns)
4. Verify pure functions clearly labeled (no hidden I/O)
5. Check for global state mutations (window, document, module-level vars)

**Expected Output:** Functions are pure where possible; mutations explicit and documented

**Deliverable:** Refactor impure functions to use immutable patterns

**Example Fix:**

```typescript
// Bad: Mutates parameter
function addTag(item: Item, tag: string) {
  item.tags.push(tag); // Mutation!
  return item;
}

// Good: Returns new object
function addTag(item: Item, tag: string): Item {
  return { ...item, tags: [...item.tags, tag] };
}
```

---

### [QA-040] Audit Law of Demeter Violations

**Description:** Find "train wrecks" - method chains that violate encapsulation
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Architecture

**Verification:**

1. Find deep property access: `grep -rn "\.\w\+\.\w\+\.\w\+\.\w\+" app/ lib/ --include="*.ts" --include="*.tsx"`
2. Check for accessing nested properties directly (>2 levels)
3. Verify objects expose behavior, not data
4. Check for "tell, don't ask" violations
5. Identify candidates for encapsulation

**Expected Output:** Maximum 2 levels of chaining; deeper access encapsulated

**Deliverable:** Identify Law of Demeter violations with refactoring suggestions

**Example Fix:**

```typescript
// Bad: Train wreck
const status = user.profile.items[0].analysis.statusClassification;

// Good: Encapsulated
const status = user.getLatestItemStatus();
// or
const status = itemService.getStatusForUser(userId);
```

---

### [QA-041] Verify Open-Closed Principle

**Description:** Find type switching that should use polymorphism
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-SOLID

**Verification:**

1. Find type switches: `grep -rn "if.*typeof\|if.*instanceof" app/ lib/ --include="*.ts" --include="*.tsx" -A 3`
2. Find switch on type/kind: `grep -rn "switch.*type\|switch.*kind" app/ lib/ --include="*.ts" --include="*.tsx"`
3. Check if new types would require modifying existing code
4. Verify strategy pattern for varying algorithms
5. Check for factory pattern hiding construction logic

**Expected Output:** Adding new types doesn't require editing existing code

**Deliverable:** Identify OCP violations with polymorphism suggestions

**Example Fix:**

```typescript
// Bad: Type switching (must edit for new types)
function processCategory(category: string) {
  if (category === 'a') {
    /* ... */
  } else if (category === 'b') {
    /* ... */
  } else if (category === 'c') {
    /* ... */
  }
}

// Good: Polymorphism (extend without editing)
interface CategoryProcessor {
  process(data: ItemData): void;
}
const processors: Record<Category, CategoryProcessor> = {
  a: new CategoryAProcessor(),
  b: new CategoryBProcessor(),
  c: new CategoryCProcessor(),
};
```

---

### [QA-042] Audit Liskov Substitution Principle

**Description:** Find subtype violations (downcasting, NotImplementedError)
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-SOLID

**Verification:**

1. Find explicit casting: `grep -rn " as [A-Z]\w\+" app/ lib/ --include="*.ts" --include="*.tsx" | grep -v "import\|unknown\|const"`
2. Find NotImplemented patterns: `grep -rn "throw.*not.*implement\|NotImplemented" app/ lib/ --include="*.ts"`
3. Check for runtime type checks on polymorphic calls
4. Verify subtypes don't weaken preconditions
5. Verify interface implementations are complete (no stubs)

**Expected Output:** Subtypes fully substitutable for base types; no downcasting needed

**Deliverable:** Identify LSP violations with proper abstraction suggestions

---

### [QA-043] Verify Interface Segregation Principle

**Description:** Find "fat interfaces" that force implementations to stub methods
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-SOLID

**Verification:**

1. Find interfaces: `grep -rn "^interface \|export interface " app/ lib/ types/ --include="*.ts"`
2. Check interfaces with >5 methods (potential ISP violation)
3. Look for optional methods that should be separate interfaces
4. Verify implementations use all interface methods
5. Check for `throw new Error('Not implemented')` in implementations

**Expected Output:** Interfaces small and focused; clients don't depend on unused methods

**Deliverable:** Identify fat interfaces with split recommendations

**Example Fix:**

```typescript
// Bad: Fat interface
interface UserService {
  getUser(id: string): User;
  createUser(data: UserData): User;
  deleteUser(id: string): void;
  sendEmail(id: string, message: string): void;
  exportData(id: string): Buffer;
}

// Good: Segregated interfaces
interface UserReader {
  getUser(id: string): User;
}
interface UserWriter {
  createUser(data: UserData): User;
  deleteUser(id: string): void;
}
interface UserNotifier {
  sendEmail(id: string, message: string): void;
}
interface UserExporter {
  exportData(id: string): Buffer;
}
```

---

### [QA-044] Audit Error Context Quality

**Description:** Ensure errors include sufficient context for debugging
**Severity:** HIGH
**Auto-fixable:** YES
**Parallel Group:** QA-Reliability

**Verification:**

1. Find empty catch blocks: `grep -rn "catch.*{[\s]*}" app/ lib/ --include="*.ts" --include="*.tsx"`
2. Find generic error throws: `grep -rn 'throw new Error("Error")\|throw new Error("")' app/ lib/ --include="*.ts"`
3. Check errors include relevant IDs, values, context
4. Verify error messages describe what failed
5. Check user-facing errors are actionable

**Expected Output:** All errors include context (IDs, values); no generic "Error occurred"

**Deliverable:** Add context to generic errors

**Example Fix:**

```typescript
// Bad: Generic error
catch (error) {
  throw new Error('Failed to process');
}

// Good: Contextual error
catch (error) {
  throw new Error(`Failed to process item ${itemId}: ${error instanceof Error ? error.message : 'Unknown error'}`);
}
```

---

### [QA-045] Verify Guard Clauses Pattern

**Description:** Ensure early returns used to reduce nesting
**Severity:** MEDIUM
**Auto-fixable:** YES
**Parallel Group:** QA-Readability

**Verification:**

1. Find deeply nested if/else: review files flagged by QA-012 (deep nesting)
2. Check for guard clauses at function start
3. Verify happy path not deeply nested
4. Look for inverted conditions that could be guards
5. Check for pyramid-shaped code (indent drift)

**Expected Output:** Functions use early returns; happy path at lowest indent level

**Deliverable:** Refactor nested conditions to guard clauses

**Example Fix:**

```typescript
// Bad: Deep nesting
function processItem(item: Item | null) {
  if (item) {
    if (item.isValid) {
      if (item.category) {
        // actual logic buried here
        return analyzeItem(item);
      }
    }
  }
  return null;
}

// Good: Guard clauses
function processItem(item: Item | null) {
  if (!item) return null;
  if (!item.isValid) return null;
  if (!item.category) return null;

  return analyzeItem(item);
}
```

---

### [QA-046] Audit Command-Query Separation

**Description:** Find functions that both change state AND return values
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Architecture

**Verification:**

1. Find functions returning values that also mutate: manual review
2. Check for methods that modify state and return status
3. Verify commands (void) separate from queries (return value)
4. Look for boolean returns indicating mutation success
5. Check for `getXAndDoY` or `fetchXAndUpdate` patterns

**Expected Output:** Commands have no return; queries have no side effects

**Deliverable:** Identify CQS violations with split recommendations

**Example Fix:**

```typescript
// Bad: Command-query violation
function addItemAndGetCount(item: Item): number {
  items.push(item); // Command
  return items.length; // Query
}

// Good: Separated
function addItem(item: Item): void {
  items.push(item);
}
function getItemCount(): number {
  return items.length;
}
```

---

### [QA-047] Verify Technical Debt Tracking

**Description:** Ensure TODO/FIXME comments have linked issues and age tracking
**Severity:** MEDIUM
**Auto-fixable:** NO
**Parallel Group:** QA-Documentation

**Verification:**

1. Find all TODOs: `grep -rn "TODO\|FIXME\|HACK\|XXX" app/ lib/ features/ --include="*.ts" --include="*.tsx"`
2. Check if TODOs reference issue numbers: `TODO(#123)` or `TODO: [TICKET-123]`
3. Verify TODOs have creation date or git blame age
4. Check for TODOs older than 90 days (stale)
5. Verify critical TODOs have scheduled remediation

**Expected Output:** All TODOs linked to issues; stale TODOs addressed or removed

**Deliverable:** TODO audit report with linked issues and age

**Example Format:**

```typescript
// Good: Tracked TODO
// TODO(#142): Refactor to use server action after Next.js 15.1 - 2026-01-15

// Bad: Orphan TODO
// TODO: fix this later
```

---

### [QA-048] Audit API Contract Stability

**Description:** Verify public function signatures don't change unintentionally
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** QA-Architecture

**Verification:**

1. Find exported functions: `grep -rn "^export function\|^export const.*=" lib/ --include="*.ts"`
2. Check for breaking changes in recent commits: `git diff HEAD~20 -- lib/`
3. Verify parameter additions use optional/default values
4. Check return types haven't changed incompatibly
5. Verify deprecation warnings for soon-to-change APIs

**Expected Output:** Public APIs stable; breaking changes documented and communicated

**Deliverable:** API stability report with breaking change risks

---

### [QA-049] Verify Code Health Trend

**Description:** Ensure new code improves overall codebase quality (Boy Scout Rule)
**Severity:** HIGH
**Auto-fixable:** NO
**Parallel Group:** QA-Meta

**Verification:**

1. Compare recent commits' complexity: `git log --since="1 month ago" --stat`
2. Check if PRs include cleanup of surrounding code
3. Verify technical debt documented and decreasing
4. Check code quality metrics (ESLint errors, type coverage) improving
5. Verify no "quick fixes" without follow-up issues

**Expected Output:** Each PR improves code health; metrics trend positive

**Deliverable:** Code health trend report with metric history

**Tracking Metrics:**

| Metric                   | Direction | How to Measure                |
| ------------------------ | --------- | ----------------------------- | -------------- | -------- |
| TypeScript strict errors | ↓         | `pnpm type-check 2>&1         | wc -l`         |
| ESLint warnings          | ↓         | `pnpm lint 2>&1               | grep "warning" | wc -l`   |
| Test coverage            | ↑         | `pnpm test:coverage`          |
| Average file size        | →         | `find app/ lib/ -name "_.ts_" | xargs wc -l    | tail -1` |
| TODO count               | ↓         | `grep -r "TODO" app/ lib/     | wc -l`         |

---

## Summary Template

After completing audit items, generate this summary:

```markdown
## QA Audit Summary

**Date:** YYYY-MM-DD
**Auditor:** [Name/Tool]
**Scope:** [App Name] - Full Application

### Code Quality Metrics

| Metric                    | Current | Target      | Status   |
| ------------------------- | ------- | ----------- | -------- |
| `any` type usage          | X       | 0 justified | ✅/⚠️/❌ |
| Average function length   | X lines | ≤50         | ✅/⚠️/❌ |
| Average file length       | X lines | ≤300        | ✅/⚠️/❌ |
| Max cyclomatic complexity | X       | ≤10         | ✅/⚠️/❌ |
| Deep nesting (>4 levels)  | X       | 0           | ✅/⚠️/❌ |
| ESLint errors             | X       | 0           | ✅/⚠️/❌ |

### TypeScript Quality

| Metric               | Count | Status   |
| -------------------- | ----- | -------- |
| `any` types          | X     | ✅/⚠️/❌ |
| Type assertions      | X     | ✅/⚠️/❌ |
| Missing return types | X     | ✅/⚠️/❌ |
| Unsafe catch blocks  | X     | ✅/⚠️/❌ |

### Architecture Health

| Area                  | Status   | Notes          |
| --------------------- | -------- | -------------- |
| Single Responsibility | ✅/⚠️/❌ | [observations] |
| Feature Isolation     | ✅/⚠️/❌ | [observations] |
| Import Organization   | ✅/⚠️/❌ | [observations] |
| Component Size        | ✅/⚠️/❌ | [observations] |

### Findings by Severity

| Severity | Count | Auto-fixable |
| -------- | ----- | ------------ |
| CRITICAL | X     | Y            |
| HIGH     | X     | Y            |
| MEDIUM   | X     | Y            |
| LOW      | X     | Y            |
| INFO     | X     | Y            |

### Technical Debt Items

**High Priority:**

1. [Item 1] - [Impact] - [Effort]
2. [Item 2] - [Impact] - [Effort]

**Medium Priority:**

1. [Item 1]
2. [Item 2]

### Recommendations

**Immediate (Critical/High):**

1. [Finding 1] - [Impact on maintainability]
2. [Finding 2] - [Impact on maintainability]

**Short-term (Medium):**

1. [Finding 1]
2. [Finding 2]

**Long-term (Low/Info):**

1. [Finding 1]

### Next Steps

1. Address HIGH severity type safety issues
2. Refactor high-complexity functions
3. Extract duplicate code to shared utilities
4. Update ESLint rules to catch issues automatically
5. Schedule technical debt reduction sprint
```

---

## Severity Definitions

| Severity     | Definition                                            | Response Time       |
| ------------ | ----------------------------------------------------- | ------------------- |
| **CRITICAL** | Causes bugs, crashes, or major maintenance burden     | Fix immediately     |
| **HIGH**     | Significantly impacts code quality or maintainability | Fix this sprint     |
| **MEDIUM**   | Moderate impact on readability or architecture        | Fix next sprint     |
| **LOW**      | Minor style or convention issue                       | Fix when convenient |
| **INFO**     | Best practice recommendation                          | Consider for future |

---

## Auto-Fixable Criteria

**YES - Can auto-fix:**

- Replace `any` with specific types
- Add explicit return types
- Fix import organization
- Remove dead code and unused imports
- Fix formatting issues
- Remove console.log statements
- Extract magic numbers to constants
- Convert .then() to async/await

**NO - Needs decision:**

- Architectural refactoring
- Component decomposition strategy
- Feature boundary decisions
- Naming convention changes
- Complex function extraction
- Technical debt prioritization

---

## Reference Resources

### Static Analysis Tools

- [ESLint](https://eslint.org/) - Linting and code quality
- [TypeScript Compiler](https://www.typescriptlang.org/) - Type checking
- [SonarQube](https://www.sonarqube.org/) - Code quality metrics
- [CodeClimate](https://codeclimate.com/) - Maintainability analysis
- [Stryker Mutator](https://stryker-mutator.io/) - Mutation testing

### Code Quality Standards

- [Clean Code (Robert Martin)](https://www.oreilly.com/library/view/clean-code-a/9780136083238/)
- [TypeScript Best Practices](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html)
- [React TypeScript Cheatsheet](https://react-typescript-cheatsheet.netlify.app/)
- [Google Engineering Practices - Code Review](https://google.github.io/eng-practices/review/reviewer/looking-for.html)
- [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)

### SOLID Principles

- [SOLID Code Review Guide (JetBrains)](https://blog.jetbrains.com/upsource/2015/08/31/what-to-look-for-in-a-code-review-solid-principles-2/)
- [Clean Code Developer Checklist](https://github.com/dev-aritra/clean-code-developer-checklist)
- [Clean Code Summary (Gist)](https://gist.github.com/wojteklu/73c6914cc446146b8b533c0988cf8d29)

### Complexity Metrics

- [Cyclomatic Complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity)
- [Cognitive Complexity (SonarSource)](https://www.sonarsource.com/resources/cognitive-complexity/)
- [Code Smell Detection Tools](https://www.codeant.ai/blogs/10-best-code-smell-detection-tools-in-2025)
