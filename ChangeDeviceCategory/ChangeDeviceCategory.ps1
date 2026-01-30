Connect-AzAccount -Identity
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -AsSecureString
Connect-MgGraph -AccessToken $token.Token 

$OldDeviceCategory = "XXXX"
$newDeviceCategory = "YYY"

#Inventory number of devices with old device category
$queryDevices = Get-MgDeviceManagementManagedDevice -Filter "DeviceCategoryDisplayName eq '$OldDeviceCategory'"
$count = $queryDevices.count
write-output "Number of devices to be modified" $count

#For each device change the category
foreach($device in $queryDevices)
{
$DeviceID = $device.ID
write-output "Name of computer" $device.devicename 

$Ref = '$Ref'
$Uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$DeviceId')/deviceCategory/$Ref"
$DeviceCategory = Get-MgDeviceManagementDeviceCategory -Filter "Displayname eq '$newDeviceCategory'" | Select-Object -ExpandProperty Id
$Body = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$DeviceCategory" }
Invoke-MgGraphRequest -Uri $Uri -Body $Body -Method PUT -ContentType "Application/JSON"
}

#Vérification du nombre
$queryDevices = Get-MgDeviceManagementManagedDevice -Filter "DeviceCategoryDisplayName eq '$OldDeviceCategory'"
$count = $queryDevices.count
write-output "Number of devices with old category" $count

$queryDevices = Get-MgDeviceManagementManagedDevice -Filter "DeviceCategoryDisplayName eq '$newDeviceCategory'"
$count = $queryDevices.count
write-output "Number of devices with new category" $count
