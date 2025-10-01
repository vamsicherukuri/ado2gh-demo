# Simple test
Write-Host 'Starting Health Check Test' -ForegroundColor Green
if (Get-Command git-sizer -ErrorAction SilentlyContinue) { Write-Host 'Git-sizer found' } else { Write-Host 'Git-sizer not found' }
