**SharePoint Settings**

Content can be shared with:  This setting controls who users can share files with in both Sharepoint and OneDrive. The permissions can be managed per app. Options are:

1.	Anyone (current setting)

2.	New & Existing Guests (requires sign in or verification code)

3.	Existing Guests

4.	Only people in your organization

Impact: (2) would require so New & Existing guests would have to authenticate via sign in or verification code via email. (3) would only allow files to be shared with Existing Guests. (4) would block anyone from having the ability share externally. There are ways files can still be shared securely outside the organization. 

---

**Recommendation:** Turn off sharing externally for both apps at tenant level (this setting). If that’s not possible, then New & Existing Guests (requires sign in or verification code) for just SharePoint, and turn off sharing externally for just OneDrive. If SharePoint users may need to share externally, then go with New & Existing Guests (requires sign in or verification code and block external sharing at the Sharepoint site level, while allowing sharing from a specific If no go then at the very least have these additional settings:

-	Uncheck “Allow Guests to share items they don’t own”

-	Check Guest access to site or OneDrive automatically expire after this many days: 60

-	People who use a verification code must reauthenticate after this may days: 30


**File and Folder links**

-	Change to Specific people (only the people the user specifies)

-	Choose the permission that’s selected by default for sharing links:

View

-	Choose expiration and permissions options for Anyone Links

-	These links must expire within this many days: 30

Files: view

Folders: view
