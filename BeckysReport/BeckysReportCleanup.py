# this script is supposed to run after running ad-report.ps1
import pandas as pd
import datetime

df = pd.read_csv('ad-report.csv')

df.loc[df['Role'] == 512, 'Role'] = ''
df.loc[df['Role'] == 514, 'Role'] = 'DISABLED'
df.loc[df['Role'] == 544, 'Role'] = 'NO_PWD_REQD'
df.loc[df['Role'] == 546, 'Role'] = 'DISABLED^NO_PWD_REQD'
df.loc[df['Role'] == 2080, 'Role'] = 'PASSWD_NOTREQD'
df.loc[df['Role'] == 66048, 'Role'] = 'NO_PWD_EXP'
df.loc[df['Role'] == 66050, 'Role'] = 'DISABLED^NO_PWD_EXP'
df.loc[df['Role'] == 66080, 'Role'] = 'NO_PWD_EXP^NO_PWD_REQD'
df.loc[df['Role'] == 66082, 'Role'] = 'DISABLED^NO_PWD_EXP^NO_PWD_REQD'

e = datetime.date.today()
df.to_excel(f"ad-report_{e}.xlsx", sheet_name="Quarterly Report", index=False)
