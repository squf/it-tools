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
