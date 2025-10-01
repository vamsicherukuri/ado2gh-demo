# Enhanced ADO2GH Inventory Script with Repository Health Checks
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

# Repository Health Check Function
function Test-RepositoryHealth {
    param(
        [string]$RepoPath,
        [string]$RepoName
    )
    
    Write-Host "`n=== Repository Health Check: $RepoName ===" -ForegroundColor Cyan
    
    $originalLocation = Get-Location
    try {
        Set-Location $RepoPath
        
        # 1. Git-Sizer Analysis
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
        
        # 2. Git LFS Check
        Write-Host "`n--- Git LFS Check ---" -ForegroundColor Yellow
        if (Test-Path ".git\lfs") {
            Write-Host "Git LFS is initialized. Checking tracked files..." -ForegroundColor Green
            git lfs ls-files
        } else {
            Write-Host "Git LFS not initialized in this repository." -ForegroundColor Blue
        }
        
        # 3. Submodules Check
        Write-Host "`n--- Submodules Check ---" -ForegroundColor Yellow
        if (Test-Path ".gitmodules") {
            Write-Host "Submodules detected. Checking status..." -ForegroundColor Green
            git submodule status
        } else {
            Write-Host "No submodules configured." -ForegroundColor Blue
        }
        
        # 4. Repository Summary
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

# Enhanced CSV Processing Function
function Add-RepositoryHealthToCSV {
    param(
        [string]$CsvPath
    )
    
    Write-Host "`n=== Enhancing CSV with LFS and Submodule Data ===" -ForegroundColor Cyan
    
    if (-not (Test-Path $CsvPath)) {
        Write-Host "CSV file not found: $CsvPath" -ForegroundColor Red
        return
    }
    
    # Read existing CSV
    $csvData = Import-Csv $CsvPath
    
    # Create enhanced data array
    $enhancedData = @()
    
    foreach ($repo in $csvData) {
        Write-Host "Processing: $($repo.repo) in $($repo.teamproject)" -ForegroundColor Yellow
        
        # Initialize new columns
        $repo | Add-Member -MemberType NoteProperty -Name "lfs-enabled" -Value "No" -Force
        $repo | Add-Member -MemberType NoteProperty -Name "lfs-files-count" -Value "0" -Force
        $repo | Add-Member -MemberType NoteProperty -Name "lfs-files-list" -Value "None" -Force
        $repo | Add-Member -MemberType NoteProperty -Name "submodules-enabled" -Value "No" -Force
        $repo | Add-Member -MemberType NoteProperty -Name "submodules-count" -Value "0" -Force
        $repo | Add-Member -MemberType NoteProperty -Name "submodules-list" -Value "None" -Force
        $repo | Add-Member -MemberType NoteProperty -Name "git-sizer-status" -Value "Not Analyzed" -Force
        
        # Create temporary directory for cloning
        $tempDir = Join-Path $env:TEMP "ado2gh_analysis_$($repo.repo)_$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        try {
            # Clone repository for analysis
            Write-Host "  Cloning repository for analysis..." -ForegroundColor Gray
            $cloneUrl = $repo.url
            
            # Clone with minimal history for faster analysis
            git clone --depth 1 $cloneUrl $tempDir 2>$null
            
            if (Test-Path $tempDir) {
                $originalLocation = Get-Location
                Set-Location $tempDir
                
                # Check Git LFS
                Write-Host "  Checking Git LFS..." -ForegroundColor Gray
                if (Test-Path ".git\lfs") {
                    $repo."lfs-enabled" = "Yes"
                    
                    # Get LFS files
                    $lfsFiles = git lfs ls-files 2>$null
                    if ($lfsFiles) {
                        $lfsFilesList = $lfsFiles -join "; "
                        $repo."lfs-files-count" = ($lfsFiles | Measure-Object).Count.ToString()
                        $repo."lfs-files-list" = if ($lfsFilesList.Length -gt 100) { 
                            $lfsFilesList.Substring(0, 97) + "..." 
                        } else { 
                            $lfsFilesList 
                        }
                    }
                } else {
                    # Check if LFS is configured but not initialized
                    if (git lfs ls-files 2>$null) {
                        $repo."lfs-enabled" = "Configured"
                        $lfsFiles = git lfs ls-files 2>$null
                        if ($lfsFiles) {
                            $lfsFilesList = $lfsFiles -join "; "
                            $repo."lfs-files-count" = ($lfsFiles | Measure-Object).Count.ToString()
                            $repo."lfs-files-list" = if ($lfsFilesList.Length -gt 100) { 
                                $lfsFilesList.Substring(0, 97) + "..." 
                            } else { 
                                $lfsFilesList 
                            }
                        }
                    }
                }
                
                # Check Submodules
                Write-Host "  Checking submodules..." -ForegroundColor Gray
                if (Test-Path ".gitmodules") {
                    $repo."submodules-enabled" = "Yes"
                    
                    # Get submodule status
                    $submoduleStatus = git submodule status 2>$null
                    if ($submoduleStatus) {
                        $submodulesList = ($submoduleStatus | ForEach-Object { 
                            $parts = $_ -split '\s+'
                            if ($parts.Length -gt 1) { $parts[1] }
                        }) -join "; "
                        
                        $repo."submodules-count" = ($submoduleStatus | Measure-Object).Count.ToString()
                        $repo."submodules-list" = if ($submodulesList.Length -gt 100) { 
                            $submodulesList.Substring(0, 97) + "..." 
                        } else { 
                            $submodulesList 
                        }
                    }
                }
                
                # Git-Sizer status (simplified check)
                $repoSizeMB = [math]::Round((Get-ChildItem -Recurse -Force | Measure-Object -Property Length -Sum).Sum / 1MB, 2)
                if ($repoSizeMB -gt 100) {
                    $repo."git-sizer-status" = "Large (${repoSizeMB}MB)"
                } elseif ($repoSizeMB -gt 50) {
                    $repo."git-sizer-status" = "Medium (${repoSizeMB}MB)"
                } else {
                    $repo."git-sizer-status" = "Small (${repoSizeMB}MB)"
                }
                
                Set-Location $originalLocation
                Write-Host "  ✅ Analysis complete" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️ Could not clone repository" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "  ❌ Error analyzing repository: $_" -ForegroundColor Red
        } finally {
            # Clean up temporary directory
            if (Test-Path $tempDir) {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
        
        $enhancedData += $repo
    }
    
    # Export enhanced CSV
    $enhancedCsvPath = $CsvPath -replace '\.csv$', '_enhanced.csv'
    $enhancedData | Export-Csv -Path $enhancedCsvPath -NoTypeInformation
    
    Write-Host "✅ Enhanced CSV saved to: $enhancedCsvPath" -ForegroundColor Green
    
    # Show summary
    $lfsEnabledCount = ($enhancedData | Where-Object { $_."lfs-enabled" -ne "No" }).Count
    $submodulesEnabledCount = ($enhancedData | Where-Object { $_."submodules-enabled" -eq "Yes" }).Count
    
    Write-Host "`n📊 Enhancement Summary:" -ForegroundColor Cyan
    Write-Host "  Total repositories analyzed: $($enhancedData.Count)" -ForegroundColor White
    Write-Host "  Repositories with LFS: $lfsEnabledCount" -ForegroundColor White
    Write-Host "  Repositories with submodules: $submodulesEnabledCount" -ForegroundColor White
}

# Main execution
Write-Host "Generating inventory report for ADO organization: $adoOrg" -ForegroundColor Green
gh ado2gh inventory-report --ado-org $adoOrg

# Enhance the repos.csv with LFS and Submodule data
if (Test-Path "repos.csv") {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "Enhancing Inventory with LFS and Submodule Data" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    
    Add-RepositoryHealthToCSV -CsvPath "repos.csv"
} else {
    Write-Host "⚠️ repos.csv not found. Skipping enhancement." -ForegroundColor Yellow
}

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