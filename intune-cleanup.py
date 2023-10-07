# just filters out intune reports to look for devices starting with EXAMPLE-
# probably only useful in cases like mine where a dozen companies are sharing a single azure tenant
# i have to sort through every other companies devices when running intune reports, hence, this file
import pandas as pd

df = pd.read_csv('example.csv')
df['Device name'].fillna('', inplace=True)
df = df[df['Device name'].str.startswith('EXAMPLE-')]
df.to_excel('C:/folder/example.xlsx', index=False)
