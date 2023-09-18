<#
    .DESCRIPTION
        O Script tem como objetivo automatizar a atualização de softwares utilizando Winget.

    .NOTES
        Criado por: Thiago Rufino
        thiagorufino.com

        Data: 04/09/2023
        Version: 1.0
#>

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

    $LogDir = "C:\Temp\Software-Autoupdate\Autoupdate.log"

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

function Get-WingetStatus {

    $ResolveWingetPath = Resolve-Path "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe" -ErrorAction SilentlyContinue | Sort-Object { [version]($_.Path -replace '^[^\d]+_((\d+\.)*\d+)_.*', '$1') }
    if ($ResolveWingetPath) {
        $WingetPath = $ResolveWingetPath[-1].Path
        if (Test-Path "$WingetPath\winget.exe") {
            $Script:Winget = "$WingetPath\winget.exe"
    
            & $Winget list --accept-source-agreements --source winget | Out-Null
            $WingetVer = & $Winget --version
    
            Write-WingetLog -Mensagem "Winget Encontrado! Versão: $WingetVer" -Componente "Verificar Winget" -Classificacao Informação
    
        }
        else {
            Write-WingetLog -Mensagem "Winget não encontrado !" -Componente "Verificar Winget" -Classificacao Alerta
            exit 0
        }
    
    }
    else {
        Write-WingetLog -Mensagem "Winget não encontrado !" -Componente "Verificar Winget" -Classificacao Alerta
        exit 0
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

            Write-WingetLog -Mensagem "Nova versão disponível para o software $WingetName (ID: $WingetID). Versão Atual: $WingetVersion. Versão disponível: $WingetAvailable" -Componente "Verificar Atualizações" -Classificacao Informação
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

    Write-WingetLog -Mensagem "Verificando políticas para softwares permitidos." -Componente "GPO" -Classificacao Alerta

    If ($AppList) {
        foreach ($AppPermitido in $AppList) {
            Write-WingetLog -Mensagem "ID: $AppPermitido" -Componente "Software Permitido" -Classificacao Informação
        }

        return $AppList

    }
    else {
        Write-WingetLog -Mensagem "Nenhuma política encontrada." -Componente "Software Permitido" -Classificacao Alerta
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
        Write-WingetLog -Mensagem "Nível de notificação: $AppList." -Componente "GPO" -Classificacao Informação
    } else {
        Write-WingetLog -Mensagem "Nível de notificação: Todos." -Componente "GPO" -Classificacao Informação
    }

    return $AppList

}

Function Confirm-Update {

    param (
        $AppID,
        $AppVersion
    )

    $JsonFile = "C:\Temp\Software-Autoupdate\InstalledApps.json"

    & Winget export -s winget -o $JsonFile --include-versions | Out-Null
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
    $notify.Icon = [System.Drawing.SystemIcons]::Warning
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

    $WingetStatus = Get-WingetStatus
    $AppsToUpdate = Get-AppUpdateAvailable
    $Permitidos = Get-AppsPermitidos
    $Aviso = Get-Aviso

    if (($null -eq $AppsToUpdate) -or (!$WingetStatus)) {

    }
    else {

        foreach ($AppToUpdate in $AppsToUpdate) {

            $AppName = ($AppToUpdate).Name
            $AppID = ($AppToUpdate).Id
            $AppVersion = ($AppToUpdate).Version
            $AppAvailable = ($AppToUpdate).AvailableVersion

            Write-WingetLog -Mensagem "ID: $AppID" -Componente "Atualizar Software" -Classificacao Informação

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
                Write-WingetLog -Mensagem "Iniciando a atualização do software $AppName da versão $AppVersion para $AppAvailable." -Componente "Atualizar Software" -Classificacao Informação
                & Winget upgrade --id $AppID --accept-package-agreements --accept-source-agreements --silent --force --disable-interactivity

                $StatusInstallation = Confirm-Update -AppID $AppID -AppVersion $AppAvailable

                if ($StatusInstallation) {
                    Write-WingetLog -Mensagem "Software $AppName atualizado para versão $AppAvailable com sucesso." -Componente "Atualizar Software" -Classificacao Informação

                    if($Aviso -ne "Nenhum"){
                        Set-Notificacao -Icone Info -Titulo "$AppName foi atualizado !" -Mensagem "Nova versão: $AppAvailable."
                    }
                    
                }
                else {
                    Write-WingetLog -Mensagem "Falha ao atualizar o Software $AppName para versão $AppAvailable." -Componente "Atualizar Software" -Classificacao Erro

                    if(($Aviso -eq "Todos") -or (!$Aviso)){
                        Set-Notificacao -Icone Error -Titulo "$AppName não foi atualizado !" -Mensagem "Erro ao atualizar para versão $AppAvailable."
                    }
                }
            }
            else {
                Write-WingetLog -Mensagem "Atualização não autorizada: O software não esta incluido na lista de aplicativos permitidos." -Componente "Atualizar Software" -Classificacao Informação

            }
        }
    }
}

Update-Apps