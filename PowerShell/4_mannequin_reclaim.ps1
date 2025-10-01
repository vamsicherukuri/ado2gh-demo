# Mannequin Reclaim Script
# Usage: .\4_mannequins_reclaim.ps1 -Org "ADO2GH-Migration" -CsvFile "mannequins.csv"

param(
    [string]$Org = "ADO2GH-Migration",
    [string]$CsvFile = "mannequins.csv"
)

$ErrorActionPreference = 'Stop'

Write-Host "Reclaiming mannequins for organization: $Org" -ForegroundColor Green
Write-Host "Using CSV file: $CsvFile" -ForegroundColor White

# Check if CSV file exists
if (-not (Test-Path -LiteralPath $CsvFile)) {
    Write-Host "Error: CSV file '$CsvFile' not found!" -ForegroundColor Red
    Write-Host "Please ensure the CSV file exists with mannequin details." -ForegroundColor Yellow
    exit 1
}

# Show CSV content before reclaiming
Write-Host "`nMannequins to reclaim:" -ForegroundColor Cyan
$csvRows = Import-Csv -LiteralPath $CsvFile
$csvRows | Format-Table -AutoSize

if ($csvRows.Count -eq 0) {
    Write-Host "No mannequins found in CSV file to reclaim." -ForegroundColor Yellow
    exit 0
}

Write-Host "Total mannequins to reclaim: $($csvRows.Count)" -ForegroundColor White

# Run the reclaim command
Write-Host "`nReclaiming mannequins..." -ForegroundColor Yellow
$cmdOutput = & gh ado2gh reclaim-mannequin --github-org $Org --csv $CsvFile 2>&1
$exit = $LASTEXITCODE

if ($exit -ne 0) {
    Write-Host "Error during reclaim process:" -ForegroundColor Red
    Write-Host $cmdOutput -ForegroundColor Red
    exit 1
}

Write-Host "`nReclaim process completed successfully!" -ForegroundColor Green
Write-Host "Command output:" -ForegroundColor White
Write-Host $cmdOutput -ForegroundColor Gray