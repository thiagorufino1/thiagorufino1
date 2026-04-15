# MS SDK M365 Agent + Copilot Studio

Bot para Microsoft Teams em Python que atua como supervisor inteligente: usa **Azure OpenAI** para entender a intenção do usuário e roteia automaticamente para os agentes especializados do **Microsoft Copilot Studio** via Direct Line, possibilitando a integração de agentes de múltiplos ambientes em uma única conversa. Construído com o **Microsoft 365 Agents SDK**.

---

## Visão geral

```
Usuário no Teams
      |
      v
Microsoft Teams (canal)
      |
      v
Azure Bot Service  <---  Autentica via Client Secret (App Registration)
      |
      v
Python Bot (aiohttp)  <---  Microsoft 365 Agents SDK
      |
      v
Azure OpenAI (supervisor + tool calling)
      |
      +---> Copilot Studio: Agente RH  (Direct Line)
      |
      +---> Copilot Studio: Agente TI  (Direct Line)
      |
      +---> (resposta direta para perguntas genéricas)
```

### Como funciona

1. O usuário envia uma mensagem no Teams.
2. O bot exibe `"Pensando..."` enquanto processa.
3. O Azure OpenAI (supervisor) analisa a mensagem e decide o próximo passo:
   - Se o assunto for de RH ou TI → chama a ferramenta correspondente e atualiza o status para `"Consultando Copilot RH..."` ou `"Consultando Copilot TI..."`
   - Se for uma pergunta genérica → responde diretamente, sem consultar nenhum agente
4. Cada ferramenta usa o `CopilotClient` para conversar com o agente do Copilot Studio via Direct Line (por meio de polling).
5. A resposta do agente especialista volta para o supervisor, que organiza a resposta final.
6. A resposta final é enviada ao usuário pelo mecanismo de streaming do SDK.

O registro de agentes é **dinâmico**: adicionar um novo agente não exige nenhuma mudança de código, apenas variáveis de ambiente.

---

## Arquitetura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| [src/app.py](src/app.py) | Servidor HTTP aiohttp, expõe `/api/messages` |
| [src/agent.py](src/agent.py) | Supervisor, loop de tool calling, handlers do Teams SDK |
| [src/config.py](src/config.py) | Leitura e validação das variáveis de ambiente do bot |
| [src/sdk_workarounds.py](src/sdk_workarounds.py) | Correções de compatibilidade para o SDK 0.8.x |
| [src/core/config.py](src/core/config.py) | Registro dinâmico de agentes do Copilot Studio |
| [src/core/copilot_client.py](src/core/copilot_client.py) | Cliente Direct Line com retry e polling |
| [src/core/session_store.py](src/core/session_store.py) | Estado de conversa por agente (`conversation_id`, `watermark`) |
| [src/prompts/chat/skprompt.txt](src/prompts/chat/skprompt.txt) | Prompt do supervisor |
| [src/prompts/chat/config.json](src/prompts/chat/config.json) | Parâmetros de completion (temperatura, max_tokens etc.) |
| [src/requirements.txt](src/requirements.txt) | Dependências Python do projeto |
| [appPackage/manifest.json](appPackage/manifest.json) | Manifesto do aplicativo no Teams |
| [infra/azure.bicep](infra/azure.bicep) | Provisionamento dos recursos Azure via Bicep |
| [m365agents.yml](m365agents.yml) | Fluxo principal de provision/deploy/publish |

---

## Pré-requisitos

### Ferramentas

- Python 3.10 ou superior
- VS Code com a extensão [Microsoft 365 Agents Toolkit](https://aka.ms/teams-toolkit) instalada
- Conta Azure com permissão para criar recursos (App Registration, Bot Service, App Service)
- Tenant Microsoft 365 com permissão para fazer sideload de aplicativos no Teams

### Serviços Azure

- **Azure OpenAI** com um deployment de modelo de chat (ex.: `gpt-4o`, `gpt-4.1`)
- **Azure Bot Service**: criado automaticamente pelo toolkit no passo de Provision

### Copilot Studio

- Um ou mais agentes publicados no Microsoft Copilot Studio
- Canal **Direct Line** habilitado em cada agente

---

## Passo a passo completo

### 1. Instalar a extensão e fazer login

1. Abra o VS Code
2. Acesse a aba **Extensions** (`Ctrl+Shift+X`)
3. Busque por `Microsoft 365 Agents Toolkit` e clique em **Install**
4. Após instalar, clique no ícone do toolkit na barra lateral esquerda (ícone de blocos)
5. Na seção **Accounts**, faça login com:
   - **Microsoft 365 account**: conta do tenant onde o bot será instalado
   - **Azure account**: conta com permissão para criar recursos (App Registration, Bot Service, App Service)

> Esses dois logins são obrigatórios. Sem eles, o toolkit não consegue provisionar recursos nem instalar o aplicativo no Teams.

---

### 2. Criar o recurso Azure OpenAI

1. Acesse o [portal Azure](https://portal.azure.com) e busque por **Azure OpenAI**
2. Clique em **Create** e preencha:
   - **Resource group**: crie um novo ou use um existente
   - **Region**: escolha a região mais próxima (ex.: `East US`, `Brazil South`)
   - **Name**: nome único para o recurso
   - **Pricing tier**: `Standard S0`
3. Clique em **Review + create** → **Create** e aguarde o provisionamento
4. Acesse o recurso criado → **Keys and Endpoint**
5. Copie a **Key 1**: será o valor de `SECRET_AZURE_OPENAI_API_KEY`
6. Copie o **Endpoint**: será o valor de `AZURE_OPENAI_ENDPOINT`
7. No menu lateral, acesse **Model deployments** → **Manage deployments**
8. Clique em **Deploy model** → **Deploy base model**
9. Escolha um modelo de chat (ex.: `gpt-4o`) → clique em **Deploy**
10. Anote o **deployment name**: será o valor de `AZURE_OPENAI_DEPLOYMENT_NAME`

---

### 3. Configurar os agentes no Copilot Studio

Repita os passos abaixo para **cada** agente que o supervisor vai orquestrar:

1. Acesse [copilotstudio.microsoft.com](https://copilotstudio.microsoft.com) e faça login com a conta do tenant
2. Clique em **Create** para criar um novo agente, ou abra um existente
3. Configure os tópicos, instruções e a base de conhecimento do agente
4. Clique em **Publish** (canto superior direito) e confirme a publicação

   > O agente precisa estar publicado para aceitar conexões via Direct Line.

5. Acesse **Settings** → **Channels**
6. Clique em **Direct Line** para abrir as configurações do canal
7. Se o canal ainda não estiver habilitado, clique em **Enable**

   > O Direct Line é o protocolo que permite que aplicações externas conversem com o agente do Copilot Studio. O bot usa o secret desse canal para autenticar as requisições.

8. Na seção **Secret keys**, copie a **Primary key**: será o valor de `SECRET_COPILOT_<ID>_DIRECT_LINE_SECRET`

   > Guarde o secret com segurança. Ele concede acesso direto ao agente sem autenticação adicional do usuário final. Se for comprometido, regenere-o imediatamente nessa mesma tela.

---

### 4. Instalar dependências Python

**Windows (PowerShell):**

```powershell
cd ms-sdk-m365-agent-copilot-studio
python -m venv venv
.\venv\Scripts\activate
pip install -r src/requirements.txt
```

**Linux/macOS:**

```bash
cd ms-sdk-m365-agent-copilot-studio
python3 -m venv venv
source venv/bin/activate
pip install -r src/requirements.txt
```

---

### 5. Configurar variáveis de ambiente

**5.1 Copiar os templates:**

Windows:
```powershell
Copy-Item env\.env.local.example      env\.env.local
Copy-Item env\.env.local.user.example env\.env.local.user
```

Linux/macOS:
```bash
cp env/.env.local.example      env/.env.local
cp env/.env.local.user.example env/.env.local.user
```

**5.2 Editar `env/.env.local`**: variáveis não secretas, commitadas no repositório:

```dotenv
# Identidade do aplicativo no Teams
APP_SHORT_NAME=Assistente Corporativo
APP_FULL_NAME=Assistente Corporativo - Supervisor de Agentes
APP_DESCRIPTION_SHORT=Supervisor inteligente de agentes especializados.
APP_DEVELOPER_NAME=TRC
APP_DEVELOPER_WEBSITE=https://www.linkedin.com/in/thiagorufinocarvalho/
APP_DEVELOPER_PRIVACY_URL=https://www.linkedin.com/in/thiagorufinocarvalho/
APP_DEVELOPER_TERMS_URL=https://www.linkedin.com/in/thiagorufinocarvalho/

# Deixe em branco: o toolkit preenche automaticamente no Provision
BOT_ID=
BOT_OBJECT_ID=
BOT_DOMAIN=
BOT_ENDPOINT=
TEAMS_APP_ID=
TEAMS_APP_TENANT_ID=
CONNECTIONS__SERVICE_CONNECTION__SETTINGS__CLIENTID=
CONNECTIONS__SERVICE_CONNECTION__SETTINGS__AUTHTYPE=
```

**5.3 Editar `env/.env.local.user`**: secrets, **nunca commitado**:

```dotenv
# Azure OpenAI
SECRET_AZURE_OPENAI_API_KEY=sua_chave_aqui
AZURE_OPENAI_ENDPOINT=https://seu-recurso.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o

# Credenciais do bot — o toolkit preenche automaticamente no Provision
# Deixe em branco se for usar o Provision automático
SECRET_BOT_PASSWORD=
CONNECTIONS__SERVICE_CONNECTION__SETTINGS__CLIENTSECRET=

# Agentes do Copilot Studio
COPILOT_AGENTS=RH,TI

COPILOT_RH_NAME=Copilot RH
COPILOT_RH_DEPARTMENT=RH
COPILOT_RH_DESCRIPTION=Use for HR requests such as vacations, payslips, payroll, benefits, hiring or HR policies.
SECRET_COPILOT_RH_DIRECT_LINE_SECRET=seu_secret_direct_line_rh

COPILOT_TI_NAME=Copilot TI
COPILOT_TI_DEPARTMENT=TI
COPILOT_TI_DESCRIPTION=Use for IT requests such as password reset, VPN, software access, devices or printers.
SECRET_COPILOT_TI_DIRECT_LINE_SECRET=seu_secret_direct_line_ti

# Polling Direct Line (opcional, os padrões já funcionam bem)
DIRECT_LINE_TIMEOUT_SEC=45
DIRECT_LINE_POLL_INTERVAL_SEC=2.0
DEBUG_MODE=false
```

> **Como o toolkit gera o `.env`:** durante o Provision e o Deploy, o toolkit lê todos os arquivos `env/*.user` e gera o `.env` na raiz do projeto, removendo o prefixo `SECRET_` dos nomes. Assim, `SECRET_AZURE_OPENAI_API_KEY` vira `AZURE_OPENAI_API_KEY` no `.env`, que é o que o Python lê via `load_dotenv()`. **Nunca edite o `.env` da raiz diretamente**, as mudanças serão sobrescritas.

---

### 6. Executar localmente com F5

**Opção A: Microsoft Teams (recomendado):**

1. Abra o projeto no VS Code
2. Pressione **F5** e selecione `Debug in Teams (Edge)` ou `Debug in Teams (Chrome)`

Na **primeira execução**, o toolkit executa automaticamente:

| Etapa | O que acontece |
|---|---|
| **Provision** | Cria o App Registration no Entra ID, registra o bot no Azure Bot Service e grava `BOT_ID` e `SECRET_BOT_PASSWORD` nos arquivos `env/` |
| **Tunnel** | Cria um túnel público via dev-tunnel na porta 3978 e grava a URL em `BOT_ENDPOINT` |
| **Deploy** | Gera o `.env` na raiz a partir dos arquivos `env/` e inicia `src/app.py` |
| **Teams** | Abre o Teams no navegador com o aplicativo já instalado |

Quando o Teams abrir, clique em **Add** para instalar o aplicativo e envie uma mensagem para testá-lo.

**Opção B: M365 Agents Playground (teste rápido, sem Teams):**

1. Pressione **F5** e selecione `Debug in Microsoft 365 Agents Playground`
2. Uma interface de chat abre no navegador, envie mensagens diretamente

> O Playground não renderiza feedback loop, badge "Gerado por IA" nem sensitivity label. Para validar esses recursos, use o Teams.

---

## Adicionar um novo agente

Nenhuma mudança de código é necessária. Edite apenas `env/.env.local.user`:

```dotenv
# Adicione o novo ID à lista existente
COPILOT_AGENTS=RH,TI,JURIDICO

# Defina as variáveis do novo agente
COPILOT_JURIDICO_NAME=Agente Jurídico
COPILOT_JURIDICO_DEPARTMENT=Jurídico
COPILOT_JURIDICO_DESCRIPTION=Use for legal, compliance and contract requests.
SECRET_COPILOT_JURIDICO_DIRECT_LINE_SECRET=seu_secret_direct_line_juridico
```

Reinicie o bot com F5. O supervisor gera automaticamente a ferramenta para o novo agente e o inclui no roteamento.

**Capacidade recomendada:** até 8–10 agentes funcionam bem com roteamento direto. Acima disso, a qualidade do roteamento pode diminuir e é recomendável organizar os agentes em grupos hierárquicos (um supervisor por área).

---

## Referência completa de variáveis

### Autenticação do bot (gerenciadas pelo toolkit)

O SDK Python usa as variáveis `CONNECTIONS__SERVICE_CONNECTION__SETTINGS__*` para autenticar as requisições recebidas do Teams. O toolkit as preenche automaticamente durante o Provision a partir do App Registration criado.

| Variável | Onde definir | Descrição |
|---|---|---|
| `BOT_ID` | `env/.env.local` (gerado pelo toolkit) | Application (client) ID do App Registration |
| `SECRET_BOT_PASSWORD` | `env/.env.local.user` (gerado pelo toolkit) | Client secret do App Registration |
| `CONNECTIONS__SERVICE_CONNECTION__SETTINGS__CLIENTID` | `env/.env.local` (gerado pelo toolkit) | Mesmo valor do `BOT_ID` |
| `CONNECTIONS__SERVICE_CONNECTION__SETTINGS__CLIENTSECRET` | `env/.env.local.user` (gerado pelo toolkit) | Mesmo valor do `BOT_PASSWORD` |
| `CONNECTIONS__SERVICE_CONNECTION__SETTINGS__TENANTID` | `env/.env.local` (gerado pelo toolkit) | ID do tenant Azure AD |
| `BOT_DOMAIN` | gerado pelo toolkit | Domínio público do túnel |
| `BOT_ENDPOINT` | gerado pelo toolkit | URL pública do endpoint `/api/messages` |
| `TEAMS_APP_ID` | gerado pelo toolkit | ID do aplicativo no Teams |

### Azure OpenAI

| Variável | Obrigatória | Padrão | Descrição |
|---|---|---|---|
| `SECRET_AZURE_OPENAI_API_KEY` | Sim | | Chave de acesso ao recurso Azure OpenAI |
| `AZURE_OPENAI_ENDPOINT` | Sim | | Endpoint do recurso (`https://....openai.azure.com/`) |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | Sim | | Nome do deployment do modelo |
| `AZURE_OPENAI_API_VERSION` | Não | `2024-12-01-preview` | Versão da API Azure OpenAI |

### Agentes do Copilot Studio

| Variável | Obrigatória | Descrição |
|---|---|---|
| `COPILOT_AGENTS` | Sim | Lista de IDs separados por vírgula: `RH,TI,JURIDICO` |
| `SECRET_COPILOT_<ID>_DIRECT_LINE_SECRET` | Sim por agente | Secret do canal Direct Line; prefixo `SECRET_` é removido pelo toolkit ao gerar o `.env` |
| `COPILOT_<ID>_NAME` | Não | Nome exibido nas atualizações de status do Teams |
| `COPILOT_<ID>_DEPARTMENT` | Não | Rótulo do departamento |
| `COPILOT_<ID>_DESCRIPTION` | Não | Descrição usada pelo supervisor para decidir o roteamento |
| `POWER_PLATFORM_ENV_<ID>` | Não | ID do ambiente do Power Platform (apenas informativo) |

### Comportamento do bot

| Variável | Padrão | Descrição |
|---|---|---|
| `M365_AGENT_FEEDBACK_LOOP` | `true` | Habilita botões de like/dislike na resposta |
| `M365_AGENT_AI_LABEL` | `true` | Exibe o badge "Gerado por IA" no Teams |
| `M365_AGENT_SENSITIVITY_NAME` | `Internal` | Nome do rótulo de sensibilidade |
| `M365_AGENT_MAX_HISTORY_TURNS` | `20` | Número de turnos de histórico mantidos por conversa |

### Polling Direct Line

| Variável | Padrão | Descrição |
|---|---|---|
| `DIRECT_LINE_TIMEOUT_SEC` | `45` | Tempo máximo aguardando resposta do agente (segundos) |
| `DIRECT_LINE_POLL_INTERVAL_SEC` | `2.0` | Intervalo entre consultas ao Direct Line (segundos) |
| `DEBUG_MODE` | `false` | Ativa logs detalhados no console |

---

## Arquivos de ambiente

| Arquivo | Commitado | Conteúdo |
|---|---|---|
| `env/.env.local.example` | sim | Modelo não secreto para `env/.env.local` |
| `env/.env.local.user.example` | sim | Modelo com secrets para `env/.env.local.user` |
| `env/.env.local` | **não** | Branding do aplicativo e IDs gerados pelo toolkit |
| `env/.env.local.user` | **não** | Secrets: chaves do Azure OpenAI, Direct Line e senha do bot |
| `env/.env.dev` | sim | Variáveis para deploy no Azure (subscription, resource group) |
| `.env` (raiz) | **não** | Gerado automaticamente pelo toolkit, não edite manualmente |

---

## Recursos do Teams SDK

### Atualizações de status dinâmicas

O usuário vê o andamento enquanto o supervisor processa a mensagem:

- `"Pensando..."`: exibido imediatamente para toda mensagem recebida
- `"Consultando Copilot RH..."`: exibido quando o supervisor roteia para o agente de RH
- `"Consultando Copilot TI..."`: exibido quando o supervisor roteia para o agente de TI

Para perguntas genéricas (sem domínio especializado), apenas `"Pensando..."` é exibido e a resposta vem diretamente do modelo.

### Memória de conversa

O histórico de mensagens é armazenado em `ConversationState` (MemoryStorage) e persistido automaticamente pelo SDK por conversa. A cada turno, o histórico completo é enviado ao supervisor como contexto, limitado pela variável `M365_AGENT_MAX_HISTORY_TURNS`.

O estado individual de cada conversa com os agentes do Copilot Studio (`conversation_id`, `watermark`) também é persistido, o que permite que o Direct Line mantenha o contexto entre turnos.

> O `MemoryStorage` padrão persiste apenas enquanto o processo está em execução. Para persistência entre reinicializações em produção, substitua por Azure Cosmos DB.

### Correções de compatibilidade do SDK (`sdk_workarounds.py`)

Três correções aplicadas automaticamente na inicialização para o SDK 0.8.x:

- **AI metadata**: garante que o badge "Gerado por IA" seja emitido mesmo sem citações
- **Feedback loop**: injeta `feedbackLoop` em `channel_data`, onde o Teams espera encontrá-lo
- **Cache JWKS**: evita uma requisição HTTPS por turno na validação do JWT, prevenindo timeouts em redes lentas

---

## Provisionamento Azure

O comando **Provision** do toolkit cria automaticamente:

| Recurso | Descrição |
|---|---|
| App Registration (Entra ID) | Identidade do bot: gera `BOT_ID` e `SECRET_BOT_PASSWORD` |
| App Service Plan (Linux, B1) | Plano de hospedagem do bot |
| Web App (Python 3.11) | Instância do bot em execução |
| User Assigned Managed Identity | Identidade para autenticação sem senha |
| Azure Bot Service | Registro do bot vinculado ao Teams |

As variáveis de saída (`BOT_ID`, `BOT_DOMAIN`, `TEAMS_APP_ID` etc.) são gravadas automaticamente nos arquivos `env/` e ficam disponíveis em execuções subsequentes.

---

## Estrutura do repositório

```
.
├── appPackage/
│   ├── manifest.json
│   ├── color.png
│   └── outline.png
├── env/
│   ├── .env.local.example
│   ├── .env.local.user.example
│   └── .env.dev
├── infra/
│   ├── azure.bicep
│   ├── azure.parameters.json
│   └── botRegistration/
│       └── azurebot.bicep
├── src/
│   ├── app.py
│   ├── agent.py
│   ├── config.py
│   ├── sdk_workarounds.py
│   ├── requirements.txt
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py
│   │   ├── copilot_client.py
│   │   └── session_store.py
│   └── prompts/
│       └── chat/
│           ├── skprompt.txt
│           └── config.json
├── m365agents.yml
├── m365agents.local.yml
├── m365agents.playground.yml
└── README.md
```

---

## Segurança

- Nunca comite chaves, tokens ou senhas reais no repositório
- Mantenha os secrets nos arquivos `env/*.user` (já ignorados pelo `.gitignore`)
- Se um secret foi commitado por engano, **rotacione-o imediatamente** no portal Azure ou no Copilot Studio
- Em produção, prefira Managed Identity no lugar de API keys para autenticar com o Azure OpenAI
- Os secrets do Direct Line concedem acesso direto aos agentes do Copilot Studio, trate-os como credenciais de produção

---

## Referências

- [Microsoft 365 Agents SDK for Python](https://github.com/microsoft/agents-for-python)
- [Microsoft 365 Agents Toolkit](https://aka.ms/teams-toolkit)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-services/openai/)
- [Bot Framework Direct Line API](https://learn.microsoft.com/azure/bot-service/rest-api/bot-framework-rest-direct-line-3-0-concepts)
- [Copilot Studio: Segurança do canal Direct Line](https://learn.microsoft.com/microsoft-copilot-studio/configure-web-security)
- [Microsoft Copilot Studio](https://learn.microsoft.com/microsoft-copilot-studio/)
