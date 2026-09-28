"""第一步：把 9 份年报每一页的文字抽出来存盘（只做一次），后面的步骤都读这份缓存。
只读留存的原件；不访问网络。"""
import json, os, sys, time, glob, hashlib
from concurrent.futures import ProcessPoolExecutor
import pdfplumber, logging
logging.getLogger("pdfminer").setLevel(logging.ERROR)
ROOT = os.path.expanduser("~/info-smoke-storage/development-info-originals/info/securities/code=600009/source=cninfo")
OUT = os.path.expanduser("~/annual-report-probe/cache")

def work(path):
    name = os.path.basename(path)
    year = int(name.split("-")[1])
    target = f"{OUT}/text-{year}.json"
    if os.path.exists(target):
        return year, "cached", 0, 0
    t = time.time()
    pages = []
    with pdfplumber.open(path) as doc:
        for i, page in enumerate(doc.pages):
            pages.append({"page": i + 1, "text": page.extract_text() or ""})
    sha = hashlib.sha256(open(path, "rb").read()).hexdigest()
    json.dump({"year": year, "file": name, "sha256": sha, "pages": pages}, open(target, "w"), ensure_ascii=False)
    return year, "done", len(pages), round(time.time() - t, 1)

if __name__ == "__main__":
    files = sorted(glob.glob(ROOT + "/sha256=*/*/annual-*.pdf"))
    assert len(files) == 9, len(files)
    with ProcessPoolExecutor(max_workers=int(sys.argv[1]) if len(sys.argv) > 1 else 3) as pool:
        for r in pool.map(work, files):
            print(r, flush=True)
