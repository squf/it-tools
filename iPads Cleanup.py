# replace "EXAMPLE" text
import pandas as pd

df = pd.read_csv('DevicesWithInventory.csv')
df['Device name'].fillna('', inplace=True)
# Filter the dataframe to keep only rows where 'Device name' starts with 'EXAMPLE-' -- filter this for the Intune group you're looking for
df = df[df['Device name'].str.startswith('EXAMPLE-')]
df.to_excel('C:/folder/EXAMPLE.xlsx', index=False)
