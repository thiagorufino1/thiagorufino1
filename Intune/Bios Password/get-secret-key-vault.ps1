# Definindo as variáveis necessárias
$clientId = "84918e1b-058d-4f25-a32b-a17beb8dc914"
$clientSecret = "pV18Q~gnQNDrYomVOZ6d1wzNPMJFzV~1DN2RLc1."
$tenantId = "783f9353-3381-4168-b6bc-a439b25dfc6a"
$keyVaultName = "bios-password"
$secretName = "BIOS"

# Obtenha o token de autenticação
$tokenEndpoint = "https://login.microsoftonline.com/$tenantId/oauth2/token"
$body = @{
    "grant_type"    = "client_credentials"
    "client_id"     = $clientId
    "client_secret" = $clientSecret
    "resource"      = "https://vault.azure.net"
}
$tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $body

# Use o token para obter o valor da secret
$secretUri = "https://$keyVaultName.vault.azure.net/secrets/$secretName/?api-version=7.0"
$headers = @{
    "Authorization" = "$($tokenResponse.token_type) $($tokenResponse.access_token)"
}
$secretResponse = Invoke-RestMethod -Uri $secretUri -Headers $headers -Method Get

# Exibir o valor da secret
Write-Host "Valor da secret '$secretName': $($secretResponse.value)" -ForegroundColor Green