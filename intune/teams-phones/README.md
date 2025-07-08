# EVERYONE LOVES TEAMS PHONES! I LOVE POLYCOM! I LOVE MICROSOFT TEAMS!

this is just a placeholder note for something i should work on at my current job but haven't gotten around to yet, not a critical issue just a housekeeping chore i should automate

notes i hastily scribbled out:

should work on some azure runbook for stale device cleanup

https://www.intuneautomation.com/script/get-stale-intune-devices

something like this but then actually cleans them up too

example issue - mostly Android Teams devices:

- if you search "CoworkerName" under Android Devices there are like 21 registered devices under his name but most of them haven't been used in months, sometimes 4+ months old
- if you search these by their serial number you will see they've actually switched over to a different primary user eventually once Intune picks them up over time, so like 12345678987z for example, this is the Very Funny Conference Room device and it was last checked in this morning in Intune -- but there are 2 other entries with this serial number that show CoworkerName as primary user and no check-in since 03/07/2025 (4 months) 
- so a "stale device cleanup" runbook that just goes and nukes anything that is like, 2 months old, should be fine. maybe 3 months old. just to be safe. 
- this isn't a critical issue usually but sometimes it can be, if a user hits 15 device entries in the main admin cloud portal then they will be blocked from signing in on other devices.
- since every time a user signs out and signs back in on a teams phone this gets registered as a "new device", users can get up to the 15 device limit more often than we'd like
- work on this later, get approval from mgmt and get a change request in, update github, etc.
