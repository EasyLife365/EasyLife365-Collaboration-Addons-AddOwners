# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)

# Write out the queue message to the information log.
Write-Host "PowerShell queue trigger function processed work item: $($QueueItem | ConvertTo-Json -Depth 6 -Compress)"

Import-Module Microsoft.Graph.Groups

# take group id from body
$groupId = $QueueItem.Body.group.id

# read env variable, split and trim string
$userIds = $env:ownersToAdd -split " " | ForEach-Object {$_.trim()}

# add all userIds as owners to the team
$userIds | ForEach-Object {
    Write-Information "Adding user [$_] as owner to team [$groupId]" -InformationAction Continue

    $params = @{
        "@odata.type" = "#microsoft.graph.aadUserConversationMember"
        roles = @(
            "owner"
        )
        "user@odata.bind" = "https://graph.microsoft.com/v1.0/users('$_')"
    }
    New-MgTeamMember -TeamId $groupId -BodyParameter $params
}
