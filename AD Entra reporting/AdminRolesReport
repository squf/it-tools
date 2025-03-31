Import-Module Microsoft.Graph
Import-Module Microsoft.Graph.Identity.Governance
Import-Module Az.Accounts
Import-Module Az.KeyVault

$AppId = "app-id-here"
$CertificateThumbprint = "thumbprint-here"
$tenantId = "tenant-id-here"

Connect-MgGraph -ClientId $AppId -CertificateThumbprint $CertificateThumbprint -tenantId $tenantId -NoWelcome
Connect-AzAccount -TenantId $tenantId -CertificateThumbprint $CertificateThumbprint -ApplicationId $AppId

# Loop Role Definition
$coll = @()
$roleDefinitions = Get-MgRoleManagementDirectoryRoleDefinition

foreach ($rd in $roleDefinitions) {
    $roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$($rd.Id)'" -ErrorAction SilentlyContinue
    if ($roleAssignments) {
        foreach ($ra in $roleAssignments) {
            # Check if the principal is a user
            try {
                $user = Get-MgUser -UserId $ra.PrincipalId -ErrorAction Stop
                $obj = [PSCustomObject]@{
                    'Id' = $ra.Id
                    'RoleDefinitionId' = $ra.RoleDefinitionId
                    'PrincipalId' = $ra.PrincipalId
                    'RoleDisplayName' = $rd.DisplayName
                    'RoleIsBuiltIn' = $rd.IsBuiltIn
                    'RoleDescription' = $rd.Description
                    'RoleIsEnabled' = $rd.IsEnabled
                    'UserDisplayName' = $user.DisplayName
                    'UserPrincipalName' = $user.UserPrincipalName
                    'UserObjectType' = $user.UserType
                    'AssignmentType' = 'User'
                }
                $coll += $obj
            } catch {
                # If not a user, it might be a service principal or group
                try {
                    $sp = Get-MgServicePrincipal -ServicePrincipalId $ra.PrincipalId -ErrorAction Stop
                    $obj = [PSCustomObject]@{
                        'Id' = $ra.Id
                        'RoleDefinitionId' = $ra.RoleDefinitionId
                        'PrincipalId' = $ra.PrincipalId
                        'RoleDisplayName' = $rd.DisplayName
                        'RoleIsBuiltIn' = $rd.IsBuiltIn
                        'RoleDescription' = $rd.Description
                        'RoleIsEnabled' = $rd.IsEnabled
                        'UserDisplayName' = $sp.DisplayName
                        'UserPrincipalName' = $sp.AppId
                        'UserObjectType' = 'ServicePrincipal'
                        'AssignmentType' = 'ServicePrincipal'
                    }
                    $coll += $obj
                } catch {
                    Write-Warning "Could not resolve principal $($ra.PrincipalId) for role $($rd.DisplayName)"
                }
            }
        }
    }
}

# Write CSV
Write-Host "Found $($coll.count) Azure admins" -ForegroundColor "Green"
$file = "c:\temp\AdminRolesReport.csv"
$coll | Export-Csv $file -NoTypeInformation -Force

# Send email
$keyVaultName = "keyvaultname-here"
$smtpServer = "smtp.office365.com"
$smtpPort = 587
$smtpUsername = "smtpserviceaccount@domain.com"
$smtpPasswordSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name "azkeyvault-secret-here" -AsPlainText
$smtpPassword = ConvertTo-SecureString -String $smtpPasswordSecret -AsPlainText -Force
$smtpCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $smtpUsername, $smtpPassword

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Verify the file exists before sending
if (Test-Path $file -PathType Leaf) {
    Send-MailMessage -To "user@domain.com" -From "smtpserviceaccount@domain.com" -Subject "Admin Roles Report" -Body "Admin Roles Report" -SmtpServer $smtpServer -Port $smtpPort -usessl -Credential $smtpCredential -Attachments $file
} else {
    Write-Error "CSV file not found at $file"
}

Disconnect-MgGraph
Disconnect-AzAccount
