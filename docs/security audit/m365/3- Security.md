**Security**

* From the Resultant report, we should look at the following authentication methods to enable:

	* Passkey (FIDO2)

	* Microsoft Authenticator

	* DUO EAM

	* All other forms should be turned off.

---

# on Passkeys (FIDO2) / additional notes

* One important note on Passkey authentication: it is not supported in the self-service password reset flow, i.e., if we set-up SSPR it doesn't do anything to help users with resetting their passkey in case it gets messed up somehow. I do not know the recovery flow off-hand in cases where a user somehow messes up their passkey method or loses their device, but I assume the good ol' "just replace the device and re-do the set-up" would always work.

* For a full list of supported hardware keys see the following: [MS Learn Docs](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-fido2-hardware-vendor)

---

* Passkey (FIDO2) authentication to Entra supports adding a Yubikey or other approved device, or, setting it up as a code within Microsoft Authenticator. According to the MS docs, once this is configured then users will not need to enter a password to authenticate, as the passkey will be tied to their Entra account and act as their authentication method. The passkey can be stored on the Yubikey type device or in MS Authenticator, though if we're handing out Yubikeys we will choose that option.

	* More info on the passwordless piece: [MS Learn Docs](https://learn.microsoft.com/en-us/entra/identity/authentication/concept-authentication-passwordless#passkeys-fido2)

		* ![image](https://github.com/user-attachments/assets/aa7069de-2585-40a7-b67e-f94db8310556)

		1. The user plugs the FIDO2 security key into their computer.

		2. Windows detects the FIDO2 security key.

		3. Windows sends an authentication request.

		4. Microsoft Entra ID sends back a nonce.

		5. The user completes their gesture to unlock the private key stored in the FIDO2 security key's secure enclave. (*I have a personal Yubikey at home and the gesture they are referring to here is pressing your thumb to the fingerprint sensor piece, at least that's how mine works at home*)

		6. The FIDO2 security key signs the nonce with the private key.

		7. The primary refresh token (PRT) token request with signed nonce is sent to Microsoft Entra ID.

		8. Microsoft Entra ID verifies the signed nonce using the FIDO2 public key.

		9. Microsoft Entra ID returns PRT to enable access to on-premises resources.

---

* This link has useful info on setting up Passkey's as an auth. method, and some more info on potential config. options: [MS Learn Docs](https://learn.microsoft.com/en-us/entra/identity/authentication/how-to-enable-passkey-fido2)

	* **We can target it to specific groups only** so I'd imagine if we were going to hand out Yubikey's to GroupA, we would make a group like "GroupA Yubikeys" and make sure all the users we want to hand devices to are in that group

	* **We can allow or deny self-service set-up**, which I assume we would want to allow, because I don't know off-hand how we would register people's Yubikey's without this (I'm reading that it would require us to do some Graph API work which is typical). I'm assuming we're already planning to do a white-glove rollout of the Yubikey's so I just assumed our department would be going to the offices to help walkthrough / educate / set-up the devices with employees, in which case self-service set-up would be preferred so that our department members don't have to go manually register each device and user via Graph API every time.
 
		* You might be imagining a scenario in which a threat actor goes and self-service registers a Yubikey to our tenant, well, they would also have to have tenant permissions to be able to add themselves to the group controlling access to this authentication method, and if the hypothetical threat actor already has that level of access then setting up a Yubikey is the least of our concerns, so I don't think disabling self-service registration is necessary. 

	* **Enforce attestation** set to YES, this checks the AAGUID sum on the key to ensure we're using valid and known hardware from the approved vendor list

	* **Enforce key restrictions:** we can set this to YES to force only specific models of Yubikey's or other token devices, or we can have this off and allow any type of key from the approved list, if we're going to stick to just using the same make/model Yubikey for everyone we would likely set this to YES and include that make/model AAGUID in the list of approved devices

* With the above settings in place we basically ensure only specific users using specific models of passkey devices are allowed to authenticate to our tenant, and this would serve as their MFA requirement so they wouldn't need to use Microsoft Authenticator or another phone app service. This is useful in <Current Company's> environment since we are not supplying everyone with company-owned MDM managed phones, so we cannot ensure every employee will have Microsoft Authenticator and we can't control apps users install on their personal phones, so having a passkey option instead is handy in this scenario.

# additional security settings

* Also recommended to turn off "**allow user consent**", which I agree should be turned off. Users should not be allowed to grant Graph API consent to any applications, this should be strictly managed through the global admins. If there is ever a business need to allow API consent it should be handled through an SDP ticket to IS Dept and a global admin will resolve it, like we do currently with all of our SSO app registrations.

---

* Lastly, there are issues surrounding using DUO EAM with SSPR at this time as well, though I keep reading blogposts from MS and DUO stating that "it's coming real soon guys!" so we'll see I guess? If you're reading this doc anytime after 2025 don't just assume DUO EAM isn't supported in Entra Hybrid SSPR flows, cuz, maybe it will be in the future.
