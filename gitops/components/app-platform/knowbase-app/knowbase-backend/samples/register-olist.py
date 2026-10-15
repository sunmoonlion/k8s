"""在集群里登记样例数据集 olist-ecommerce（k8s 仓 tree-build/SDD/modules/0023-fin-forecast.md 第三节）。

在 knowfeed 后端 API 容器里运行：用 knowfeed 自己的对象存储写权限把文件放进 knowfeed-originals 的 knowfeed/samples/ 下
（知识服务的存储身份只读 knowfeed/ 前缀），再用 knowfeed 自己的服务身份调知识服务的登记接口。不打印令牌。

    kubectl -n app-platform-dev exec -i deploy/knowfeed-api -c api -- \\
        python -c "$(cat register-olist.py)" "$(cat build.json)" < olist-ecommerce.sqlite

build.json 是 knowbase-backend `scripts/build_olist_dataset.py` 打印的那一行。同一版本已经登记过就只报告、不再上传。
"""

import asyncio
import hashlib
import json
import sys

import httpx

from app.infrastructure.external.knowbase_app import ServiceTokenProvider
from app.infrastructure.storage.object_storage import ObjectStorage
from core.config import get_settings


async def current(client: httpx.AsyncClient, url: str, headers: dict, dataset_id: str):
    response = await client.get(url, headers=headers)
    response.raise_for_status()
    body = response.json()
    rows = body.get("datasets", body) if isinstance(body, dict) else body
    return next((r for r in rows if r.get("dataset_id") == dataset_id), None)


async def main() -> int:
    build = json.loads(sys.argv[1])
    data = sys.stdin.buffer.read()
    digest = hashlib.sha256(data).hexdigest()
    if digest != build["sha256"] or len(data) != build["size_bytes"]:
        print(json.dumps({"result": "file_mismatch", "sha256": digest, "size_bytes": len(data)}))
        return 2
    settings = get_settings()
    url = settings.knowbase_app_dataset_url
    if not url:
        print(json.dumps({"result": "dataset_url_not_configured"}))
        return 2
    token = await ServiceTokenProvider(settings).get_token()
    headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    async with httpx.AsyncClient(timeout=60) as client:
        before = await current(client, url, headers, build["dataset_id"])
        if before and before.get("data_version") == build["data_version"]:
            print(json.dumps({"result": "already_registered", "registered": before}, ensure_ascii=False))
            return 0
        key = f"knowfeed/samples/{build['dataset_id']}/{build['data_version']}/{build['dataset_id']}.sqlite"
        stored = ObjectStorage().put_bytes(
            object_key=key,
            data=data,
            content_type="application/vnd.sqlite3",
            metadata={"source-app": build["source_app"]},
        )
        payload = {
            "dataset_id": build["dataset_id"],
            "data_version": build["data_version"],
            "title": build["title"],
            "security_code": None,
            "object": f"s3://{stored.bucket}/{stored.object_key}",
            "object_version_id": stored.version_id,
            "sha256": stored.sha256,
            "size_bytes": stored.size_bytes,
            "start_date": build["start_date"],
            "end_date": build["end_date"],
            "source_app": build["source_app"],
            "source_ref": "olist-sample",
            "quality_passed": True,
        }
        response = await client.post(url, json=payload, headers=headers)
        after = await current(client, url, headers, build["dataset_id"])
    print(
        json.dumps(
            {
                "result": "registered" if response.status_code in (200, 201) else "refused",
                "http_status": response.status_code,
                "object": payload["object"],
                "object_version_id": stored.version_id,
                "registered": after,
                "detail": None if response.status_code in (200, 201) else response.text[:500],
            },
            ensure_ascii=False,
        )
    )
    return 0 if response.status_code in (200, 201) else 1


sys.exit(asyncio.run(main()))
