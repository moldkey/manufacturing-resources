#!/bin/bash
# 扫描四站已有内容，生成站点内容索引
# 跑一次就行，后续只用索引

BASE=/root/.link-builder
IDX=$BASE/site-content-index.json
echo "{}" > $IDX

echo "=== 扫描 DeepSeekS 内容 ==="
# 品类/行业页面
DS_ITEMS=$(ssh root@8.155.15.13 "find /www/wwwroot/deepseeks.com.cn/ -maxdepth 1 -type d | grep -v '^/www/wwwroot/deepseeks.com.cn/$' | xargs -I{} basename {} | grep -v '^\\.' | grep -v 'assets\|data\|okf\|kg\|html' " 2>/dev/null)
echo "Done: DS"

echo "=== 扫描 MFGABC 内容 ==="
MFG_ITEMS=$(ssh root@38.190.206.18 -p 54758 "find /var/www/mfgabc/ -maxdepth 1 -type d | xargs -I{} basename {} | grep -v '^\\.' | grep -v 'auth\|data\|okf\|docs' " 2>/dev/null)
echo "Done: MFG"

echo "=== 构建索引 ==="
python3 << PY
import json, os

idx = {}

# DeepSeekS 品类/城市页面
ds_cats = """$DS_ITEMS""".strip().split('\n')
ds_urls = []
for cat in ds_cats:
    if cat:
        cat = cat.strip()
        ds_urls.append({
            "url": f"https://www.deepseeks.com.cn/{cat}/",
            "title": cat.replace('-', ' ').title(),
            "type": "category"
        })
        # Some have sub-items
        if cat in ['trade-policy', 'categories']:
            subpages = os.popen(f"ssh root@8.155.15.13 'ls /www/wwwroot/deepseeks.com.cn/{cat}/ 2>/dev/null | head -20'").read().strip().split()
            for sp in subpages:
                sp = sp.strip()
                ds_urls.append({
                    "url": f"https://www.deepseeks.com.cn/{cat}/{sp}",
                    "title": sp.replace('-', ' ').title(),
                    "type": "subpage"
                })
idx["deepseeks"] = ds_urls[:200]  # 最多200条

# MFGABC 品类/城市页面
mfg_items = """$MFG_ITEMS""".strip().split('\n')
mfg_urls = []
for item in mfg_items:
    if item and item not in ['blog','inquiry','articles']:
        item = item.strip()
        mfg_urls.append({
            "url": f"https://www.mfgabc.com/{item}/",
            "title": item.replace('-', ' ').title(),
            "type": "category"
        })
idx["mfgabc"] = mfg_urls[:100]

# MJ7 内容
mj7_urls = [
    {"url": "https://www.mj7.cn/knowledge/mj7/articles/39b95c12.html", "title": "五轴联动加工在轨道交通领域的应用前景", "type": "article"},
    {"url": "https://www.mj7.cn/knowledge/mj7/articles/b3ed5052.html", "title": "建材装饰行业CNC编程技巧与工艺优化", "type": "article"},
]
# 添加 OKF 页面
okf_pages = os.popen("ssh root@8.155.15.13 'find /www/wwwroot/www.mj7.cn/okf/ -type f -name \"*.md\" 2>/dev/null'").read().strip().split()
for p in okf_pages[:30]:
    p = p.replace('/www/wwwroot/www.mj7.cn', '').replace('.md', '')
    mj7_urls.append({
        "url": f"https://www.mj7.cn{p}",
        "title": p.split('/')[-1].replace('-', ' ').title(),
        "type": "okf"
    })
idx["mj7"] = mj7_urls

# OracleLuck - 抽取一些现有的诗词/古籍页面路径
ol_urls = [
    {"url": "https://www.oracleluck.com", "title": "OracleLuck 中华文化站", "type": "home"},
    {"url": "https://taiyige.oracleluck.com", "title": "太乙阁古籍全文库", "type": "portal"},
    {"url": "https://taixige.oracleluck.com", "title": "泰西阁西方文化", "type": "portal"},
    {"url": "https://daozang.oracleluck.com", "title": "道藏全文库", "type": "portal"},
    {"url": "https://reading.oracleluck.com", "title": "玄学阅读", "type": "portal"},
    {"url": "https://xueyuan.oracleluck.com", "title": "知学院玄学教学", "type": "portal"},
    {"url": "https://ai.oracleluck.com", "title": "OracleLuck AI", "type": "ai"},
    {"url": "https://app.oracleluck.com", "title": "OracleLuck 工具", "type": "tools"},
]
# 扫描 OracleLuck 诗词页面
ol_poems = os.popen("ssh root@8.155.15.13 'ls /www/wwwroot/oracleluck.com/guoxue/poem/ 2>/dev/null | head -30'").read().strip().split()
for p in ol_poems[:10]:
    p = p.strip()
    ol_urls.append({
        "url": f"https://www.oracleluck.com/guoxue/poem/{p}",
        "title": f"诗词 - {p.replace('.html', '')}",
        "type": "poem"
    })
idx["oracleluck"] = ol_urls

with open("$IDX", "w", encoding="utf-8") as f:
    json.dump(idx, f, ensure_ascii=False, indent=2)

total = sum(len(v) for v in idx.values())
print(f"✅ 索引完成: {total} 条 URL")
for k, v in idx.items():
    print(f"  {k}: {len(v)} 条")
PY
