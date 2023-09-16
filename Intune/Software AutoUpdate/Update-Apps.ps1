<#
    .SYNOPSIS
        Script para configuração do Winget para atualizaçãoo automática. 

    .DESCRIPTION
        O Script tem como objetivo implementar o AutoUpdate para aplicativos permitidos.

    .NOTES
        Desenvolvido por: Renan Barbosa e Thiago Rufino.
        Departamento: Gestão de Endpoint, Softwares, Office 365 e AVD.
        Empresa: Cielo S.A
        Data: 04/09/2023
        Version: 1.0
#>

function Write-WingetLog {

    param(
        [Parameter(Mandatory=$True, HelpMessage = "Cielo - Winget AutoUpdate
        Inserir a mensagem para ser adicionada do log do Winget Autoupdate.")][string]$Mensagem,
        [Parameter(Mandatory=$True, HelpMessage = "Cielo - Winget AutoUpdate
        Inserir o componente responsagem por essa linha do log.")][String]$Componente,
        [parameter(Mandatory = $true, HelpMessage = "Cielo - Winget AutoUpdate
        Definir a classicação do tipo de log:

        Informação
        Alerta
        Erro")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("Informação", "Alerta", "Erro")]
        [string]$Classificacao
    );

    $LogDir = "C:\Temp\Winget\Winget.log"

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

    $logmessage = "<![LOG[$Mensagem]LOG]!><time=`"$($time)`" date=`"$($date)`" component=`"$($Componente)`" context=`"$($Context)`" type=`"$($Classificacao)`" thread=`"$($PID)`" Company=`"Cielo`">";

    Out-File -FilePath $LogDir -Append -InputObject $logmessage -Encoding UTF8;
    $size=(Get-Item $LogDir).length

    if ( $size -gt 5120000 ) {
        Move-Item -Path $LogDir -Destination "$LogDir.bak" -Force
    }
}

function Get-WingetStatus {

    $ResolveWingetPath = Resolve-Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe" -ErrorAction SilentlyContinue | Sort-Object { [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1') }

    if ($ResolveWingetPath) {

        $WingetPath = $ResolveWingetPath[-1].Path

        if (Test-Path "$WingetPath\winget.exe") {
            $Script:Winget = "$WingetPath\winget.exe"    

            & $Winget list --accept-source-agreements -s winget | Out-Null
            $WingetVer = & $Winget --version

            Write-WingetLog -Mensagem "Winget Encontrado! Versão: $WingetVer" -Componente "Verificar Winget" -Classificacao Informação
            return $true

        } else {
            Write-WingetLog -Mensagem "Winget não encontrado !" -Componente "Verificar Winget" -Classificacao Alerta
            Install-WinGet
        }

    } else {
        Write-WingetLog -Mensagem "Winget não encontrado !" -Componente "Verificar Winget" -Classificacao Alerta
        Install-WinGet
    }
}

function Install-WinGet {

    try {
        Write-WingetLog -Mensagem "Instalando complemento Microsoft.VCLibs.x64.14.00.Desktop.appx." -Componente "Installar Winget" -Classificacao Informação
        Add-AppxProvisionedPackage -Online -PackagePath "$PSScriptRoot\Microsoft.VCLibs.x64.14.00.Desktop.appx" -SkipLicense | Out-Null

        Write-WingetLog -Mensagem "Instalando complemento Microsoft.UI.Xaml.2.7.x64.appx." -Componente "Installar Winget" -Classificacao Informação
        Add-AppxProvisionedPackage -Online -PackagePath "$PSScriptRoot\Microsoft.VCLibs.x64.14.00.Desktop.appx" -SkipLicense | Out-Null

        Write-WingetLog -Mensagem "Instalando DesktopAppInstaller.appx." -Componente "Installar Winget" -Classificacao Informação
        Add-AppxProvisionedPackage -Online -PackagePath "$PSScriptRoot\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -SkipLicense | Out-Null

        Write-WingetLog -Mensagem "Winget Instalado." -Componente "Installar Winget" -Classificacao Informação
    }

    catch {
        Write-WingetLog -Mensagem "Falha ao instalar o Winget." -Componente "Installar Winget" -Classificacao Erro
    }
}

function Get-IncludedApps {

    if (Test-Path "HKLM:\SOFTWARE\Policies\Cielo\Winget-AutoUpdate\Permitidos") {

        $Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Cielo\Winget-AutoUpdate\Permitidos'
        $ValueNames = (Get-Item -Path "HKLM:\SOFTWARE\Policies\Cielo\Winget-AutoUpdate\Permitidos").Property

        $AppList = @()

        foreach ($ValueName in $ValueNames) {
            $AppIDs = [Microsoft.Win32.Registry]::GetValue($Key, $ValueName, $false)
            $AppList += $AppIDs
        }
    }

    Write-WingetLog -Mensagem "Verificando políticas para softwares permitidos." -Componente "GPO" -Classificacao Alerta

    If ($AppList) {
        foreach ($AppPermitido in $AppList){
            Write-WingetLog -Mensagem "ID: $AppPermitido" -Componente "Software Permitido" -Classificacao Informação
        }

        return $AppList

    } else {
        Write-WingetLog -Mensagem "Nenhuma política encontrada." -Componente "Software Permitido" -Classificacao Alerta
    }
}

function Get-ExcludedApps {

    if (Test-Path "HKLM:\SOFTWARE\Policies\Cielo\Winget-AutoUpdate\Bloqueados") {

        $Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Cielo\Winget-AutoUpdate\Bloqueados'
        $ValueNames = (Get-Item -Path "HKLM:\SOFTWARE\Policies\Cielo\Winget-AutoUpdate\Bloqueados").Property

        $AppList = @()

        foreach ($ValueName in $ValueNames) {
            $AppIDs = [Microsoft.Win32.Registry]::GetValue($Key, $ValueName, $false)
            $AppList += $AppIDs
        }
    }

    Write-WingetLog -Mensagem "Verificando políticas para softwares bloqueados." -Componente "GPO" -Classificacao Alerta

    If ($AppList) {
        foreach ($AppBloqueado in $AppList){
            Write-WingetLog -Mensagem "ID: $AppBloqueado" -Componente "Software Bloqueado" -Classificacao Informação
        }

        return $AppList

    } else {
        Write-WingetLog -Mensagem "Nenhuma política encontrada." -Componente "Software Bloqueado" -Classificacao Alerta
    }
}

function Get-AppUpdateAvailable {
    $null = Get-WingetStatus
    class Software {
        [string]$Name
        [string]$Id
        [string]$Version
        [string]$AvailableVersion
    }

    $upgradeResult = & $Winget upgrade --source winget | Out-String

    if (!($upgradeResult -match "-----")) {
        Write-WingetLog -Mensagem "Nenhuma atualização disponível." -Componente "Verificar Atualizações" -Classificacao Alerta
    } else {

        $lines = $upgradeResult.Split([Environment]::NewLine) | Where-Object { $_ }
        $fl = 0

        while (-not $lines[$fl].StartsWith("-----")) {
            $fl++
        }

        $fl = $fl - 1
        $index = $lines[$fl] -split '(?<=\s)(?!\s)'

        $idStart = [System.Text.Encoding]::UTF8.GetByteCount($($index[0] -replace '[\u4e00-\u9fa5]', '**'))
        $versionStart = $idStart + [System.Text.Encoding]::UTF8.GetByteCount($($index[1] -replace '[\u4e00-\u9fa5]', '**'))
        $availableStart = ($versionStart + [System.Text.Encoding]::UTF8.GetByteCount($($index[2] -replace '[\u4e00-\u9fa5]', '**'))) -4

        $upgradeList = @()

        For ($i = $fl + 2; $i -lt $lines.Length; $i++) {
            $line = $lines[$i] -replace "[\u2026]", " "

            if ($line.StartsWith("-----")) {

                $fl = $i - 1
                $index = $lines[$fl] -split '(?<=\s)(?!\s)'

                $idStart = [System.Text.Encoding]::UTF8.GetByteCount($($index[0] -replace '[\u4e00-\u9fa5]', '**'))
                $versionStart = $idStart + [System.Text.Encoding]::UTF8.GetByteCount($($index[1] -replace '[\u4e00-\u9fa5]', '**'))
                $availableStart = ($versionStart + [System.Text.Encoding]::UTF8.GetByteCount($($index[2] -replace '[\u4e00-\u9fa5]', '**'))) -4
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

        foreach ($WingetApps in $upgradeList){

            $WingetName = ($WingetApps).Name
            $WingetID = ($WingetApps).Id
            $WingetVersion = ($WingetApps).Version
            $WingetAvailable = ($WingetApps).AvailableVersion

            Write-WingetLog -Mensagem "Nova versão disponível para o software $WingetName (ID: $WingetID). Versão Atual: $WingetVersion. Versão disponível: $WingetAvailable" -Componente "Verificar Atualizações" -Classificacao Informação
        }

        return $upgradeList | Sort-Object { Get-Random }

    }

}

Function Confirm-Installation {

    param (
        $AppID,
        $AppVersion
    )

    $JsonFile = "C:\Temp\Winget\InstalledApps.json"

    & Winget export -s winget -o $JsonFile --include-versions | Out-Null
    $Json = Get-Content $JsonFile -Raw | ConvertFrom-Json

    $Packages = $Json.Sources.Packages
    Remove-Item $JsonFile -Force

    $Apps = $Packages | Where-Object { $_.PackageIdentifier -eq $AppID -and $_.Version -like "$AppVersion*"}

    if ($Apps){
        return $true
    }

    else{
        return $false
    }

}

function Update-Apps {

    $WingetStatus = Get-WingetStatus
    $AppsToUpdate = Get-AppUpdateAvailable
    $Permitidos = Get-IncludedApps
    $BloqueadoExcecao = Get-ExcludedApps

    if (($null -eq $AppsToUpdate) -or (!$WingetStatus)){

    } else {

        foreach ($AppToUpdate in $AppsToUpdate){

            $AppName = ($AppToUpdate).Name
            $AppID = ($AppToUpdate).Id
            $AppVersion = ($AppToUpdate).Version
            $AppAvailable = ($AppToUpdate).AvailableVersion

            Write-WingetLog -Mensagem "ID: $AppID" -Componente "Atualizar Software" -Classificacao Informação

                foreach ($exception in $BloqueadoExcecao){
                    if ($exception -eq $AppID) {
                        $isException = $true
                        break
                    } else {
                        $isException = $false
                    }
                }

                foreach ($AllowApps in $Permitidos){
                    if ($AllowApps -eq $AppID) {
                        $isAllowApps = $true
                        break
                    } else {
                        $isAllowApps = $false
                    }
                }

            if ($isException){
                Write-WingetLog -Mensagem "Atualização não autorizada: Restrição devido a políticas de exceção." -Componente "Atualizar Software" -Classificacao Informação

            } elseif (!$isAllowApps){
                Write-WingetLog -Mensagem "Atualização não autorizada: O software não esta listado entre os aplicativos permitidos." -Componente "Atualizar Software" -Classificacao Informação

            } else {
                Write-WingetLog -Mensagem "Iniciando a atualização do software $AppName da versão $AppVersion para $AppAvailable." -Componente "Atualizar Software" -Classificacao Informação
                & Winget upgrade --id $AppID --accept-package-agreements --accept-source-agreements --silent --scope machine --force --disable-interactivity

                $StatusInstallation = Confirm-Installation -AppID $AppID -AppVersion $AppAvailable

                if ($StatusInstallation){
                    Write-WingetLog -Mensagem "Software $AppName atualizado para versão $AppAvailable com sucesso." -Componente "Atualizar Software" -Classificacao Informação
                } else {
                    Write-WingetLog -Mensagem "Falha ao atualizar o Software $AppName para versão $AppAvailable." -Componente "Atualizar Software" -Classificacao Erro
                }
            }
        }
    }
}

Update-Apps