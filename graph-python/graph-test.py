"""
about:

- this is the first script i will make just to ensure my configuration is working and i can authenticate to graph api via .py script
- i want to use client-secret credential authentication which requires a registered entra app
- furthermore, i want to store this information in an .env file in the working directory so i can just call the same thing in any other .py files i make for graph in the future
- running this file will spit out a list of users verifying that graph api client-secret authentication is working correctly
- this requires you to first register an entra app, give it the necessary application permissions, create a client secret, and copy the [client ID|client secret|tenant id] values into the same working directory as the script in a .env file for managing authentication 
"""

"""
dependencies:

- python-dotenv (for handling .env files)
- msal (microsoft authentication library, so i can use the client-secret authentication in the files)
"""

import os
from dotenv import load_dotenv
import msal
import requests

load_dotenv()

client_id = os.getenv('CLIENT_ID')
client_secret = os.getenv('CLIENT_SECRET')
tenant_id = os.getenv('TENANT_ID')
authority = f'https://login.microsoftonline.com/{tenant_id}'

app = msal.ConfidentialClientApplication(
    client_id,
    authority=authority,
    client_credential=client_secret
)

token_response = app.acquire_token_for_client(scopes=["https://graph.microsoft.com/.default"])
access_token = token_response.get('access_token')

headers = {
    'Authorization': f'Bearer {access_token}'
}

graph_url = 'https://graph.microsoft.com/v1.0/users'
response = requests.get(graph_url, headers=headers)
users = response.json()
print(users)
