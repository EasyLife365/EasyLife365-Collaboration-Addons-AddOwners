# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write out the queue message to the information log.
Write-Host "HTTP trigger function processed a request of type: $($Request.eventType)."

# add request body to queue
Push-OutputBinding -Name queueItem -Value $Request

# respond to http request
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = [System.Net.HttpStatusCode]::ok
    Body = "OK"
})