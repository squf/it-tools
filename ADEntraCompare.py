# this script relies on computer reports existing in a static location
# update the ad_computers & entra_computers variable locations at the top
# i have a seperate powershell script called "exportADComputers.ps1" on my github to grab the AD computers report
# you can export Entra devices in your environment through the GUI at entra.microsoft.com
import pandas as pd

ad_computers = pd.read_csv(r'C:\reports\AD_Computers.csv')
entra_computers = pd.read_csv(r'C:\reports\Entra_Computers.csv')

entra_computers.rename(columns={'displayName': 'Name'}, inplace=True)

matches = pd.merge(ad_computers, entra_computers, on='Name', how='inner')

ad_missing_in_entra = ad_computers[~ad_computers['Name'].isin(entra_computers['Name'])]

entra_missing_in_ad = entra_computers[~entra_computers['Name'].isin(ad_computers['Name'])]

output_path = r'C:\reports\Computer_Comparison.xlsx'
with pd.ExcelWriter(output_path, engine='xlsxwriter') as writer:
    ad_computers.to_excel(writer, sheet_name='AD Computers', index=False)
    entra_computers.to_excel(writer, sheet_name='Entra Computers', index=False)
    matches.to_excel(writer, sheet_name='Matches', index=False)
    ad_missing_in_entra.to_excel(writer, sheet_name='AD Missing in Entra', index=False)

print(f"Comparison file saved to: {output_path}")
