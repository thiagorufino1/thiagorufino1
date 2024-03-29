﻿<#
    .DESCRIPTION
        O Script tem como objetivo automatizar a atualização de softwares utilizando Winget.

    .NOTES
        Criado por: Thiago Rufino
        thiagorufino.com

        Data: 04/09/2023
        Version: 1.0
#>

function Set-Directory {
    $Directory = "C:\Temp\Software-Autoupdate"

    if (!(Test-Path $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force
    }

    Return $Directory
}

function Write-WingetLog {

    param(
        [Parameter(Mandatory = $True, HelpMessage = "Inserir a mensagem para ser adicionada do log do Winget Autoupdate.")][string]$Mensagem,
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
    $LogDir = "$Dir\Autoupdate.log"

    if (!(Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType File -Force
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

function Find-Winget {

    $WingetPath = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe" } | Select-Object -ExpandProperty FullName -First 1

    if ($WingetPath) {
        if (Test-Path -Path "$WingetPath\winget.exe") {

            $Winget = "$WingetPath\winget.exe"
            $SoftwareList = & $Winget list --accept-source-agreements
            $WingetVer = & $Winget --version

            Write-WingetLog -Mensagem "Winget Instalado ! Versão: $WingetVer." -Componente "Verificar Winget" -Classificacao Informação
            Return $Winget

        }
        else {
            Write-WingetLog -Mensagem "Winget não encontrado!" -Componente "Verificar Winget" -Classificacao Alerta
        }
    }
    else {
        Write-WingetLog -Mensagem "Winget não encontrado!" -Componente "Verificar Winget" -Classificacao Alerta
    }
}

function Invoke-Winget {
    $WingetPath = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Directory | Where-Object { $_.Name -like "Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe" } | Select-Object -ExpandProperty FullName -First 1
    $Winget = "$WingetPath\winget.exe"
    return $Winget
}

function Get-AppUpdateAvailable {
    
    class Software {
        [string]$Name
        [string]$Id
        [string]$Version
        [string]$AvailableVersion
    }

    $Winget = Invoke-Winget
    $upgradeResult = & $Winget upgrade --source winget | Out-String

    if (!($upgradeResult -match "-----")) {
        Return $false
    }
    else {

        $lines = $upgradeResult.Split([Environment]::NewLine) | Where-Object { $_ }
        $fl = 0

        while (-not $lines[$fl].StartsWith("-----")) {
            $fl++
        }

        $fl = $fl - 1
        $index = $lines[$fl] -split '(?<=\s)(?!\s)'

        $idStart = [System.Text.Encoding]::UTF8.GetByteCount($($index[0] -replace '[\u4e00-\u9fa5]', '**'))
        $versionStart = $idStart + [System.Text.Encoding]::UTF8.GetByteCount($($index[1] -replace '[\u4e00-\u9fa5]', '**'))
        $availableStart = ($versionStart + [System.Text.Encoding]::UTF8.GetByteCount($($index[2] -replace '[\u4e00-\u9fa5]', '**'))) - 4

        $upgradeList = @()

        For ($i = $fl + 2; $i -lt $lines.Length; $i++) {
            $line = $lines[$i] -replace "[\u2026]", " "

            if ($line.StartsWith("-----")) {

                $fl = $i - 1
                $index = $lines[$fl] -split '(?<=\s)(?!\s)'

                $idStart = [System.Text.Encoding]::UTF8.GetByteCount($($index[0] -replace '[\u4e00-\u9fa5]', '**'))
                $versionStart = $idStart + [System.Text.Encoding]::UTF8.GetByteCount($($index[1] -replace '[\u4e00-\u9fa5]', '**'))
                $availableStart = ($versionStart + [System.Text.Encoding]::UTF8.GetByteCount($($index[2] -replace '[\u4e00-\u9fa5]', '**'))) - 4
            }

            if ($line -match "\w\.\w") {

                $software = [Software]::new()

                $nameDeclination = $([System.Text.Encoding]::UTF8.GetByteCount($($line.Substring(0, $idStart) -replace '[\u4e00-\u9fa5]', '**')) - $line.Substring(0, $idStart).Length)
                $software.Name = $line.Substring(0, $idStart - $nameDeclination).TrimEnd()
                $software.Id = $line.Substring($idStart - $nameDeclination, $versionStart - $idStart).TrimEnd()
                $software.Version = $line.Substring($versionStart - $nameDeclination, $availableStart - $versionStart).TrimEnd()
                $software.AvailableVersion = $line.Substring($availableStart - $nameDeclination).TrimEnd()
                $upgradeList += $software
            }
        }

        return $upgradeList | Sort-Object { Get-Random }

    }

}

function Get-AppsPermitidos {

    if (Test-Path "HKLM:\SOFTWARE\Policies\SoftwareAutoupdate\Permitidos") {

        $Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\SoftwareAutoupdate\Permitidos'
        $ValueNames = (Get-Item -Path "HKLM:\SOFTWARE\Policies\SoftwareAutoupdate\Permitidos").Property

        $AppList = @()

        foreach ($ValueName in $ValueNames) {
            $AppIDs = [Microsoft.Win32.Registry]::GetValue($Key, $ValueName, $false)
            $AppList += $AppIDs
        }
    }

    If ($AppList) {
        return $AppList
    }
    else {
        Return $false
    }
}

function Get-WingetTrigger {

    $Winget = Find-Winget
    $AppsToUpdate = (Get-AppUpdateAvailable).id
    $Permitidos = Get-AppsPermitidos

    if ($Winget) {
        if ($AppsToUpdate) {

            Write-WingetLog -Mensagem "Verificando atualizações disponíveis." -Componente "Verificar Atualizações" -Classificacao Informação
            $UpdateFound = $false

            foreach ($item in $Permitidos){
                if ($AppsToUpdate -contains $item){
                    $UpdateFound = $true
                    break
                }
            }

            if ($UpdateFound) {
                Write-WingetLog -Mensagem "Novas versões de softwares encontradas, iniciando atualizações." -Componente "Verificar Atualizações" -Classificacao Informação
                #Exit 1
                #Write-Host "executa o update" -ForegroundColor Green
            } else {
                Write-WingetLog -Mensagem "Nenhuma atualização disponível para os softwares permitidos." -Componente "Verificar Atualizações" -Classificacao Informação
                #Exit 0
                #Write-Host "não executa o update" -ForegroundColor Red
            }

        } else {
            Write-WingetLog -Mensagem "Nenhuma atualização disponível." -Componente "Verificar Atualizações" -Classificacao Informação
            #Exit 0
            #Write-Host "não executa o update" -ForegroundColor Red
        }
    } else {
        #Exit 0
        #Write-Host "Winget nao encontrado" -ForegroundColor Red
    }
}

Get-WingetTrigger