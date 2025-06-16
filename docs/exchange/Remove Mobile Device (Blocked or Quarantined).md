# Requirements:

* **Powershell 7**

	* https://www.thomasmaurer.ch/2019/07/how-to-install-and-update-powershell-7/

* **Exchange Online Management EXOv3 module installed**

	* https://www.powershellgallery.com/packages/ExchangeOnlineManagement/

* `connect-exchangeonline` -- connected to Exchange via Powershell

# Cmdlets used:

* **list specific users mobile devices:**

	* `Get-MobileDevice -Mailbox "username@domain.com"`

* **list all quarantined / blocked devices:**

	* `Get-MobileDevice -ResultSize Unlimited | Where-Object {$_.DeviceAccessState -eq "Quarantined" -or $_.DeviceAccessState -eq "Blocked"}`

* **remove mobile device:**

	* `Remove-MobileDevice -Identity ...`

Use either the specific cmdlet or list all devices cmdlet to gather the **Identity** value of the device, this is what we need to input into the `Remove-MobileDevice -Identity ...` cmdlet in order to get rid of it, example:

* `1ab11253-z124-78x3-6a6a-8g1234567n69\ExchangeActiveSyncDevices\Hx§Outlook§123456ABCD789EFGHIJKB17C1A3E755E`

* The **Identity** value will always be in this format: `GUIDString\ExchangeActiveSyncDevices\Outlook$DeviceID`
* So the full cmdlet to remove a device will look like this:
	* `Remove-MobileDevice -Identity 1ab11253-z124-78x3-6a6a-8g1234567n69\ExchangeActiveSyncDevices\Hx§Outlook§123456ABCD789EFGHIJKB17C1A3E755E` -- no quotes or parenthesis around the Identity value

# Example issue:

* User has a mobile device that is quarantined:

* ![image](https://github.com/user-attachments/assets/0f42ae2f-d3e3-426c-ac44-f0dcf4dc58e4)


* ![image](https://github.com/user-attachments/assets/5a505dc5-9191-4300-b50c-6031a0cdea3f)


* ![image](https://github.com/user-attachments/assets/7c8bb6ea-c0f6-4369-99ab-bcf562519d1d)



* But we're unable to delete or remove the device, and we need to delete it so it doesn't show up in audit reports

* Even when we go to Exchange > Mobile > Mobile Device Access menu, there is no delete button here

* We're able to compare the Device ID from her mailbox to the quarantined device list and locate it:
	* ![image](https://github.com/user-attachments/assets/e55cc7aa-a945-4f5f-be1d-9ba03d42762f)

* We are looking for: 1234567890ABCDEFGHIJKLMNOP -- so I click through every Quarantined Device until I find the matching one, which in this case is: b01yeee-1234-5678a-4321-aaaaaguidstring58

* We don't necessarily need to gather her deviceID and GUID value here, but, I want to make a mental note of them so when I locate them in Powershell I know that I am targeting the correct device and not accidentally deleting some other device.

---

# Removing the device via Powershell:

* Learn docs: https://learn.microsoft.com/en-us/powershell/module/exchange/get-mobiledevice?view=exchange-ps & https://learn.microsoft.com/en-us/powershell/module/exchange/remove-mobiledevice?view=exchange-ps

* Cmdlets used:

	1) `Get-MobileDevice -Mailbox "username@domain.com"`
	* This cmdlet gives me the device identity for the associated user
	* Highlight + copy the "Identity" string value

	2) `Remove-MobileDevice -Identity (paste the copied Identity string value here, no quotes or parenthesis needed)`
	
* There is a confirmation message because this is a `Remove` cmdlet which destroys the data, after confirmation, device is deleted. You can confirm this by re-running the `Get-MobileDevice ...` cmd from step 1.
	
* After running `Get-MobileDevice` cmdlet again, I see User has no associated mobile device any longer -- there is no output

* When I refresh Exchange and go check Users's mobile devices there, it is now gone as expected:

	* ![image](https://github.com/user-attachments/assets/56541801-4111-4720-951e-ef809b418d50)


* The Quarantined devices page in Exchange web portal (on refresh) also shows that device is now removed.

---
# What about the rest of the devices?

* We had 3 other devices stuck in Quarantine, but we didn't know the associated users. I had Admin FWD me a copy of the latest Quarantined Devices report that Tier1 receives to see if this information is listed there.

* The Mobile Device list just shows every single mobile device, so I have to do some digging

* This list contains DeviceID value, so, I tried to find all three of their deviceID values, but was unable to for the two older ones -- only found value: 123456ABCD789EFGHIJKB17C1A3E755E for the most recent one, which is:
	* 123456ABCD789EFGHIJKB17C1A3E755E | iOS XX.X.X | Outlook for iOS and Android | Outlook-iOS/2.0 | First Lastname | FirstL@domain.com
	* The two older ones show: 
	* ![image](https://github.com/user-attachments/assets/e95e2a92-148e-4475-9d62-6e82a7a70cbe)

* There is a different cmdlet to try here:

* `Get-MobileDevice -ResultSize Unlimited | Where-Object {$_.DeviceAccessState -eq "Quarantined" -or $_.DeviceAccessState -eq "Blocked"}`

* This shows all blocked / quarantined devices in the tenant

* I copied all of their Identity lines out to a notepad

* With the identity lines above, I just run the `Remove-MobileDevice -Identity ...` line again and removed the two very old broken ones.

* Then I run the quarantine filter cmdlet again and verify they are gone

* Also in Exchange they are gone

* So in this instance where we had  stuck very old devices (1-2 years+), we would not have received reports of these devices on the e-mail, and also there would have been no other way to remove these devices without using Powershell, so I don't think there's really anything Tier1 could have done in this instance about these devices and hence why the issue got escalated to me and hence this doc I made about how to fix it.
