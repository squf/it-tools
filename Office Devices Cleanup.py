import pandas as pd

df = pd.read_csv('example.csv')
df['Device name'].fillna('', inplace=True)
df = df[df['Device name'].str.startswith('EXAMPLE-')]
df.to_excel('C:/folder/example.xlsx', index=False)
