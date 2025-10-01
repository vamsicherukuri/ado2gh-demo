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

# Configuration variables for Azure DevOps to GitHub repository migration.
$ADO_ORG = "contosodevopstest" 
$ADO_TEAM_PROJECT = "eShopOnWeb" 
$ADO_REPO = "eShopOnWeb" 
$GITHUB_ORG = "ADO2GH-Migration" 
$GITHUB_REPO = "eShopOnWeb-New"
$LOG_FILE = "pilot-migration-log-$(Get-Date -Format 'yyyyMMdd').txt"

# Migration validation function
function Confirm-Migration {
    param (
        [string]$adoTeamProject,
        [string]$adoRepo,
        [string]$githubRepo
    )

    Write-Output "[$(Get-Date)] Validating migration: $githubRepo" | Tee-Object -FilePath $LOG_FILE -Append

    # GitHub repo info
    gh repo view "$GITHUB_ORG/$githubRepo" --json createdAt,diskUsage,defaultBranchRef,isPrivate |
        Out-File -FilePath "validation-$githubRepo.json"

    # Get GitHub branches
    $ghBranches = gh api "/repos/$GITHUB_ORG/$githubRepo/branches" | ConvertFrom-Json
    $ghBranchNames = $ghBranches | ForEach-Object { $_.name }

    # Set up ADO auth
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$env:ADO_PAT"))
    $headers = @{ Authorization = "Basic $base64AuthInfo" }

    # Get ADO branches
    $adoBranchUrl = "https://dev.azure.com/$ADO_ORG/$adoTeamProject/_apis/git/repositories/$adoRepo/refs?filter=heads/&api-version=7.1"
    $adoBranchResponse = Invoke-RestMethod -Uri $adoBranchUrl -Headers $headers -Method Get
    $adoBranches = $adoBranchResponse.value
    $adoBranchNames = $adoBranches | ForEach-Object { $_.name -replace '^refs/heads/', '' }

    # Compare branch counts
    $ghBranchCount = $ghBranchNames.Count
    $adoBranchCount = $adoBranchNames.Count
    $branchCountStatus = if ($ghBranchCount -eq $adoBranchCount) { "✅ Matching" } else { "❌ Not Matching" }

    Write-Output "[$(Get-Date)] Branch Count: ADO=$adoBranchCount | GitHub=$ghBranchCount | $branchCountStatus" | Tee-Object -FilePath $LOG_FILE -Append

    # Compare branch names
    $missingInGH = $adoBranchNames | Where-Object { $_ -notin $ghBranchNames }
    $missingInADO = $ghBranchNames | Where-Object { $_ -notin $adoBranchNames }

    if ($missingInGH.Count -gt 0) {
        Write-Output "[$(Get-Date)] Branches missing in GitHub: $($missingInGH -join ', ')" | Tee-Object -FilePath $LOG_FILE -Append
    }
    if ($missingInADO.Count -gt 0) {
        Write-Output "[$(Get-Date)] Branches missing in ADO: $($missingInADO -join ', ')" | Tee-Object -FilePath $LOG_FILE -Append
    }

    # Validate commit counts and latest commit IDs
    foreach ($branchName in ($ghBranchNames | Where-Object { $_ -in $adoBranchNames })) {
        # GitHub commit count and latest SHA
        $ghCommitCount = 0
        $ghLatestSha = ""
        $page = 1
        $perPage = 100

        do {
            $ghCommits = gh api "/repos/$GITHUB_ORG/$githubRepo/commits?sha=$branchName&page=$page&per_page=$perPage" | ConvertFrom-Json
            if ($page -eq 1 -and $ghCommits.Count -gt 0) {
                $ghLatestSha = $ghCommits[0].sha
            }
            $ghCommitCount += $ghCommits.Count
            $page++
        } while ($ghCommits.Count -eq $perPage)

        # ADO commit count and latest SHA
        $adoCommitCount = 0
        $adoLatestSha = ""
        $skip = 0
        $batchSize = 1000

        do {
            $adoUrl = "https://dev.azure.com/$ADO_ORG/$adoTeamProject/_apis/git/repositories/$adoRepo/commits?`$top=$batchSize&`$skip=$skip&searchCriteria.itemVersion.version=$branchName&searchCriteria.itemVersion.versionType=branch&api-version=7.1"
            $adoResponse = Invoke-RestMethod -Uri $adoUrl -Headers $headers -Method Get
            $adoBatch = $adoResponse.value
            if ($skip -eq 0 -and $adoBatch.Count -gt 0) {
                $adoLatestSha = $adoBatch[0].commitId
            }
            $adoCommitCount += $adoBatch.Count
            $skip += $batchSize
        } while ($adoBatch.Count -eq $batchSize)

        # Match status
        $countMatch = ($ghCommitCount -eq $adoCommitCount)
        $shaMatch = ($ghLatestSha -eq $adoLatestSha)

        $commitCountStatus = if ($countMatch) { "✅ Matching" } else { "❌ Not Matching" }
        $shaStatus = if ($shaMatch) { "✅ Matching" } else { "❌ Not Matching" }

        # Log results
        Write-Output "[$(Get-Date)] Branch '$branchName': ADO Commits=$adoCommitCount | GitHub Commits=$ghCommitCount | $commitCountStatus" | Tee-Object -FilePath $LOG_FILE -Append
        Write-Output "[$(Get-Date)] Branch '$branchName': ADO SHA=$adoLatestSha | GitHub SHA=$ghLatestSha | $shaStatus" | Tee-Object -FilePath $LOG_FILE -Append
    }

    Write-Output "[$(Get-Date)] Validation complete for $githubRepo" | Tee-Object -FilePath $LOG_FILE -Append
}

Write-Output "[$(Get-Date)] Starting pilot migration: $ADO_TEAM_PROJECT/$ADO_REPO" | Tee-Object -FilePath $LOG_FILE -Append

# Make the repo read-only before migration
Write-Output "[$(Get-Date)] Locking ADO repository: $ADO_REPO" | Tee-Object -FilePath $LOG_FILE -Append
gh ado2gh lock-ado-repo --ado-org $ADO_ORG --ado-team-project $ADO_TEAM_PROJECT --ado-repo $ADO_REPO | Tee-Object -FilePath $LOG_FILE -Append

# Execute pilot migration 
Write-Output "[$(Get-Date)] Executing migration to GitHub" | Tee-Object -FilePath $LOG_FILE -Append
gh ado2gh migrate-repo --ado-org $ADO_ORG --ado-team-project $ADO_TEAM_PROJECT --ado-repo $ADO_REPO --github-org $GITHUB_ORG --github-repo $GITHUB_REPO | Tee-Object -FilePath $LOG_FILE -Append

# Check migration result and run validation
if ($LASTEXITCODE -eq 0) {
    Write-Output "[$(Get-Date)] SUCCESS: Pilot migration completed successfully" | Tee-Object -FilePath $LOG_FILE -Append
    Confirm-Migration -adoTeamProject $ADO_TEAM_PROJECT -adoRepo $ADO_REPO -githubRepo $GITHUB_REPO
} else {
    Write-Output "[$(Get-Date)] FAILED: Pilot migration failed with exit code $LASTEXITCODE" | Tee-Object -FilePath $LOG_FILE -Append
}

Write-Output "[$(Get-Date)] Pilot migration process completed" | Tee-Object -FilePath $LOG_FILE -Append