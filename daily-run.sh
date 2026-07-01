#!/bin/bash
# ====== 自动化外链系统 - 每日运行 ======
# 运行：每天8:00自动执行
# 功能：生成内容 → 推送到 GitHub/Gitee → 记录日志

BASE=/root/.link-builder
LOG=$BASE/logs
mkdir -p $LOG

TS() { date "+%Y-%m-%d %H:%M:%S"; }

echo "[$(TS)] ====== 外链自动化每日运行 ======" >> $LOG/daily.log

cd $BASE

# ====== Step 1: 生成新内容 ======
echo "[$(TS)] 生成新内容..." >> $LOG/daily.log
python3 post.py >> $LOG/daily.log 2>&1
CONTENT=$(cat current_post.json 2>/dev/null | python3 -c "import json,sys; c=json.load(sys.stdin); print(c['title'][:50])" 2>/dev/null)
echo "[$(TS)] 内容: $CONTENT" >> $LOG/daily.log

# ====== Step 2: 生成资源页 ======
SLUG=$(date +%s | md5sum | head -c8)
TITLE=$(cat current_post.json | python3 -c "import json,sys; print(json.load(sys.stdin)['title'])")
BODY=$(cat current_post.json | python3 -c "
import json,sys,re
b = json.load(sys.stdin)['body']
b = re.sub(r'<a href=\"([^\"]+)\">([^<]+)</a>', r'[\2](\1)', b)
print(b)
")

cat > "resource-${SLUG}.md" << RESOURCE
# ${TITLE}

${BODY}

---

## 平台导航

- [MJ7 - 制造业全产业链平台](https://www.mj7.cn)
- [DeepSeekS - 制造业出海工具站](https://www.deepseeks.com.cn)
- [MFGABC - 全球制造互动平台](https://www.mfgabc.com)
- [OracleLuck - 中华文化平台](https://www.oracleluck.com)

*资源页面 · $(date "+%Y-%m-%d %H:%M")*
RESOURCE

# ====== Step 3: 更新 README ======
# Add new page to the navigation list
echo "- [${TITLE}](resource-${SLUG}.md)" >> README.md

# ====== Step 4: Push to GitHub ======
echo "[$(TS)] 推送到 GitHub..." >> $LOG/daily.log
git add resource-${SLUG}.md README.md
git commit -m "Add: ${TITLE}" >> $LOG/daily.log 2>&1
git push origin main >> $LOG/daily.log 2>&1

# ====== Step 5: Push to Gitee ====== 
echo "[$(TS)] 推送到 Gitee..." >> $LOG/daily.log
git push gitee main >> $LOG/daily.log 2>&1

echo "[$(TS)] ✅ 完成 - ${SLUG}" >> $LOG/daily.log
echo "====== 完成 ======" >> $LOG/daily.log
