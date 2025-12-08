"""认证服务客户端 - 调用认证服务获取用户信息"""
import httpx
from typing import Optional, Dict, Any

from app.core.config import settings


class AuthClient:
    """认证服务客户端"""
    
    def __init__(self):
        self.base_url = settings.AUTH_SERVICE_URL
    
    async def get_user_by_token(self, token: str) -> Dict[str, Any]:
        """
        从认证服务获取用户信息
        
        Args:
            token: JWT Token
            
        Returns:
            用户信息字典
            
        Raises:
            httpx.HTTPStatusError: 如果请求失败
        """
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{self.base_url}/api/v1/auth/me",
                headers={"Authorization": f"Bearer {token}"},
                timeout=5.0
            )
            response.raise_for_status()
            return response.json()
    
    async def validate_token(self, token: str) -> bool:
        """
        验证Token是否有效
        
        Args:
            token: JWT Token
            
        Returns:
            True 如果Token有效，False 否则
        """
        try:
            await self.get_user_by_token(token)
            return True
        except:
            return False


# 全局实例
auth_client = AuthClient()

