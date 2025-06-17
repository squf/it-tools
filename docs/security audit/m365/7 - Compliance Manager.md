**Purview > Solutions > Compliance Manager**

1.     From this dashboard you may create **compliance assessments** based on a library of governance frameworks which will audit your environment and create **“Improvement Actions”** for your tenant

2.     These Improvement Actions give you **Microsoft Documentation for implementation** and can be manually edited with notes to sign-off on controls taken by 3rd party tools (Cisco ESA for DMARC as an example)

1.     Microsoft Purview includes **Data Loss Prevention** (Microsoft Information Protection) which can be augmented by Varonis for deeper classification, Microsoft AD/Entra ID auditing, file exposure, and more.

----

# what it is

* Purview (Microsoft) and Varonis (third-party) are looking to accomplish the same basic goal, of giving us a way to do deeper file auditing and data-loss prevention (DLP), i.e., getting reports of who accessed what data and controlling that at scale via cloud. 

* Both offer the capability to choose from a list of industry standards and then offer guidance for you to go through a checklist and make sure your company data is meeting those regulatory standards. I had a quick chat with (Internal Compliance Department) to determine relevant compliance frameworks for our business.

* That being said, I cannot find anywhere where Purview supports (One Of Our Industry Standard Compliance Frameworks) out-of-box, but, Varonis appears to support it.

* ---

* # final notes / these were internal and sent to leadership, but some ideas here would apply to other environments as well

* My team will have to, and can, manage standing these up to begin with and managing them for a time, but Purview/Varonis are really more "Security" focused concerns, so if our company ever ends up with a dedicated Security team in the future -- we would want to transition the day-to-day management of these platforms to them. I'm just saying!

* Probably it would be a good idea for a few of the following before we just go hogwild on purchasing stuff nobody in our department is a deep expert on: 

	* If considering Varonis, do a demo / meet & greet call with them and mainly just drill them on all the compliance standards they can help us meet, to ensure that if we purchased Varonis we can actually meet industry standard compliance frameworks, so I'd recommend coming up with a good finalized list before such a call.

	* If you really want to do a bang up job on configuring all of this stuff, might be a good idea to reach out to Resultant again for specifically standing up our compliance / DLP integrations (whether that's strictly Purview, strictly Varonis, or a combo of both) -- just to rely on their outside expertise in this case. My team could probably stand them both up, but I just assume Resultant could stand them both up better. 

* I think it would be wise to have at least a few hours of talks / trainings / demos, some tips & guidelines etc., from Resultant and/or Varonis (if we're purchasing Varonis, I'm just assuming it would be a good idea to go with Varonis as it covers a wider range of products, frameworks, and offers automated remediation tooling) for our department, just so we're not completely winging it with Google & Reddit searches -- only because the compliance piece is a little more important than a lot of the other IT work we do. Like its okay if I mess up installing an app, I can uninstall it later. It's okay if I mess up setting up a server, I can delete it and remake it correctly. If I mess up compliance and we get sued and eat a huge fine or something well that's not quite as harmless yeah.

*  ---

*  I also noted that most of Purview's functionality is (as of the time of this writing) locked behind E5 licensing, which we do not have. So we're going to need to tack on a 6-figure+ annual budget increase to move to E5 licensing. Varonis is also $$$ expensive.
