# Definir variáveis de autenticação
$clientId = Get-AutomationVariable -Name 'autopilot-client-id'
$clientSecret = Get-AutomationVariable -Name 'autopilot-secrets'
$tenantId = Get-AutomationVariable -Name 'autopilot-tenant-id'

# Informações necessárias para enviar dados para o ponto de extremidade DCR.
$dceEndpoint = ""
$dcrImmutableId = ""
$streamName = "Custom-AutopilotEvents"

# Obter token de autenticação
$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    resource      = "https://graph.microsoft.com"
}
$tokenResponse = Invoke-RestMethod -Method Post -Uri $authUrl -Body $body
$accessToken = $tokenResponse.access_token
 
# Consultar API do Defender ATP para obter informações sobre computadores
$AutopilotEventsUrl = "https://graph.microsoft.com/beta/deviceManagement/autopilotEvents"
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/json"
}
$AutopilotEvents = Invoke-RestMethod -Method Get -Uri $AutopilotEventsUrl -Headers $headers
 
# TimeGenerated
$currentTime = Get-Date ([datetime]::UtcNow) -Format O
 
# Definir a data atual e o horário do início do intervalo de 24 horas
$currentDateTime = [datetime]::ParseExact($currentTime, "yyyy-MM-ddTHH:mm:ss.fffffffK", $null)
$dateTime24HoursAgo = $currentDateTime.AddHours(-24)
 
# Função para converter a duração
Function Convert-Duration {
    param ($duration)
 
    if ($null -ne $duration) { 
        $hours = if ($duration -match '(\d+)H') { [int]::Parse($matches[1]) } else { 0 }
        $minutes = if ($duration -match '(\d+)M') { [int]::Parse($matches[1]) } else { 0 }
        $seconds = if ($duration -match '(\d+)S') { [int]::Parse($matches[1]) } else { 0 }
 
        return (New-TimeSpan -Hours $hours -Minutes $minutes -Seconds $seconds).ToString("hh\:mm\:ss")
    } 
    else { 
        return "00:00:00"
    }
}
 
# Criar array com informações dos computadores
$Devices_info_Array = @()
ForEach ($Detail in $AutopilotEvents.Value) {
    # Converter a data e hora do fim da implantação para o tipo DateTime
    $deploymentEndDateTime = [DateTime]::Parse($Detail.deploymentEndDateTime)
 
    # Verificar se a data e hora do fim da implantação é dentro do último dia (24 horas)
    if ($deploymentEndDateTime -gt $dateTime24HoursAgo) {
 
        $UserID = $Detail.userPrincipalName
        $UsersUrl = "https://graph.microsoft.com/v1.0/users/$UserID"
        $UPN = Invoke-RestMethod -Method Get -Uri $UsersUrl -Headers $headers
 
        $Obj = New-Object PSObject
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "TimeGenerated" -Value $currentTime
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "ID_Autopilot_Event" -Value $Detail.id
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device_ID" -Value $Detail.deviceId
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device_Registered_DateTime" -Value $Detail.deviceRegisteredDateTime
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Enrollment_Start_DateTime" -Value $Detail.enrollmentStartDateTime
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Enrollment_Type" -Value $Detail.enrollmentType
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Event_DateTime" -Value $Detail.eventDateTime
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device_Serial_Number" -Value $Detail.deviceSerialNumber
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Managed_Device_Name" -Value $Detail.managedDeviceName
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "User_Principal_Name" -Value $UPN.userPrincipalName
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Deployment_Profile_Display_Name" -Value $Detail.windowsAutopilotDeploymentProfileDisplayName
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Enrollment_State" -Value $Detail.enrollmentState
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Completion_Page_Configuration_Display_Name" -Value $Detail.windows10EnrollmentCompletionPageConfigurationDisplayName
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Deployment_State" -Value $Detail.deploymentState
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device_Setup_Status" -Value $Detail.deviceSetupStatus
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Account_Setup_Status" -Value $Detail.accountSetupStatus
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "OS_Version" -Value $Detail.osVersion
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Deployment_Duration" -Value (Convert-Duration $Detail.deploymentDuration)
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Deployment_Total_Duration" -Value (Convert-Duration $Detail.deploymentTotalDuration)
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device_Preparation_Duration" -Value (Convert-Duration $Detail.devicePreparationDuration)
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Device_Setup_Duration" -Value (Convert-Duration $Detail.deviceSetupDuration)
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Account_Setup_Duration" -Value (Convert-Duration $Detail.accountSetupDuration)
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Deployment_Start_DateTime" -Value $Detail.deploymentStartDateTime
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Deployment_End_DateTime" -Value $Detail.deploymentEndDateTime
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Targeted_App_Count" -Value $Detail.targetedAppCount
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Targeted_Policy_Count" -Value $Detail.targetedPolicyCount
        Add-Member -InputObject $Obj -MemberType NoteProperty -Name "Enrollment_Failure_Details" -Value $Detail.enrollmentFailureDetails
        $Devices_info_Array += $Obj
 
    }
}
 
# Converter array para JSON
$Devices_Details_Json = $Devices_info_Array | ConvertTo-Json
 
# Obter um token de portador (bearer) usado posteriormente para autenticação no DCE
$url = "https://monitor.azure.com//.default"
$encodedUrl = [System.Uri]::EscapeUriString($url)
$scope = $encodedUrl
$body = "client_id=$clientId&scope=$scope&client_secret=$clientSecret&grant_type=client_credentials";
$headers = @{"Content-Type" = "application/x-www-form-urlencoded" };
$LoginUri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"
 
$bearerToken = (Invoke-RestMethod -Uri $LoginUri -Method "Post" -Body $body -Headers $headers).access_token
 
# Envie os dados para o espaço de trabalho de análise de logs por meio do DCE.
$Uploadbody = $Devices_Details_Json;
$headers = @{"Authorization" = "Bearer $bearerToken"; "Content-Type" = "application/json" };
$uri = "$dceEndpoint/dataCollectionRules/$dcrImmutableId/streams/$($streamName)?api-version=2021-11-01-preview"
 
$uploadResponse = Invoke-RestMethod -Uri $uri -Method "Post" -Body $Uploadbody -Headers $headers
$uploadResponse
 
# Mostre os deployments registrados nos últimos 24 horas
$Devices_info_Array | Select-Object ID_Autopilot_Event, Device_ID, Managed_Device_Name, User_Principal_Name, Device_Serial_Number, Deployment_State, Deployment_Total_Duration | Format-Table -AutoSize