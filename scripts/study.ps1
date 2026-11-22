# 学习导航脚本（PowerShell 版）：在 VS Code 中打开对应文件到相关行。
#
#   .\scripts\study.ps1 setup
#   .\scripts\study.ps1 auth
#   .\scripts\study.ps1 commit 41cf1ef
#   .\scripts\study.ps1 goto backend/app/security.py issue_token
#   .\scripts\study.ps1 -DryRun auth
#
# 若被执行策略拦截，改用：
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\study.ps1 auth

param(
    [switch]$DryRun,
    [Parameter(Position = 0)][string]$Command,
    [Parameter(Position = 1)][string]$Arg1,
    [Parameter(Position = 2)][string]$Arg2
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$Editor = $env:EDITOR_CLI
if (-not $Editor) {
    foreach ($candidate in @('code', 'cursor', 'code-insiders')) {
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            $Editor = $candidate
            break
        }
    }
}
if (-not $Editor) {
    Write-Error '找不到 code 或 cursor 命令，请先把编辑器加入 PATH。'
    exit 1
}

function Open-Spec {
    param([string]$Spec)

    $file = $Spec
    $pattern = $null
    if ($Spec.Contains('::')) {
        $parts = $Spec -split '::', 2
        $file = $parts[0]
        $pattern = $parts[1]
    }

    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        Write-Warning "跳过（文件不存在）：$file"
        return
    }

    $line = $null
    if ($pattern) {
        $escaped = [regex]::Escape($pattern)
        $match = Select-String -LiteralPath $file -Pattern $escaped -List -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($match) { $line = $match.LineNumber }
    }

    if ($DryRun) {
        if ($line) { Write-Output "$Editor -r -g ${file}:${line}   # $pattern" }
        else { Write-Output "$Editor -r $file" }
        return
    }

    if ($line) { & $Editor -r -g "${file}:${line}" }
    else { & $Editor -r $file }
}

$topicSetup = @(
    'docker-compose.yml::postgres:'
    'backend/pyproject.toml::[project]'
    'backend/app/config.py::class Settings'
    'backend/app/db.py::async def get_session'
    'backend/app/main.py::async def lifespan'
    'backend/app/worker.py::class WorkerSettings'
    'backend/app/tasks/__init__.py::TASKS ='
    'backend/migrations/versions/20260826_1621_users.py::def upgrade'
    'frontend/vite.config.ts::proxy:'
    'frontend/src/main.tsx'
    'frontend/src/App.tsx::export default function App'
)

$topicAuth = @(
    'backend/app/models/user.py::class User'
    'backend/app/schemas/auth.py::class Credentials'
    'backend/app/security.py::def hash_password'
    'backend/app/security.py::def issue_token'
    'backend/app/services/auth.py::async def register'
    'backend/app/routers/auth.py::def _start_session'
    'backend/app/deps.py::async def current_user'
    'backend/app/main.py::api.include_router(auth.router)'
    'backend/tests/test_auth.py::async def test_register_sets_session_cookie'
    'backend/tests/conftest.py::TEST_USER_PREFIX'
    'frontend/src/api/auth.ts::export const authApi'
    'frontend/src/hooks/useAuth.ts::export function useCurrentUser'
    'frontend/src/layouts/RequireAuth.tsx::export default function RequireAuth'
    'frontend/src/pages/AuthPage.tsx::const RULES'
    'frontend/src/App.tsx::<RequireAuth'
)

$topicRedis = @(
    'docker-compose.yml::redis:'
    'backend/app/queue.py::async def queue'
    'backend/app/queue.py::async def enqueue'
    'backend/app/services/tools.py::async def submit'
    'backend/app/worker.py::class WorkerSettings'
    'backend/app/events.py::def redis_client'
    'backend/app/events.py::def _channel'
    'backend/app/events.py::async def publish'
    'backend/app/events.py::async def subscribe'
    'backend/app/services/runs.py::async def _commit'
    'backend/app/routers/events.py::async def stream_run'
    'frontend/src/hooks/useRun.ts::new EventSource'
)

$topicCh3 = @(
    'docs/notes/03-异步任务与实时推送.md::### 3.2'
    'backend/app/queue.py::async def enqueue'
    'backend/app/events.py::async def publish'
    'backend/app/worker.py::class WorkerSettings'
    'backend/app/tasks/__init__.py::TASKS ='
    'backend/app/tasks/tools.py::async def run_tool'
    'backend/app/services/tools.py::async def submit'
    'backend/app/services/runs.py::async def start'
    'backend/app/routers/events.py::async def stream_run'
    'frontend/src/hooks/useRun.ts::new EventSource'
)

$topicArch = @(
    'docs/notes/04-系统架构.md::## 必会 5 句'
    'backend/app/routers/sessions.py::async def confirm_plan'
    'backend/app/services/agent.py::async def respond'
    'backend/app/services/agent.py::async def continue_plan'
    'backend/app/agent/graph.py::async def _plan'
    'backend/app/agent/graph.py::def _verify'
    'backend/app/tools/base.py::class ToolSpec'
    'backend/app/services/tools.py::async def submit'
    'backend/app/queue.py::async def enqueue'
    'backend/app/tasks/tools.py::async def run_tool'
    'backend/app/services/runs.py::async def _commit'
    'backend/app/routers/events.py::async def stream_run'
    'backend/app/services/selections.py::async def get'
    'frontend/src/hooks/useRun.ts::new EventSource'
)

function Show-Usage {
    Write-Output '用法：'
    Write-Output '  .\scripts\study.ps1 setup'
    Write-Output '  .\scripts\study.ps1 auth'
    Write-Output '  .\scripts\study.ps1 redis'
    Write-Output '  .\scripts\study.ps1 ch3'
    Write-Output '  .\scripts\study.ps1 arch'
    Write-Output '  .\scripts\study.ps1 commit <hash>'
    Write-Output '  .\scripts\study.ps1 goto <file> <pattern>'
    Write-Output '  .\scripts\study.ps1 -DryRun auth'
}

switch ($Command) {
    'setup' {
        foreach ($spec in $topicSetup) { Open-Spec $spec }
    }
    'auth' {
        foreach ($spec in $topicAuth) { Open-Spec $spec }
    }
    'redis' {
        foreach ($spec in $topicRedis) { Open-Spec $spec }
    }
    'ch3' {
        foreach ($spec in $topicCh3) { Open-Spec $spec }
    }
    'arch' {
        foreach ($spec in $topicArch) { Open-Spec $spec }
    }
    'commit' {
        if (-not $Arg1) {
            Write-Error '用法：.\scripts\study.ps1 commit <hash>'
            exit 1
        }
        $files = git show --pretty=format: --name-only $Arg1 |
            Where-Object { $_ -ne '' } |
            Sort-Object -Unique
        foreach ($file in $files) { Open-Spec $file }
        Write-Output "共 $($files.Count) 个文件（提交 $Arg1）。"
    }
    'goto' {
        if (-not $Arg1 -or -not $Arg2) {
            Write-Error '用法：.\scripts\study.ps1 goto <file> <pattern>'
            exit 1
        }
        Open-Spec "${Arg1}::${Arg2}"
    }
    default {
        Show-Usage
        exit 1
    }
}
