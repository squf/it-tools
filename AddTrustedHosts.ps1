# this script is supposed to pull in a "hosts.csv" file containing 1 column of IP addresses, to add to your local TrustedHosts cache
# The .csv header is just "Asset" as seen on line 18 -> $csvData.Asset
Write-Host "🚨 RUN THIS FROM YOUR Domain Admin ACCOUNT 🚨" -ForegroundColor Green

# this line fetches the current directory where the script is saved at locally
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = (Get-Item $scriptDir).Parent.Parent.FullName

# this line may need some tweaking in your environment
# what i am doing here is looking up a few directories from where i'm saving this script file at for a "hosts.csv" file
# this contains a huge list of IP addresses for me that i want to add to TrustedHosts
$csvFiles = Get-ChildItem -Path $rootDir -Filter 'hosts.csv' -Recurse | Where-Object { $_.DirectoryName -notmatch 'scripts' }

# collecting all the IP addresses from the hosts.csv file
$allIPAddresses = @()
foreach ($csvFile in $csvFiles) {
    $csvData = Import-Csv -Path $csvFile.FullName
    $allIPAddresses += $csvData.Asset
}
$allIPAddresses = $allIPAddresses | ForEach-Object { $_.Trim() } | Sort-Object -Unique

# checking your current trusted hosts cache to avoid overwriting it
$currentTrusted = (Get-Item WSMan:\localhost\Client\TrustedHosts).Value -split ',' | ForEach-Object { $_.Trim() }
$combined = ($currentTrusted + $allIPAddresses) | Where-Object { $_ -ne "" } | Sort-Object -Unique

# chunking IP addresses into batches to stay under the 10239 character limit, set-item will apparently just silently fail if it exceeds this length limit and i didn't know about that until now??? ok
# my "hosts.csv" contained over 1,500 IP addresses I wanted to run remote pwsh cmdlets to, which exceeds the limit i can update TrustedHosts with at one time, so it needs to be batched out into chunks
$trustedString = ""
$batch = @()

foreach ($ip in $combined) {
    $testString = ($batch + $ip) -join ','
    if ($testString.Length -gt 10239) {
        Set-Item WSMan:\localhost\Client\TrustedHosts -Value ($batch -join ',')
        Write-Host "✅ Committed batch of $($batch.Count) IPs to TrustedHosts"
        $batch = @($ip)
    } else {
        $batch += $ip
    }
}

# commence to batching. i even included cute little emojis how sweet.
if ($batch.Count -gt 0) {
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value ($batch -join ',')
    Write-Host "✅ Committed final batch of $($batch.Count) IPs to TrustedHosts"
}

Write-Host "`n🎉 TrustedHosts update complete. You can verify with:`n(Get-Item WSMan:\localhost\Client\TrustedHosts).Value"
