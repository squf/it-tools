run ad-report.ps1 first, it will output a .csv file
run ad-report.py next, it will cleanup the .csv file and convert it to an .xlsx format with timestamp

note: typically have to run the .py script from an IDE, doesn't seem to work from just a python shell, probably because it needs to load in the .csv as a dataframe and then make edits to it and the shell just closes out immediately
