#!/usr/bin/env python3
"""
LibreOffice 文档转换服务
提供 REST API 接口，支持多种文档格式互转

⚠️ 重要说明：
  - LibreOffice 对某些格式转换可能不完美（如 PDF 转 Word）
  - 建议优先使用 PDF 作为输出格式（最可靠）
  - OpenDocument 格式（.odt, .ods, .odp）转换质量最好（LibreOffice 原生格式）

支持的输入格式：
  - 文档：Word (.doc, .docx), OpenDocument (.odt), RTF (.rtf), PDF (.pdf), TXT, HTML
  - 表格：Excel (.xls, .xlsx), OpenDocument (.ods), CSV
  - 演示文稿：PowerPoint (.ppt, .pptx), OpenDocument (.odp)

支持的输出格式：
  - 文档：PDF ✅, HTML ✅, TXT ✅, RTF ✅, ODT ✅, DOCX ⚠️, DOC ⚠️
  - 表格：ODS ✅, CSV ✅, XLSX ⚠️, XLS ⚠️
  - 演示文稿：ODP ✅, PPTX ⚠️, PPT ⚠️

转换质量说明：
  ✅ = 转换质量好，推荐使用
  ⚠️ = 转换可能丢失部分格式，建议测试后使用

LibreOffice 会自动识别输入格式并转换为目标格式
"""

import os
import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import Optional
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn

app = FastAPI(
    title="Document Converter API",
    description="基于 LibreOffice 的文档转换服务",
    version="1.0.0"
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 生产环境应限制具体域名
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 配置
UPLOAD_DIR = Path("/tmp/uploads")
OUTPUT_DIR = Path("/tmp/outputs")
MAX_FILE_SIZE = 50 * 1024 * 1024  # 50MB

# LibreOffice 支持的格式（扩展列表，支持互转）
# 文档格式
SUPPORTED_INPUT_FORMATS = [
    # Word 文档
    ".doc", ".docx", ".docm",
    # Excel 表格
    ".xls", ".xlsx", ".xlsm", ".csv",
    # PowerPoint 演示文稿
    ".ppt", ".pptx", ".pptm",
    # OpenDocument 格式
    ".odt", ".ods", ".odp", ".odg", ".odf",
    # 其他文档格式
    ".rtf", ".pdf", ".txt", ".html", ".htm",
    # 图像格式（LibreOffice 可以处理）
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff", ".svg"
]

# 输出格式（LibreOffice 支持的所有常见输出格式）
SUPPORTED_OUTPUT_FORMATS = [
    # 文档格式
    "pdf", "html", "txt", "rtf", "odt", "docx", "doc",
    # 表格格式
    "xlsx", "xls", "ods", "csv",
    # 演示文稿格式
    "pptx", "ppt", "odp",
    # 图像格式
    "png", "jpg", "jpeg", "gif", "bmp", "tiff", "svg"
]

# 创建临时目录
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


class ConvertResponse(BaseModel):
    success: bool
    format: str
    original_filename: str
    converted_filename: str
    download_url: str
    file_size: int
    message: Optional[str] = None


class HealthResponse(BaseModel):
    status: str
    libreoffice_version: str
    supported_formats: list


def get_libreoffice_version() -> str:
    """获取 LibreOffice 版本"""
    try:
        result = subprocess.run(
            ["libreoffice", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.stdout.strip() if result.returncode == 0 else "unknown"
    except Exception:
        return "unknown"


def convert_document(
    input_file: Path,
    output_format: str,
    output_dir: Path
) -> Path:
    """
    使用 LibreOffice 转换文档
    
    Args:
        input_file: 输入文件路径
        output_format: 输出格式 (pdf, html, txt)
        output_dir: 输出目录
    
    Returns:
        输出文件路径
    
    Note:
        - PDF 转 TXT: 可能丢失格式，适合提取文本内容
        - PDF 转 PDF: 会重新处理 PDF，可能改变文件大小
    """
    output_file = output_dir / f"{input_file.stem}.{output_format}"
    
    # LibreOffice 转换命令
    # 注意：对于 PDF 转 TXT，LibreOffice 会提取文本内容
    cmd = [
        "libreoffice",
        "--headless",
        "--convert-to", output_format,
        "--outdir", str(output_dir),
        str(input_file)
    ]
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=60,  # 60秒超时
            check=True
        )
        
        if not output_file.exists():
            raise FileNotFoundError(f"转换失败：输出文件不存在 {output_file}")
        
        return output_file
    except subprocess.TimeoutExpired:
        raise Exception("转换超时，请检查文档大小")
    except subprocess.CalledProcessError as e:
        raise Exception(f"转换失败：{e.stderr}")
    except Exception as e:
        raise Exception(f"转换错误：{str(e)}")


@app.get("/health", response_model=HealthResponse)
async def health_check():
    """健康检查"""
    return HealthResponse(
        status="healthy",
        libreoffice_version=get_libreoffice_version(),
        supported_formats=SUPPORTED_OUTPUT_FORMATS
    )


@app.get("/api/v1/formats")
async def get_formats():
    """
    获取支持的格式
    
    返回所有支持的输入和输出格式列表
    LibreOffice 会自动识别输入格式并转换为目标格式
    """
    return {
        "input_formats": sorted(SUPPORTED_INPUT_FORMATS),
        "output_formats": sorted(SUPPORTED_OUTPUT_FORMATS),
        "description": "LibreOffice 支持多种格式互转，可以自动识别输入格式",
        "examples": {
            "文档转换（推荐）": [
                "docx → pdf ✅",
                "docx → odt ✅",
                "docx → html ✅",
                "docx → txt ✅"
            ],
            "表格转换（推荐）": [
                "xlsx → pdf ✅",
                "xlsx → ods ✅",
                "xlsx → csv ✅"
            ],
            "演示文稿转换（推荐）": [
                "pptx → pdf ✅",
                "pptx → odp ✅",
                "pptx → html ✅"
            ],
            "PDF 处理": [
                "pdf → txt ⚠️（提取文本，可能不完美）",
                "pdf → html ⚠️（质量取决于 PDF 类型）"
            ],
            "注意事项": [
                "✅ = 转换质量好，推荐使用",
                "⚠️ = 转换可能丢失部分格式，建议测试",
                "PDF 作为输出格式最可靠",
                "OpenDocument 格式转换质量最好"
            ]
        }
    }


@app.post("/api/v1/convert", response_model=ConvertResponse)
async def convert(
    file: UploadFile = File(...),
    format: str = Form("pdf"),
    embed_images: bool = Form(True)
):
    """
    转换文档
    
    Args:
        file: 上传的文件
        format: 输出格式（支持所有 LibreOffice 支持的格式）
        embed_images: HTML 格式是否嵌入图片（仅对 HTML 格式有效）
    
    支持的转换示例（基于实际测试）：
      - Word → PDF ✅ / HTML ✅ / TXT ✅ / ODT ✅ / DOCX ⚠️
      - PDF → TXT ⚠️ / HTML ⚠️ / ODT ⚠️（PDF 转其他格式质量取决于 PDF 类型）
      - Excel → PDF ✅ / CSV ✅ / ODS ✅ / XLSX ⚠️
      - PowerPoint → PDF ✅ / HTML ✅ / ODP ✅ / PPTX ⚠️
    
    推荐转换：
      - 任何格式 → PDF（最可靠）
      - 任何格式 → OpenDocument 格式（.odt, .ods, .odp，质量最好）
      - Word/Excel/PowerPoint → 对应格式（可能丢失部分格式）
    """
    # 验证输出格式
    if format not in SUPPORTED_OUTPUT_FORMATS:
        raise HTTPException(
            status_code=400,
            detail=f"不支持的输出格式: {format}。支持的格式: {', '.join(sorted(SUPPORTED_OUTPUT_FORMATS))}"
        )
    
    # 验证文件扩展名
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in SUPPORTED_INPUT_FORMATS:
        # 给出警告，但允许尝试（LibreOffice 可能会支持）
        logger.warning(f"未在支持列表中检测到格式: {file_ext}，将尝试让 LibreOffice 自动识别")
        logger.info(f"如果转换失败，请使用支持的格式: {', '.join(SUPPORTED_INPUT_FORMATS[:10])}...")
    
    # 创建临时文件
    temp_input = None
    temp_output_dir = None
    
    try:
        # 创建临时目录
        temp_output_dir = Path(tempfile.mkdtemp(dir=OUTPUT_DIR))
        temp_input = temp_output_dir / file.filename
        
        # 保存上传的文件
        content = await file.read()
        
        # 检查文件大小
        if len(content) > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=400,
                detail=f"文件过大，最大支持 {MAX_FILE_SIZE / 1024 / 1024}MB"
            )
        
        temp_input.write_bytes(content)
        
        # 转换文档
        output_file = convert_document(temp_input, format, temp_output_dir)
        
        # 返回结果
        return ConvertResponse(
            success=True,
            format=format,
            original_filename=file.filename,
            converted_filename=output_file.name,
            download_url=f"/api/v1/download/{output_file.name}",
            file_size=output_file.stat().st_size
        )
    
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"转换失败: {str(e)}")
    
    finally:
        # 清理临时文件（可选：保留一段时间供下载）
        # 这里暂时不删除，由定时任务清理
        pass


@app.get("/api/v1/download/{filename}")
async def download_file(filename: str):
    """下载转换后的文件"""
    file_path = OUTPUT_DIR / filename
    
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="文件不存在")
    
    return FileResponse(
        path=file_path,
        filename=filename,
        media_type="application/octet-stream"
    )


@app.on_event("startup")
async def startup():
    """启动时检查"""
    # 检查 LibreOffice 是否安装
    version = get_libreoffice_version()
    if version == "unknown":
        logger.warning("⚠️  警告: 无法检测 LibreOffice 版本，请确保已安装")
    else:
        logger.info(f"✅ LibreOffice 版本: {version}")
        logger.info(f"✅ 支持的输入格式: {len(SUPPORTED_INPUT_FORMATS)} 种")
        logger.info(f"✅ 支持的输出格式: {len(SUPPORTED_OUTPUT_FORMATS)} 种")
        logger.info(f"✅ 支持的输入格式: {len(SUPPORTED_INPUT_FORMATS)} 种")
        logger.info(f"✅ 支持的输出格式: {len(SUPPORTED_OUTPUT_FORMATS)} 种")


if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        log_level="info"
    )

