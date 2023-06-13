import pandas as pd

# Import the CSV file as a Pandas dataframe
df = pd.read_csv('DevicesWithInventory.csv')

# Fill NaN values in the 'Device name' column with an empty string
df['Device name'].fillna('', inplace=True)

# Filter the dataframe to keep only rows where 'Device name' starts with 'WINS-'
df = df[df['Device name'].str.startswith('WINS-')]

# Export the filtered dataframe to an XLSX file in the specified directory
df.to_excel('C:/scripts/Intune Reports/Miller Intune FIELD Devices.xlsx', index=False)
