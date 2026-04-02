/**
 * NestJS 接入 auth-app 所需的环境变量。
 * 在 .env 或 K8s Secret 中设置，通过 @nestjs/config 的 ConfigService 读取。
 *
 * 与 Flask / FastAPI 版本变量名完全一致（方便跨服务统一）。
 */

// .env 示例（复制到项目根目录）
/*
# auth-app JWT 验签配置
AUTH_JWKS_URL=http://localhost:3030/api/v1/jwks
AUTH_JWT_ISSUER=http://localhost:3030/api/v1
AUTH_JWT_AUDIENCE=myapp-api
*/

// 在 AppModule 中加载（已有 ConfigModule 则跳过）：
//
// @Module({
//   imports: [
//     ConfigModule.forRoot({ isGlobal: true }),
//     AuthModule,
//     ...
//   ],
// })
// export class AppModule {}

// ConfigService 读取示例（在 Service 内）：
//
// constructor(private config: ConfigService) {}
//
// const url = this.config.getOrThrow<string>('AUTH_JWKS_URL');
