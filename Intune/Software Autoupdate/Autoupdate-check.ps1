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

    $logmessage = "<![LOG[$Mensagem]LOG]!><time=`"$($time)`" date=`"$($Date)`" component=`"$($Componente)`" context=`"$($Context)`" type=`"$($Classificacao)`" thread=`"$($PID)`">";

    Out-File -FilePath $LogDir -Append -InputObject $logmessage -Encoding UTF8;

}

$WingetPath = Get-ChildItem -Path "C:\Program Files\WindowsApps" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe" } | Select-Object -ExpandProperty FullName -First 1

if ($WingetPath) {
    if (Test-Path -Path "$WingetPath\winget.exe") {

        [bool]$WingetStatus = $true
        $Winget = "$WingetPath\winget.exe"
        $WingetVer = & $Winget --version
        Write-WingetLog -Mensagem "Winget Encontrado! Versão: $WingetVer." -Componente "Verificar Winget" -Classificacao Informação

        $upgradeResult = & $Winget upgrade --source winget

        if (!($upgradeResult -match "-----")) {
            Write-WingetLog -Mensagem "Nenhuma atualização disponível." -Componente "Verificar Atualizações" -Classificacao Alerta
            [bool]$WingetUpdate = $false

        }
        else {
            Write-WingetLog -Mensagem "Atualizações encontradas, inciando verificações." -Componente "Verificar Atualizações" -Classificacao Informação
            [bool]$WingetUpdate = $true
        }

    }
    else {
        Write-WingetLog -Mensagem "Winget não Encontrado!" -Componente "Verificar Winget" -Classificacao Alerta
        [bool]$WingetStatus = $false
    }
}
else {
    Write-WingetLog -Mensagem "Winget não Encontrado!" -Componente "Verificar Winget" -Classificacao Alerta
    [bool]$WingetStatus = $false
}

if ($WingetStatus -and $WingetUpdate) {
    Exit 1
}
else {
    Exit 0
}