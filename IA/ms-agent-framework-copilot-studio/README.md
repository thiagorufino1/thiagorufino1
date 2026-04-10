# MS Agent Framework + Copilot Studio

Orquestrador em Python para terminal que usa o Microsoft Agent Framework como supervisor e delega perguntas para agentes especializados do Microsoft Copilot Studio via Direct Line.

## Visão geral

```text
app.py
  -> AgentRouter
       -> tools dinâmicas geradas a partir do registro de agentes
            -> CopilotClient
                 -> Direct Line
                      -> agente do Copilot Studio
```

Componentes principais:

| Arquivo | Responsabilidade |
|---|---|
| `app.py` | CLI interativo com Rich |
| `core/router.py` | Supervisor, sessão do Agent Framework e roteamento |
| `core/tools/copilot_tools.py` | Fábrica de tools dinâmicas para cada agente |
| `core/copilot_client.py` | Cliente Direct Line com retry, polling e reuse de conexão |
| `core/session_store.py` | Estado de sessão do orquestrador |
| `core/config.py` | Leitura de variáveis de ambiente e registro de agentes |

## Como funciona

1. O usuário envia uma pergunta no terminal.
2. O supervisor do Agent Framework decide qual tool especializada chamar.
3. Cada tool usa o `CopilotClient` para conversar com um agente do Copilot Studio via Direct Line.
4. O estado da conversa com cada agente é mantido por sessão.
5. A resposta do especialista volta para o supervisor, que organiza a saída final.

O registro de agentes é dinâmico. Se `COPILOT_AGENTS` estiver definido, as tools são geradas a partir dessa lista. Se não estiver, o projeto entra em modo legado com RH e TI.

## Pré-requisitos

- Python 3.11+
- Recurso Azure OpenAI com deployment configurado
- Um ou mais agentes publicados no Microsoft Copilot Studio com canal Direct Line habilitado

## Azure OpenAI

O projeto usa `OpenAIChatClient` do Microsoft Agent Framework com `azure_endpoint`, `api_key` e `model`. Essa forma está alinhada com a documentação atual do framework para clientes OpenAI/Azure OpenAI.

Variáveis obrigatórias:

- `AZURE_OPENAI_API_KEY`
- `AZURE_OPENAI_ENDPOINT`
- `AZURE_OPENAI_DEPLOYMENT_NAME`

Observação: a documentação atual do Agent Framework também destaca fluxos com credenciais Entra ID e `AzureOpenAIResponsesClient`. Este projeto, hoje, usa `OpenAIChatClient` com chave.

## Copilot Studio

Para cada agente:

1. Crie ou abra o agente no Copilot Studio.
2. Publique o agente.
3. Ative o canal Direct Line.
4. Guarde o secret do canal.

## Configuração

Copie o arquivo de exemplo:

```powershell
Copy-Item .env.example .env
```

```bash
cp .env.example .env
```

### Modo dinâmico

Exemplo com três agentes:

```dotenv
COPILOT_AGENTS="RH,TI,JURIDICO"

COPILOT_RH_DIRECT_LINE_SECRET="..."
COPILOT_RH_NAME="Copilot RH"
COPILOT_RH_DEPARTMENT="RH"
COPILOT_RH_DESCRIPTION="Use for HR requests such as vacations and payslips."

COPILOT_TI_DIRECT_LINE_SECRET="..."
COPILOT_TI_NAME="Copilot TI"
COPILOT_TI_DEPARTMENT="TI"
COPILOT_TI_DESCRIPTION="Use for IT requests such as password reset and VPN."

COPILOT_JURIDICO_DIRECT_LINE_SECRET="..."
COPILOT_JURIDICO_NAME="Agente Juridico"
COPILOT_JURIDICO_DEPARTMENT="Legal"
COPILOT_JURIDICO_DESCRIPTION="Use for legal and compliance requests."
```

### Modo legado

Se `COPILOT_AGENTS` não estiver definido, o projeto usa:

```dotenv
DIRECT_LINE_SECRET_RH="..."
DIRECT_LINE_SECRET_TI="..."
```

## Variáveis de ambiente

| Variável | Obrigatória | Descrição |
|---|---|---|
| `AZURE_OPENAI_API_KEY` | Sim | Chave do Azure OpenAI |
| `AZURE_OPENAI_ENDPOINT` | Sim | Endpoint do recurso Azure OpenAI |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | Sim | Nome do deployment/modelo |
| `COPILOT_AGENTS` | Não | Lista separada por vírgula para registro dinâmico |
| `COPILOT_<ID>_DIRECT_LINE_SECRET` | Depende | Secret Direct Line do agente |
| `COPILOT_<ID>_NAME` | Não | Nome exibido no CLI |
| `COPILOT_<ID>_DEPARTMENT` | Não | Rótulo do departamento |
| `COPILOT_<ID>_DESCRIPTION` | Não | Descrição da tool usada pelo supervisor |
| `POWER_PLATFORM_ENV_<ID>` | Não | Id do ambiente Power Platform, apenas informativo |
| `DIRECT_LINE_SECRET_RH` | Legado | Secret do agente RH no modo legado |
| `DIRECT_LINE_SECRET_TI` | Legado | Secret do agente TI no modo legado |
| `DIRECT_LINE_TIMEOUT_SEC` | Não | Timeout total de polling por resposta |
| `DIRECT_LINE_POLL_INTERVAL_SEC` | Nao | Intervalo entre polls |
| `DEBUG_MODE` | Não | Ativa logs verbosos e timeline extra |
| `STRUCTURED_LOGGING` | Não | Emite logs em JSON |

## Instalação

```bash
python -m venv .venv
```

Windows:

```powershell
.venv\Scripts\activate
```

Linux/macOS:

```bash
source .venv/bin/activate
```

Instale o pacote:

```bash
pip install -e .
```

Dependências de desenvolvimento:

```bash
pip install -e ".[dev]"
```

## Execução

Windows:

```powershell
.venv\Scripts\python app.py
```

Linux/macOS:

```bash
.venv/bin/python app.py
```

Comandos do terminal:

| Comando | Descrição |
|---|---|
| `/help` | Lista os comandos |
| `/agents` | Mostra os agentes registrados |
| `/status` | Exibe o estado completo da sessão atual |
| `/debug` | Mostra as últimas respostas brutas dos subagentes |
| `/activities` | Mostra as atividades Direct Line capturadas |
| `/timeline` | Mostra a timeline de chamadas aos agentes |
| `/reset` | Reinicia a sessão atual |
| `/session <id>` | Troca para outra sessão |
| `/exit` | Encerra o chat |

## Limites atuais

- O storage padrão de sessão é em memória.
- A integração é server-to-server via Direct Line, sem autenticação do usuário final.
- O projeto é focado em CLI; não expõe endpoint HTTP.

## Observações de implementação

- O supervisor gera tools dinâmicas a partir do registro carregado por ambiente.
- O `CopilotClient` reutiliza `httpx.AsyncClient` para pooling de conexões.
- No `reset` da sessão e no encerramento do app, os clientes HTTP são fechados explicitamente.

## Referências consultadas

- Microsoft Agent Framework Python README: https://github.com/microsoft/agent-framework/blob/main/python/README.md
- Agent Framework OpenAI package README: https://github.com/microsoft/agent-framework/blob/main/python/packages/openai/README.md
- HTTPX async docs: https://github.com/encode/httpx/blob/master/docs/async.md
