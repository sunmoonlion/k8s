/**
 * @CurrentUser()
 * 从 request.user 取出 JWT payload，注入到路由方法参数。
 *
 * 用法：
 *   @Get('/profile')
 *   getProfile(@CurrentUser() user: JwtPayload) {
 *     return { userId: user.sub, role: user.role };
 *   }
 *
 *   // 只取某个字段
 *   @Get('/me')
 *   me(@CurrentUser('sub') userId: string) { ... }
 */
import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { JwtPayload } from './jwks.guard';

export const CurrentUser = createParamDecorator(
  (field: keyof JwtPayload | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user: JwtPayload = request.user;
    return field ? user?.[field] : user;
  },
);
