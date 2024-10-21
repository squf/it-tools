# run this script with domain admin rights to be able to read the GPOs
$exportLocation = "C:\GPOs"

if (!(Test-Path -Path $exportLocation)) {
    New-Item -ItemType Directory -Path $exportLocation
}

$GPOs = Get-GPO -All
foreach ($GPO in $GPOs) {
    $GPOname = $GPO.DisplayName
    $GPOnameCleanup = $GPOname -replace '[\\/:*?"<>|]', '_'
    $reportFilePath = Join-Path $exportLocation "$($GPOnameCleanup).xml"
    Get-GPOReport -Guid $GPO.Id -ReportType XML -Path $reportFilePath

    Write-Host "Exported $GPOname to $reportFilePath"
}

Write-Host "All GPO reports have been exported to $exportLocation"
