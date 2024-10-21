exportADComputers - grabs all AD computer objects in domain and exports .csv to "C:\reports" directory

please either create this directory on your own PC or update the variables in the script file before using it, i did not include any checking for making the directory if it doesn't exist

ADEntraCompare - you can export your Entra computers from entra.microsoft.com, and save them as "Entra_computers.csv" to the same "C:\reports" directory

once you have both reports in one location, the python script will use pandas and xlsxwriter libraries (dependencies in this case), and output a cleaned up report which shows mismatches between the two

this is useful only in HAADJ environments where you are using Entra Connect to move all your domain devices into Entra, this report is meant to highlight devices which are missing in Entra (maybe you are excluding servers or VMs or something, or maybe you want to check that the Entra sync is working correctly in other ways)
