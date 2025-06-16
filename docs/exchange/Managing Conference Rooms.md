* **requirements:**

	* powershell 7

	* `connect-exchangeonline` - Exchange Online powershell module, connected to Exchange

* **make a room list:**

	* `New-Distributiongroup -Name 'Meeting Rooms' -RoomList`

		Name |         DisplayName  | GroupType | PrimarySmtpAddress
    ----          -----------   --------- ------------------
		Meeting Rooms | Meeting Rooms | Universal | MeetingRooms@domain.com

* **add members to room list:**

	* `Add-DistributionGroupMember -Identity 'Meeting Rooms' -Member MeetingRoom1@domain.com`

* **verify room list property:**

	* PrimarySmtpAddress                                     : MeetingRooms@domain.com
		RecipientType                                          : MailUniversalDistributionGroup
		RecipientTypeDetails                                   : RoomList

* **verify room list membership**:

	* ```Get-DistributionGroupMember -Identity 'Meeting Rooms' | Select-Object Name, PrimarySmtpAddress

* https://www.reddit.com/r/Office365/comments/1cwco23/comment/l4w94h0/

* https://learn.microsoft.com/en-us/outlook/troubleshoot/calendaring/configure-room-finder-rooms-workspaces#verify-the-properties-for-rooms-and-workspaces

* in order to show in Room Finder, they have to all have at least the City property set based on what I read in the links above

* so I made a script to set the city for all of them to Cityville and ran it

* **Changes can take up to 48 hours before they show up in Room Finder**

* **verify City property update**:

	* `Get-Place -Identity "MeetingRoom1@domain.com" | Format-List`

	* City: Cityville

---

## List of all current mailboxes

* We waited 48 hours and verified "Meeting Rooms" is showing up in Outlook now, so having confirmed that this will work, I need to go through and add all of our existing meeting rooms to that RoomList. This includes all onprem and cloud only meeting rooms.

* To find all Cloud room mailboxes, I ran: `Get-Mailbox -RecipientTypeDetails RoomMailbox | Select-Object PrimarySmtpAddress`

* To find all OnPrem room mailboxes, I added a Column to view email addresses in AD, went to the 'Meeting Rooms' OU, exported that list of items, and used Copilot to extract only the SMTP addresses.

* Now I can combine them all into the script below to add them.

---

script to add all rooms to the new room list:

``````
$emailAddresses = @(
    "MeetingRoom1@domain.com",
    "MeetingRoom2@domain.com",
    "MeetingRoom3@domain.com",
    "AddMoreAsNeeded@domain.com"
)

foreach ($email in $emailAddresses) {
    Add-DistributionGroupMember -Identity 'Meeting Rooms' -Member $email
}
```
```
