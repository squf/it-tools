# Replace these with your actual app registration details
# Remember to run this script BEFORE ODHF.ps1
# Remember this only gives you a 1 hour access token before it expires, and you can't exit your shell window or open a new one or whatever
# Run $Auth after running this script to verify if pulls your access token and sets it to $Auth variable correctly
$tenantId = "<YOUR-TENANT-ID-HERE>"
$clientId = "<YOUR-CLIENT/APP-ID-HERE>"
$clientSecret = "<YOUR-CLIENT-SECRET-HERE>"

$scope = "https://graph.microsoft.com/.default"

$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    scope         = $scope
}

try {
    Write-Host "🔐 Requesting token from Microsoft Identity Platform..."
    $response = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" `
                                  -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"

    $accessToken = $response.access_token
    Write-Host "`n✅ Token acquired successfully."
    Write-Host "🔑 Access Token (first 100 chars): $($accessToken.Substring(0,100))..."

    $tokenParts = $accessToken -split '\.'
    $payload = $tokenParts[1]
    switch ($payload.Length % 4) {
        2 { $payload += '==' }
        3 { $payload += '=' }
        1 { $payload += '===' }
    }
    $payload = $payload.Replace('-', '+').Replace('_', '/')
    $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
    $json = $decoded | ConvertFrom-Json
    Write-Host "`n🔍 Token Audience (aud): $($json.aud)"
    Write-Host "🔐 Token Roles (roles): $($json.roles)"
    Write-Host "📅 Token Expiration (exp): $([DateTimeOffset]::FromUnixTimeSeconds($json.exp).ToLocalTime())"

    # this is where it sets the token to the $Auth variable ok
    $global:Auth = @{ access_token = $accessToken }
}
catch {
    Write-Host "❌ Failed to acquire token: $($_.Exception.Message)"
}
