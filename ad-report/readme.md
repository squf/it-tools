# quarterly report on AD users and their status

- at one of my jobs i had to provide an Excel report every quarter on our entire AD user inventory, with the status of the user (Disabled, PWD expired, etc)
- that's what these scripts were for
- the .ps1 script would work well to grab me all the users and their status, but it would export the status in HEX format like *514* instead of *Disabled*
- so the .py script would be run afterwards, to cleanup the output from the .ps1 script. so basically just doing a big find+replace for me

**run ad-report.ps1 first**, it will output a .csv file
**run ad-report.py next**, it will cleanup the .csv file and convert it to an .xlsx format with timestamp

note: typically have to run the .py script from an IDE, doesn't seem to work from just a python shell, probably because it needs to load in the .csv as a dataframe and then make edits to it and the shell just closes out immediately i assume
