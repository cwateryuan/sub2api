param(
  [string]$Repo = "D:\AI\sub2api",
  [string]$Branch = "local-web-custom",
  [string]$UpstreamBranch = "main",
  [string]$Message = "",
  [switch]$SkipBuild,
  [switch]$NoPush
)

$ErrorActionPreference = "Stop"

function Step($Title, [scriptblock]$Block) {
  Write-Host ""
  Write-Host "==> $Title" -ForegroundColor Cyan
  & $Block
}

Step "Enter repo" {
  Set-Location $Repo
  git status --short
}

Step "Checkout branch" {
  $current = (git branch --show-current).Trim()
  if ($current -ne $Branch) {
    git checkout $Branch
  }
}

Step "Merge upstream" {
  git fetch upstream
  git merge "upstream/$UpstreamBranch"
}

Step "Show backend version" {
  if (Test-Path "backend/cmd/server/VERSION") {
    Get-Content "backend/cmd/server/VERSION"
  }
}

if (-not $SkipBuild) {
  Step "Run local build" {
    npm run all
  }
}

Step "Show working tree" {
  git status --short
}

if ([string]::IsNullOrWhiteSpace($Message)) {
  $Message = Read-Host "Commit message, or press Enter to skip commit"
}

if (-not [string]::IsNullOrWhiteSpace($Message)) {
  Step "Stage known project files" {
    git add -u
    git add frontend/src frontend/public frontend/index.html frontend/package.json frontend/pnpm-lock.yaml
    git add .dockerignore Dockerfile SKILL.md package.json tools/local-build-all.ps1 .gitignore
  }

  Step "Commit if staged changes exist" {
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
      Write-Host "No staged changes. Skip commit."
    } else {
      git commit -m $Message
    }
  }
}

if (-not $NoPush) {
  Step "Push branch" {
    git push origin $Branch
  }
}

Write-Host ""
Write-Host "Done. After push, run on server: sub2api -up" -ForegroundColor Green
