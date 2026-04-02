/**
 * @Public()
 * 标记某个路由不需要鉴权（配合全局 JwksGuard 使用）。
 *
 * 用法：
 *   @Public()
 *   @Get('/health')
 *   health() { return 'ok'; }
 */
import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
