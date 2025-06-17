**App Protection Policies – Data Protection**

Platform: **iOS & Android**
Target Policy to: **Core Microsoft Apps** - *current setting is Selected Apps*

Data Transfer:

-	Backup to iTunes/iCloud: Block – current setting
-	Send org data to other apps: Policy Managed Apps (only send other data to other org managed apps) - current setting
-	Save copies of org data: Block – current setting
-	Allow users to save copies to selected services: OneDrive & Sharepoint – current setting
-	Transfer telecom data to: any dialer app – current setting
-	Receive data from other apps: Policy managed apps – current setting is All Apps
-	Open data into org documents: Block – current setting
-	Allow users to open data from selected apps: OneDrive & Sharepoint – current setting is OneDrive, Sharepoint, Camera, Photo Library
-	Restrict Cut/Copy/Paste: Policy managed apps with paste in (data can be pasted INTO a managed app, but not pasted OUT of that app to an unmanaged app) – current setting
-	Encrypt org data: Require – current setting
-	Sync Policy managed app data with native apps or add-in: Block – current setting is Allow
-	Printing org data: Block – current setting is Allow
-	Restrict web content transfer with other apps: specify browser (Edge) – current setting is Any app
-	Org data notifications: Allow – current setting

---

**Impact:**

Changing Target Policy: FROM Selected Apps TO Core Microsoft Apps would target only Core Microsoft apps. This is actually less security because you lose the ability to manage other non MS apps like Adobe.
Changing Receive data from other apps: FROM  All Apps TO Policy Managed Apps would prevent users from being able to send data from an unmanaged app into a managed app. Users would only be able to send data from managed apps to managed apps. This would affect attaching any kind of attachment, sharing externally from unmanaged app into a managed app.  Example would be users would not be able to add an attachment from inside their personal Photo Gallery, from inside the gallery. Select a photo and click share, Outlook and other apps would not be an option. 
Changing Allow users to open data from selected apps FROM OneDrive, Sharepoint, Camera, Photo Library tTO only OneDrive & Sharepoint will make it so users will only be able to open data from OneDrive and SharePoint. Similar to above but vice versa basically. Example would be users would not be able to attach a picture in their gallery from inside Outlook. New email, add attachment, only OneDrive & Sharepoint would be the available options. 
Changing Sync Policy managed app data with native apps or add-in: FROM Allow TO Block – This would prevent users from syncing their Outlook or Teams calendars, work Contacts, and other managed work data into native device apps like Google Calendar or iOS calendar, etc. 
Changing Printing org data: FROM Allow TO Block would prevent the ability to print org data to a printer. 

**App Protection Policies – Access Requirements**
Access Requirements:
1.	PIN for Access: Required – current setting
2.	Simple PIN: Block – current setting
3.	Pin Length: minimum of 6 – current setting
4.	Touch ID instead of PIN: Allow – current setting
5.	Override biometrics with PIN after timeout: Require – current setting is Not required
6.	Timeout: 30 minutes – current setting is 0
7.	FaceID instead of PIN: Allow – current setting
8.	PIN Reset after number of days: Yes, 365 days – current setting is No
9.	Work or School account credentials for access: Not Required – current setting
10.	Recheck access requirements after ___ min of inactivity: 30 – current setting is 720
Conditional Launch
-	Max PIN attempts: 5 - Action: reset PIN – current setting
-	Offline grace Period: 90 days - Action: Wipe Data (off of the users device) – current setting
Device Conditions
-	Jailbroken/rooted device: Block Access – current setting
Assignment
-	Add Group: All users or target more granular Security Groups of users. 
-	Ability to create separate policies for different groups of users based on use case
Impact: 
Changing Override biometrics with PIN after timeout: FROM Not required TO Require would force a PIN login after timeout. Biometrics still allowed, but PIN is required if outside the inactivity timeout window. Currently device timeout is 0 so the Timeout setting in Access Requirements (above) would need to be something > 0 
Changing Timeout: FROM 0 to 30 minutes sets the inactivity period that Override biometrics with PIN after timeout would set if we made that Require
Changing  PIN Reset after number of days: FROM No TO Yes, 365 days would introduce a requirement to users to reset the app PIN after 365 days. A 
Changing Recheck access requirements after ___ min of inactivity: FROM 720 TO 30 would make the device recheck app protection policy requirements and compliance of them every 30 minutes. User would not be affected here at 720 or 30, unless their device had an issue with the policy and compliance. 30 would make issues be known faster. 

---

**Recommendation:**

Require Override biometrics with PIN after timeout and introduce a Timeout. This is a small increase in security overall but prevents biometrics from potentially being exploited if a device was stolen.
Make Timeout: 120 minutes (Resultant recommended 30, it’s currently 0)
 Impartial to PIN reset after 365 days, don’t feel that resetting a mobile device’s local app PIN adds a significant layer of security. 365 days is a long time. Either don’t have it at all, or have it be shorter than 1 year. 180 or 90 days instead of 365. App PINS are also the same for all MS apps. You don’t have a separate app PIN for Outlook and then another for Teams; your Outlook PIN also works for the Teams app if it asks for a PIN.  
Recheck access requirements after _ min of inactivity should be set to half of the Timeout setting. If timeout is 120 then make this 60. If timeout is 30 make this 15. 
-	Settings as are they are now, we are rechecking access requirements every 720 minutes, but there is no timeout. That means the device never times out, so if we had a PIN required for override biometrics, it would never never prompts for a PIN because it never reaches inactive status. If we set both timeout and recheck access requirements to 30 minutes then I believe that users would be prompted for PIN entry on next open of the managed app, every 30 minutes they go inactive. 
-	Sources below, but basically Timeout should be greater than Recheck access requirements. 

Excerpt:
Timeout (minutes of inactivity)	Specify a time in minutes after which either a passcode or numeric (as configured) PIN will override the use of a fingerprint or face as method of access. This timeout value should be greater than the value specified under 'Recheck the access requirements after (minutes of inactivity)'.	30

[MS Learn Docs](https://learn.microsoft.com/en-us/mem/intune/apps/app-protection-policy-settings-ios)
[MS Learn Docs](https://learn.microsoft.com/en-us/mem/intune/apps/app-protection-policy)

