# Parâmetros de Autenticação
$tenantId = "144ac447-f91a-4a05-96f3-caa37e9d992f"
$appId = "26ef7a1e-1de9-4ae7-949a-dc59167f68c3"
$appSecret = "MhJ8Q~Ie8-8NYG6xhDjfdlaXZpLlxjvkOOo2acb5"

# Obter Token de Acesso
$body = @{
    Grant_Type    = "client_credentials"
    Scope         = "https://graph.microsoft.com/.default"
    Client_Id     = $appId
    Client_Secret = $appSecret
}
$tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Method POST -Body $body

# Definir o cabeçalho de autenticação
$token = $tokenResponse.access_token
$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

# Definir o ID do novo usuário principal
$newUserId = "9fb58225-2708-44ce-a9c0-89a0cfd15f51"

# Nome do computador
$computerName = "W10-02"

# Obter o ID do dispositivo gerenciado
try {
    $deviceQuery = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?\$filter=deviceName eq '$computerName'"
    $devices = Invoke-RestMethod -Uri $deviceQuery -Method GET -Headers $headers

    if ($devices.value.Count -eq 0) {
        Write-Host "Nenhum dispositivo encontrado com o nome '$computerName'."
        exit
    }

    $deviceId = $devices.value[0].id
    Write-Host "ID do dispositivo: $deviceId"

    $userQuery = "https://graph.microsoft.com/v1.0/users/$newUserId"
    $user = Invoke-RestMethod -Uri $userQuery -Method GET -Headers $headers

    if ($user -eq $null) {
        Write-Host "Usuário com o ID '$newUserId' não encontrado."
        exit
    }

    Write-Host "Nome do usuário: $($user.displayName)"
    Write-Host "ID do usuário: $($user.id)"

    $body = @{
        assignedUser = @{
            '@odata.id' = $userQuery
        }
    } | ConvertTo-Json

    Write-Host "Corpo da solicitação PATCH:"
    Write-Host $body

    $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$deviceId" -Method PATCH -Headers $headers -Body $body
    Write-Host "Resposta do servidor:"
    Write-Host $response
} catch {
    Write-Host "Erro ao enviar solicitação PATCH: $($_.Exception.Message)"
}

try {
    $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$deviceId" -Method PATCH -Headers $headers -Body $body
    Write-Host "Resposta do servidor:"
    Write-Host $response
} catch {
    Write-Host "Erro ao enviar solicitação PATCH: $($_.Exception.Message)"
    exit
}
