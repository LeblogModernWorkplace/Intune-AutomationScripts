write-output "Start of the script"

# Authenticate and connect to Microsoft Graph
Connect-AzAccount -Identity
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -AsSecureString
Connect-MgGraph -AccessToken $token.Token 

$reportName = 'DevicesWithInventory'
$fileName = "DevicesWithInventory.csv"
$storageAccountName = "yourstorageaccountname"
$containerName = "yourstorageaccountnamecontainer"

# Construct the graph API request
$body = @"
{ 
    "reportName": "$reportName", 
    "localizationType": "LocalizedValuesAsAdditionalColumn"
} 
"@


$id = (Invoke-MgGraphRequest -Method POST -Body $body -Uri https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs).id
$status = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$id')" -Method GET).status

while (-not ($status -eq 'completed')) {
    $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$id')" -Method Get
    $status = ($response).status
    Start-Sleep -Seconds 2
}

$localFilePath = "./$fileName"
$localFilePathZip = "./$fileName.zip"
Invoke-WebRequest -Uri $response.url -OutFile $localFilePathZip
Expand-Archive $localFilePathZip -DestinationPath $localFilePath



$file = Get-ChildItem -Path $localFilePath -Force -Recurse -File | Select-Object -First 1

# Export the CSV in the blob storage

try {
   $Context = New-AzStorageContext -StorageAccountName $storageAccountName
Set-AzStorageBlobContent -Force -File $file -Container $containerName -Blob $localFilePath -Context $Context -StandardBlobTier 'Hot'
    Write-Output "CSV successfully exported in : $ContainerName"
}
catch {
    Write-Error "Failed to export CSV : $($_.Exception.Message)"
}

write-output "End of the script"



