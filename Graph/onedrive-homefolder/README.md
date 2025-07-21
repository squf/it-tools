# OneDrive Home Folder Migration Scripts

This repository contains a set of PowerShell scripts designed to migrate on-premises user home directories to their respective OneDrive for Business accounts. The main script creates a `Home Folder` in each user's OneDrive and copies their entire directory structure into it.

This project was developed for a Hybrid Azure AD Joined (HAADJ) environment and serves as a free alternative to paid tools like ShareGate for this specific migration task.

**Disclaimer:** These scripts worked in my environment as of July 2025. While they include robust error handling, use them at your own risk. For enterprise-grade migrations with support, consider purchasing a dedicated tool like **[ShareGate](https://sharegate.com/)**.

-----

## 📋 Prerequisites

Before you begin, ensure you have the following:

  * **PowerShell 7+** (`pwsh7`) and **Windows Terminal**.
  * An **Entra ID App Registration** with the required permissions (see below).
  * User OneDrive accounts must be **[pre-provisioned](https://learn.microsoft.com/en-us/sharepoint/pre-provision-accounts)**.
  * The `OneDrive` PowerShell module by Marcel Meurer. Install it with:
    ```powershell
    Install-Module -Name OneDrive -Force
    ```

-----

## ⚙️ App Registration Setup

You'll need to create an Entra ID App Registration for the scripts to authenticate with the Microsoft Graph API.

1.  **[Register an application](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app)** in your Entra ID tenant.

2.  Create a **Client Secret** for the application. **Copy the secret value immediately**—it will not be visible again.

3.  Grant the following **Application** API permissions to your app registration and provide admin consent:

    #### Microsoft Graph

      * `Files.ReadWrite.All`
      * `Sites.ReadWrite.All`
      * `User.Read.All`

    #### SharePoint

      * `Sites.FullControl.All`
      * `User.Read.All`

    > **Note:** The permissions listed above are a refined set sufficient for this task based on my internal testing, though I may be missing some, this should work though.

-----

## 🚀 How to Use

The process involves two main scripts: `get-token.ps1` to authenticate and `ODHF.ps1` to perform the migration.

### Step 1: Configure the Scripts

1.  **`get-token.ps1`:** Open the script and fill in the variables at the top with your Entra app's **Tenant ID**, **Client ID**, and the **Client Secret** you saved earlier.
2.  **`ODHF.ps1`:** Open the script and set the `$baseLocalRoot` variable to the UNC path of your on-premises user home directories (e.g., `\\server\users`).

### Step 2: Run the Migration

1.  Open a new PowerShell 7 terminal.
2.  First, run the authentication script:
    ```powershell
    .\get-token.ps1
    ```
    This will obtain an access token and store it in a session variable (`$Auth`). The token is valid for one hour.
3.  Next, run the main migration script:
    ```powershell
    .\ODHF.ps1
    ```
4.  The script will prompt you for the `username` of the user you wish to migrate (e.g., `FirstnameL`).
5.  The script will then locate their on-prem folder, connect to their OneDrive, and begin the copy process. Progress will be displayed in the console.

> **Important:** Both scripts must be run in the **same terminal session**, as `ODHF.ps1` depends on the `$Auth` variable created by `get-token.ps1`.

-----

## ✨ Features & Logic

The main script (`ODHF.ps1`) has been optimized to be efficient and resilient:

  * **Batch Folder Creation:** Creates up to 20 folders in a single API call to reduce throttling risk.
  * **Efficient File Syncing:** Before uploading, it fetches a list of remote files to avoid re-uploading existing content, saving a significant number of API calls.
  * **Throttling & Delay Handling:** Includes logic to automatically wait and retry on `HTTP 429 (Too Many Requests)` errors and `HTTP 404 (Not Found)` errors caused by API replication delays.
  * **Large File Support:** Automatically uses resumable upload sessions for files larger than 15 MB.
  * **Logging:** All operations are logged to a user-specific text file in `C:\tmp\ODHF_Logs`, making it easy to track progress and troubleshoot.

-----

## troubleshooting & Notes

  * **`401 Unauthorized` Errors:** If you encounter `401` errors, check for any **Conditional Access policies** based on geolocation. You may need to temporarily exclude your admin account or the app's service principal.
  * **API Throttling (`429` Errors):** If you still hit throttling limits, you can register a **second Entra app** and create a copy (`get-token2.ps1`) with the new credentials. This allows you to run two migrations in parallel under separate API quotas.

-----

## 📂 Script Descriptions

This repository contains several scripts, but you only need `get-token.ps1` and `ODHF.ps1` for production use. The others are included for context and archival purposes.

  * `get-token.ps1`: Authenticates to the Graph API and stores the access token. **Must be run first.**
  * `ODHF.ps1`: The primary script that performs the migration. Prompts for a username and copies the data.
  * `check-od.ps1`: A small helper script to quickly check the contents of a user's `Home Folder` in OneDrive after migration.
  * `get-authaud.ps1`: An early troubleshooting script used to decode access tokens and verify scopes.
  * `ODHF-debug.ps1`: An instrumented version of the main script that logs every API request and response. Invaluable for debugging but not for production use.
