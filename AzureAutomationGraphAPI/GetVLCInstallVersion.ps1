Write-Output "Start of Script"

# Authenticate and connect to Microsoft Graph with system managed identity
Connect-AzAccount -Identity
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -AsSecureString
Connect-MgGraph -AccessToken $token.token


$storageAccountName = "nameofyourstorageaccountname"
$containerName = "nameofyourstoragecontainername"
$filename = "Devices_VLC.csv"

$OutputCsv = Join-Path $env:TEMP "Devices_VLC.csv"

# ---- Load all the intune managed device and get the vlc version on it ----
$allDevices = Get-MgDeviceManagementManagedDevice -All
$apps = Get-MgDeviceManagementDetectedApp -All | Where-Object {$_.DisplayName -like "*VLC*"}

$results = @()

foreach ($app in $apps) {
    $devices = Get-MgDeviceManagementDetectedAppManagedDevice -DetectedAppId $app.Id -All
    foreach ($d in $devices) {
        $fullDevice = $allDevices | Where-Object { $_.Id -eq $d.Id }

        $results += [PSCustomObject]@{
            Application     = $app.DisplayName
            Version         = $app.Version
            DeviceName      = $d.DeviceName
            AzureADDeviceId = $fullDevice.AzureAdDeviceId
            OS              = $d.OperatingSystem
                }
    }
}

# CSV Export in temporary folder
$results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8

# CSV Export in blob storage
try {
    $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName
    Set-AzStorageBlobContent -File $OutputCsv -Container $ContainerName -Blob $Filename -Context $ctx -StandardBlobTier 'Hot' -Force
    Write-Output "CSV successfully exported in : $ContainerName/$Filename"
}
catch {
    Write-Error "Failed to export CSV : $($_.Exception.Message)"
}

Write-Output "End of Script"

