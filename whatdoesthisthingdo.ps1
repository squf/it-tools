# Teams webhook URL
$uri = "https://arteraservices.webhook.office.com/webhookb2/4127f798-3092-4654-9393-8aa34ed4de78@21802c71-f78d-4116-a81f-c204aaadc19a/IncomingWebhook/4620881f164042fab5ed79c3d1be13b0/903d861d-c34a-4dc1-945a-15a621092eb5"

# Image on the left-hand side, a regular user picture
$ItemImage = 'https://em-content.zobj.net/source/microsoft-teams/363/construction-worker_1f477.png'

# Get the current time and calculate the 1 hour threshold
$currentTime = Get-Date
$creationThreshold = $currentTime.AddHours(-1)

$NewUsersTable = New-Object 'System.Collections.Generic.List[System.Object]'
$ArrayTable = New-Object 'System.Collections.Generic.List[System.Object]'

# Retrieve user objects created within the last hour in the specified OU
$users = Get-ADUser -Filter * -SearchBase "OU=Millerpipeline,OU=artera.com,DC=corp,DC=artera,DC=com" -SearchScope Subtree -Properties WhenCreated | Where-Object { $_.WhenCreated -ge $creationThreshold }
foreach ($user in $users) {
    Write-Host "Working on $($user.Name)" -ForegroundColor White

    $hoursSinceCreation = (New-TimeSpan -Start $user.WhenCreated -End $currentTime).TotalHours

    $obj = [PSCustomObject]@{
        'Name' = $user.Name
        'CreationTime' = $hoursSinceCreation
        'CreationTimestamp' = $user.WhenCreated.ToShortDateString()
        'EmailAddress' = $user.EmailAddress
        'Enabled' = $user.Enabled
        'SamAccountName' = $user.SamAccountName
    }

    $NewUsersTable.Add($obj)
}
Write-Host "New users: $($NewUsersTable.Count)"
$ArrayTable = $NewUsersTable | ForEach-Object {
    $activityTitle = $_.Name
    $activitySubtitle = $_.EmailAddress
    $activityText = "$($_.Name) was created $($_.CreationTime) hours ago"
    $activityImage = $ItemImage
    $facts = @(
        @{
            name  = 'Creation Timestamp'
            value = $_.CreationTimestamp
        },
        @{
            name  = 'Enabled'
            value = $_.Enabled.ToString()
        },
        @{
            name  = 'SamAccountName'
            value = $_.SamAccountName
        }
    )

    $section = @{
        activityTitle = $activityTitle
        activitySubtitle = $activitySubtitle
        activityText = $activityText
        activityImage = $activityImage
        facts = $facts
    }

    $section | ConvertTo-Json -Depth 100
}

$sectionsJson = $ArrayTable -join ','

$body = @"
{
    "title": "New Users - Notification",
    "text": "$($ArrayTable.Count) new users created within the last hour.",
    "sections": [ $sectionsJson ]
}
"@

Write-Host "Sending new user account POST" -ForegroundColor Green
Invoke-RestMethod -Uri $uri -Method Post -Body $body -ContentType 'application/json'