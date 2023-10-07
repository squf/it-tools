$LocalIconFolderPath = "C:\Program Files (x86)\Microsoft\Edge\Application"
$SourceIcon = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$DestinationIcon = "C:\Program Files (x86)\Microsoft\Edge\Application"

New-Item $LocalIconFolderPath -Type Directory

curl $SourceIcon -o $DestinationIcon

$new_object = New-Object -ComObject WScript.Shell
$destination = $new_object.SpecialFolders.Item('AllUsersDesktop')
$source_path = Join-Path -Path $destination -ChildPath '\\Email.lnk'
$source = $new_object.CreateShortcut($source_path)
$source.TargetPath = 'https://outlook.com'
$source.IconLocation = ”C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe”
$source.Save()
