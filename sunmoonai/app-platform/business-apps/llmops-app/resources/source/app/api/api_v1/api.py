from fastapi import APIRouter

from app.api.api_v1.endpoints import (
    app,
    dataset,
    conversation,
    document,
    segment,
    workflow,
    api_key,
    api_tool,
    upload_file,
    auth,
    account,
    oauth,
    ai,
    audio,
    builtin_app,
    builtin_tool,
    assistant_agent,
    analysis,
    language_model,
    platform,
    wechat,
    web_app,
    openapi,
)

api_router = APIRouter()

# LLMOps endpoints
api_router.include_router(app.router, prefix="/apps", tags=["llmops-app"])
api_router.include_router(dataset.router, prefix="/datasets", tags=["llmops-dataset"])
api_router.include_router(conversation.router, prefix="/conversations", tags=["llmops-conversation"])
api_router.include_router(document.router, prefix="/datasets", tags=["llmops-document"])
api_router.include_router(segment.router, prefix="/datasets", tags=["llmops-segment"])
api_router.include_router(workflow.router, prefix="/workflows", tags=["llmops-workflow"])
api_router.include_router(api_key.router, prefix="/openapi/api-keys", tags=["llmops-api-key"])
api_router.include_router(api_tool.router, prefix="/api-tools", tags=["llmops-api-tool"])
api_router.include_router(upload_file.router, prefix="/upload-files", tags=["llmops-upload-file"])
api_router.include_router(auth.router, prefix="/auth", tags=["llmops-auth"])
api_router.include_router(account.router, prefix="/account", tags=["llmops-account"])
api_router.include_router(oauth.router, prefix="/oauth", tags=["llmops-oauth"])
api_router.include_router(ai.router, prefix="/ai", tags=["llmops-ai"])
api_router.include_router(audio.router, prefix="/audio", tags=["llmops-audio"])
api_router.include_router(builtin_app.router, prefix="/builtin-apps", tags=["llmops-builtin-app"])
api_router.include_router(builtin_tool.router, prefix="/builtin-tools", tags=["llmops-builtin-tool"])
api_router.include_router(assistant_agent.router, prefix="/assistant-agent", tags=["llmops-assistant-agent"])
api_router.include_router(analysis.router, prefix="/analysis", tags=["llmops-analysis"])
api_router.include_router(language_model.router, prefix="/language-models", tags=["llmops-language-model"])
api_router.include_router(platform.router, prefix="/platform", tags=["llmops-platform"])
api_router.include_router(wechat.router, prefix="/wechat", tags=["llmops-wechat"])
api_router.include_router(web_app.router, prefix="/web-apps", tags=["llmops-web-app"])
api_router.include_router(openapi.router, prefix="/openapi", tags=["llmops-openapi"])

