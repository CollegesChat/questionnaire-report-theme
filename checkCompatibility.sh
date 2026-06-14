#!/bin/bash
# 設定：遇到錯誤立即停止，且管線錯誤會回傳到腳本層級
set -eo pipefail

# CSS 檢查
find public -type f -name '*.css' -print0 | \
xargs -0 npx doiuse \
--browsers "Chrome >= 109, Firefox >= 115, iOS >= 15" \
--quiet > /dev/null

# JS 檢查
find public -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.cjs' \) \
-exec npx esbuild {} \
--target=chrome109,firefox115,safari15 \
--format=esm \
--bundle=false \
--log-level=error \
\; > /dev/null

echo "所有檢查皆已通過。"