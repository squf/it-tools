# querying graph api with python

* i would like to be able to query graph api with python to simplify many processes in my current role
* (i could use powershell instead, i could install powershell on debian, i could have powershell export things to .csv or .json for me and then run a separate script on them with python, etc.)
* (i choose to use python out of personal preference, i prefer just doing things directly in bash without an ide, i prefer sticking to my wsl2 debian terminal as much as possible, python exposes a wider array of libraries than powershell does for other use-cases)
* often i am asked to provide lots of reports from Entra / Exchange / Teams / Intune / M365 Admin / Purview / et al. Microsoft related admin portals
* all of these can be queried in one way or another via graph, and doing so via api will likely expose even more details for me than the GUI
* i am in a Windows shop using a Windows work PC, so you're not gonna believe what's coming next, that's right I'm going to use WSL2 Debian to host my python venv and all dependencies

# additional to-do's:

* see if i can pull together more advanced reporting, e.g., a device configuration report which includes all assigned groups receiving the profile (Intune)
* most graph api data will be returned to me in json format which should make it possible for me to run it through something like matplotlib to turn it into a graph, businessheads love graphs. use graph to make graphs
* see about setting up reports covering our Intune autopatch roll-out (maybe even make them a daemon? connect them to SMTP? send email alerts? what about a Teams webhook alert? who knows the possibilities are endless with graph api and python)

# firewall notes:

* i couldn't figure out how to add this to a global environment location and all the pip.conf files i tried creating with this didn't work so i simply gave up and moved onto something else
* for reference at my current environment i can't use `pip install` to add python dependencies so i need to run the following line for all pip installs:

* `pip install --trusted-host=pypi.org --trusted-host=files.pythonhosted.org [input python library name here, e.g., pandas]`

# graph x ray tool:

* https://graphxray.merill.net/
* this tool is really good for finding API endpoints
* install it > in browser open developer tools | go to ... menu > more tools > developer tools (ctrl+shift+i - shortcut) > click the little >> menu in dev tools > open up graph x ray blade
* with x ray open, just start clicking around in any of the microsoft admin portals
* the x ray will start showing you the API endpoints / GET requests being made, and even can output stuff to javascript / powershell / etc. for you as well
* this is useful for finding what endpoint to target with other scripts like the ones i'll be building in this directory
