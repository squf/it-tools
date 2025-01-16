"""
about:

- first off this assumes you have a .env and entra app set up for handling client-secret authentication
- this script will loop through every group in intune in your tenant and find which config policies are assigned to it
- spits out a .csv when its done (intune_winDeviceConfigPolicies.csv)
- this script is built on the azure.identity python library for token authentication to Graph API 
- so therefore, this script will make direct HTTP requests to graph api endpoints
- there is another option to use the msgraph python library instead, but i wanted to use direct API requests instead because i am hoping it will be a more stable way of using this script for a longer period of time
- i dont know what wacky changes microsoft might make to the msgraph sdk at any given time 
- also includes some logic to handle converting GUID to human readable format for groups, very nice

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

def get_group_name(group_id):
    """Fetch group displayName from its GUID. Fallback to GUID if it fails."""
    group_url = f"https://graph.microsoft.com/v1.0/groups/{group_id}"
    resp = requests.get(group_url, headers=headers)
    if resp.status_code == 200:
        return resp.json().get("displayName", group_id)
    return group_id

def main():
    endpoints = [
        "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?$expand=assignments",
        "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?$expand=assignments"
    ]

    all_policies = []
    for url in endpoints:
        resp = requests.get(url, headers=headers)
        resp.raise_for_status()
        items = resp.json().get("value", [])
        if items:
            all_policies.extend(items)

    print(f"Retrieved {len(all_policies)} configuration policy objects from both endpoints.")

    policy_data = []
    for policy in all_policies:
        policy_name = policy.get("displayName", "")
        description = policy.get("description", "")

        assignments = policy.get("assignments", [])
        included_groups = []
        excluded_groups = []

        for assignment in assignments:
            target = assignment.get("target", {})
            assignment_type = target.get("@odata.type", "").lower()
            group_id = target.get("groupId")

            if group_id:
                group_name = get_group_name(group_id)
                if "exclusiongroupassignmenttarget" in assignment_type:
                    excluded_groups.append(group_name)
                else:
                    included_groups.append(group_name)
            else:
                included_groups.append("Non-Group Target (All Devices/Users/Filter?)")

        policy_data.append({
            "Policy Name": policy_name,
            "Description": description,
            "Included Groups": ", ".join(included_groups),
            "Excluded Groups": ", ".join(excluded_groups)
        })

    df = pd.DataFrame(policy_data)
    df.to_csv("intune_winDeviceConfigPolicies.csv", index=False)
    print("\nExported all Windows device configuration policies to intune_winDeviceConfigPolicies.csv")

if __name__ == "__main__":
    main()
