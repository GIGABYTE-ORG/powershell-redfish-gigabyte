# import-example.ps1
# Import all *.psm1 under ./example

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulePath = Join-Path $ScriptRoot "example"

if (-not (Test-Path $ModulePath)) {
    Write-Error "Module folder not found: $ModulePath"
    exit 1
}

Get-ChildItem -Path $ModulePath -Filter *.psm1 -Recurse | ForEach-Object {
    try {
        Write-Host "Importing module: $($_.FullName)"
        Import-Module $_.FullName -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to import module $($_.Name): $_"
    }
}
