﻿<#
    .NOTES
        Criado por: Thiago Rufino
        thiagorufino.com

        Data: 19/02/2024
        Version: 1.0
#>

# App Registrations
$clientId = "84918e1b-058d-4f25-a32b-a17beb8dc914"
$clientSecret = "pV18Q~gnQNDrYomVOZ6d1wzNPMJFzV~1DN2RLc1."
$tenantId = "783f9353-3381-4168-b6bc-a439b25dfc6a"

# Key Vault
$keyVaultName = "kv-bios-pwd"  #Nome do Key Vault.
$NewSecretName = "FEV-2024"    #Nome da secret com a senha mais recente.

function Set-Directory {
    $Directory = "C:\Temp\BiosPassword"
 
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
    $LogName = "BiosPassword.log"
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

function Get-Manufacturer {
    $Manufacturer = (Get-WmiObject Win32_ComputerSystem).Manufacturer
    Return $Manufacturer
}

function Get-DellModule {

    if (Test-Path -Path "C:\Program Files\WindowsPowerShell\Modules\DellBIOSProvider") {
        Import-Module -Name DellBIOSProvider -ErrorAction SilentlyContinue
    }
    else {
        Install-PackageProvider -Name Nuget -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        Install-Module -Name DellBIOSProvider -Force -Scope AllUsers -ErrorAction SilentlyContinue
        Start-Sleep 2
        Import-Module -Name DellBIOSProvider -ErrorAction SilentlyContinue
    }

    $DellBIOSProvider = Get-Module DellBIOSProvider
 
    if ($DellBIOSProvider) {
 
        Write-Log -Mensagem "O módulo DellBIOSProvider (versão $($DellBIOSProvider.Version)) foi encontrado." -Componente "Get-DellModule" -Classificacao Informação
        return $true
       
    }
    else {
        Write-Log -Mensagem "A instalação do módulo DellBIOSProvider falhou." -Componente "Get-DellModule" -Classificacao Informação
        return $false
    }
   
}

function Get-isPwdSet {
    $IsAdminPasswordSet = Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet
    Return $IsAdminPasswordSet.CurrentValue
}

function Get-NewPwd {

    $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/token"

    $body = @{
        "grant_type"    = "client_credentials"
        "client_id"     = $clientId
        "client_secret" = $clientSecret
        "resource"      = "https://vault.azure.net"
    }

    $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body
    $secretUri = "https://$keyVaultName.vault.azure.net/secrets/$NewSecretName/?api-version=7.0"
    $headers = @{ "Authorization" = "$($tokenResponse.token_type) $($tokenResponse.access_token)" }

    $secretResponse = Invoke-RestMethod -Uri $secretUri -Headers $headers -Method Get

    Return $secretResponse.value
}

function Get-LastPwd {
    $NewPwd = Get-NewPwd
    Set-Item -Path DellSmbios:\Security\AdminPassword "$NewPwd" -Password "$NewPwd" -ErrorAction SilentlyContinue

    return $?
}

$ModuloStatus = Get-DellModule
$Fabricante = Get-Manufacturer

if ($Fabricante -like "*Dell*") {

    if ($ModuloStatus -eq "True") {

        $SetPwdStatus = Get-isPwdSet
        if ($SetPwdStatus -eq "True") {

            $LastPwdStatus = Get-LastPwd
            if ($LastPwdStatus -eq "True") {
                Write-Log -Mensagem "A senha já está atualizada com a versão mais recente." -Componente "Verificar BIOS" -Classificacao Informação
                Exit 0
            }
            else {
                Write-Log -Mensagem "A senha da BIOS está desatualizada. Iniciando o processo de atualização." -Componente "Verificar BIOS" -Classificacao Informação
                Exit 1
            }

        }
        else {
            Write-Log -Mensagem "O dispositivo não tem senha definida na BIOS. Iniciando o processo de definição." -Componente "Verificar BIOS" -Classificacao Informação
            Exit 1
        }

    }
    else {
        Write-Log -Mensagem "O Módulo DellBIOSProvider não foi encontrado." -Componente "Verificar Módulo" -Classificacao Informação
        Exit 0
    }
}
else {
    Write-Log -Mensagem "Este dispositivo não é um equipamento Dell, portanto, esta solução não é compatível." -Componente "Verificar Fabricante" -Classificacao Informação
    Exit 0
}