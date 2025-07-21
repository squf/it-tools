# OneDrive Home Folder Migration Scripts

This repository contains a PowerShell script designed to migrate on-premises user home directories to their respective OneDrive for Business accounts. The script creates a `Home Folder` in each user's OneDrive and copies their entire directory structure into it.

This project was developed for a Hybrid Azure AD Joined (HAADJ) environment and serves as a free alternative to paid tools for this specific migration task.

**Disclaimer:** These scripts worked in my environment as of July 2025. While they include robust error handling, use them at your own risk. For enterprise-grade migrations with support, consider purchasing a dedicated tool like **[ShareGate](https://sharegate.com/)**.

-----

## 📋 Prerequisites

Before you begin, ensure you have the following:

  * **PowerShell 7+** (`pwsh7`) and **Windows Terminal**.
  * An **Entra ID App Registration** with the required permissions (see below).
  * User OneDrive accounts must be **[pre-provisioned](https://learn.microsoft.com/en-us/sharepoint/pre-provision-accounts)**.

-----

## ⚙️ App Registration Setup

You'll need to create an Entra ID App Registration for the script to authenticate with the Microsoft Graph API.

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

-----

## 🚀 How to Use

The `ODHF.ps1` script is completely standalone and handles authentication automatically.

### Step 1: Configure the Script

Open `ODHF.ps1` in an editor and fill in the configuration variables at the top:

1.  **Authentication Details:** Add your Entra app's `clientId`, `clientSecret`, and `tenantId`.
2.  **Path Details:** Set the `$baseLocalRoot` variable to the UNC path of your on-premises user home directories (e.g., `\\server\users`).

### Step 2: Run the Migration

1.  Open a PowerShell 7 terminal and navigate to the script directory.
2.  Run the script:
    ```powershell
    .\ODHF.ps1
    ```
3.  The script will prompt you for the `username` of the user you wish to migrate (e.g., `FirstnameL`).
4.  After confirmation, the script will acquire an access token and begin the copy process.

-----

## ✨ Features & Logic

The main script (`ODHF.ps1`) has been optimized to be efficient and resilient:

  * **Automatic Token Refresh:** The script is standalone. It automatically acquires and refreshes its access token, allowing it to run for many hours without interruption.
  * **Batch Folder Creation:** Creates up to 20 folders in a single API call to reduce throttling risk.
  * **Efficient File Syncing:** Before uploading, it fetches a list of remote files to avoid re-uploading existing content.
  * **Throttling & Delay Handling:** Includes logic to automatically wait and retry on `HTTP 429` (throttling) errors and `HTTP 404` errors caused by API replication delays.
  * **Large File Support:** Automatically uses resumable upload sessions for files larger than 15 MB.
  * **Logging:** All operations are logged to a user-specific text file in `C:\tmp\ODHF_Logs` for easy tracking.

-----

## Troubleshooting & Notes

  * **`401 Unauthorized` Errors:** If you encounter `401` errors on the first run, check for **Conditional Access policies** based on geolocation. You may need to temporarily exclude your admin account or the app's service principal.
  * **API Throttling (`429` Errors):** If you need to run multiple large migrations in parallel, you can register a **second Entra app** and create a copy of `ODHF.ps1` with the new credentials. This allows you to run two instances simultaneously under separate API quotas.

-----

## 📂 Script Descriptions

This repository contains several scripts, but **only `ODHF.ps1` is needed for production use**. The others are included for context and archival purposes.

  * **`ODHF.ps1`**: The all-in-one, standalone script that performs the migration. It handles authentication, token refreshes, and all file/folder operations.
  * **`get-token.ps1`**: A legacy script for simple authentication. Its logic has been integrated into `ODHF.ps1` and it is no longer needed.
  * **`check-od.ps1`**: A small helper script to quickly check the contents of a user's `Home Folder` in OneDrive after migration.
  * **`ODHF-debug.ps1`**: An instrumented version of the main script that logs every API request and response. Invaluable for debugging but not for production use.
  * **`get-authaud.ps1`**: An early troubleshooting script used to decode access tokens and verify scopes.
