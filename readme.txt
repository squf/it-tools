make a .csv named "computer_displaynames_serials.csv" with two columns

First column header: Hostname (this will contain the computer objects)
Second column header: DisplayName (this will contain the display names of the user)
Third column header: Serial Number (this will contain the PC S/N)

Example:

Hostname,DisplayName,SerialNumber
COMPUTER01,John Smith,ABC123
COMPUTER02,Jane Doe,XYZ789

Run the script

It should find every ComputerObject in AD that matches whats in the .csv file and update the computer description field to include the associated users DisplayName | SerialNumber. I need to generate this report first via iCare and create the .csv file.