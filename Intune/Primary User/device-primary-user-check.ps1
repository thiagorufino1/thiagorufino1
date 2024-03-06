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

function Get-LocalDevice {
    
    try {
        $DeviceUri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'"
        $DeviceResponse = (Invoke-RestMethod -Uri $DeviceUri -Headers $headers -Method Get)
        $Device = $DeviceResponse.value
        return $Device
    }
    catch {
        Write-Log -Mensagem "Error : $($error[0].exception.message)" -Componente "Get-LocalDevice" -Classificacao Informação
    }
}

function Get-LocalUser {

    try {
        $UserUri = "https://graph.microsoft.com/v1.0/users?`$select=id,displayName,userPrincipalName&`$filter=startsWith(userPrincipalName,'$($LocalUser)')"
        $UserResponse = (Invoke-RestMethod -Uri $UserUri -Headers $headers -Method Get)
        $User = $UserResponse.value
        return $User
    }
    catch {
        Write-Log -Mensagem "Error : $($error[0].exception.message)" -Componente "Get-LocalUser" -Classificacao Informação
    }    
}

function Get-CurrentlyPrimaryUser {

    param (
        [string]$DeviceID
    )

    try {
        $PrimaryUserUri = "https://graph.microsoft.com/beta/deviceManagement/manageddevices('$DeviceID')/users"
        $PrimaryUserResponse = (Invoke-RestMethod -Uri $PrimaryUserUri -Headers $headers -Method Get)
        $PrimaryUser = $PrimaryUserResponse.value
        return $PrimaryUser
    }
    catch {
        Write-Log -Mensagem "Error : $($error[0].exception.message)" -Componente "Get-CurrentlyPrimaryUser" -Classificacao Informação
    }
}

function Test-PrimaryUser {

    param(
        [string]$UserID,
        [string]$CurrentlyPrimaryUserID
    )

    if ($UserID -eq $CurrentlyPrimaryUserID) {
        Write-Log -Mensagem "Primary User esta correto." -Componente "Test-PrimaryUser" -Classificacao Informação
        return $true
    }
    else {
        Write-Log -Mensagem "Primary User esta incorreto." -Componente "Test-PrimaryUser" -Classificacao Informação
        return $false
    }
    
}

# Nome do dispositivo e usuário
#$DeviceName = $env:COMPUTERNAME
$DeviceName = "W10-02"

#$LocalUser = $env:USERNAME + '@'
$LocalUser = 'admin@'

$Device = Get-LocalDevice
$User = Get-LocalUser

if ($Device) {
    Write-Log -Mensagem "Dispositivo:  $($Device.deviceName) ($($Device.id))" -Componente "Get-LocalDevice" -Classificacao Informação

    if ($User) {
        Write-Log -Mensagem "Usuário Local:  $($User.userPrincipalName) ($($User.id))" -Componente "Get-LocalUser" -Classificacao Informação
        $CurrentlyPrimaryUser = Get-CurrentlyPrimaryUser -DeviceID $Device.id

        if ($CurrentlyPrimaryUser) {
            Write-Log -Mensagem "Primary User Atual:  $($CurrentlyPrimaryUser.userPrincipalName) ($($CurrentlyPrimaryUser.id))" -Componente "Get-CurrentlyPrimaryUser" -Classificacao Informação

            $StatusPrimaryUser = Test-PrimaryUser -UserID $User.id -CurrentlyPrimaryUserID $CurrentlyPrimaryUser.id
            if ($StatusPrimaryUser -eq $true) { Write-Host "OK" } else { Write-Host "NOK" }

        }
        else {
            Write-Log -Mensagem "Erro ao obter ID do Primary User definido atualmente." -Componente "Erro ao Obter ID" -Classificacao Informação
        }

    }
    else {
        Write-Log -Mensagem "Erro ao obter ID do usuário local." -Componente "Erro ao Obter ID" -Classificacao Informação
    }

}
else {
    Write-Log -Mensagem "Erro ao obter ID do dispositivo." -Componente "Erro ao Obter ID" -Classificacao Informação
}