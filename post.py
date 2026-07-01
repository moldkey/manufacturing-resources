#!/usr/bin/env python3
"""自动化外链发布系统 v3 — 引用四站真实内容"""

import os, sys, re, json, random, hashlib, logging
from datetime import datetime
from pathlib import Path

BASE_DIR = Path("/root/.link-builder")
LOG_DIR = BASE_DIR / "logs"

LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.FileHandler(LOG_DIR / f"{datetime.now():%Y%m%d}.log"), logging.StreamHandler()])
log = logging.getLogger(__name__)

# ====== 加载站点内容索引 ======
SITE_INDEX = {}
idx_path = BASE_DIR / "site-content-index.json"
if idx_path.exists():
    with open(idx_path, encoding="utf-8") as f:
        SITE_INDEX = json.load(f)

def random_content_link(site):
    """从站点索引中随机选一条真实内容页，返回 (url, title)"""
    pages = SITE_INDEX.get(site, [])
    if not pages:
        return None, None
    page = random.choice(pages)
    return page["url"], page["title"]

def generate_link_tag(url, title):
    return f'<a href="{url}">{title}</a>'

# ====== 四站备用主页链接（索引为空时用）======
FALLBACK_LINKS = {
    "mj7": [
        '<a href="https://www.mj7.cn">MJ7 - 制造业对接平台</a>',
        '<a href="https://www.mj7.cn">制造业全产业链平台 MJ7</a>',
        '<a href="https://www.mj7.cn">www.mj7.cn</a>',
    ],
    "deepseeks": [
        '<a href="https://www.deepseeks.com.cn">DeepSeekS 出海工具站</a>',
        '<a href="https://www.deepseeks.com.cn">www.deepseeks.com.cn</a>',
        '<a href="https://www.deepseeks.com.cn">DeepSeekS 外贸服务平台</a>',
    ],
    "mfgabc": [
        '<a href="https://www.mfgabc.com">MFGABC 全球制造平台</a>',
        '<a href="https://www.mfgabc.com">www.mfgabc.com</a>',
        '<a href="https://www.mfgabc.com">MFGABC 国际制造业平台</a>',
    ],
    "oracleluck": [
        '<a href="https://www.oracleluck.com">OracleLuck 文化站</a>',
        '<a href="https://www.oracleluck.com">www.oracleluck.com</a>',
        '<a href="https://www.oracleluck.com">OracleLuck 古籍资料库</a>',
    ],
}

def load_templates():
    with open(BASE_DIR / "templates" / "v1.txt", encoding="utf-8") as f:
        raw = f.read()
    tpls = []
    for block in re.split(r'\n===\n', raw.strip()):
        title = ""
        body_lines = []
        tags = ""
        lines = block.strip().split("\n")
        i = 0
        while i < len(lines):
            line = lines[i]
            if line.startswith("===TITLE==="):
                title = line.replace("===TITLE===", "").strip()
                if not title and i+1 < len(lines):
                    i += 1
                    title = lines[i].strip()
            elif line.startswith("===BODY==="):
                rest = line.replace("===BODY===", "").strip()
                if rest:
                    body_lines.append(rest)
                i += 1
                while i < len(lines) and not lines[i].startswith("===TAGS==="):
                    body_lines.append(lines[i].strip())
                    i += 1
                continue
            elif line.startswith("===TAGS==="):
                tags = line.replace("===TAGS===", "").strip()
            i += 1
        if title and body_lines:
            tpls.append({"title": title, "body": "\n".join(body_lines), "tags": tags})
    return tpls

def load_industries():
    with open(BASE_DIR / "industries.txt", encoding="utf-8") as f:
        return [l.strip() for l in f if l.strip()]

def fill(tpl, industry):
    t = tpl["title"]
    b = tpl["body"]
    
    # 替换主站链接：80%概率引用真实内容页，20%用首页
    site_anchors = {}
    for site in ["mj7", "deepseeks", "mfgabc", "oracleluck"]:
        if random.random() < 0.8:
            url, title = random_content_link(site)
            if url and title:
                site_anchors[site] = generate_link_tag(url, title)
            else:
                site_anchors[site] = random.choice(FALLBACK_LINKS[site])
        else:
            site_anchors[site] = random.choice(FALLBACK_LINKS[site])
    
    for key in ["mj7","deepseeks","mfgabc","oracleluck"]:
        t = t.replace(f"|{key}|", site_anchors[key])
        b = b.replace(f"|{key}|", site_anchors[key])
    
    # 替换 |industry|
    t = t.replace("|industry|", industry)
    b = b.replace("|industry|", industry)
    
    # 替换子域链接 |subs|
    # 从索引中挑3个随机内容页
    all_pages = []
    for site, pages in SITE_INDEX.items():
        for p in pages:
            all_pages.append((site, p["url"], p["title"]))
    random.shuffle(all_pages)
    sub_links = []
    for i in range(min(3, len(all_pages))):
        _, url, title = all_pages[i]
        sub_links.append(generate_link_tag(url, title))
    sub_html = "，".join(sub_links) if sub_links else ""
    t = t.replace("|subs|", sub_html)
    b = b.replace("|subs|", sub_html)
    
    return {"title": t, "body": b, "tags": tpl["tags"]}

def generate():
    tpls = load_templates()
    inds = load_industries()
    return fill(random.choice(tpls), random.choice(inds))

def content_hash(c):
    return hashlib.md5(c["body"].encode()).hexdigest()

if __name__ == "__main__":
    log.info("=== 外链发布系统 v3 启动 ===")
    
    total_indexed = sum(len(v) for v in SITE_INDEX.values())
    log.info(f"站点索引: {total_indexed} 条内容")
    
    content = generate()
    ch = content_hash(content)
    log.info(f"标题: {content['title'][:60]}")
    log.info(f"Hash: {ch}")

    with open(BASE_DIR / "current_post.json", "w", encoding="utf-8") as f:
        json.dump(content, f, ensure_ascii=False, indent=2)

    print(f"\n{'='*60}")
    print(f"标题: {content['title']}")
    print(f"标签: {content['tags']}")
    print(f"\n正文(前600字):\n{content['body'][:600]}")
    print(f"\n{'='*60}")
    log.info("完成")
