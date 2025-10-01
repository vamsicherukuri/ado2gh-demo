# Mannequin Finder Script
# Usage: .\3_mannequin_validation_fix.ps1 -Org "ADO2GH-Migration" -Out "mannequins.csv"

param(
  [string]$Org = "ADO2GH-Migration",
  [string]$Out = "mannequins.csv"
)

$ErrorActionPreference = 'Stop'

Write-Host "Finding mannequins for organization: $Org" -ForegroundColor Green

# Run the gh ado2gh generate-mannequin-csv command
$cmdOutput = & gh ado2gh generate-mannequin-csv --github-org $Org --output $Out 2>&1
$exit = $LASTEXITCODE

if ($exit -ne 0) {
    Write-Host "Error: $cmdOutput" -ForegroundColor Red
    exit 1
}

# Extract mannequin information from command output
$totalMannequins = 0
$previouslyReclaimed = 0

foreach ($line in $cmdOutput) {
    if ($line -match "# Mannequins Found: (\d+)") {
        $totalMannequins = [int]$matches[1]
    }
    if ($line -match "# Mannequins Previously Reclaimed: (\d+)") {
        $previouslyReclaimed = [int]$matches[1]
    }
}

# Display mannequin details
Write-Host "`nMannequin Details:" -ForegroundColor Cyan
Write-Host "Total mannequins found: $totalMannequins" -ForegroundColor White
Write-Host "Previously reclaimed: $previouslyReclaimed" -ForegroundColor Green
Write-Host "Unclaimed (in CSV): $($totalMannequins - $previouslyReclaimed)" -ForegroundColor Yellow

# Show unclaimed mannequins from CSV
if (Test-Path -LiteralPath $Out) {
    $csvRows = Import-Csv -LiteralPath $Out
    if ($csvRows.Count -gt 0) {
        Write-Host "`nUnclaimed mannequins:" -ForegroundColor Yellow
        $csvRows | Format-Table -AutoSize
    } else {
        Write-Host "`nAll mannequins are already reclaimed!" -ForegroundColor Green
    }
}