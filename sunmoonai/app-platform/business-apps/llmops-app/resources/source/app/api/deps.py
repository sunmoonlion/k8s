from typing import Annotated, AsyncGenerator, Dict, Any

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.auth_client import auth_client
from app.db.postgresql.session import SessionLocal

reusable_oauth2 = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/login/oauth")


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as db:
        yield db


def get_token_payload(token: str):
    """解析Token，获取payload"""
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGO])
        return payload
    except (jwt.JWTError, ValidationError):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Could not validate credentials",
        )


async def get_current_user(
    token: Annotated[str, Depends(reusable_oauth2)]
) -> Dict[str, Any]:
    """
    获取当前用户（从认证服务）
    
    注意：这里返回的是字典，不是User模型，因为用户数据在认证服务
    """
    token_data = get_token_payload(token)
    if token_data.get("refresh") or token_data.get("totp"):
        # Refresh token is not a valid access token and TOTP True can only be used to validate TOTP
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Could not validate credentials",
        )
    
    # 调用认证服务获取用户信息
    try:
        user = await auth_client.get_user_by_token(token)
        return user
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Could not validate credentials",
        )


async def get_current_active_user(
    current_user: Annotated[Dict[str, Any], Depends(get_current_user)],
) -> Dict[str, Any]:
    """获取当前活跃用户"""
    if not current_user.get("is_active", False):
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user


async def get_current_active_superuser(
    current_user: Annotated[Dict[str, Any], Depends(get_current_user)],
) -> Dict[str, Any]:
    """获取当前超级用户"""
    if not current_user.get("is_superuser", False):
        raise HTTPException(status_code=400, detail="The user doesn't have enough privileges")
    return current_user

