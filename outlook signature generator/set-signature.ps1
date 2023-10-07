# this script is meant to be set up as a group policy
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Bypass -Force

$sourceFolder = '\\server\folder'
$currentUserName = $env:USERNAME
$sourceFileName = "$currentUserName"
$sourceFilePath = Join-Path -Path $sourceFolder -ChildPath "$sourceFileName.htm"
$destinationFolder = "$env:APPDATA\Microsoft\Signatures"
if (-not (Test-Path -Path $destinationFolder)) {
    New-Item -Path $destinationFolder -ItemType Directory -Force | Out-Null
    "Destination folder created." | Out-File -FilePath $outputFilePath -Append -Force
}

$destinationFileName = "$currentUserName.htm"
$destinationFilePath = Join-Path -Path $destinationFolder -ChildPath $destinationFileName
$outputFilePath = "C:\users\$env:USERNAME\sig-log.txt"
"Destination folder created." | Out-File -FilePath $outputFilePath -Append -Force
$sourceFilePath | Out-File -FilePath $outputFilePath -Append -Force
$destinationFilePath | Out-File -FilePath $outputFilePath -Append -Force
"Checking if source file exists..." | Out-File -FilePath $outputFilePath -Append -Force

if (Test-Path -Path $sourceFilePath) {
    "Source file found. Copying to destination..." | Out-File -FilePath $outputFilePath -Append -Force
    }
    try {
        Copy-Item -Path $sourceFilePath -Destination $destinationFilePath -Force -ErrorAction Stop
    }
    catch {
        $errorMessage = "Failed to copy source file to destination."
        $errorMessage | Out-File -FilePath $outputFilePath -Append -Force
        exit
    }

$regKeyPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Setup"
$regKeyName = "DisableRoamingSignatures"
$regKeyValue = 1

try {
    if (!(Test-Path $regKeyPath)) {
        "Parent key does not exist: $regKeyPath" | Out-File -FilePath $outputFilePath -Append -Force
        exit
    }

    Set-ItemProperty -Path $regKeyPath -Name $regKeyName -Value $regKeyValue -Type DWORD -Force
    "Registry value created: $regKeyPath\$regKeyName = $regKeyValue" | Out-File -FilePath $outputFilePath -Append -Force
}
catch {
    "Failed to create registry value: $regKeyPath\$regKeyName" | Out-File -FilePath $outputFilePath -Append -Force
}

$regKeyPath2 = "HKCU:\Software\Microsoft\Office\16.0\Common\MailSettings"
$regKeyName2 = "DisableSignatures"
$regKeyValue2 = 0

try {
    if (!(Test-Path $regKeyPath2)) {
        "Parent key does not exist: $regKeyPath2" | Out-File -FilePath $outputFilePath -Append -Force
        exit
    }

    Set-ItemProperty -Path $regKeyPath2 -Name $regKeyName2 -Value $regKeyValue2 -Type DWORD -Force
    "Registry value created: $regKeyPath2\$regKeyName2 = $regKeyValue2" | Out-File -FilePath $outputFilePath -Append -Force
}
catch {
    "Failed to create registry value: $regKeyPath2\$regKeyName2" | Out-File -FilePath $outputFilePath -Append -Force
}

$registryPath3 = "HKCU:\SOFTWARE\Microsoft\Office\16.0\Common\MailSettings"
$propertiesToDelete3 = @("NewSignature", "ReplySignature")

foreach ($property in $propertiesToDelete3) {
    try {
        $propertyValue = Get-ItemPropertyValue -Path $registryPath3 -Name $property -ErrorAction Stop
        Remove-ItemProperty -Path $registryPath3 -Name $property -ErrorAction SilentlyContinue
        "Deleted registry value '$property' from path '$registryPath3'" | Out-File -FilePath $outputFilePath -Append -Force
    }
    catch {
        "Property '$property' does not exist at path '$registryPath3'." | Out-File -FilePath $outputFilePath -Append -Force
    }
}
