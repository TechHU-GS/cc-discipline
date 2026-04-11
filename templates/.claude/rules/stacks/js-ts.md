## JavaScript / TypeScript Discipline

### Type Safety
- TypeScript projects: don't use `any` to escape the type system — use `unknown` + type guard
- When modifying interfaces (interface/type), confirm all usage sites are adapted
- New code should prefer TypeScript strict mode

### Async Handling
- All async calls must have error handling (try/catch or .catch)
- Be intentional about Promise concurrency — `Promise.all` vs `Promise.allSettled` is a deliberate choice
- Avoid callback hell — if nesting exceeds 2 levels, refactor to async/await

### Frontend Specific
- Before modifying a component, confirm props interface and state management approach
- Don't directly manipulate the DOM (in React/Vue projects)
- Style changes must consider responsiveness and impact on other components

### Prohibited
- No `// @ts-ignore` unless accompanied by a detailed comment explaining why
- No modifying webpack/vite/next config without understanding the build configuration
- No introducing new global state without stating the justification
