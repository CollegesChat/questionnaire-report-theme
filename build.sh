#!/usr/bin/env bash

#------------------------------------------------------------------------------
# @file
# 终极精简版构建脚本 - 使用 Hugo Extended，移除 Node.js 与 Dart Sass 依赖
#------------------------------------------------------------------------------

set -euo pipefail

build_temp_dir=""

cleanup() {
  if [[ -n "${build_temp_dir:-}" && -d "${build_temp_dir}" ]]; then
    rm -rf "${build_temp_dir}"
  fi
}

trap cleanup EXIT SIGINT SIGTERM

main() {

  # 依赖版本定义（已移除 DART_SASS_VERSION）
  GO_VERSION=1.26.3
  HUGO_VERSION=0.163.0

  export TZ=Europe/Oslo

  # 创建本地自定义二进制目录
  mkdir -p "${HOME}/.local/bin"

  # 0. 安装 uv 并配置环境变量
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"

  # 1. 创建临时目录用于下载和解压工具
  build_temp_dir=$(mktemp -d)
  pushd "${build_temp_dir}" > /dev/null

  echo "Installing Go ${GO_VERSION}..."
  curl -sLJO "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
  tar -C "${HOME}/.local" -xf "go${GO_VERSION}.linux-amd64.tar.gz"
  export PATH="${HOME}/.local/go/bin:${PATH}"

  echo "Installing Hugo Extended ${HUGO_VERSION}..."
  curl -sLJO "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz"
  mkdir -p "${HOME}/.local/hugo"
  tar -C "${HOME}/.local/hugo" -xf "hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz"
  export PATH="${HOME}/.local/hugo:${PATH}"

  popd > /dev/null

  # 验证依赖
  echo "Verifying installations..."
  echo Go: "$(go version)"
  echo Hugo: "$(hugo version)"

  # 2. 配置 Git
  echo "Configuring Git..."
  git config core.quotepath false
  if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    git fetch --unshallow
  fi

  # 3. 克隆生成器
  if [ -d "generator" ]; then
    rm -rf generator
  fi
  echo "Cloning website-generator repository..."
  git clone https://github.com/CollegesChat/website-generator.git generator

  # 4. 运行 Python 脚本生成 Markdown
  echo "Building Markdown files with uv..."
  export SITE_DIR="$(pwd)"

  pushd generator > /dev/null
  uv sync
  uv run python main.py
  popd > /dev/null

  # 5. 注入时间戳
  echo "Injecting current build time into hugo.yaml..."
  BUILD_TIME=$(TZ='Asia/Shanghai' date +'%Y-%m-%d %H:%M:%S')
  COPYRIGHT_STR="<a href='https://creativecommons.org/licenses/by-nc-sa/4.0/' target='_blank' rel='noopener'>CC BY-NC-SA 4.0</a> | Generated on ${BUILD_TIME} (UTC+8)"
  sed -i "s#copyright: \"\$copyright\"#copyright: \"${COPYRIGHT_STR}\"#g" hugo.yaml

  # 6. Hugo 编译
  echo "Building the static website with Hugo..."
  hugo build --gc --minify -d public

  # 7. 清理静态文件
  echo "Cleaning up output folder..."
  pushd public > /dev/null
  rm -rf asciinema katex
  rm -f mermaid.min.js
  popd > /dev/null

  echo "Build completed successfully!"
}

main "$@"