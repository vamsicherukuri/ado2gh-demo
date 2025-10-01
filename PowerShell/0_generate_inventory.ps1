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

# Use the declared variables in the command
Write-Host "Generating inventory report for ADO organization: $adoOrg" -ForegroundColor Green
gh ado2gh inventory-report --ado-org $adoOrg