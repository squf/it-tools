#Variables creating local folder and download .ico file
$LocalIconFolderPath = "C:\Program Files (x86)\Microsoft\Edge\Application"
$SourceIcon = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$DestinationIcon = "C:\Program Files (x86)\Microsoft\Edge\Application"


#Step 1 - Create a folder to place the URL icon
New-Item $LocalIconFolderPath -Type Directory

#Step 2 - Download a ICO file from a website into previous created folder
curl $SourceIcon -o $DestinationIcon

#Step 3 - Add the custom URL shortcut to your Desktop with custom icon
$new_object = New-Object -ComObject WScript.Shell
$destination = $new_object.SpecialFolders.Item('AllUsersDesktop')
$source_path = Join-Path -Path $destination -ChildPath '\\Miller Email.lnk'
$source = $new_object.CreateShortcut($source_path)
$source.TargetPath = 'https://outlook.com/artera.com'
$source.IconLocation = ”C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe”
$source.Save()