#!/usr/bin/env bash

#------------------------------------------------------------------------------
# @file
# 精简版构建脚本 - 移除了不需要的 Node.js 依赖
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

  # 移除了 NODE_VERSION
  DART_SASS_VERSION=1.100.0
  GO_VERSION=1.26.3
  HUGO_VERSION=0.163.0

  export TZ=Europe/Oslo
  echo "Installing uv..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"
  # 1. 安装所需工具（跳过 Node.js）
  build_temp_dir=$(mktemp -d)
  pushd "${build_temp_dir}" > /dev/null

  mkdir -p "${HOME}/.local"

  echo "Installing Dart Sass ${DART_SASS_VERSION}..."
  curl -sLJO "https://github.com/sass/dart-sass/releases/download/${DART_SASS_VERSION}/dart-sass-${DART_SASS_VERSION}-linux-x64.tar.gz"
  tar -C "${HOME}/.local" -xf "dart-sass-${DART_SASS_VERSION}-linux-x64.tar.gz"
  export PATH="${HOME}/.local/dart-sass:${PATH}"

  echo "Installing Go ${GO_VERSION}..."
  curl -sLJO "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
  tar -C "${HOME}/.local" -xf "go${GO_VERSION}.linux-amd64.tar.gz"
  export PATH="${HOME}/.local/go/bin:${PATH}"

  echo "Installing Hugo ${HUGO_VERSION}..."
  curl -sLJO "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_${HUGO_VERSION}_linux-amd64.tar.gz"
  mkdir -p "${HOME}/.local/hugo"
  tar -C "${HOME}/.local/hugo" -xf "hugo_${HUGO_VERSION}_linux-amd64.tar.gz"
  export PATH="${HOME}/.local/hugo:${PATH}"

  popd > /dev/null

  # 验证依赖（移除 Node.js 验证）
  echo "Verifying installations..."
  echo Dart Sass: "$(sass --version)"
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