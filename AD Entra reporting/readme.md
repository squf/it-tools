# **exportADComputers** 

grabs all AD computer objects in domain and exports .csv to "C:\reports" directory

please either create this directory on your own PC or update the variables in the script file before using it, i did not include any checking for making the directory if it doesn't exist

# **ADEntraCompare** 

you can export your Entra computers from entra.microsoft.com, and save them as "Entra_computers.csv" to the same "C:\reports" directory

once you have both reports in one location, the python script will use pandas and xlsxwriter libraries (dependencies in this case), and output a cleaned up report which shows mismatches between the two

this is useful only in HAADJ environments where you are using Entra Connect to move all your domain devices into Entra, this report is meant to highlight devices which are missing in Entra (maybe you are excluding servers or VMs or something, or maybe you want to check that the Entra sync is working correctly in other ways)

# **useful workaround for python libraries**

if you're in an environment where SSL inspection on the firewall is blocking access to pypi.org and you can't install libraries in your python venv as a result, try this line:

**pip install --trusted-host=pypi.org --trusted-host=files.pythonhosted.org --user {name of whatever you're installing}**

i found this from: https://github.com/pypa/pip/issues/5363 -- and it allowed me to bypass the error i was getting when trying to install pandas and xlsxwriter at my current company 

*the error i was receiving, in case you want to confirm you're getting the same error:* 

*(Retrying (Retry(total=4, connect=None, read=None, redirect=None, status=None)) after connection broken by 'SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1045)'))': /simple/pip/)*
