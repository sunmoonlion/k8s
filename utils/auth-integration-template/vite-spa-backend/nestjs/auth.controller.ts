/**
 * AuthController — vite-spa BFF OAuth 端点
 *
 * 路由前缀 /api/auth（在 AuthModule 中配置）：
 *   GET  /api/auth/login     → 重定向到 auth-app 登录页
 *   POST /api/auth/callback  → SPA 换 token，写 Redis session + Cookie
 *   GET  /api/auth/me        → 返回当前用户信息
 *   POST /api/auth/logout    → 撤销 token，清 Redis + Cookie
 *
 * 接入新 app 时修改：
 *   - 环境变量（见 config_example.ts）
 *   - SESSION_COOKIE 改为本 app 的名字
 */
import {
  Body,
  Controller,
  Get,
  HttpException,
  HttpStatus,
  Post,
  Req,
  Res,
} from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { Request, Response } from 'express'
import { randomBytes, createHash } from 'crypto'
import { randomUUID } from 'crypto'
import fetch from 'node-fetch'
import { URLSearchParams } from 'url'
import { SessionService, OAuthSession } from './session.service'

class CallbackDto {
  code:  string
  state: string
}

@Controller('api/auth')
export class AuthController {
  private readonly authBackendUrl:  string
  private readonly clientId:        string
  private readonly clientSecret:    string
  private readonly redirectUri:     string
  private readonly audience:        string
  private readonly sessionCookie:   string
  private readonly pkceCookie = 'oidc_pkce'
  private readonly isProd: boolean

  constructor(
    private readonly config:  ConfigService,
    private readonly session: SessionService,
  ) {
    this.authBackendUrl = config.getOrThrow('AUTH_BACKEND_URL')
    this.clientId       = config.getOrThrow('AUTH_CLIENT_ID')
    this.clientSecret   = config.get('AUTH_CLIENT_SECRET', '')
    this.redirectUri    = config.getOrThrow('AUTH_REDIRECT_URI')
    this.audience       = config.get('AUTH_JWT_AUDIENCE', 'myapp-api')    // ← 修改
    this.sessionCookie  = config.get('AUTH_SESSION_COOKIE', 'myapp_session') // ← 修改
    this.isProd         = config.get('NODE_ENV') === 'production'
  }

  // ─────────────── PKCE 工具 ───────────────

  private pkceVerifier(): string {
    return randomBytes(32).toString('base64url')
  }

  private pkceChallenge(verifier: string): string {
    return createHash('sha256').update(verifier).digest('base64url')
  }

  // ─────────────── GET /api/auth/login ───────────────

  @Get('login')
  async login(@Res() res: Response): Promise<void> {
    const verifier  = this.pkceVerifier()
    const challenge = this.pkceChallenge(verifier)
    const state     = randomBytes(32).toString('base64url')
    const pkceId    = randomUUID()

    await this.session.setPkce(pkceId, { state, verifier })

    const params = new URLSearchParams({
      response_type:         'code',
      client_id:             this.clientId,
      redirect_uri:          this.redirectUri,
      scope:                 'openid profile email',
      state,
      code_challenge:        challenge,
      code_challenge_method: 'S256',
      aud:                   this.audience,
    })

    res.cookie(this.pkceCookie, pkceId, {
      httpOnly: true,
      sameSite: 'lax',
      maxAge:   300 * 1000,
      secure:   this.isProd,
    })
    res.redirect(`${this.authBackendUrl}/authorize?${params}`)
  }

  // ─────────────── POST /api/auth/callback ───────────────

  @Post('callback')
  async callback(
    @Body()           body: CallbackDto,
    @Req()            req:  Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ ok: boolean }> {
    const pkceId = req.cookies[this.pkceCookie]
    if (!pkceId) throw new HttpException('missing pkce cookie', HttpStatus.BAD_REQUEST)

    const pkce = await this.session.getPkce(pkceId)
    if (!pkce) throw new HttpException('pkce session expired', HttpStatus.BAD_REQUEST)
    await this.session.deletePkce(pkceId)

    if (pkce.state !== body.state) throw new HttpException('state mismatch', HttpStatus.BAD_REQUEST)

    // code 换 token
    const tokenRes = await fetch(`${this.authBackendUrl}/token`, {
      method:  'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body:    new URLSearchParams({
        grant_type:    'authorization_code',
        code:          body.code,
        redirect_uri:  this.redirectUri,
        client_id:     this.clientId,
        client_secret: this.clientSecret,
        code_verifier: pkce.verifier,
        audience:      this.audience,
      }).toString(),
    })
    if (!tokenRes.ok) {
      const err: any = await tokenRes.json().catch(() => ({}))
      throw new HttpException(
        err.error_description ?? 'token exchange failed',
        HttpStatus.BAD_GATEWAY,
      )
    }
    const tokenData: any = await tokenRes.json()

    const sessionId: string = randomUUID()
    const oauthSession: OAuthSession = {
      access_token:  tokenData.access_token,
      refresh_token: tokenData.refresh_token ?? null,
      expires_at:    Date.now() + (tokenData.expires_in ?? 900) * 1000,
    }
    await this.session.setSession(sessionId, oauthSession)

    res.cookie(this.sessionCookie, sessionId, {
      httpOnly: true,
      sameSite: 'lax',
      maxAge:   7 * 24 * 3600 * 1000,
      path:     '/',
      secure:   this.isProd,
    })
    res.clearCookie(this.pkceCookie)
    return { ok: true }
  }

  // ─────────────── GET /api/auth/me ───────────────

  @Get('me')
  async me(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<unknown> {
    const sessionId = req.cookies[this.sessionCookie]
    if (!sessionId) throw new HttpException('not authenticated', HttpStatus.UNAUTHORIZED)

    let oauthSession = await this.session.getSession(sessionId)
    if (!oauthSession) throw new HttpException('session expired', HttpStatus.UNAUTHORIZED)

    // access_token 不足 60 秒时自动刷新
    if (oauthSession.expires_at - Date.now() < 60_000 && oauthSession.refresh_token) {
      const refreshed = await this.tryRefresh(sessionId, oauthSession)
      if (!refreshed) {
        res.clearCookie(this.sessionCookie, { path: '/' })
        throw new HttpException('session refresh failed', HttpStatus.UNAUTHORIZED)
      }
      oauthSession = refreshed
    }

    const userRes = await fetch(`${this.authBackendUrl}/auth/me`, {
      headers: { Authorization: `Bearer ${oauthSession.access_token}` },
    })
    if (userRes.status === 401) {
      await this.session.deleteSession(sessionId)
      throw new HttpException('token invalid', HttpStatus.UNAUTHORIZED)
    }
    if (!userRes.ok) throw new HttpException('upstream error', HttpStatus.BAD_GATEWAY)

    return userRes.json()
  }

  // ─────────────── POST /api/auth/logout ───────────────

  @Post('logout')
  async logout(
    @Req() req: Request,
    @Res({ passthrough: true }) res: Response,
  ): Promise<{ ok: boolean }> {
    const sessionId = req.cookies[this.sessionCookie]
    if (sessionId) {
      const oauthSession = await this.session.getSession(sessionId)
      if (oauthSession?.refresh_token) {
        // 尽力而为，失败不阻断
        await fetch(`${this.authBackendUrl}/logout`, {
          method:  'POST',
          headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
          body:    new URLSearchParams({
            client_id:     this.clientId,
            client_secret: this.clientSecret,
            refresh_token: oauthSession.refresh_token,
          }).toString(),
        }).catch(() => {})
      }
      await this.session.deleteSession(sessionId)
    }

    res.clearCookie(this.sessionCookie, { path: '/' })
    return { ok: true }
  }

  // ─────────────── 私有：刷新 access_token ───────────────

  private async tryRefresh(
    sessionId: string,
    current: OAuthSession,
  ): Promise<OAuthSession | null> {
    try {
      const res = await fetch(`${this.authBackendUrl}/token`, {
        method:  'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body:    new URLSearchParams({
          grant_type:    'refresh_token',
          refresh_token: current.refresh_token!,
          client_id:     this.clientId,
          client_secret: this.clientSecret,
          audience:      this.audience,
        }).toString(),
      })
      if (!res.ok) {
        await this.session.deleteSession(sessionId)
        return null
      }
      const data: any = await res.json()
      const updated: OAuthSession = {
        access_token:  data.access_token,
        refresh_token: data.refresh_token ?? current.refresh_token,
        expires_at:    Date.now() + (data.expires_in ?? 900) * 1000,
      }
      await this.session.setSession(sessionId, updated)
      return updated
    } catch {
      await this.session.deleteSession(sessionId)
      return null
    }
  }
}
