#!/usr/bin/env bash
# 学习导航脚本：在 VS Code 中直接打开对应文件到相关行。
#
#   ./scripts/study.sh setup           # 项目搭建相关文件
#   ./scripts/study.sh auth            # 用户认证相关文件
#   ./scripts/study.sh commit <hash>   # 打开某个提交改动过的所有文件
#   ./scripts/study.sh goto <file> <pattern>   # 打开文件并定位到第一个匹配行
#   ./scripts/study.sh -n auth         # 只打印将执行的命令，不打开编辑器
#
# 依赖：VS Code 的 code 命令（或 Cursor 的 cursor）。

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DRY_RUN=0
if [[ "${1:-}" == "-n" || "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

EDITOR_CLI="${EDITOR_CLI:-}"
if [[ -z "$EDITOR_CLI" ]]; then
  for candidate in code cursor code-insiders; do
    if command -v "$candidate" >/dev/null 2>&1; then
      EDITOR_CLI="$candidate"
      break
    fi
  done
fi
if [[ -z "$EDITOR_CLI" ]]; then
  echo "找不到 code 或 cursor 命令，请先把编辑器加入 PATH。" >&2
  exit 1
fi

# 文件::定位文本；不带 :: 时只打开文件
open_spec() {
  local spec="$1"
  local file="${spec%%::*}"
  local pattern=""
  [[ "$spec" == *"::"* ]] && pattern="${spec#*::}"

  if [[ ! -f "$file" ]]; then
    echo "跳过（文件不存在）：$file" >&2
    return
  fi

  local line=""
  if [[ -n "$pattern" ]]; then
    line="$(grep -n -m1 -F -- "$pattern" "$file" | cut -d: -f1 || true)"
  fi

  if [[ -n "$line" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "$EDITOR_CLI -r -g $file:$line   # $pattern"
    else
      "$EDITOR_CLI" -r -g "$file:$line"
    fi
  else
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "$EDITOR_CLI -r $file"
    else
      "$EDITOR_CLI" -r "$file"
    fi
  fi
}

topic_setup=(
  "docker-compose.yml::postgres:"
  "backend/pyproject.toml::[project]"
  "backend/app/config.py::class Settings"
  "backend/app/db.py::async def get_session"
  "backend/app/main.py::async def lifespan"
  "backend/app/worker.py::class WorkerSettings"
  "backend/app/tasks/__init__.py::TASKS ="
  "backend/migrations/versions/20260826_1621_users.py::def upgrade"
  "frontend/vite.config.ts::proxy:"
  "frontend/src/main.tsx"
  "frontend/src/App.tsx::export default function App"
)

topic_auth=(
  "backend/app/models/user.py::class User"
  "backend/app/schemas/auth.py::class Credentials"
  "backend/app/security.py::def hash_password"
  "backend/app/security.py::def issue_token"
  "backend/app/services/auth.py::async def register"
  "backend/app/routers/auth.py::def _start_session"
  "backend/app/deps.py::async def current_user"
  "backend/app/main.py::api.include_router(auth.router)"
  "backend/tests/test_auth.py::async def test_register_sets_session_cookie"
  "backend/tests/conftest.py::TEST_USER_PREFIX"
  "frontend/src/api/auth.ts::export const authApi"
  "frontend/src/hooks/useAuth.ts::export function useCurrentUser"
  "frontend/src/layouts/RequireAuth.tsx::export default function RequireAuth"
  "frontend/src/pages/AuthPage.tsx::const RULES"
  "frontend/src/App.tsx::<RequireAuth"
)

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}

case "${1:-}" in
  setup)
    for spec in "${topic_setup[@]}"; do open_spec "$spec"; done
    ;;
  auth)
    for spec in "${topic_auth[@]}"; do open_spec "$spec"; done
    ;;
  commit)
    hash="${2:-}"
    if [[ -z "$hash" ]]; then
      echo "用法：./scripts/study.sh commit <hash>" >&2
      exit 1
    fi
    files="$(git show --pretty=format: --name-only "$hash" | sed '/^$/d' | sort -u)"
    count=0
    while IFS= read -r file; do
      [[ -z "$file" ]] && continue
      open_spec "$file"
      count=$((count + 1))
    done <<< "$files"
    echo "共 $count 个文件（提交 $hash）。"
    ;;
  goto)
    file="${2:-}"
    pattern="${3:-}"
    if [[ -z "$file" || -z "$pattern" ]]; then
      echo "用法：./scripts/study.sh goto <file> <pattern>" >&2
      exit 1
    fi
    open_spec "$file::$pattern"
    ;;
  *)
    usage
    exit 1
    ;;
esac
