"""
about:

- this script will loop through every group in intune in your tenant and find which config policies are assigned to it
- prints in terminal and also spits out a .csv when its done (intune_deviceConfigPolicies.csv)
- this is lowkey goated when finding config policy group assignments is the vibe
- im sorry for that last sentence
- this script is built on the azure.identity python library for token authentication to Graph API 
- so therefore, this script will make direct HTTP requests to graph api endpoints
- there is another option to use the msgraph python library instead, but i wanted to use direct API requests instead because i am hoping it will be a more stable way of using this script for a longer period of time
- i dont know what wacky changes microsoft might make to the msgraph sdk at any given time 

dependencies:

- os (for interacting with the operating system)
- requests (for handling HTTP GET/POST requests)
- pandas (for csv output at the end)
- dotenv (for handling the .env file and client-secret authentication
- azure.identity (for authenticating with the .env file)
"""

import os
import requests
import pandas as pd
from dotenv import load_dotenv
from azure.identity import ClientSecretCredential

load_dotenv()

client_id = os.getenv('CLIENT_ID')
client_secret = os.getenv('CLIENT_SECRET')
tenant_id = os.getenv('TENANT_ID')

credential = ClientSecretCredential(tenant_id, client_id, client_secret)
token = credential.get_token("https://graph.microsoft.com/.default").token

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

groups_url = "https://graph.microsoft.com/v1.0/groups"
groups_response = requests.get(groups_url, headers=headers)
groups_response.raise_for_status()
groups_data = groups_response.json().get('value', [])

if not groups_data:
    print("No groups found.")
    exit()

all_dc = []
for group in groups_data:
    group_id = group["id"]
    group_name = group["displayName"]
    print(f"Processing group '{group_name}' with id: {group_id}")
    dcp_url = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies?$expand=assignments"
    dcp_response = requests.get(dcp_url, headers=headers)
    dcp_response.raise_for_status()
    all_policies = dcp_response.json().get('value', [])

    assigned_policies = [
        p for p in all_policies
        if any(a['target'].get('groupId') == group_id for a in p.get('assignments', []))
    ]
    print(f"Device Compliance Policies assigned to '{group_name}':")
    for p in assigned_policies:
        print("   ", p["displayName"])

    dcuris = {
        "ConfigurationPolicies": "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?$expand=assignments",
        "DeviceConfigurations": "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?$expand=assignments",
        "GroupPolicyConfigurations": "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations?$expand=assignments",
        "MobileAppConfigurations": "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations?$expand=assignments"
    }

    for name, url in dcuris.items():
        resp = requests.get(url, headers=headers)
        resp.raise_for_status()
        configs = resp.json().get('value', [])
        assigned_configs = [
            c for c in configs
            if any(a['target'].get('groupId') == group_id for a in c.get('assignments', []))
        ]
        all_dc.extend(assigned_configs)
        if assigned_configs:
            print(f"\n[{name}] assigned to '{group_name}':")
            for dc in assigned_configs:
                display_name = dc.get('displayName') or dc.get('name')
                print("   ", display_name)

if all_dc:
    policy_data = [{
        'Policy Name': dc.get('displayName') or dc.get('name'),
        'Description': dc.get('description'),
        'Assigned Groups': ', '.join([
            a['target']['groupId'] for a in dc.get('assignments', [])
            if a['target'].get('groupId')
        ])
    } for dc in all_dc]

    df = pd.DataFrame(policy_data)
    df.to_csv('intune_deviceConfigPolicies.csv', index=False)
    print("\nExported Intune Device Configuration Policies to intune_deviceConfigPolicies.csv")
else:
    print("No assigned device configurations found.")
