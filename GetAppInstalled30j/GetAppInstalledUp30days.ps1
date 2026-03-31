# Authenticate and connect to Microsoft Graph
Connect-AzAccount -Identity
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -AsSecureString
Connect-MgGraph -AccessToken $token.Token

#List app
$apps = @("")

#Build body for mggraphrequest
foreach ($app in $apps) {  
write-output $app

$reportName = ''
$storageAccountName = ""
$containerName = ""
$snapshotsContainerName = ""

$Body = ConvertTo-Json @{
    reportName = 'DeviceInstallStatusByApp'
    filter = "(ApplicationId eq '$app')"
    select     = @(
        'DeviceName'
        'UserPrincipalName'
        'Platform'
        'AppVersion'
        'DeviceId'
        'AssignmentFilterIdsExist'
        'LastModifiedDateTime'
        'AppInstallState'
        'AppInstallStateDetails'
        'HexErrorCode'
    )
    format     = 'csv'
    snapshotId = ''
}

#Export Intune report
$id = (Invoke-MgGraphRequest -Method POST -Body $body -Uri https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs).id
$status = (Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$id')" -Method GET).status

while (-not ($status -eq 'completed')) {
    $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$id')" -Method Get
    $status = ($response).status
    Start-Sleep -Seconds 2
}

#mapping appid to appname
If($app -eq "" )
   {
     $appname = "AppName"
     write-output $appname
   }

Else
   {
     ""  
   }

#download and zip extract
$localFilePath = "./$appname.csv"
$localFilePathZip = "./$app.zip"
Invoke-WebRequest -Uri $response.url -OutFile $localFilePathZip
Expand-Archive $localFilePathZip -DestinationPath $localFilePath

#traitement csv
$Context = New-AzStorageContext -StorageAccountName $storageAccountName

$file = Get-ChildItem -Path $localFilePath -Force -Recurse -File | Select-Object -First 1

$dateactu = Get-Date
write-output $dateactu

$dateLimit = (Get-Date).AddDays(-29)
write-output $dateLimit

$data = Import-Csv $file.FullName

$filteredData = $data | Where-Object {
     $_.AppInstallState_loc -eq "Installed" -and
  [datetime]$_.LastModifiedDateTime -lt $dateLimit
}

$filteredFile = "$localFilePath\filtered_$appname.csv"
$filteredData | Export-Csv -Path $filteredFile -NoTypeInformation

$file = Get-Item $filteredFile
#storage account upload
# add snapshot file with timestamp
$date = Get-Date -format "dd-MMM-yyyy_HH:mm"
$timeStampFileName = $appname + $date + ".csv"
Set-AzStorageBlobContent -Container $snapshotsContainerName -File $file -Blob $timeStampFileName -Force -Context $Context 

Set-AzStorageBlobContent -Force -File $file -Container $containerName -Blob $localFilePath -Context $Context -StandardBlobTier 'Hot'

}

# add device in entra id group
# Define Microsoft Graph API endpoint
$GraphBaseURL = "https://graph.microsoft.com/v1.0"

# Function to get Device ID by name
function Get-DeviceID {
    param ($DeviceName)
    $DeviceURL = "$GraphBaseURL/devices?`$filter=displayName eq '$DeviceName'"
    $Device = Invoke-MgGraphRequest -Uri $DeviceURL -Method GET
    return $Device.value[0].id
}

# ID du groupe Entra ID où ajouter les devices
$groupId = ""

# Import du CSV filtré
$filteredData = Import-Csv $filteredFile

foreach ($entry in $filteredData) {

    $intuneDeviceId = Get-DeviceID -DeviceName $entry.DeviceName

    if (-not $intuneDeviceId) {
        Write-Output "Pas de DeviceId pour : $($entry.DeviceName)"
        continue
    }

    $checkUrl = "https://graph.microsoft.com/v1.0/groups/$groupId/members/$intuneDeviceId"

try {
    $null = Invoke-MgGraphRequest -Method GET -Uri $checkUrl
    write-output $intuneDeviceId
    Write-Output "Device Déjà présent : $($entry.DeviceName)"
      continue
}
catch {
   Write-Output "Device non présent "
   Write-Output "Ajout du device $($entry.DeviceName) ($intuneDeviceId) dans le groupe..."

    # Ajout dans le groupe
    $body = @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/devices/$intuneDeviceId"
    }

    Invoke-MgGraphRequest -Method POST `
        -Uri "https://graph.microsoft.com/v1.0/groups/$groupId/members/`$ref" `
        -Body ($body | ConvertTo-Json)

    Write-Output "Ajouté : $($entry.DeviceName)"
    }
}

    
