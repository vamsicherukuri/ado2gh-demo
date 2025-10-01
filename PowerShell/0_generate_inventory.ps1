# ADO2GH Inventory Script with Git-Sizer Health Checks
# Declare variables at the top of the script
$adoOrg = "contosodevopstest"  # Replace with your actual ADO organization name

# Check to make sure we have the required Tokens for access to GitHub and AzDO
$missingTokens = $false

if (!$env:ADO_PAT) {
    Write-Host "Missing ADO_PAT Environment Variable" -ForegroundColor Red
    $missingTokens = $true
}

if (!$env:GH_PAT) {
    Write-Host "Missing GH_PAT Environment Variable" -ForegroundColor Red
    $missingTokens = $true
}

if ($missingTokens) {
    Write-Host "Please set the required environment variables before running this script." -ForegroundColor Yellow
    exit
}

# Repository Health Check Function (Git-Sizer only)
function Test-RepositoryHealth {
    param(
        [string]$RepoPath,
        [string]$RepoName
    )
    
    Write-Host "`n=== Repository Health Check: $RepoName ===" -ForegroundColor Cyan
    
    $originalLocation = Get-Location
    try {
        Set-Location $RepoPath
        
        # Git-Sizer Analysis
        Write-Host "`n--- Git-Sizer Analysis ---" -ForegroundColor Yellow
        if (Get-Command git-sizer -ErrorAction SilentlyContinue) {
            Write-Host "Running git-sizer..." -ForegroundColor Green
            git-sizer --verbose
        } elseif (Test-Path ".\git-sizer\git-sizer.exe") {
            Write-Host "Using local git-sizer..." -ForegroundColor Green
            .\git-sizer\git-sizer.exe --verbose
        } elseif (Test-Path "..\git-sizer\git-sizer.exe") {
            Write-Host "Using local git-sizer (parent dir)..." -ForegroundColor Green
            ..\git-sizer\git-sizer.exe --verbose
        } else {
            Write-Host "Git-sizer not found. Skipping analysis." -ForegroundColor Yellow
        }
        
        # Repository Summary
        Write-Host "`n--- Repository Summary ---" -ForegroundColor Yellow
        $repoSize = (Get-ChildItem -Recurse -Force | Measure-Object -Property Length -Sum).Sum
        Write-Host "Total Repository Size: $([math]::Round($repoSize / 1MB, 2)) MB" -ForegroundColor Cyan
        
    } catch {
        Write-Host "Error analyzing repository: $_" -ForegroundColor Red
    } finally {
        Set-Location $originalLocation
    }
    
    Write-Host "=== Health Check Complete ===" -ForegroundColor Cyan
}

# Main execution - ADO2GH Inventory Generation
Write-Host "Generating inventory report for ADO organization: $adoOrg" -ForegroundColor Green
gh ado2gh inventory-report --ado-org $adoOrg

# Run health checks on local repositories
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Starting Repository Health Checks" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

$currentDir = Get-Location
Write-Host "Scanning for Git repositories in: $currentDir" -ForegroundColor Yellow

# Look for .git directories
$gitRepos = Get-ChildItem -Directory -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq ".git" }

if ($gitRepos.Count -gt 0) {
    Write-Host "Found $($gitRepos.Count) Git repository/repositories" -ForegroundColor Green
    
    foreach ($gitDir in $gitRepos) {
        $repoPath = $gitDir.Parent.FullName
        $repoName = $gitDir.Parent.Name
        
        Test-RepositoryHealth -RepoPath $repoPath -RepoName $repoName
    }
} else {
    Write-Host "No local Git repositories found." -ForegroundColor Blue
    Write-Host "Health checks work on existing cloned repositories." -ForegroundColor Gray
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "Inventory and Health Check Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green