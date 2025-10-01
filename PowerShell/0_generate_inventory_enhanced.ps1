# Declare variables at the top of the script
$adoOrg = "contosodevopstest"  # Replace with your actual ADO organization name

# check to make sure we have the required Tokens for access to GitHub and AzDO
$missingTokens = $false

if (!$env:ADO_PAT) {
    write-host "Missing ADO_PAT Environment Variable" -ForegroundColor Red
    $missingTokens = $true
}

if (!$env:GH_PAT) {
    write-host "Missing GH_PAT Environment Variable" -ForegroundColor Red
    $missingTokens = $true
}

if ($missingTokens) {
    write-host "Please set the required environment variables before running this script." -ForegroundColor Yellow
    exit
}

# Repository Health Check Function
function Invoke-RepositoryHealthCheck {
    param (
        [string]$repositoryPath,
        [string]$repositoryName
    )
    
    Write-Host "`n=== Repository Health Check: $repositoryName ===" -ForegroundColor Cyan
    Write-Host "Repository Path: $repositoryPath" -ForegroundColor Gray
    
    # Change to repository directory
    $originalLocation = Get-Location
    try {
        Set-Location -Path $repositoryPath -ErrorAction Stop
        
        # 1. Git-Sizer Health Check
        Write-Host "`n--- Git-Sizer Analysis ---" -ForegroundColor Yellow
        $gitSizerOutput = "git-sizer-$repositoryName-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        
        # Check if git-sizer is available
        $gitSizerPath = Get-Command git-sizer -ErrorAction SilentlyContinue
        if ($gitSizerPath) {
            Write-Host "Running git-sizer analysis..." -ForegroundColor Green
            git-sizer --verbose > $gitSizerOutput 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Git-sizer analysis completed. Report saved to: $gitSizerOutput" -ForegroundColor Green
                # Show summary
                Write-Host "Summary:" -ForegroundColor Cyan
                Get-Content $gitSizerOutput | Select-Object -First 20
            } else {
                Write-Host "⚠️ Git-sizer analysis had issues. Check $gitSizerOutput for details." -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️ Git-sizer not found. Install it for repository size analysis." -ForegroundColor Yellow
            Write-Host "   Download from: https://github.com/github/git-sizer/releases" -ForegroundColor Gray
        }
        
        # 2. Git LFS Check
        Write-Host "`n--- Git LFS Analysis ---" -ForegroundColor Yellow
        $lfsOutput = "git-lfs-files-$repositoryName-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        
        # Check if Git LFS is initialized
        if (Test-Path ".git/lfs") {
            Write-Host "Git LFS detected. Checking tracked files..." -ForegroundColor Green
            git lfs ls-files > $lfsOutput 2>&1
            $lfsFileCount = (Get-Content $lfsOutput -ErrorAction SilentlyContinue | Measure-Object).Count
            
            if ($lfsFileCount -gt 0) {
                Write-Host "✅ Found $lfsFileCount LFS-tracked files. List saved to: $lfsOutput" -ForegroundColor Green
                Write-Host "LFS Files Preview:" -ForegroundColor Cyan
                Get-Content $lfsOutput | Select-Object -First 10
                if ($lfsFileCount -gt 10) {
                    Write-Host "... and $($lfsFileCount - 10) more files" -ForegroundColor Gray
                }
            } else {
                Write-Host "ℹ️ No LFS-tracked files found." -ForegroundColor Blue
                Remove-Item $lfsOutput -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "ℹ️ Git LFS not initialized in this repository." -ForegroundColor Blue
        }
        
        # 3. Submodules Check
        Write-Host "`n--- Submodules Analysis ---" -ForegroundColor Yellow
        $submoduleOutput = "git-submodules-$repositoryName-$(Get-Date -Format 'yyyyMMdd-HHmm').txt"
        
        if (Test-Path ".gitmodules") {
            Write-Host "Submodules configuration detected. Checking status..." -ForegroundColor Green
            git submodule status > $submoduleOutput 2>&1
            $submoduleCount = (Get-Content $submoduleOutput -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" } | Measure-Object).Count
            
            if ($submoduleCount -gt 0) {
                Write-Host "✅ Found $submoduleCount submodules. Status saved to: $submoduleOutput" -ForegroundColor Green
                Write-Host "Submodules Status:" -ForegroundColor Cyan
                Get-Content $submoduleOutput
            } else {
                Write-Host "⚠️ Submodules configured but none found or initialized." -ForegroundColor Yellow
                Remove-Item $submoduleOutput -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "ℹ️ No submodules configured in this repository." -ForegroundColor Blue
        }
        
        # 4. Repository Size Summary
        Write-Host "`n--- Repository Summary ---" -ForegroundColor Yellow
        $repoSize = (Get-ChildItem -Recurse -Force | Measure-Object -Property Length -Sum).Sum
        $gitSize = (Get-ChildItem .git -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        
        Write-Host "Total Repository Size: $([math]::Round($repoSize / 1MB, 2)) MB" -ForegroundColor Cyan
        Write-Host "Git Database Size: $([math]::Round($gitSize / 1MB, 2)) MB" -ForegroundColor Cyan
        Write-Host "Working Directory Size: $([math]::Round(($repoSize - $gitSize) / 1MB, 2)) MB" -ForegroundColor Cyan
        
    }
    catch {
        Write-Host "❌ Error analyzing repository: $_" -ForegroundColor Red
    }
    finally {
        Set-Location -Path $originalLocation
    }
    
    Write-Host "`n=== Health Check Complete: $repositoryName ===" -ForegroundColor Cyan
}

# Use the declared variables in the command
Write-Host "Generating inventory report for ADO organization: $adoOrg" -ForegroundColor Green
gh ado2gh inventory-report --ado-org $adoOrg

# After generating the inventory, run health checks on any local repositories
Write-Host "`n" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Starting Repository Health Checks" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Check if there are any Git repositories in the current directory or subdirectories
$currentDir = Get-Location
Write-Host "`nScanning for Git repositories in: $currentDir" -ForegroundColor Yellow

# Look for .git directories to identify repositories
$gitRepos = Get-ChildItem -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq ".git" }

if ($gitRepos.Count -gt 0) {
    Write-Host "Found $($gitRepos.Count) Git repository/repositories:" -ForegroundColor Green
    
    foreach ($gitDir in $gitRepos) {
        $repoPath = $gitDir.Parent.FullName
        $repoName = $gitDir.Parent.Name
        
        Write-Host "`nAnalyzing: $repoPath" -ForegroundColor Cyan
        Invoke-RepositoryHealthCheck -repositoryPath $repoPath -repositoryName $repoName
    }
} else {
    Write-Host "ℹ️ No local Git repositories found in current directory tree." -ForegroundColor Blue
    Write-Host "   Health checks are designed for existing cloned repositories." -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Inventory and Health Check Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green