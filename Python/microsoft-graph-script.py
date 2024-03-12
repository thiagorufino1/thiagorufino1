import requests

# Defina suas credenciais e outros parâmetros necessários
client_id = '27f044fd-dffc-4c75-a5d9-bca69affff22'
client_secret = 'jdk8Q~81LeJ9ieXDKWzBptocCaR3H5Btvcbq2dA7'
tenant_id = '144ac447-f91a-4a05-96f3-caa37e9d992f'
device_id = '32083bd6-801f-4865-b67a-cfc96030bfa7'

# Obtenha um token de acesso válido
token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
token_data = {
    'grant_type': 'client_credentials',
    'client_id': client_id,
    'client_secret': client_secret,
    'scope': 'https://graph.microsoft.com/.default'
}
token_response = requests.post(token_url, data=token_data)
token = token_response.json().get('access_token')

# Consulta do nome do dispositivo usando o Graph API
graph_api_url = f"https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/{device_id}"
headers = {
    'Authorization': 'Bearer ' + token,
    'Content-Type': 'application/json'
}

# Fazendo a solicitação GET para obter informações do dispositivo
response = requests.get(graph_api_url, headers=headers)

# Verificar se a solicitação foi bem-sucedida
if response.status_code == 200:

    device_info = response.json()
    device_name = device_info.get('deviceName')
    device_deviceRegistrationState = device_info.get('deviceRegistrationState')
    device_userPrincipalName = device_info.get('userPrincipalName')
    device_complianceState = device_info.get('complianceState')

    print(f"Nome do dispositivo: {device_name}")
    print(f"Nome do dispositivo: {device_userPrincipalName}")
    print(f"Nome do dispositivo: {device_complianceState}")
    print(f"Nome do dispositivo: {device_deviceRegistrationState}")

else:
    print(f"Falha ao consultar o dispositivo. Código de status: {response.status_code}")