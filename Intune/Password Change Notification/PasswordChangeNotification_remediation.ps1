<#
    .DESCRIPTION
        Notificações automáticas para lembretes de expiração de senha.

    .NOTES
        Criado por: Thiago Rufino
        thiagorufino.com

        Data: 23/09/2023
        Version: 1.0
#>

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
$DisplayName = $User.value.displayName
$ConvertData = [System.DateTimeOffset]::ParseExact($LastPasswordChangeDate, "yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture)

# Calcula a data da próxima alteração de senha
$NextPasswordChangeDate = $ConvertData.AddDays($PasswordExpirationDays)
$CurrentDate = Get-Date

# Calcula o número de dias restantes até a próxima alteração de senha
[int]$DaysRemaining = ($NextPasswordChangeDate - $CurrentDate).Days

# Configuração de imagens e notificação
$HeroImageFile = "http://thiagorufino.com/wp-content/uploads/2023/09/HeroImage.png"
$LogoImageFile = "http://thiagorufino.com/wp-content/uploads/2023/09/logo_tr.png"
$HeroImageName = "HeroImage.png"
$LogoImageName = "logo.png"
$Action = "https://passwordreset.microsoftonline.com/"

# Função para exibir a notificação
function Display-ToastNotification() {
    
    # Carrega namespaces necessários para notificação
    $Load = [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
    $Load = [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
 
    # Carrega a notificação no formato necessário
    $ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    $ToastXml.LoadXml($Toast.OuterXml)
		
    # Exibir a notificação
    try {
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($App).Show($ToastXml)
    }
    catch { 

    }

    # Reproduzir áudio personalizado, se configurado
    if ($CustomAudio -eq "True") {
        Invoke-Command -ScriptBlock {
            Add-Type -AssemblyName System.Speech
            $speak = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $speak.Speak($CustomAudioTextToSpeech)
            $speak.Dispose()
        }    
    }
}


$TitleText = "Aviso de Expiração de Senha"
$BodyText1 = "Sua senha irá expirar em $DaysRemaining dias."
$BodyText2 = "Para manter a segurança da sua conta e garantir o acesso contínuo aos nossos serviços, recomendamos que você altere sua senha o mais rápido possível."
$BodyText3 = ""
$HeaderText = "Olá $DisplayName."

# Download e armazenamento de imagens temporárias
$HeroImagePath = Join-Path -Path $Env:Temp -ChildPath $HeroImageName
If (!(Test-Path $HeroImagePath)) { 
    Start-BitsTransfer -Source $HeroImageFile -Destination $HeroImagePath
}	

$LogoImagePath = Join-Path -Path $Env:Temp -ChildPath $LogoImageName
If (!(Test-Path $LogoImagePath)) { 
    Start-BitsTransfer -Source $LogoImageFile -Destination $LogoImagePath 
}
 
$PSAppStatus = "True"

# Configuração de notificações para o aplicativo
if ($PSAppStatus -eq "True") {
    $RegPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings"
    $App = "Windows.Defender.SecurityCenter"
		
    if (-NOT(Test-Path -Path "$RegPath\$App")) {
        New-Item -Path "$RegPath\$App" -Force
        New-ItemProperty -Path "$RegPath\$App" -Name "ShowInActionCenter" -Value 1 -PropertyType "DWORD"
    }
		
    if ((Get-ItemProperty -Path "$RegPath\$App" -Name "ShowInActionCenter" -ErrorAction SilentlyContinue).ShowInActionCenter -ne "1") {
        New-ItemProperty -Path "$RegPath\$App" -Name "ShowInActionCenter" -Value 1 -PropertyType "DWORD" -Force
    }
}

# Configuração de chaves do registro para notificações
$EnabledKey = get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\"
$EnabledKey = $EnabledKey.Enabled
if ($EnabledKey -eq "0") {

    write-host "Warning: $($App) notifications have been silenced! Re-enabling!"
    new-itemproperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\" -name "Enabled" -value 1 -ErrorAction SilentlyContinue
    set-itemproperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\" -name "Enabled" -value 1 -ErrorAction SilentlyContinue

}

$UrgentKey = get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\"
$UrgentKey = $UrgentKey.AllowUrgentNotifications
if ($UrgentKey -ne "1") {
    write-host "Warning: $($App) notifications were not allowed to send during DND, changing!"
    new-itemproperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\" -name "AllowUrgentNotifications" -value 1 -ErrorAction SilentlyContinue
    set-itemproperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\" -name "AllowUrgentNotifications" -value 1 -ErrorAction SilentlyContinue
}

$LockKey = get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\"
$LockKey = $LockKey.AllowContentAboveLock
if ($LockKey -ne "0") {
    write-host "Warning: $($App) notifications were allowed on the lock screen, changing!"
    new-itemproperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\" -name "AllowContentAboveLock" -value 0 -ErrorAction SilentlyContinue
    set-itemproperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\" -name "AllowContentAboveLock" -value 0 -ErrorAction SilentlyContinue
}

$RankKey = get-ItemProperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\"
$RankKey = $RankKey.Rank
if ($RankKey -ne "99") {
    write-host "Warning: $($App) notifications were not set to priority, changing!"
    new-itemproperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\" -name "Rank" -value 99 -ErrorAction SilentlyContinue
    set-itemproperty -path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings\$($App)\" -name "Rank" -value 99 -ErrorAction SilentlyContinue
}

# Configuração de conteúdo da notificação
$ActionButtonContent = "Alterar Agora"
$DismissButtonContent = "Lembrar mais tarde"

# Configuração de áudio personalizado (opcional)
$CustomAudio = "false"
$CustomAudioTextToSpeech = $Xml.Configuration.Option | Where-Object { $_.Name -like 'CustomAudio' } | Select-Object -ExpandProperty 'TextToSpeech'

# Configuração do cenário da notificação
$Scenario = "Reminder"

# Criação da notificação com texto, imagens e ações
[xml]$Toast = @"
	<toast scenario="$Scenario">
	<visual>
	<binding template="ToastGeneric">
		<image placement="hero" src="$HeroImagePath"/>
		<image id="1" placement="appLogoOverride" hint-crop="circle" src="$LogoImagePath"/>
		<text>$HeaderText</text>
		<group>
			<subgroup>
				<text hint-style="subtitle" hint-wrap="false" >$TitleText</text>
			</subgroup>
		</group>
		<group>
			<subgroup>     
				<text hint-style="body" hint-wrap="true" >$BodyText1</text>
			</subgroup>
		</group>
		<group>
			<subgroup>     
				<text hint-style="body" hint-wrap="true" >$BodyText2</text>
			</subgroup>
		</group>
        <group>
        <subgroup>     
            <text hint-style="body" hint-wrap="true" >$BodyText3</text>
        </subgroup>
    </group>
	</binding>
	</visual>
	<actions>
		<action activationType="protocol" arguments="$Action" content="$ActionButtonContent" />
		<action activationType="system" arguments="dismiss" content="$DismissButtonContent"/>
	</actions>
	</toast>
"@

#Chama a função para exibir a notificação
Display-ToastNotification