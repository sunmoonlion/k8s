/**
 * JwksGuard
 * 全局（或按需）的 JWT 验签 Guard。
 * 验证通过后将 payload 写入 request.user，供 @CurrentUser() 取用。
 *
 * 用法一：全局启用（推荐），配合 @Public() 跳过不需鉴权的路由
 *   // main.ts 或 AppModule
 *   app.useGlobalGuards(app.get(JwksGuard));
 *
 * 用法二：按 Controller / 路由启用
 *   @UseGuards(JwksGuard)
 *   @Get('/profile')
 *   getProfile(@CurrentUser() user: JwtPayload) { ... }
 */
import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { Request } from 'express';
import { importJWK, jwtVerify } from 'jose';
import { JwksService } from './jwks.service';
import { IS_PUBLIC_KEY } from './public.decorator';

export interface JwtPayload {
  sub: string;        // 用户 ID（字符串）
  role: string;       // 'user' | 'admin'
  scope: string;
  iss: string;
  aud: string | string[];
  iat: number;
  exp: number;
  [key: string]: unknown;
}

@Injectable()
export class JwksGuard implements CanActivate {
  constructor(
    private readonly jwks: JwksService,
    private readonly config: ConfigService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    // @Public() 标记的路由直接放行
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<Request>();
    const token = this.extractToken(request);
    if (!token) throw new UnauthorizedException('Missing Bearer token');

    const payload = await this.verifyToken(token);
    (request as any).user = payload;
    return true;
  }

  private extractToken(request: Request): string | undefined {
    const auth = request.headers.authorization ?? '';
    if (auth.startsWith('Bearer ')) return auth.slice('Bearer '.length);
    return undefined;
  }

  private async verifyToken(token: string): Promise<JwtPayload> {
    const keys = await this.jwks.getKeys();
    if (!keys.length) throw new UnauthorizedException('JWKS unavailable');

    const issuer = this.config.get<string>('AUTH_JWT_ISSUER');
    const audience = this.config.get<string>('AUTH_JWT_AUDIENCE');

    // 尝试每把公钥，找到能验签的那把（支持密钥轮换）
    const errors: string[] = [];
    for (const jwk of keys) {
      try {
        const publicKey = await importJWK(jwk, 'RS256');
        const { payload } = await jwtVerify(token, publicKey, {
          algorithms: ['RS256'],
          ...(issuer ? { issuer } : {}),
          ...(audience ? { audience } : {}),
        });
        return payload as unknown as JwtPayload;
      } catch (e: any) {
        errors.push(e.message);
      }
    }

    throw new UnauthorizedException(`Token verification failed: ${errors[0]}`);
  }
}
