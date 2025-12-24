# 兼容策略代码分析报告

## 概述

本文档分析了各个项目中存在的兼容策略相关代码，以便在实施 Session + Cookie 方案时进行清理。

---

## 一、auth-app-bff（NestJS）

### 1.1 兼容旧接口

**位置**：
- `src/auth/auth.service.ts` (797-819 行)
- `src/auth/auth.controller.ts` (320-338 行)

**代码**：
```typescript
// ==================== 兼容旧接口 ====================

/**
 * 兼容旧的 signin 接口
 * POST /auth/signin
 */
@Post('auth/signin')
async signin(@Body() dto: OAuthLoginDto) {
  return this.authService.signin(dto.username, dto.password);
}

/**
 * 兼容旧的 signup 接口
 * POST /auth/signup
 */
@Post('auth/signup')
async signup(@Body() dto: OAuthLoginDto) {
  return this.authService.signup(dto.username, dto.password);
}
```

**说明**：
- 这些接口是为了兼容旧的 API 路径（`/auth/signin` 和 `/auth/signup`）
- 实际功能与新的 `/login/oauth` 和 `/users/` 相同
- **建议**：由于是首次开发，可以**删除**这些兼容接口

---

## 二、auth-app-ssr（Nuxt 3）

### 2.1 Token Store（整个项目基于 JWT Token）

**位置**：
- `stores/tokens.ts` - Token 存储管理
- `api/core.ts` - API 调用核心（设置 Bearer Token header）
- `api/auth.ts` - 所有认证相关 API 调用
- `stores/auth.ts` - 使用 Token Store

**关键代码**：

#### `stores/tokens.ts`
```typescript
export const useTokenStore = defineStore("tokens", {
  state: (): ITokenResponse => ({
    access_token: "",
    refresh_token: "",
    token_type: ""
  }),
  persist: true,  // 持久化到 localStorage/cookie
  // ...
  actions: {
    async getTokens(payload: { username: string; password?: string }) {
      // 获取 token 并存储
    },
    async refreshTokens() {
      // 刷新 token
    },
    // ...
  }
});
```

#### `api/core.ts`
```typescript
export const apiCore = {
  headers(token: string) {
    return {
      "Cache-Control": "no-cache",
      Authorization: `Bearer ${token}`  // 所有 API 调用都使用 Bearer Token
    }
  }
}
```

#### `api/auth.ts`
所有 API 调用都使用 `apiCore.headers(token)` 设置 Authorization header：
```typescript
async getProfile(token: string) {
  return await useFetch<IUserProfile>(`${apiCore.url()}/users/`, {
    headers: apiCore.headers(token)  // 使用 Bearer Token
  });
}
```

**说明**：
- 这不是兼容策略，而是**当前的实现方式**
- 整个 SSR 项目都基于 JWT Token 机制
- **需要完全重构**：移除 Token Store，改为使用 Cookie

---

## 三、incubator-app-bff（Python/FastAPI）

### 3.1 认证相关代码

**位置**：
- `app/core/auth_client.py` - 调用 auth-app-bff 的客户端
- `app/api/deps.py` - 依赖注入，从 Bearer Token 获取用户

**关键代码**：

#### `app/core/auth_client.py`
```python
class AuthClient:
    async def get_user_by_token(self, token: str) -> Dict[str, Any]:
        """从认证服务获取用户信息（使用 Bearer Token）"""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/auth/me",
                headers={"Authorization": f"Bearer {token}"},  # 使用 Bearer Token
                timeout=5.0
            )
            return response.json()
```

#### `app/api/deps.py`
```python
async def get_current_user(
    token: Annotated[str, Depends(reusable_oauth2)]  # 从 Authorization header 提取 token
) -> Dict[str, Any]:
    user = await auth_client.get_user_by_token(token)  # 使用 Bearer Token 调用 auth-app-bff
    return user
```

**说明**：
- 这不是兼容策略，而是**当前的实现方式**
- 使用 Bearer Token 调用 `auth-app-bff` 的 `/auth/me` 接口
- **需要改造**：改为从 Cookie 读取并转发

---

## 四、llmops-app-bff（Python/FastAPI）

### 4.1 认证相关代码

**位置**：
- `app/core/auth_client.py` - 调用 auth-app-bff 的客户端
- `app/api/deps.py` - 依赖注入，从 Bearer Token 获取用户

**关键代码**：

#### `app/core/auth_client.py`
```python
class AuthClient:
    async def get_user_by_token(self, token: str) -> Dict[str, Any]:
        """从认证服务获取用户信息（使用 Bearer Token）"""
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/auth/me",
                headers={"Authorization": f"Bearer {token}"},  # 使用 Bearer Token
                timeout=5.0
            )
            return response.json()
```

#### `app/api/deps.py`
```python
async def get_current_user(
    token: Annotated[str, Depends(reusable_oauth2)]  # 从 Authorization header 提取 token
) -> Dict[str, Any]:
    user = await auth_client.get_user_by_token(token)  # 使用 Bearer Token 调用 auth-app-bff
    return user
```

**说明**：
- 与 `incubator-app-bff` 相同，使用 Bearer Token 机制
- **需要改造**：改为从 Cookie 读取并转发

---

## 五、incubator-app-ssr 和 llmops-app-ssr

**说明**：
- 未找到相关代码（可能还未实现或使用不同的认证方式）
- 需要进一步确认

---

## 六、总结

### 6.1 实际存在的兼容代码（需要删除）

**只有 auth-app-bff 有明确的兼容代码**：

| 项目 | 位置 | 代码 | 操作 |
|------|------|------|------|
| **auth-app-bff** | `src/auth/auth.controller.ts` | `/auth/signin` 和 `/auth/signup` 接口 | **删除**（明确的兼容旧接口代码） |
| **auth-app-bff** | `src/auth/auth.service.ts` | `signin()` 和 `signup()` 方法 | **删除**（明确的兼容旧接口代码） |

### 6.2 不符合新架构的代码（需要重构/改造）

**这些不是兼容代码，只是当前实现不符合新的 Session + Cookie 架构**：

| 项目 | 位置 | 当前实现 | 需要改造 |
|------|------|----------|----------|
| **auth-app-ssr** | `stores/tokens.ts` | Token Store 管理 JWT | **完全重构**：删除 Token Store |
| **auth-app-ssr** | `api/core.ts` | `Authorization: Bearer ${token}` | **完全重构**：移除 Bearer Token，使用 Cookie |
| **auth-app-ssr** | `api/auth.ts` | 所有 API 调用使用 Bearer Token | **完全重构**：改为使用 `credentials: 'include'` |
| **auth-app-ssr** | `stores/auth.ts` | 使用 `tokenStore.token` | **完全重构**：移除所有 token 相关代码 |
| **incubator-app-bff** | `app/core/auth_client.py` | 使用 Bearer Token 调用 auth-app-bff | **改造**：改为从 Cookie 读取并转发 |
| **incubator-app-bff** | `app/api/deps.py` | 从 Authorization header 提取 token | **改造**：改为从 Cookie 读取 |
| **llmops-app-bff** | `app/core/auth_client.py` | 使用 Bearer Token 调用 auth-app-bff | **改造**：改为从 Cookie 读取并转发 |
| **llmops-app-bff** | `app/api/deps.py` | 从 Authorization header 提取 token | **改造**：改为从 Cookie 读取 |

---

## 七、分类说明

### 7.1 兼容代码 vs 当前实现

**关键区别**：

1. **兼容代码**（auth-app-bff）：
   - 明确的兼容旧接口的代码
   - 注释中标注了"兼容旧接口"
   - 功能与新的接口重复（`/auth/signin` vs `/login/oauth`）
   - **操作**：直接删除

2. **当前实现**（其他项目）：
   - 不是兼容代码，而是当前的实现方式
   - 使用 JWT Token / Bearer Token 机制
   - 不符合新的 Session + Cookie 架构
   - **操作**：重构/改造为新架构

### 7.2 改造范围

**需要删除的代码**（兼容代码）：
- ✅ auth-app-bff: `/auth/signin` 和 `/auth/signup` 接口

**需要重构的代码**（不符合新架构）：
- ✅ auth-app-ssr: 整个 Token Store 机制
- ✅ incubator-app-bff: Bearer Token 认证方式
- ✅ llmops-app-bff: Bearer Token 认证方式

---

## 八、注意事项

1. **兼容代码（auth-app-bff）**：
   - `/auth/signin` 和 `/auth/signup` 是明确的兼容接口，可以删除
   - 由于是首次开发，不需要保留这些兼容接口
   - 删除前需要确认是否有其他系统或客户端在使用这些接口（但根据用户说明，这是首次开发，应该没有）

2. **当前实现（其他项目）**：
   - 这些不是兼容代码，只是当前实现不符合新架构
   - 需要按照新架构进行重构/改造
   - 工作量较大，需要系统性的改造

3. **改造原则**：
   - 兼容代码：直接删除
   - 当前实现：重构为新架构（Session + Cookie）

---

## 九、待确认事项

- [ ] 是否有其他系统或客户端在使用 `/auth/signin` 和 `/auth/signup` 接口？
- [ ] `incubator-app-ssr` 和 `llmops-app-ssr` 的认证实现方式是什么？
- [ ] 是否有其他隐藏的兼容策略代码？

