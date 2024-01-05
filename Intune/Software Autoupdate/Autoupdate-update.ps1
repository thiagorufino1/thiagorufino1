<#
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
        Write-WingetLog -Mensagem "Nenhuma atualização disponível." -Componente "Configuração" -Classificacao Alerta
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

        foreach ($WingetApps in $upgradeList) {

            $WingetName = ($WingetApps).Name
            $WingetID = ($WingetApps).Id
            $WingetVersion = ($WingetApps).Version
            $WingetAvailable = ($WingetApps).AvailableVersion

            Write-WingetLog -Mensagem "ID: $WingetID - Nova versão disponível para o software $WingetName. Versão Atual: $WingetVersion. Versão disponível: $WingetAvailable" -Componente "Nova Atualização" -Classificacao Informação
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

    Write-WingetLog -Mensagem "Obtendo lista de softwares permitidos." -Componente "Configuração" -Classificacao Alerta

    If ($AppList) {
        foreach ($AppPermitido in $AppList) {
            Write-WingetLog -Mensagem "Software Permitido - ID: $AppPermitido" -Componente "Configuração" -Classificacao Informação
        }

        return $AppList

    }
    else {
        Write-WingetLog -Mensagem "Nenhuma política encontrada." -Componente "Configuração" -Classificacao Alerta
    }
}

function Get-Aviso {

    if (Test-Path "HKLM:\SOFTWARE\Policies\SoftwareAutoupdate\Aviso") {

        $Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Policies\SoftwareAutoupdate\Aviso'
        $ValueNames = (Get-Item -Path "HKLM:\SOFTWARE\Policies\SoftwareAutoupdate\Aviso").Property

        $AppList = @()

        foreach ($ValueName in $ValueNames) {
            $AppIDs = [Microsoft.Win32.Registry]::GetValue($Key, $ValueName, $false)
            $AppList += $AppIDs
        }
    }

    if($AppList){
        Write-WingetLog -Mensagem "Nível de notificação: $AppList." -Componente "Configuração" -Classificacao Informação
    } else {
        Write-WingetLog -Mensagem "Nível de notificação: Todos." -Componente "Configuração" -Classificacao Informação
    }

    return $AppList

}

Function Confirm-Update {

    param (
        $AppID,
        $AppVersion
    )

    $Dir = Set-Directory
    $Winget = Invoke-Winget
    $JsonFile = "$Dir\InstalledApps.json"

    Start-Process $Winget -ArgumentList "export -s winget -o $JsonFile --include-versions" -PassThru -Wait -WindowStyle Hidden
    $Json = Get-Content $JsonFile -Raw | ConvertFrom-Json

    $Packages = $Json.Sources.Packages
    Remove-Item $JsonFile -Force

    $Apps = $Packages | Where-Object { $_.PackageIdentifier -eq $AppID -and $_.Version -like "$AppVersion*" }

    if ($Apps) {
        return $true
    }

    else {
        return $false
    }

}

function Set-Notificacao {

    param (
        $Icone,
        $Titulo,
        $Mensagem
    )

    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::$Icone
    $notify.BalloonTipText = $Mensagem
    $notify.BalloonTipTitle = $Titulo
    $notify.Visible = $true
    
    # Exiba a notificação de balão por 5 segundos (5000 milissegundos)
    $notify.ShowBalloonTip(10000)
    
    # Aguarde um pouco antes de limpar e fechar a notificação
    Start-Sleep -Seconds 11
    
    # Limpe e feche o objeto de notificação de balão
    $notify.Dispose()
    
}

function Update-Apps {

    $Winget = Invoke-Winget
    $Aviso = Get-Aviso
    $Permitidos = Get-AppsPermitidos
    $AppsToUpdate = Get-AppUpdateAvailable

    if (($null -eq $AppsToUpdate) -or (!$Winget)) {}
    else {

        foreach ($AppToUpdate in $AppsToUpdate) {

            $AppName = ($AppToUpdate).Name
            $AppID = ($AppToUpdate).Id
            $AppVersion = ($AppToUpdate).Version
            $AppAvailable = ($AppToUpdate).AvailableVersion

            #Write-WingetLog -Mensagem "ID: $AppID" -Componente "Atualizar Software" -Classificacao Informação

            foreach ($AllowApps in $Permitidos) {
                if ($AllowApps -eq $AppID) {
                    $isAllowApps = $true
                    break
                }
                else {
                    $isAllowApps = $false
                }
            }

            if ($isAllowApps) {
                Write-WingetLog -Mensagem "ID: $AppID - Iniciando a atualização do software $AppName da versão $AppVersion para $AppAvailable." -Componente "Atualizar Software" -Classificacao Informação
                Start-Process $Winget -ArgumentList "upgrade --id $AppID --accept-package-agreements --accept-source-agreements --silent --force --disable-interactivity" -PassThru -Wait -WindowStyle Hidden

                $StatusInstallation = Confirm-Update -AppID $AppID -AppVersion $AppAvailable

                if ($StatusInstallation) {
                    Write-WingetLog -Mensagem "ID: $AppID - Software $AppName atualizado para versão $AppAvailable com sucesso." -Componente "Atualizar Software" -Classificacao Informação

                    if($Aviso -ne "Nenhum"){
                        Set-Notificacao -Icone Info -Titulo "$AppName foi atualizado !" -Mensagem "Nova versão: $AppAvailable."
                    }
                    
                }
                else {
                    Write-WingetLog -Mensagem "ID: $AppID - Falha ao atualizar o Software $AppName para versão $AppAvailable." -Componente "Atualizar Software" -Classificacao Erro

                    if(($Aviso -eq "Todos") -or (!$Aviso)){
                        Set-Notificacao -Icone Error -Titulo "$AppName não foi atualizado !" -Mensagem "Erro ao atualizar para versão $AppAvailable."
                    }
                }
            }
            else {
                Write-WingetLog -Mensagem "ID: $AppID - Atualização não autorizada: O software não esta incluido na lista de aplicativos permitidos." -Componente "Atualizar Software" -Classificacao Alerta

            }
        }
    }
}

Update-Apps