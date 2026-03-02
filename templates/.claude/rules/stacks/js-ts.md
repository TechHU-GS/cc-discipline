---
globs: "**/*.js,**/*.jsx,**/*.ts,**/*.tsx,**/*.mjs,**/*.cjs,**/package.json,**/tsconfig.json"
description: "JS/TS 规则 — 编辑 JavaScript/TypeScript 文件时自动注入"
---

## JavaScript / TypeScript 工作纪律

### 类型安全
- TypeScript 项目：不要用 `any` 逃避类型系统 — 用 `unknown` + type guard
- 修改接口（interface/type）时，确认所有使用处都适配
- 新代码优先用 TypeScript 严格模式

### 异步处理
- 所有 async 调用必须有错误处理（try/catch 或 .catch）
- 注意 Promise 的并发 — `Promise.all` vs `Promise.allSettled` 的选择要有意识
- 避免 callback hell — 如果超过 2 层嵌套，重构为 async/await

### 前端特有
- 组件修改前确认 props 接口和 state 管理方式
- 不要直接操作 DOM（在 React/Vue 项目中）
- 样式修改要考虑响应式和其他组件的影响

### 禁止事项
- 禁止 `// @ts-ignore` 除非有详细注释说明为什么
- 禁止在不理解构建配置的情况下修改 webpack/vite/next 配置
- 禁止引入新的全局状态而不说明理由
