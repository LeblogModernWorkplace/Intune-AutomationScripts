# Authenticate and connect to Microsoft Graph
Connect-AzAccount -Identity
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com" -AsSecureString
Connect-MgGraph -AccessToken $token.Token 


Import-Module Microsoft.Graph.Beta.Reports
Import-Module Microsoft.Graph.Beta.DeviceManagement


# Obtenir la liste des scripts
$devicemanagementscript = Get-MgBetaDeviceManagementScript -ExpandProperty "assignments" -Top 50 

# Initialiser un tableau pour stocker les résultats
$devicemanagementscriptsLists = @()

# Parcourir chaque script
foreach ($script in $devicemanagementscript ) {
  $scriptId = $script.Id
  $scriptName = $script.DisplayName
  write-output $scriptId
  write-output $scriptName
  
$CompliantDevices = Get-MgBetaDeviceManagementScriptRunSummary -DeviceManagementScriptId $scriptId | Select-Object -ExpandProperty SuccessDeviceCount
$ErrorDevices = Get-MgBetaDeviceManagementScriptRunSummary -DeviceManagementScriptId $scriptId | Select-Object -ExpandProperty ErrorDeviceCount
      # Ajouter les résultats au tableau
   
    $complianceResults = [PSCustomObject]@{
       PolicyID = $scriptId
       PolicyName = $scriptName
       CompliantDevices = $compliantDevices
    ErrorDevices = $ErrorDevices
           }
      $devicemanagementscriptsLists += $complianceResults 
}


# Afficher les résultats et exporter en csv
write-output $devicemanagementscriptsLists

