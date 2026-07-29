param(
  [string]$Repo = "D:\AI\sub2api",
  [string]$Branch = "local-web-custom",
  [string]$UpstreamBranch = "main",
  [string]$Message = "",
  [switch]$SkipBuild,
  [switch]$NoPush
)

$ErrorActionPreference = "Stop"
$script:BuildSucceeded = $false

function Step($Title, [scriptblock]$Block) {
  Write-Host ""
  Write-Host "==> $Title" -ForegroundColor Cyan
  & $Block
}

function Run($File, [string[]]$Arguments) {
  & $File @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed with exit code ${LASTEXITCODE}: $File $($Arguments -join ' ')"
  }
}

function Assert-NoMergeConflictMarkers {
  $trackedMatches = git grep -n -E "^(<<<<<<<|=======[[:space:]]*$|>>>>>>>)" -- . 2>$null
  $trackedExit = $LASTEXITCODE
  if ($trackedExit -eq 0) {
    Write-Host $trackedMatches -ForegroundColor Red
    throw "Merge conflict markers found in tracked files. Resolve them before commit/push."
  }
  if ($trackedExit -ne 1) {
    throw "Failed to scan tracked files for merge conflict markers."
  }

  $untrackedFiles = git ls-files --others --exclude-standard
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to list untracked files."
  }
  $textExtensions = @(
    ".go", ".ts", ".tsx", ".js", ".jsx", ".vue", ".json", ".yaml", ".yml",
    ".md", ".txt", ".ps1", ".sh", ".html", ".css", ".scss", ".env", ".example"
  )
  $untrackedTextFiles = @(
    $untrackedFiles | Where-Object {
      if ([string]::IsNullOrWhiteSpace($_)) {
        return $false
      }
      $name = $_.Trim()
      $ext = [System.IO.Path]::GetExtension($name).ToLowerInvariant()
      $textExtensions -contains $ext -or $name -like "*Dockerfile" -or $name -like "*.env.example"
    }
  )
  if ($untrackedTextFiles.Count -gt 0) {
    $untrackedMatches = Select-String -LiteralPath $untrackedTextFiles -Pattern "^(<<<<<<<|=======\s*$|>>>>>>>)" -ErrorAction SilentlyContinue
    if ($untrackedMatches) {
      $untrackedMatches | ForEach-Object {
        Write-Host "$($_.Path):$($_.LineNumber):$($_.Line)" -ForegroundColor Red
      }
      throw "Merge conflict markers found in untracked files. Resolve them before commit/push."
    }
  }
}

function Assert-NoUnmergedFiles {
  $unmerged = git diff --name-only --diff-filter=U
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to check unmerged files."
  }
  if ($unmerged) {
    Write-Host $unmerged -ForegroundColor Red
    throw "Unmerged files remain. Resolve them before build/commit/push."
  }
}

Step "Enter repo" {
  Set-Location $Repo
  Run "git" @("status", "--short")
}

Step "Checkout branch" {
  $current = (git branch --show-current).Trim()
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to read current branch."
  }
  if ($current -ne $Branch) {
    Run "git" @("checkout", $Branch)
  }
}

Step "Merge upstream" {
  Run "git" @("fetch", "upstream")
  Run "git" @("merge", "upstream/$UpstreamBranch")
}

Step "Check merge result" {
  Assert-NoUnmergedFiles
  Assert-NoMergeConflictMarkers
}

Step "Show backend version" {
  if (Test-Path "backend/cmd/server/VERSION") {
    Get-Content "backend/cmd/server/VERSION"
  }
}

if (-not $SkipBuild) {
  Step "Run local build" {
    Run "npm" @("run", "all")
    $script:BuildSucceeded = $true
  }
}

Step "Show working tree" {
  Run "git" @("status", "--short")
}

if ([string]::IsNullOrWhiteSpace($Message)) {
  $Message = Read-Host "Commit message, or press Enter to skip commit"
}

if (-not [string]::IsNullOrWhiteSpace($Message)) {
  Step "Pre-commit safety checks" {
    Assert-NoUnmergedFiles
    Assert-NoMergeConflictMarkers
  }

  Step "Stage known project files" {
    Run "git" @("add", "-u")
    Run "git" @("add", "frontend/src", "frontend/public", "frontend/index.html", "frontend/package.json", "frontend/pnpm-lock.yaml")
    Run "git" @("add", ".dockerignore", "Dockerfile", "SKILL.md", "package.json", "tools/local-build-all.ps1", ".gitignore")
  }

  Step "Commit if staged changes exist" {
    git diff --cached --quiet
    $diffExit = $LASTEXITCODE
    if ($diffExit -eq 0) {
      Write-Host "No staged changes. Skip commit."
    } elseif ($diffExit -eq 1) {
      Run "git" @("commit", "-m", $Message)
    } else {
      throw "Failed to inspect staged changes."
    }
  }

  Step "Post-commit safety checks" {
    Assert-NoMergeConflictMarkers
  }
}

if (-not $NoPush) {
  Step "Pre-push safety checks" {
    Assert-NoUnmergedFiles
    Assert-NoMergeConflictMarkers
    if (-not $SkipBuild -and -not $script:BuildSucceeded) {
      Run "npm" @("run", "all")
      $script:BuildSucceeded = $true
    }
  }

  Step "Push branch" {
    Run "git" @("push", "origin", $Branch)
  }
}

if ($NoPush) {
  Write-Host ""
  Write-Host "Done. Push skipped." -ForegroundColor Green
} else {
  Write-Host ""
  Write-Host "Done. After push, run on server: sub2api -up" -ForegroundColor Green
}
