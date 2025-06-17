# Conditional Access Policies (CAPs)

# Named locations - Trusted Countries

* Our first recommendation was to set-up Trusted Countries in Entra, which some of the below CAP's will rely on later. We were already leveraging Trusted Locations for other settings like Network, but we didn't have anything for geolocation prior to the audit.
* This seems like an obvious "yes" to me, we should enable this. I don't think CompanyName does any business outside of these Continental United States (God bless America) 🎆⚾🌭🦅🍔(These colors don't run)
* One thing to note is, as we've already seen in the past, we get a lot of log-in attempts from all over the world -- to my understanding, turning this on won't stop those attempts from showing up in our sign-in logs, but it would at least prevent any ability for those geo-locations outside the US from ever accessing our data even if they successfully phished a password, they would have to spoof their geo-location as well in order to even have a chance to do anything nefarious. Plus it should have zero impact on our daily operations. Just another hurdle in the way for foreign threat actors to have to go over with minimal to no impact on us, should be good.
* Having this trusted location set-up is a requirement for CA02 below as well.

---

* Github note: I listed all of these recommendations out internally, and then made a separate document where I compared all of these to our existing CAP's, then we went through and made the recommended changes after securing leadership approval.
* Below are what could be considered "industry standard" recommended CAP's, at least a good baseline to start with.

---

# Resultant recommendations:

* **CA01: MFA**
	* Include all users
	* Include all cloud apps
	* Conditions: n/a
	* Grant: Grant access, require MFA
	* Session: n/a

* **CA02: Geoblocking**
	* Include all users
	* Include all cloud apps
	* Conditions: any location, exclude Trusted Countries
	* Grant: Block access
	* Session: n/a

* **CA03: Compliant Devices**
	* Include all users
	* Include all cloud apps
	* Conditions: Include all devices
	* Grant: Grant access, require device marked as compliant
	* Session: n/a

* **CA04: Block Persistent Browser Sessions**
	* Include all users
	* Include all cloud apps
	* Conditions: client apps - browser
	* Grant: n/a
	* Session: Persistent Browser: set to Never

* **CA05: Require App Protection (MAM) Policy**
	* Include all users
	* Include Office 365 apps
	* Conditions: Device platforms - iOS & Android | Client apps: Browser, Mobile apps & desktop clients
	* Grant: Grant access, require app protection policy
	* Session: n/a

* **CA06: Block Legacy Authentication**
	* Include all users
	* Include all cloud apps
	* Conditions: Client apps, Exchange ActiveSync clients, other clients
	* Grant: Block access
	* Session: n/a

* **CA07: Require MFA to Join Entra**
	* Include all users
	* Include cloud apps - user actions - register or join devices
	* Conditions: n/a
	* Grant: Grant access, require MFA
	* Session: n/a
