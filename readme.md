# Use Azure Functions and Graph PowerShell to add owners to a newly created Team

This is a sample Azure Function.

The app uses two functions:

- request: this function provides an endpoint for http requests that can be called by easylife. upon receiving a request it adds it's body to a storage queue.
- queue: this function is triggered anytime an item is added to the storage queue. it takes the object id of the team from the request's body and adds any userid found in `ownersToAdd` as owner

The app can be deployed using PowerShell with Azure CLI. You need to install the Azure CLI, which you can find here: [https://aka.ms/installazurecliwindows](https://aka.ms/installazurecliwindows).

## Deploy the solution to an Azure Subscription via PowerShell

You can use the following PowerShell and Azure CLI code to deploy the solution to an Azure subscription. Update the values of variables in the first few lines to match your requirements, then run the whole thing in a PowerShell session.

```powershell
# edit parameters
# specify the name and location of the resources that will be created
$resourceGroupName = "rgr-func-elowner"
$functionAppName = "az-func-elowner"
$storageAccountName = "stofuncelowner01"
$location = "westeurope"
$subscriptionName = "my-azure-subscription"
# space spearated list of users to add as owners
$ownersToAdd = "96e0b6f6-4613-4e33-a51a-be2410d0131a 96e0b6f6-4613-4e33-a51a-be2410d0131a"

# login to azure and optionally change subscription

az login
az account set --subscription $subscriptionName

# there should be no need to change anything below this

# create resource group
az group create `
    --name $resourceGroupName `
    --location $location

# create storage account
az storage account create `
    --name $storageAccountName `
    --resource-group $resourceGroupName `
    --location $location `
    --sku Standard_LRS

# create function app and configure settings
$funcAppOutput = az functionapp create `
    --consumption-plan-location $location `
    --name $functionAppName --os-type Windows `
    --resource-group $resourceGroupName `
    --runtime powershell `
    --storage-account $storageAccountName `
    --functions-version 4 `
    --assign-identity '[system]' | ConvertFrom-Json

az functionapp config appsettings set `
    --name $functionAppName `
    --resource-group $resourceGroupName `
    --settings "ownersToAdd=$ownersToAdd"

# get service principals for permission assignment
$servicePrincipalId = $funcAppOutput.identity.principalId
$graphObjectId = (az ad sp list --display-name 'Microsoft Graph' | ConvertFrom-Json)[0].id

# assign permissions to the managed identity
@(
    '0121dc95-1b9f-4aed-8bac-58c5ac466691' # TeamMember.ReadWrite.All
) | ForEach-Object{
    $body = @{
        principalId = $servicePrincipalId
        resourceId = $graphObjectId
        appRoleId = $_
    } | ConvertTo-Json -Compress
    $uri = "https://graph.microsoft.com/v1.0/servicePrincipals/$servicePrincipalId/appRoleAssignments"
    $header = "Content-Type=application/json"
    # for some reason, the body must only use single quotes
    az rest --method POST --uri $uri --header $header --body $body.Replace('"',"'")
}

# update deploy package
$deployPath = Get-ChildItem | `
    Where-Object {$_.Name -notmatch "deploypkg" -and $_.Name -notmatch "_automation" } | `
    Compress-Archive -DestinationPath deploypkg.zip -Force -PassThru

# deploy the zipped package
az functionapp deployment source config-zip `
    --name $functionAppName `
    --resource-group $resourceGroupName `
    --src $deployPath.FullName
```
