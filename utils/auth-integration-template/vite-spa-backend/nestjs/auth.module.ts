/**
 * AuthModule — vite-spa BFF 鉴权模块
 *
 * 在 AppModule 中导入：
 *   @Module({ imports: [ConfigModule.forRoot({ isGlobal: true }), AuthModule] })
 *   export class AppModule {}
 */
import { Module } from '@nestjs/common'
import { ConfigModule } from '@nestjs/config'
import { AuthController } from './auth.controller'
import { SessionService } from './session.service'

@Module({
  imports:     [ConfigModule],
  controllers: [AuthController],
  providers:   [SessionService],
  exports:     [SessionService],
})
export class AuthModule {}
