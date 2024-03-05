<#
    .DESCRIPTION
        O Script tem como objetivo de atualizar o primary user do dispositivo

    .NOTES
        Criado por: Thiago Rufino
        thiagorufino.com

        Data: 04/03/2024
        Version: 1.0
#>

# App Registrations
$clientId = "27f044fd-dffc-4c75-a5d9-bca69affff22"
$clientSecret = "ual8Q~06UgaWJ3cuTGWLNbxJs1_QqPy-CUgLSb0m"
$tenantId = "144ac447-f91a-4a05-96f3-caa37e9d992f"

# Autenticação
$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"

$authParams = @{
    client_id     = $clientId
    client_secret = $clientSecret
    grant_type    = "client_credentials"
    resource      = "https://graph.microsoft.com"
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri $authUrl -Body $authParams

$accessToken = $tokenResponse.access_token

$headers = @{
    Authorization  = "Bearer $accessToken"
    'Content-Type' = 'application/json'
}

#$DeviceName = $env:COMPUTERNAME
$DeviceName = "W10-02"

#$LocalUser = $env:USERNAME + '@'
$LocalUser = 'admin@'


function Get-DeviceID {
    
    try {
        $DeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'"
        $DeviceResponse = (Invoke-RestMethod -Uri $DeviceUri -Headers $headers -Method Get)
        $DeviceID = $DeviceResponse.value.id
        return $DeviceID
    }
    catch {
        Write-output "Error : $($error[0].exception.message)"
    }
}

function Get-UserID {

    try {
        $UserUri = "https://graph.microsoft.com/v1.0/users?`$select=id,displayName,userPrincipalName,lastPasswordChangeDateTime&`$filter=startsWith(userPrincipalName,'$($LocalUser)')"
        $UserResponse = (Invoke-RestMethod -Uri $UserUri -Headers $headers -Method Get)
        $UserID = $UserResponse.value.id
        return $UserID
    }
    catch {
        Write-output "Error : $($error[0].exception.message)"
    }    
}

function Set-NewPrimaryUser {

    param (
        [string]$DeviceID,
        [string]$UserID
    )
    
    try {
        $DeviceIDUri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$DeviceID')/users/`$ref"
        $UserIDUri = "https://graph.microsoft.com/beta/users/" + $UserID
        $id = "@odata.id"
        $Body = @{ $id = "$UserIDUri" } | ConvertTo-Json -Compress
        $response = (Invoke-RestMethod -Uri $DeviceIDUri -Headers $headers -Method POST -Body $Body)
        return $response
    }
    catch {
        Write-output "Error : $($error[0].exception.message)"
    }
}

$DID = Get-DeviceID
$UID = Get-UserID
Set-NewPrimaryUser -DeviceID $DID -UserID $UID

function Get-CurrentlyPrimaryUser {

    param (
        $DeviceID
    )
    try {
        $PrimaryUserUri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$DeviceID')/users"
        $PrimaryUserResponse = (Invoke-RestMethod -Uri $PrimaryUserUri -Headers $headers -Method Get)
        $PrimaryUserID = $PrimaryUserResponse.value.id
        return $PrimaryUserID
    }
    catch {
        Write-output "Error : $($error[0].exception.message)"
    }
}

Get-CurrentlyPrimaryUser -DeviceID $DID
