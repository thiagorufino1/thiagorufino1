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
    $WingetPackage = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller"
    $WingetPatch = Test-Path $WingetPackage.InstallLocation

    if ($WingetPatch) {
        $Winget = Join-Path -Path $WingetPackage.InstallLocation -ChildPath "Winget.exe"

        & $Winget list --accept-source-agreements --source winget | Out-Null
        $WingetVer = & $Winget --version

        Write-WingetLog -Mensagem "Winget Encontrado! Versão: $WingetVer" -Componente "Verificar Winget" -Classificacao Informação

        $upgradeResult = & $Winget upgrade --source winget | Out-String

        if (!($upgradeResult -match "-----")) {
            Write-WingetLog -Mensagem "Nenhuma atualização disponível." -Componente "Verificar Atualizações" -Classificacao Alerta
            Exit 0
        }
        else {
            Exit 1
        }

    }
    else {
        Write-WingetLog -Mensagem "Winget não encontrado !" -Componente "Verificar Winget" -Classificacao Alerta

        Write-WingetLog -Mensagem "Iniciando o download do Winget e componentes." -Componente "Verificar Winget" -Classificacao Alerta
        $progressPreference = 'silentlyContinue'
        Invoke-WebRequest -Uri "https://aka.ms/getwinget" -OutFile "C:\Temp\Software-Autoupdate\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        Invoke-WebRequest -Uri "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -OutFile "C:\Temp\Software-Autoupdate\Microsoft.VCLibs.x64.14.00.Desktop.appx"
        Invoke-WebRequest -Uri "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx" -OutFile "C:\Temp\Software-Autoupdate\Microsoft.UI.Xaml.2.7.x64.appx"

        Write-WingetLog -Mensagem "Iniciando a instalação Winget e componentes." -Componente "Verificar Winget" -Classificacao Alerta
        Add-AppxPackage "C:\Temp\Software-Autoupdate\Microsoft.VCLibs.x64.14.00.Desktop.appx" -ErrorAction SilentlyContinue
        Add-AppxPackage "C:\Temp\Software-Autoupdate\Microsoft.UI.Xaml.2.7.x64.appx" -ErrorAction SilentlyContinue
        Add-AppxPackage "C:\Temp\Software-Autoupdate\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" -ErrorAction SilentlyContinue

        Start-Sleep 30

        $WingetPackage = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller"

        if ($WingetPackage) {
            Write-WingetLog -Mensagem "Winget instalado com sucesso." -Componente "Verificar Winget" -Classificacao Alerta
            
            if (!($upgradeResult -match "-----")) {
                Write-WingetLog -Mensagem "Nenhuma atualização disponível." -Componente "Verificar Atualizações" -Classificacao Alerta
                Exit 0
            }
            else {
                Exit 1
            }

        }
        else {
            Write-WingetLog -Mensagem "Falha ao instalar Winget." -Componente "Verificar Winget" -Classificacao Alerta
            Exit 0
        }
    }
}

Get-WingetStatus