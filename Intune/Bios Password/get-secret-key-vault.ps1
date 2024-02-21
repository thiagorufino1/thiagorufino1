<#
    .DESCRIPTION
        O Script tem como objetivo implementar ou atualizar a senha da BIOS utilizando Intune e Azure Key Vault

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
$keyVaultName = "kv-bios-pwd"
$NewSecretName = "FEV-2024"

function Set-Directory {
    $Directory = "C:\Temp\Bios-Password"

    if (!(Test-Path $Directory)) {
        New-Item -Path $Directory -ItemType Directory -Force
    }

    Return $Directory
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
    $LogDir = "$Dir\bios-password.log"

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

function Get-OldPwd {

    $tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/token"

    $body = @{
        "grant_type"    = "client_credentials"
        "client_id"     = $clientId
        "client_secret" = $clientSecret
        "resource"      = "https://vault.azure.net"
    }

    $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body
    $secretsUri = "https://$keyVaultName.vault.azure.net/secrets/?api-version=7.0"
    $headers = @{ "Authorization" = "$($tokenResponse.token_type) $($tokenResponse.access_token)" }

    $secretsResponse = Invoke-RestMethod -Uri $secretsUri -Headers $headers -Method Get

    $secrets = @()

    foreach ($secret in $secretsResponse.value) {

        $secretName = ($secret.id -split '/')[-1]
        $secretValueUri = "https://$keyVaultName.vault.azure.net/secrets/$secretName/?api-version=7.0"
        $secretValueResponse = Invoke-RestMethod -Uri $secretValueUri -Headers $headers -Method Get

        if ($secretName -ne $NewSecretName) {

            $secretObject = [PSCustomObject]@{
                Name  = $secretName
                Value = $secretValueResponse.value
            }

            $secrets += $secretObject
        }
    }

    Return $secrets
}

function Get-isPwdSet {
    $IsAdminPasswordSet = Get-Item -Path DellSmbios:\Security\IsAdminPasswordSet
    Return $IsAdminPasswordSet.CurrentValue
}

function Update-Pwd {

    $OldPwd = Get-OldPwd
    $NewPwd = Get-NewPwd

    foreach ($item in $OldPwd) {

        try {
            Set-Item -Path DellSmbios:\Security\AdminPassword "$NewPwd" -Password "$($item.Value)" -ErrorAction Stop
            Write-Log -Mensagem "Senha $NewSecretName definida com sucesso, senha $($item.Name) utilizada como antiga." -Componente "Atualizar Senha" -Classificacao Informação

            return $true
        }
        catch {
            Write-Log -Mensagem "A Secret $($item.Name) não foi aceita como senha antiga." -Componente "Atualizar Senha" -Classificacao Informação
        }
        
    }

    return $false
}

function Set-Pwd {

    $NewPwd = Get-NewPwd

    try {
        Set-Item -Path DellSmbios:\Security\AdminPassword "$NewPwd" -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host "Erro ao definir a senha. Tentando próximo item..."
    }
    
}

$IsPwdSet = Get-isPwdSet

if ($IsPwdSet -eq "True") {
    Write-Log -Mensagem "BIOS já possui senha definida, iniciando a atualização." -Componente "Atualizar Senha" -Classificacao Informação

    $UpdateStatus = Update-Pwd

    if ($UpdateStatus -eq $true) {
        Write-Log -Mensagem "Atualização bem sucedida." -Componente "Atualizar Senha" -Classificacao Informação
    }
    else {
        Write-Log -Mensagem "Falha ao atualizar a senha da BIOS, nenhuma das senhas antigas cadastradas no Key Vault é compativel com a senha definida neste computador." -Componente "Atualizar Senha" -Classificacao Informação
    }

}
elseif ($IsPwdSet -eq "False") {
    Write-Log -Mensagem "BIOS não possui senha definida, iniciando a definicão da senha da BIOS." -Componente "Definir Senha" -Classificacao Informação
    
    $SetStatus = Set-Pwd
    if ($SetStatus -eq $true) {
        Write-Log -Mensagem "Senha definida com sucesso." -Componente "Definir Senha" -Classificacao Informação
    }
    else {
        Write-Log -Mensagem "Falha ao definir senha." -Componente "Definir Senha" -Classificacao Informação
    }

}
else {
    Write-Log -Mensagem "Erro ao iniciar a definição de senha." -Componente "Erro Senha" -Classificacao Informação
}