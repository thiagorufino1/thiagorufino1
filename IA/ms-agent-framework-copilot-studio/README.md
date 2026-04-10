# MS Agent Framework + Copilot Studio

Orquestrador serverless em Python que usa o **Microsoft Agent Framework** como supervisor e roteia conversas para agentes especializados do **Microsoft Copilot Studio** via Direct Line, mantendo contexto de sessão contínuo no terminal.

## Arquitetura

```
app.py  (CLI interativo)
  └── AgentRouter  (supervisor – agent-framework + Azure OpenAI)
        ├── ask_rh_agent → CopilotClient → Direct Line → Agente RH (Power Platform)
        └── ask_it_agent → CopilotClient → Direct Line → Agente TI (Power Platform)
```

| Arquivo | Responsabilidade |
|---|---|
| `app.py` | Loop de chat interativo com Rich (UI, streaming de status) |
| `core/router.py` | Supervisor que decide qual agente chamar |
| `core/copilot_tools.py` | Tools registradas no supervisor (`ask_rh_agent`, `ask_it_agent`) |
| `core/copilot_client.py` | Cliente Direct Line (conversationId + watermark persistidos por sessão) |
| `core/session_store.py` | Store em memória de sessões do orquestrador |
| `core/config.py` | Leitura e validação de variáveis de ambiente |

---

## Pré-requisitos

- Python 3.11+
- Acesso ao **Azure OpenAI** (recurso + deployment GPT-4o ou superior)
- Dois agentes publicados no **Microsoft Copilot Studio** com canal Direct Line ativado

---

## 1. Azure OpenAI – Criar recurso e deployment

### 1.1 Criar o recurso Azure OpenAI

1. Acesse o [Azure Portal](https://portal.azure.com) e clique em **Create a resource**.
2. Pesquise por **Azure OpenAI** e clique em **Create**.
3. Preencha:
   - **Subscription**: sua assinatura
   - **Resource group**: crie um novo ou use existente
   - **Region**: selecione uma região com disponibilidade do modelo desejado (ex: `East US 2`)
   - **Name**: nome único para o recurso (ex: `meu-openai-rh`)
   - **Pricing tier**: `Standard S0`
4. Clique em **Review + create** → **Create**.

### 1.2 Criar o deployment do modelo

1. Acesse o recurso criado → clique em **Go to Azure OpenAI Studio** (ou acesse `https://oai.azure.com`).
2. No menu lateral, acesse **Deployments** → **Create new deployment**.
3. Preencha:
   - **Model**: selecione `gpt-4o` (ou `gpt-4o-mini` para custo menor)
   - **Deployment name**: anote este nome — ele vai para `AZURE_OPENAI_DEPLOYMENT_NAME`
4. Clique em **Create**.

### 1.3 Obter endpoint e API key

1. No [Azure Portal](https://portal.azure.com), abra seu recurso Azure OpenAI.
2. No menu lateral, acesse **Keys and Endpoint**.
3. Copie:
   - **KEY 1** → `AZURE_OPENAI_API_KEY`
   - **Endpoint** → `AZURE_OPENAI_ENDPOINT` (formato: `https://<nome>.openai.azure.com/`)

> **Alternativa com App Registration (Entra ID)**
>
> Se preferir autenticação via identidade gerenciada ou service principal em vez de API key:
>
> 1. No [Azure Portal](https://portal.azure.com), acesse **Microsoft Entra ID** → **App registrations** → **New registration**.
> 2. Preencha **Name** (ex: `agent-framework-sp`) e clique em **Register**.
> 3. Anote o **Application (client) ID** e o **Directory (tenant) ID**.
> 4. Acesse **Certificates & secrets** → **New client secret** → copie o valor gerado.
> 5. No recurso Azure OpenAI, acesse **Access control (IAM)** → **Add role assignment**.
> 6. Atribua o role **Cognitive Services OpenAI User** ao service principal criado.
> 7. Substitua `AZURE_OPENAI_API_KEY` pela autenticação via `DefaultAzureCredential` (requer ajuste no código e instalação do pacote `azure-identity`).

---

## 2. Microsoft Copilot Studio – Configurar os agentes

Repita este processo para cada agente (RH e TI).

### 2.1 Criar e publicar o agente

1. Acesse o [Microsoft Copilot Studio](https://copilotstudio.microsoft.com).
2. Selecione o **ambiente Power Platform** correto (canto superior direito).
3. Clique em **Create** → escolha um template ou **New agent**.
4. Configure tópicos, conhecimento e instruções do agente.
5. Clique em **Publish** (canto superior direito) para disponibilizar o agente.

> O agente **precisa estar publicado** para receber mensagens via Direct Line.

### 2.2 Ativar o canal Direct Line

1. No agente publicado, acesse **Settings** (ícone de engrenagem) → **Channels**.
2. Localize o canal **Direct Line** e clique nele.
3. Clique em **Enable** / **Add channel** (se ainda não estiver ativo).
4. Copie o **Secret Key** exibido → este é o valor de `DIRECT_LINE_SECRET_RH` (ou `_TI`).

> O secret é exibido uma única vez. Guarde-o com segurança. Se perder, gere um novo clicando em **Regenerate**.

### 2.3 Configurações recomendadas no agente

| Configuração | Recomendação |
|---|---|
| **Linguagem** | Defina o idioma padrão (ex: Português) em Settings → General |
| **Authentication** | Defina como **No authentication** para uso server-to-server via Direct Line |
| **Idle session timeout** | Aumente para 30+ min se conversas forem longas (Settings → General) |
| **Allow escalation** | Desative se não houver handoff humano configurado |
| **Fallback topic** | Personalize a mensagem de erro/fallback para respostas mais úteis |

---

## 3. Variáveis de ambiente

Copie `.env.example` para `.env` e preencha todos os valores:

```bash
cp .env.example .env
```

| Variável | Obrigatória | Descrição |
|---|---|---|
| `AZURE_OPENAI_API_KEY` | Sim | API key do recurso Azure OpenAI |
| `AZURE_OPENAI_ENDPOINT` | Sim | Endpoint do recurso (`https://<nome>.openai.azure.com/`) |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | Sim | Nome do deployment criado (ex: `gpt-4o`) |
| `DIRECT_LINE_SECRET_RH` | Sim | Secret do canal Direct Line do agente de RH |
| `DIRECT_LINE_SECRET_TI` | Sim | Secret do canal Direct Line do agente de TI |
| `COPILOT_RH_NAME` | Não | Nome de exibição do agente RH (padrão: `Copilot RH`) |
| `COPILOT_TI_NAME` | Não | Nome de exibição do agente TI (padrão: `Copilot TI`) |
| `POWER_PLATFORM_ENV_RH` | Não | ID do ambiente Power Platform do agente RH (informativo) |
| `POWER_PLATFORM_ENV_TI` | Não | ID do ambiente Power Platform do agente TI (informativo) |
| `DIRECT_LINE_TIMEOUT_SEC` | Não | Timeout (s) para aguardar resposta do agente (padrão: `45`) |
| `DIRECT_LINE_POLL_INTERVAL_SEC` | Não | Intervalo (s) entre polls ao Direct Line (padrão: `2.0`) |
| `DEBUG_MODE` | Não | Ativa logs detalhados e timeline de agentes (padrão: `false`) |

---

## 4. Instalação

```bash
# 1. Criar e ativar ambiente virtual
python -m venv .venv

# Windows
.venv\Scripts\activate

# Linux / macOS
source .venv/bin/activate

# 2. Instalar dependências (modo editável para desenvolvimento)
pip install -e .

# Para instalar também as dependências de dev (pytest, black):
pip install -e ".[dev]"
```

**Dependências principais** (declaradas em `pyproject.toml`):

| Pacote | Versão mínima | Função |
|---|---|---|
| `httpx` | 0.27.0 | Cliente HTTP async para Direct Line |
| `python-dotenv` | 1.0.1 | Leitura do arquivo `.env` |
| `agent-framework` | 1.0.0 | Supervisor LLM com suporte a tools |
| `rich` | 13.0.0 | Interface de terminal com cores e spinners |

---

## 5. Executar

```bash
# Windows
.venv\Scripts\python app.py

# Linux / macOS
.venv/bin/python app.py
```

### Comandos disponíveis no terminal

| Comando | Descrição |
|---|---|
| `/help` | Lista todos os comandos |
| `/agents` | Exibe os agentes registrados e seus ambientes |
| `/status` | JSON completo da sessão atual |
| `/debug` | Últimas respostas brutas de cada agente |
| `/activities` | Atividades Direct Line brutas por agente |
| `/timeline` | Timeline de chamadas a agentes na sessão |
| `/reset` | Reinicia a sessão (nova conversa com os agentes) |
| `/session <id>` | Troca para outra sessão (cria se não existir) |
| `/exit` | Encerra o chat |

---

## 6. Como o roteamento funciona

O supervisor (Azure OpenAI) recebe a mensagem do usuário e decide automaticamente qual tool chamar:

- **`ask_rh_agent`** → férias, holerite, benefícios, recrutamento, políticas de RH
- **`ask_it_agent`** → senha, acesso, VPN, software, equipamentos, rede, impressoras
- **Ambas em sequência** → quando a mensagem mistura assuntos de RH e TI

A resposta do agente especialista é preservada; o supervisor apenas organiza ou conecta quando necessário.

---

## Limitações desta versão

- Sessões mantidas apenas em memória (perdidas ao reiniciar).
- Integração via Direct Line server-to-server (sem SSO/autenticação de usuário final).
- Sem endpoint HTTP exposto — uso exclusivo via CLI.
- Dois agentes fixos (RH e TI); para adicionar mais, edite `core/config.py` e registre novas tools em `core/copilot_tools.py`.
