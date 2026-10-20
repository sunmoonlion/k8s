import json, sys, time, urllib.parse, urllib.request
URL = "https://www.cninfo.com.cn/new/hisAnnouncement/query"
CATS = {"年报": "category_ndbg_szsh", "半年报": "category_bndbg_szsh", "一季报": "category_yjdbg_szsh", "三季报": "category_sjdbg_szsh"}
out = []
for name, cat in CATS.items():
    for page in (1, 2):
        data = urllib.parse.urlencode({"pageNum": page, "pageSize": 30, "column": "sse", "tabName": "fulltext", "plate": "sh",
            "stock": "600519,gssh0600519", "searchkey": "", "secid": "", "category": cat + ";", "trade": "",
            "seDate": "2021-01-01~2026-10-18", "sortName": "", "sortType": "", "isHLtitle": "true"}).encode()
        req = urllib.request.Request(URL, data=data, headers={"User-Agent": "Mozilla/5.0", "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8"})
        body = json.loads(urllib.request.urlopen(req, timeout=30).read())
        for a in body.get("announcements") or []:
            out.append({"kind": name, "title": a["announcementTitle"], "url": a["adjunctUrl"], "time": a["announcementTime"]})
        if not body.get("hasMore"):
            break
        time.sleep(1)
json.dump(out, sys.stdout, ensure_ascii=False, indent=1)
