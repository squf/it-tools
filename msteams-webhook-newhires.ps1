# replace this URI with your webhook link from whatever app you're setting up a webhook in (Microsoft Teams in this case)
$uri = "https://examplecompany.webhook.office.com/webhookb2/..."
$ItemImage = 'example.png'


$currentTime = Get-Date
$creationThreshold = $currentTime.AddHours(-1)
$NewUsersTable = New-Object 'System.Collections.Generic.List[System.Object]'
$ArrayTable = New-Object 'System.Collections.Generic.List[System.Object]'

$users = Get-ADUser -Filter * -SearchBase "OU=example,OU=company.com,DC=corp,DC=company,DC=com" -SearchScope Subtree -Properties WhenCreated | Where-Object { $_.WhenCreated -ge $creationThreshold }
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
