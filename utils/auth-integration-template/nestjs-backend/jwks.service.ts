/**
 * JwksService
 * 从 auth-app JWKS 端点拉取公钥并缓存（TTL 10 分钟）。
 * 供 JwksGuard 调用，不直接暴露给业务代码。
 *
 * 依赖：
 *   npm install jose @nestjs/config
 */
import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface JwksCache {
  keys: any[];
  fetchedAt: number;
}

const JWKS_TTL_MS = 10 * 60 * 1000; // 10 分钟

@Injectable()
export class JwksService implements OnModuleInit {
  private cache: JwksCache = { keys: [], fetchedAt: 0 };

  constructor(private readonly config: ConfigService) {}

  async onModuleInit() {
    // 启动时预热缓存，避免第一个请求慢
    await this.getKeys();
  }

  async getKeys(): Promise<any[]> {
    if (this.cache.keys.length && Date.now() - this.cache.fetchedAt < JWKS_TTL_MS) {
      return this.cache.keys;
    }

    const jwksUrl = this.config.getOrThrow<string>('AUTH_JWKS_URL');
    const resp = await fetch(jwksUrl, { signal: AbortSignal.timeout(5000) });
    if (!resp.ok) throw new Error(`JWKS fetch failed: ${resp.status}`);

    const { keys } = await resp.json();
    this.cache = { keys: keys ?? [], fetchedAt: Date.now() };
    return this.cache.keys;
  }
}
