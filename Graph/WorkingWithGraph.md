* Install Graph X Ray -> https://graphxray.merill.net/
  
* F12 in Browser, open Graph X Ray:
  * ![image](https://github.com/user-attachments/assets/b8212bbd-931b-4572-bdde-cc6c001da233)

* It will load in the API backend values whenever you load a page:
	* ![image](https://github.com/user-attachments/assets/9fef4191-7b35-4a0e-b450-2098730626f8)


* **PRO-TIP:** *It loads on page load so either get the xray blade up before you click on the page you're trying to grab API calls for, or, click out > clear session > click back in*
  
* From here do some standard Powershell stuff. I'm always in PWSH7 running `connect-mggraph` so don't need to do any of the `import-module` from the pics above. In this example I'm trying to get a list of all users assigned to a given Enterprise App in Entra, so, I know I need to use `get-mgserviceprincipalapproleassignedto` based on going through the API calls via X Ray. I already know my AppID / ObjectID (xray will tell you which one to use for the appropriate service principal)
  
* so my final line can look like: `Get-MgServicePrincipalAppRoleAssignedTo -ServicePrincipalId "objectID-HERE" -All | fl PrincipalDisplayName`
  
* and I can pipe this out to an `export-csv` if I want a file of it.
  
* my final result in shell will look like this:
	* ![image](https://github.com/user-attachments/assets/7137782a-6336-49ee-84be-4d7aad068665)

 * **Pagination**

 * I think by default Graph API in Powershell only returns the top 100 results, so, I just put `-All` parameter into all my shell calls to try and get around this, seems to work as far as I can tell.

---

 * Another way to work with Graph is via: https://developer.microsoft.com/en-us/graph/graph-explorer -- and tools like Postman -- these displays are good for giving a lot of comprehensive information but I typically will want to wrap all this into a Powershell script at some point, and I find X Ray works better for my use-case as a result generally.

 * **Why?** - making direct calls this way or using `Invoke-MgGraphRequest` and building powershell scripts out of direct API calls where possible is good because a lot of stuff is either constantly breaking or changing on the frontend of Microsoft cloud services, but the API backend stuff typically remains more stable. Also more information is exposed via this method, so you can only do some things this way.

 * It just makes it a lot easier to do things like bulk administration (moving hundreds of users in or out of a group or app), getting data for making displays / flowcharts / spreadsheets, reporting on various health status issues in the environment etc.

 * I will try to work on uploading my Graph powershell scripts where possible
