**Some additional recommendations that came about as a result of our m365 security audit**

1.	Ensure Entra Connect (AD Sync) is set up with password writeback
-	This will allow you to manage Identity from both on-prem and Entra without inconsistent synchronization

2.	Purchase Entra ID P2 Licensing addon or replace current E3 licenses with M365 E5 (P2 is bundled with M365 E5 Licensing) for Risk-based Conditional Access rules and ID Governance (automated ID workflows).

a.	Privileged Identity Management – Like AppLocker but better

b.	Risk Based Conditional Access

c.	Vulnerabilities and risky account detection

3.	Microsoft Purview includes Data Loss Prevention (Microsoft Information Protection) which can be augmented by Varonis for deeper classification, Microsoft AD/Entra ID auditing, file exposure, and more.

a.	Purview licensing requires E5, this does not come with Entra P2.

**Impact:**

* Setting up Entra Connect to get password write back and SSPR (self service password reset) will make it so users have the ability to update their password or unlock their account using a web browser, and when they change their password it will writeback to On-Prem AD and vice versa (reset Exchange Online account password and it resets On-Prem AD account’s password). User impact should be very minimal to non-existant; user experience will improve when resetting passwords because they can do it themselves. 

* Purchasing Entra ID P2 or M365 E5 will not cause an impact to users. The tenant gains features that are broken out in the comparison spreadsheet. 

* Microsoft Purview – Requires E5 license, gets access to DLP, data classifications/labels, PAM, Insider Risk, eDiscovery, and more. Impact of this to the user would be minimal to none since these are additional features/reporting. 

**Recommendation:**

* Setup Entra Connect and setup password writeback and SSPR. SSPR does not need P2

* Evaluate license needs further. Purview does require E5 licensing. If DLP and Defender for Cloud Apps (and Defender EDR/XDR/MDR) is of interest then it might be most effective to get the E5 addon. 

* P2 can be a separate addon, around $9 per user. E5 is around $52-$54/user and replaces E3 license. E3 is around $34. So, $43/user for E3 + P2 addon VS $54/user for E5 (includes p2). To some extent Teams Phones licensing is included with E5, though Microsoft has changed licensing on E5 and there are reports that it may no longer be included.

**Staying E3 and purchase Entra P2 addon**

* If we went this route we would not have access to DLP and Purview and other features in E5 such as Defender for Endpoint, Defender for O365 (ATP, URL Sandboxing + attachment sandboxing), Defender for Cloud Apps, advanced compliance reporting/eDiscovery, insider risk management. 
