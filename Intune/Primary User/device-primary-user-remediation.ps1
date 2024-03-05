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

function Set-Directory {
    $Directory = "C:\Temp\PrimaryUser"
 
    if (!(Test-Path $Directory)) {
        $DirResult = New-Item -Path $Directory -ItemType Directory -Force -InformationAction Stop
        Return $DirResult.FullName
    }
    else {
        Return $Directory
    }
}
 
function Write-Log {
 
    param(
        [Parameter(Mandatory = $True, HelpMessage = "Inserir a mensagem para ser adicionada no log.")][string]$Mensagem,
        [Parameter(Mandatory = $True, HelpMessage = "Inserir o componente responsagem por essa linha do log.")][String]$Componente,
        [parameter(Mandatory = $true, HelpMessage = "Definir a classicação do tipo de log:
 
        Informação
        Alerta
        Erro")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Informação", "Alerta", "Erro")]
        [string]$Classificacao
    );
 
    $Dir = Set-Directory
    $LogName = "PrimaryUser.log"
    $LogDir = "$Dir\$LogName"
 
    if (!(Test-Path $LogDir)) {
        New-Item -Name $LogName -Path $Dir -ItemType File -Force
        
    }
 
    if (-not(Test-Path -Path 'variable:global:TimezoneBias')) {
        [string]$global:TimezoneBias = [System.TimeZoneInfo]::Local.GetUtcOffset((Get-Date)).TotalMinutes
 
        if ($TimezoneBias -match "^-") {
            $TimezoneBias = $TimezoneBias.Replace('-', '+')
        }
 
        else {
            $TimezoneBias = '-' + $TimezoneBias
        }
    }
 
    $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), $TimezoneBias)
    $Date = (Get-Date -Format "dd-MM-yyyy")
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
 
    $logmessage = "<![LOG[$Mensagem]LOG]!><time=`"$($time)`" date=`"$($date)`" component=`"$($Componente)`" context=`"$($Context)`" type=`"$($Classificacao)`" thread=`"$($PID)`">";
 
    Out-File -FilePath $LogDir -Append -InputObject $logmessage -Encoding UTF8;
 
}

function Get-DeviceID {
    
    try {
        $DeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'"
        $DeviceResponse = (Invoke-RestMethod -Uri $DeviceUri -Headers $headers -Method Get)
        $DeviceID = $DeviceResponse.value.id

        Write-Log -Mensagem "Informações do Dispositivo:" -Componente "Get-DeviceID" -Classificacao Informação
        Write-Log -Mensagem "ID: $DeviceID." -Componente "Get-DeviceID" -Classificacao Informação
        Write-Log -Mensagem "Nome: $($DeviceResponse.value.deviceName)." -Componente "Get-DeviceID" -Classificacao Informação
        

        return $DeviceID
    }
    catch {
        Write-Log -Mensagem "Error : $($error[0].exception.message)" -Componente "Get-DeviceID" -Classificacao Informação
    }
}

function Get-UserID {

    try {
        $UserUri = "https://graph.microsoft.com/v1.0/users?`$select=id,displayName,userPrincipalName&`$filter=startsWith(userPrincipalName,'$($LocalUser)')"
        $UserResponse = (Invoke-RestMethod -Uri $UserUri -Headers $headers -Method Get)
        $UserID = $UserResponse.value.id

        Write-Log -Mensagem "Informações do Usuário:" -Componente "Get-DeviceID" -Classificacao Informação
        Write-Log -Mensagem "ID: $UserID." -Componente "Get-UserID" -Classificacao Informação
        Write-Log -Mensagem "Nome: $($UserResponse.value.displayName)." -Componente "Get-UserID" -Classificacao Informação
        Write-Log -Mensagem "UserPrincipalName: $($UserResponse.value.userPrincipalName)" -Componente "Get-UserID" -Classificacao Informação

        return $UserID
    }
    catch {
        Write-Log -Mensagem "Error : $($error[0].exception.message)" -Componente "Get-UserID" -Classificacao Informação
    }    
}

function Get-CurrentlyPrimaryUser {

    param (
        $DeviceID
    )
    try {
        $PrimaryUserUri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$DeviceID')/users"
        $PrimaryUserResponse = (Invoke-RestMethod -Uri $PrimaryUserUri -Headers $headers -Method Get)
        $PrimaryUserID = $PrimaryUserResponse.value.id

        Write-Log -Mensagem "Usuário: $($PrimaryUserResponse.value.displayName) 
        UserPrincipalName: $($PrimaryUserResponse.value.userPrincipalName) 
        ID: $PrimaryUserID." -Componente "Get-CurrentlyPrimaryUser" -Classificacao Informação

        return $PrimaryUserID
    }
    catch {
        Write-Log -Mensagem "Error : $($error[0].exception.message)" -Componente "Get-CurrentlyPrimaryUser" -Classificacao Informação
    }
}

function Test-PrimaryUser {

    $DID = Get-DeviceID
    $UID = Get-UserID
    $CurrentlyPrimaryUser = Get-CurrentlyPrimaryUser -DeviceID $DID

    if ($UID -eq $CurrentlyPrimaryUser) {
        Write-Log -Mensagem "Primary User correto" -Componente "Check-PrimaryUser" -Classificacao Informação
        return $true
    }
    else {
        Write-Log -Mensagem "Primary User incorreto" -Componente "Check-PrimaryUser" -Classificacao Informação
        return $false
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

$DeviceID = Get-DeviceID
$UserID = Get-UserID
$CurrentlyPrimaryUser = Get-CurrentlyPrimaryUser -DeviceID $DID