# quarterly report on AD users and their status

- at one of my jobs i had to provide an Excel report every quarter on our entire AD user inventory, with the status of the user (Disabled, PWD expired, etc)
- that's what these scripts were for
- the .ps1 script would work well to grab me all the users and their status, but it would export the status in HEX format like *514* instead of *Disabled*
- so the .py script would be run afterwards, to cleanup the output from the .ps1 script. so basically just doing a big find+replace for me

**run ad-report.ps1 first**, it will output a .csv file
**run ad-report.py next**, it will cleanup the .csv file and convert it to an .xlsx format with timestamp

note: typically have to run the .py script from an IDE, doesn't seem to work from just a python shell, probably because it needs to load in the .csv as a dataframe and then make edits to it and the shell just closes out immediately i assume

# general powershell tips for common AD reporting use-cases

- take for example, you want to quickly export a security group from AD and include some info like their Name and Job title:
- `Get-ADGroupMember -identity "Group Users" | Get-ADUser -properties Title | select name, title | export-csv "C:\somedirectory\groupusers.csv"`
- `Get-ADGroupMember` will let you find an AD group in powershell, but doesn't include the User details
- `Get-ADGroup -filter * | select name` will report all AD groups by name of the group
- `Get-ADUser` is what you need to find some other details specific to the User objects
- So, you start with `Get-ADGroupMember` to find the group you're looking for and then pipe `|` it into `Get-ADUser` to find user-specific details, in this example we're looking for `-properties Title` which is the Job Title (listed under Properties > Organization > Job Title in the AD GUI)
- Next, we pipe all of that into only selecting the name and title with `select name, title` before piping it into a csv export: `export-csv "C:\somedirectory\groupusers.csv"`
- This way we can very quickly get AD group reports with some user details on any group we want from AD
- You can use this string to list all available ADUser properties for tweaking what you want to report: `Get-ADUser <username> -Properties * | Get-Member` this will output all of the valid property names you can target
- You can do the same with an AD group with `Get-ADGroup "GroupName" -Properties * | Get-Member` you can also leave the end pipe off but i prefer the formatting with the `Get-Member` pipe personally
