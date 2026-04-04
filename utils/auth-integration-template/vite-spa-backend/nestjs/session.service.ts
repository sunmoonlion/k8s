/**
 * SessionService — Redis session 管理（vite-spa BFF 模式）
 *
 * 负责：PKCE 临时存储、OAuth session 读写刷新
 */
import { Injectable } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { createClient } from 'redis'

export interface OAuthSession {
  access_token:  string
  refresh_token: string | null
  expires_at:    number   // ms since epoch
}

export interface PkceEntry {
  state:    string
  verifier: string
}

@Injectable()
export class SessionService {
  private readonly redis: ReturnType<typeof createClient>

  constructor(private readonly config: ConfigService) {
    this.redis = createClient({ url: config.get<string>('REDIS_URL', 'redis://localhost:6379/0') })
    this.redis.connect()
  }

  private sessionKey(id: string) { return `bff:sessions:${id}` }
  private pkceKey(id: string)    { return `bff:pkce:${id}` }

  async getSession(id: string): Promise<OAuthSession | null> {
    const raw = await this.redis.get(this.sessionKey(id))
    return raw ? JSON.parse(raw) : null
  }

  async setSession(id: string, session: OAuthSession, ttlSeconds = 7 * 24 * 3600): Promise<void> {
    await this.redis.setEx(this.sessionKey(id), ttlSeconds, JSON.stringify(session))
  }

  async deleteSession(id: string): Promise<void> {
    await this.redis.del(this.sessionKey(id))
  }

  async setPkce(id: string, entry: PkceEntry): Promise<void> {
    await this.redis.setEx(this.pkceKey(id), 300, JSON.stringify(entry))
  }

  async getPkce(id: string): Promise<PkceEntry | null> {
    const raw = await this.redis.get(this.pkceKey(id))
    return raw ? JSON.parse(raw) : null
  }

  async deletePkce(id: string): Promise<void> {
    await this.redis.del(this.pkceKey(id))
  }
}
