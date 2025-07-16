# Extract and decode the payload from the JWT access token
# If you're actually using this script to pull your apps scopes and roles and such then uh you've probably gotten too lost in the weeds already and should seriously just purchase ShareGate
# or maybe you're 1std smarter than I am in which case good for you plz send help
$token = $Auth.access_token
$tokenParts = $token -split '\.'

if ($tokenParts.Length -ge 2) {
    $payload = $tokenParts[1]

    switch ($payload.Length % 4) {
        2 { $payload += '==' }
        3 { $payload += '=' }
        1 { $payload += '===' }
    }

    $payload = $payload.Replace('-', '+').Replace('_', '/')

    try {
        $decoded = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($payload))
        $json = $decoded | ConvertFrom-Json
        Write-Host "`n🔍 Token Audience (aud): $($json.aud)"
        Write-Host "🔐 Token Scopes (scp): $($json.scp)"
        Write-Host "🔐 Token Roles (roles): $($json.roles)"
        Write-Host "👤 Token Subject (sub): $($json.sub)"
        Write-Host "📅 Token Expiration (exp): $([DateTimeOffset]::FromUnixTimeSeconds($json.exp).ToLocalTime())"
    }
    catch {
        Write-Host "❌ Failed to decode token payload: $($_.Exception.Message)"
    }
} else {
    Write-Host "❌ Invalid token format."
}
