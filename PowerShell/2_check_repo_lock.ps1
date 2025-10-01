# Script to check if ADO repository is locked
$ADO_ORG = "contosodevopstest"
$ADO_TEAM_PROJECT = "eShopOnWeb"
$ADO_REPO = "eShopOnWeb"

Write-Host "Testing repository access for $ADO_ORG/$ADO_TEAM_PROJECT/$ADO_REPO..." -ForegroundColor Yellow

try {
    # First, try to list all repositories in the project to see what's available
    Write-Host "Fetching all repositories in project '$ADO_TEAM_PROJECT'..." -ForegroundColor Yellow
    
    $headers = @{
        Authorization = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$env:ADO_PAT")))"
    }
    
    $allReposUrl = "https://dev.azure.com/$ADO_ORG/$ADO_TEAM_PROJECT/_apis/git/repositories?api-version=7.0"
    $allReposResponse = Invoke-RestMethod -Uri $allReposUrl -Headers $headers -Method GET
    
    Write-Host "Found $($allReposResponse.count) repositories in project:" -ForegroundColor Green
    
    # Find the target repository in the list
    $targetRepo = $null
    foreach ($repo in $allReposResponse.value) {
        Write-Host "  - Name: $($repo.name), ID: $($repo.id)" -ForegroundColor Cyan
        if ($repo.name -eq $ADO_REPO) {
            $targetRepo = $repo
        }
    }
    
    if ($targetRepo) {
        Write-Host "`nRepository found: $($targetRepo.name)" -ForegroundColor Green
        Write-Host "Repository ID: $($targetRepo.id)" -ForegroundColor Green
        Write-Host "Repository URL: $($targetRepo.webUrl)" -ForegroundColor Green
        Write-Host "Default Branch: $($targetRepo.defaultBranch)" -ForegroundColor Green
        
        # Check if we can access the repository's refs (this will fail if truly locked)
        Write-Host "`nTesting repository access by getting branches..." -ForegroundColor Yellow
        $refsUrl = "https://dev.azure.com/$ADO_ORG/$ADO_TEAM_PROJECT/_apis/git/repositories/$($targetRepo.id)/refs?api-version=7.0"
        
        try {
            $refsResponse = Invoke-RestMethod -Uri $refsUrl -Headers $headers -Method GET
            Write-Host "✓ Successfully accessed repository branches ($($refsResponse.count) refs found)" -ForegroundColor Green
            Write-Host "Repository appears to be accessible (not locked for read operations)" -ForegroundColor Green
        } catch {
            Write-Host "✗ Failed to access repository branches: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "This could indicate the repository is locked or you don't have permissions" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nRepository '$ADO_REPO' not found in the project!" -ForegroundColor Red
    }
    
    # Try to get repository permissions to check for deny permissions
    Write-Host "Checking repository permissions..." -ForegroundColor Yellow

    # Note: You would need additional permissions to check security settings
    # This is a basic connectivity test
    
} catch {
    Write-Host "Error accessing repository: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nNote: To fully check if repository is locked, check the Security tab in Azure DevOps Project Settings > Repositories" -ForegroundColor Cyan