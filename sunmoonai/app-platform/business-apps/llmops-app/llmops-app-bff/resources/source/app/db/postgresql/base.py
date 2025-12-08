# Import all the models, so that Base has them before being
# imported by Alembic
from app.db.postgresql.base_class import Base  # noqa
# LLMOps models
from app.models.postgresql.llmops_app import (  # noqa
    LLMOpsApp,
    AppConfig,
    AppConfigVersion,
    AppDatasetJoin,
)
from app.models.postgresql.llmops_dataset import (  # noqa
    Dataset,
    Document,
    Segment,
    KeywordTable,
    DatasetQuery,
    ProcessRule,
)
from app.models.postgresql.llmops_conversation import (  # noqa
    Conversation,
    Message,
    MessageAgentThought,
)
from app.models.postgresql.llmops_workflow import (  # noqa
    Workflow,
    WorkflowResult,
)
from app.models.postgresql.llmops_api_key import ApiKey  # noqa
from app.models.postgresql.llmops_api_tool import (  # noqa
    ApiToolProvider,
    ApiTool,
)
from app.models.postgresql.llmops_platform import (  # noqa
    WechatConfig,
    WechatEndUser,
    WechatMessage,
)
from app.models.postgresql.llmops_upload_file import UploadFile  # noqa
from app.models.postgresql.llmops_end_user import EndUser  # noqa

