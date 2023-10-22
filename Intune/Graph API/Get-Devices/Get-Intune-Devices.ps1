<#
    .DESCRIPTION
        Listar equipamentos registrados no Intune

    .NOTES
        Criado por: Thiago Rufino
        thiagorufino.com

        Data: 19/10/2023
        Version: 1.0
#>

# Define as informações de autenticação do aplicativo no Azure AD
$clientId = ""
$clientSecret = ""
$tenantId = ""

$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"

$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    resource      = "https://graph.microsoft.com"
}

$tokenResponse = Invoke-RestMethod -Method Post -Uri $authUrl -Body $body
$accessToken = $tokenResponse.access_token

$apiUrl = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices"

$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/json"
}

# Obtém informações do usuário correspondente
$Devices = Invoke-RestMethod -Method Get -Uri $apiUrl -Headers $headers

# Gera o nome do arquivo CSV com base na data e hora atual
$dateTime = Get-Date -Format "dd-MM-yyyy-HH-mm-ss"
$csvFileName = "intune-devices-$dateTime.csv"

# Caminho do arquivo CSV de destino
$csvFilePath = "C:\Temp\$csvFileName"

# Função para converter bytes para gigabytes
function Convert-ToGB {
    param (
        [long]$Bytes
    )
    return "$([math]::Round($Bytes / 1GB, 2)) GB"
}

# Cor do Cabeçalho (Windows Powershell 7.2+)
$psstyle.Formatting.TableHeader = "`e[36;1m"
$psstyle.Formatting.FormatAccent = "`e[36;1m"


# Cria um array para armazenar os objetos
$csvData = @()

# Retorna as informações dos dispositivos no formato desejado e adiciona ao array
$devices.value | ForEach-Object {
    $deviceInfo = [PSCustomObject]@{
        DeviceName           = $_.deviceName
        ComplianceState      = $_.complianceState
        UserDisplayName      = $_.userDisplayName
        UserPrincipalName    = $_.userPrincipalName
        Manufacturer         = $_.manufacturer
        Model                = $_.model
        SerialNumber         = $_.serialNumber
        EnrolledDateTime     = (Get-Date $_.enrolledDateTime).ToString("dd/MM/yyyy hh:mm:ss")
        LastSyncDateTime     = (Get-Date $_.lastSyncDateTime).ToString("dd/MM/yyyy hh:mm:ss")
        OperatingSystem      = $_.operatingSystem
        OSVersion            = $_.osVersion
        DeviceEnrollmentType = $_.deviceEnrollmentType
        IsEncrypted          = $_.isEncrypted
        DiskSpaceTotal       = Convert-ToGB -Bytes $_.totalStorageSpaceInBytes
        DiskSpaceFree        = Convert-ToGB -Bytes $_.freeStorageSpaceInBytes
        Id                   = $_.id
        AzureADDeviceId      = $_.azureADDeviceId
    }

    $csvData += $deviceInfo
}

# Exporta o array para um arquivo CSV
$csvData | Export-Csv -Path $csvFilePath -NoTypeInformation

# Mostra as informações dos dispositivos
$csvData #| Format-Table -Property *