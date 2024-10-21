# why

- a really funny way to generate arbitrarily long lists of random password strings, then set them as users passwords in active directory
- i needed to prepare a few hundred laptops for users as we swapped them all out with a new AD domain, Entra joined, and Intune enrolled -- basically a full lift & shift from an old domain with no cloud, to a new hybrid cloud domain joined process. the company decided that just full fleet inventory replacement would be the quickest way to resolve this.
- because there were hundreds of users getting new laptops spread out all across the Eastern US, and because the company was OK with this, i decided it would be quicker to just reset their passwords randomly than to try contacting all of them and gathering their current passwords (the herding cats problem)
- we ended up keeping the list of randomly set passwords with us which helped us in the deployment as well, and basically my team & i would work with the users during the deployment to reset their AD passwords back to something else they preferred after we delivered the new laptop to them
