# .ABOUT
# tweak the number of Write-Host and Scramble-String's you need to fit your .csv you're generating
# this makes it simple to grab a huge list of random passwords and plop them into your .csv
# the .csv has to be formatted like: samaccountname;randompassword -- using ; delimiter 
# the .csv has to be named: RandomizedReset.csv -- its hardcoded in my SetRandomPasswordFromCSV.ps1 script

function Get-RandomCharacters($length, $characters) {
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}

function Scramble-String([string]$inputString){     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $outputString = -join $scrambledStringArray
    return $outputString 
}

$password = Get-RandomCharacters -length 5 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacters -length 1 -characters '1234567890'
$password += Get-RandomCharacters -length 1 -characters '!"§$%&/()=?}][{@#*+'

Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password
Write-Host $password
$password = Scramble-String $password