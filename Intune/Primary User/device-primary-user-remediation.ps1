<#
    .NOTES
        Criado por: Thiago Rufino
        thiagorufino.com

        Data: 10/03/2024
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

$DeviceName = $env:COMPUTERNAME
$LocalUser = $env:USERNAME + '@'

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
        return $true
    }
    else {
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

$DeviceName = $env:COMPUTERNAME
$LocalUser = $env:USERNAME + '@'

$Device = Get-LocalDevice
$User = Get-LocalUser

Set-NewPrimaryUser -DeviceID $Device.id -UserID $User.id

$Status = Test-PrimaryUser

if ($Status -eq $true) {
    Write-Log -Mensagem "O Usuário $($User.userPrincipalName) foi configurado como Primary User com sucesso." -Componente "Set-NewPrimaryUser" -Classificacao Informação
}
else {
    Write-Log -Mensagem "Falha ao definir o Usuário Primário." -Componente "Set-NewPrimaryUser" -Classificacao Informação
}