# Define the directory path
$dirPath = "C:\scripts\WINS Groups Checkers"

# Get the list of .ps1 files in the directory
$ps1Files = Get-ChildItem -Path $dirPath -Filter *.ps1 | Where-Object {$_.Name -ne "Run_All.ps1"}

# Loop through the .ps1 files and run every other one
for ($i = 0; $i -lt $ps1Files.Count; $i += 2) {
    & $ps1Files[$i].FullName
}
