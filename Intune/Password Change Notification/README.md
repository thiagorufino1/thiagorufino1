# Notificações automáticas para lembretes de expiração de senha.

Em um mundo cada vez mais digital, a segurança das informações é uma prioridade essencial para qualquer organização. Uma parte crítica dessa segurança está relacionada à gestão de senhas. Senhas fortes e atualizadas regularmente são um dos principais pilares da proteção dos dados.

No entanto, administrar efetivamente a política de alteração de senhas pode ser um desafio. Como garantir que os usuários estejam cientes da necessidade de alterar suas senhas antes que expirem ? A resposta pode estar na automação e nas notificações.
<br><br>


# Benefícios de Notificações de Senha Prestes a Expirar
A implementação de notificações Toast para senhas prestes a expirar traz vários benefícios:

* **Consciência do Usuário:** Os usuários estarão cientes da necessidade de alterar suas senhas com antecedência, reduzindo o risco de bloqueios de contas devido a senhas expiradas.

* **Melhor Gestão de Segurança:** Isso ajuda a reforçar a política de segurança de senhas e incentiva a conformidade dos usuários.

* **Redução de Sobrecarga de Suporte:** Com notificações automatizadas, os usuários podem tomar a iniciativa de alterar suas senhas de maneira simplificada, resultando em uma redução significativa no número de solicitações à equipe de suporte. Isso promove a autonomia dos usuários e otimiza a eficiência da equipe de suporte.

Em resumo, as notificações para senhas prestes a expirar são uma abordagem inteligente para melhorar a segurança de senhas em sua organização. Com a automação adequada e a comunicação eficaz, você pode manter seus dados protegidos e seus usuários informados. Lembre-se sempre de adaptar essa estratégia às necessidades específicas de sua organização e de manter as políticas de segurança de senhas atualizadas.
<br><br>

# Pre-requisitos

* App Registration<br>
    - Criar App
        - Abrir **portal.azure.com**
        - Navegue ate **App Registrations**
        - Selecione **New registration**
        - Adicione o nome para o App e marque a opção **"Accounts in this organizational directory only"**
        - Clique em **Register**
<br><br>
    - Permissões da API <br>
    Agora vamos atribuir as permissões necessarias para que o aplicativo

<p align="center">
    <img src="Intune/Password Change Notification/img/api-permissions.png" height="250">
</p>

<br><br>

    - Certificados e Segredos
    Nessa etapa vamos criar a senha que iremos utilizar para autenticação.

    "img"

* Imagens


<br>
<br>

# Configuração