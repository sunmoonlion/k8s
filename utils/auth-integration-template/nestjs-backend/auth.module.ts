/**
 * AuthModule
 * 将 JwksService 和 JwksGuard 注册为可导出的模块。
 *
 * 接入步骤：
 * 1. 把此目录下的文件复制到项目的 src/auth/ 目录
 * 2. 在 AppModule 中导入 AuthModule
 * 3. 在 main.ts 中启用全局 Guard（见下方注释）
 * 4. 在 .env 中设置三个环境变量（见 config_example.ts）
 *
 * main.ts 全局启用示例：
 *   import { JwksGuard } from './auth/jwks.guard';
 *   const app = await NestFactory.create(AppModule);
 *   app.useGlobalGuards(app.get(JwksGuard));  // 需要 APP_GUARD provider 或直接 get
 *
 * 或者在 AppModule providers 中注册为全局 Guard（推荐，支持 DI）：
 *   providers: [{ provide: APP_GUARD, useClass: JwksGuard }]
 */
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { JwksService } from './jwks.service';
import { JwksGuard } from './jwks.guard';

@Module({
  imports: [ConfigModule],
  providers: [JwksService, JwksGuard],
  exports: [JwksService, JwksGuard],
})
export class AuthModule {}
