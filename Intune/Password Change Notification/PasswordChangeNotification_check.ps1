# Define as informações de autenticação do aplicativo no Azure AD
$clientId = ""
$clientSecret = ""
$tenantId = ""

# Configurações de política de senha
[int]$PasswordExpirationDays = 90
[int]$DaysRemainingAlert = 10

# URL de autenticação do Azure AD
$authUrl = "https://login.microsoftonline.com/$tenantId/oauth2/token"

# Parâmetros para obter um token de acesso
$body = @{
    grant_type    = "client_credentials"
    client_id     = $clientId
    client_secret = $clientSecret
    resource      = "https://graph.microsoft.com"
}

# Obtém o token de acesso
$tokenResponse = Invoke-RestMethod -Method Post -Uri $authUrl -Body $body
$accessToken = $tokenResponse.access_token

# Prefixo do nome de usuário local para procurar
$LocalUser = $env:USERNAME + '@'
#$LocalUser = 'thiago@'

# Constrói a URL da API do Microsoft Graph para listar usuários
$apiUrl = "https://graph.microsoft.com/v1.0/users?`$select=id,displayName,userPrincipalName,lastPasswordChangeDateTime&`$filter=startsWith(userPrincipalName,'$($LocalUser)')"

# Cabeçalhos da solicitação com o token de acesso
$headers = @{
    "Authorization" = "Bearer $accessToken"
    "Content-Type"  = "application/json"
}

# Obtém informações do usuário correspondente
$User = Invoke-RestMethod -Method Get -Uri $apiUrl -Headers $headers

# Extrai a data da última alteração de senha e a converte em um formato utilizável
$LastPasswordChangeDate = $User.value.lastPasswordChangeDateTime
$ConvertData = [System.DateTimeOffset]::ParseExact($LastPasswordChangeDate, "yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)

# Calcula a data da próxima alteração de senha
$NextPasswordChangeDate = $ConvertData.AddDays($PasswordExpirationDays)
$CurrentDate = Get-Date

# Calcula o número de dias restantes até a próxima alteração de senha
[int]$DaysRemaining = ($NextPasswordChangeDate - $CurrentDate).Days

# Verifica se a senha está prestes a expirar
if ($DaysRemaining -le $DaysRemainingAlert) { 
    
    Exit 1
}
else {
    
    Exit 0
}