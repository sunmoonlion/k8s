from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from starlette.middleware.cors import CORSMiddleware

from app.api.api_v1.api import api_router
from app.core.config import settings
from app.core.exceptions import CustomException
from app.core.response import error_json
# from app.db.neo4j import NeomodelConfig

app = FastAPI(
    title=settings.PROJECT_NAME, openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Set all CORS enabled origins
if settings.BACKEND_CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[str(origin).strip("/") for origin in settings.BACKEND_CORS_ORIGINS],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )


@app.exception_handler(CustomException)
async def custom_exception_handler(request: Request, exc: CustomException):
    """自定义异常处理器"""
    return JSONResponse(
        status_code=exc.code,
        content=error_json(exc.message, exc.code, exc.data)
    )


app.include_router(api_router, prefix=settings.API_V1_STR)

# nmc = NeomodelConfig()
# nmc.ready()
