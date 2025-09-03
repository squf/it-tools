#==================================================================
# ✨ SETUP AND CONFIGURATION ✨
#==================================================================

# === AUTHENTICATION DETAILS ===
$clientId     = "<your-client-id-here>"
$clientSecret = "<your-client-secret-here>"
$tenantId     = "<your-tenantId-here>"

# === FOLDER CONFIGURATION ===
$folderToCreate = "Home Folder"

# === LOGGING SETUP ===
$logDir = "C:\tmp\CreateHomeFolder_Logs"
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory | Out-Null }
$logFile = Join-Path $logDir "activity_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"

# Global variable to hold the token and its expiry time
$global:AuthTokenInfo = @{}
$headers = @{} # Initialize empty headers hashtable

#==================================================================
# ✨ REUSABLE CORE FUNCTIONS (from your original script) ✨
#==================================================================

function Write-Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "$timestamp - $message"
    Write-Host $entry
    Add-Content -Path $logFile -Value $entry
}

function Get-NewGraphToken {
    Write-Log "🔄 Refreshing API access token..."
    $tokenUrl = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
    $tokenBody = @{
        client_id     = $clientId
        client_secret = $clientSecret
        scope         = "https://graph.microsoft.com/.default"
        grant_type    = "client_credentials"
    }

    try {
        $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
        $global:AuthTokenInfo.AccessToken = $tokenResponse.access_token
        # Set expiry to 5 minutes before it actually expires, for a safe buffer
        $global:AuthTokenInfo.ExpiresOn = (Get-Date).AddSeconds($tokenResponse.expires_in - 300)
        # Apply the token to the global headers for future calls
        $headers.Authorization = "Bearer $($global:AuthTokenInfo.AccessToken)"
        Write-Log "✅ New token acquired. Valid until $($global:AuthTokenInfo.ExpiresOn.ToString('T'))"
    }
    catch {
        Write-Log "❌ FATAL: Could not get new access token. Error: $($_.Exception.Message)"
        throw
    }
}

function Invoke-GraphApiRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)] [hashtable]$Splat,
        [int]$MaxRetries = 5,
        [int]$DefaultRetryAfterSeconds = 10
    )

    # === TOKEN REFRESH LOGIC ===
    if (-not $global:AuthTokenInfo.AccessToken -or (Get-Date) -ge $global:AuthTokenInfo.ExpiresOn) {
        Get-NewGraphToken
    }
    # Ensure the splat uses the current valid token
    $Splat.Headers = $headers
    # === END TOKEN REFRESH LOGIC ===

    $retryCount = 0
    while ($true) {
        try {
            return Invoke-RestMethod @Splat
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $errorResponse = $_.Exception.Response
            
            if ($errorResponse.StatusCode.value__ -eq 429 -and $retryCount -lt $MaxRetries) {
                $retryCount++
                $waitTimeSeconds = $DefaultRetryAfterSeconds
                if ($errorResponse.Headers['Retry-After']) {
                    $waitTimeSeconds = [int]$errorResponse.Headers['Retry-After']
                }
                Write-Log "⏳ API throttled (429). Retrying in $waitTimeSeconds seconds... (Attempt $retryCount of $MaxRetries)"
                Start-Sleep -Seconds $waitTimeSeconds
            }
            else {
                # For any other error, just throw it to be handled by the calling function
                throw
            }
        }
        catch {
            # For non-HTTP errors, throw immediately
            throw
        }
    }
}

#==================================================================
# ✨ SCRIPT EXECUTION BEGINS HERE ✨
#==================================================================

Write-Log "🚀 Script starting. Logging to '$logFile'"

# Step 1: Get an initial access token
Get-NewGraphToken

# Step 2: Get ALL users from the tenant, handling pagination
Write-Log "🔍 Fetching all users from tenant..."
$allUsers = @()
$usersUrl = "https://graph.microsoft.com/v1.0/users?`$select=id,userPrincipalName"

do {
    try {
        $irmParams = @{ Uri = $usersUrl; Method = 'GET' }
        $response = Invoke-GraphApiRequestWithRetry -Splat $irmParams
        
        $allUsers += $response.value
        $usersUrl = $response.'@odata.nextLink' # Get the URL for the next page of results
        Write-Host "`rFound $($allUsers.Count) users..." -NoNewline
    }
    catch {
        Write-Log "❌ Failed to get users. Error: $($_.Exception.Message)"
        exit
    }
} while ($null -ne $usersUrl)

Write-Host "" # Newline after the progress counter
Write-Log "✅ Found a total of $($allUsers.Count) users. Starting folder creation process."

# Step 3: Loop through each user and create the folder
foreach ($user in $allUsers) {
    Write-Log "--------------------------------------------------"
    Write-Log "Processing user: $($user.userPrincipalName)"

    try {
        # First, we need the user's OneDrive Drive ID
        $driveUrl = "https://graph.microsoft.com/v1.0/users/$($user.id)/drive"
        $irmParams = @{ Uri = $driveUrl; Method = 'GET' }
        $driveResponse = Invoke-GraphApiRequestWithRetry -Splat $irmParams
        $driveId = $driveResponse.id

        # Now, create the folder in the root of that drive
        # The "root" in the Graph API corresponds to the "Documents" folder in the OneDrive UI
        $createFolderUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/root/children"
        $folderBody = @{
            name   = $folderToCreate
            folder = @{}
            "@microsoft.graph.conflictBehavior" = "fail" # This will cause an error if the folder exists
        } | ConvertTo-Json

        $irmParams = @{
            Uri         = $createFolderUrl
            Method      = 'POST'
            Body        = $folderBody
            ContentType = "application/json"
        }
        Invoke-GraphApiRequestWithRetry -Splat $irmParams | Out-Null
        Write-Log "  -> ✅ SUCCESS: Created '$folderToCreate' folder."

    }
    catch {
        # Check if the error was because the folder already exists (409 Conflict)
        if ($_.Exception.Response.StatusCode.value__ -eq 409) {
            Write-Log "  -> ℹ️ INFO: Folder '$folderToCreate' already exists. Skipping."
        }
        # Check if the error was because the user has no OneDrive (404 Not Found)
        elseif ($_.Exception.Response.StatusCode.value__ -eq 404) {
            Write-Log "  -> ⚠️ WARNING: User does not have a OneDrive provisioned. Skipping."
        }
        else {
            # Log any other errors
            Write-Log "  -> ❌ ERROR: $($_.Exception.Message)"
        }
    }
}

Write-Log "--------------------------------------------------"
Write-Log "🎉 Script finished."
