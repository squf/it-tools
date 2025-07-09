# about

- a collection of things i've worked on at various companies
- i typically work with Microsoft (Entra / Intune / Azure) stack in a system administrator (or sometimes even cloud architect if they're feeling fancy) role wherever i am at, so that's the role(s) these tools are tailored for
- some tools may be very specific to whichever environment i was working at when i made it, some may be more generally useful
- every environment i have ever been at so far has been HAADJ so if you're a Windows admin you're already groaning just reading that, this repo therefore has a ton of weird wonky stuff to clobber on-prem stuff together for use with cloud stuff
- you can in fact build an entire career out of helping orgs transition from HAADJ to AADJ!

# docs

- i recently added a docs repo here to store documentation on a wide variety of topics i encounter, these will just be markdown files for reading and not scripts per se

# links / shoutouts

*my most used links / most commonly referenced for my own work, all of the personal blogs here belong to well-known Microsoft MVPs*

- [Intune Automation](https://www.intuneautomation.com/) - one of Ugur Koc's websites, extremely useful and professional Powershell scripts to use in your environment
- [Ugur's GitHub](https://github.com/ugurkocde) - additional very helpful resources provided for free by Ugur
- [Rudy Ooms' blog](https://call4cloud.nl/) - Rudy is extremely prolific in his writing and extensively details how Intune really works behind the scenes
- [PatchMyPC blog](https://patchmypc.com/blog/) - more posts by Rudy here and the PatchMyPC team, a good blog even if you don't use PMPC
- [T-Bones' blog](https://www.tbone.se/) - a very helpful blog and where i started learning to use Azure runbooks from
- [WinAdmins blog & Discord](https://winadmins.io/) - very useful resources here, and having an active Discord full of fellow Windows Admins is 👌
- [Jeffrey Snover's blog](https://www.jsnover.com/blog/) - invented Powershell ⚠️ not frequently updated and mostly abandoned but some good old info on here
- [boot.dev](https://www.boot.dev/) - a great place to learn backend engineering concepts and languages, a little on the pricy side but i think its worth it

# future goals

*basically a blogpost about me*

- i'm currently in college but close to graduating, so i need to finish my bachelor's up so i can have more freetime to focus on IT stuff
- what i'd like to start moving toward is more "devops" type work, but i'd like to build up developer skills myself before doing that so i am starting to study C# at this time
- i'm doing indie gamedev with C# as a fun way of learning the language, since that seems more interesting to me than building a calculator app or something, i figure if i can make a game in C# i ought to be able to make an azure ci/cd pipeline or whatever
- in addition, grinding boot.dev courses (see above link), for topics and languages more directly related to devops (i just really like C# ok)
- i think i need to beef up my infra/ops skills a bit more too, so i'd like to get some more MS certs under my belt in addition to building up some development knowledge
- specific things i'm trying to focus on for "devops": docker, kubernetes, terraform, and fintech related tooling given my current role providing IT support for a financial institution, basically a lot of things covered on boot.dev. oh, and github itself! that's why i'm starting to use my github profile a lot more recently, because i'd like to convince my company to let us open an Enterprise GitHub account and start using GitHub Actions and maintaining our loose scattered codebases in a central repo etc.

- i am aware that the term "devops" is VERY contentious and like throwing a hand grenade into any ☝️🤓 convo, since it means something different everywhere its implemented, i'm just looking at it currently as "basically a more advanced and better version of the stuff i am already currently doing". like for example, i manually spin up an azure vm currently, but what if i used terraform to do that? that sounds neat. i manually smash a powershell script and store it wherever on our on-prem infra, what if it was just in a github repo and i could call it remotely? sounds pretty neat to me. what about all the apps i have to manually support currently, and all their dependencies? sure would be swell if i could just wrap all that junk into a docker container, ooh or better yet, what if i could just set up kubernetes to be like "all these computers need these apps on them plz push" and then i guarantee all our production PC's have all the apps and dependencies they need on them all the time? this is all that i mean by the term "devops". i don't actually work with any developers, so, certainly not devops in that sense of the term.
