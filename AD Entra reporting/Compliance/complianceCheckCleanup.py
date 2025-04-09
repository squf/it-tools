# requires pandas library
import pandas as pd

# make sure this points to the correct file from complianceCheck.ps1 which you must run first
# both the .ps1 and this .py file should be in the same working directory on your PC for ease of use
df = pd.read_csv('complianceCheck.csv', sep=';')

df['ComplianceReason'] = df['Settingname'].str.extract(r'Windows10CompliancePolicy\.(.+)')

grouped = df.groupby('ComplianceReason')

with pd.ExcelWriter('complianceCheckCleaned.xlsx') as writer:
    for name, group in grouped:
        sheet_name = str(name)[:31]  
        group.to_excel(writer, sheet_name=sheet_name, index=False)

print("Report successfully organized into complianceCheckCleaned.xlsx")
input("Press Enter to close...")
