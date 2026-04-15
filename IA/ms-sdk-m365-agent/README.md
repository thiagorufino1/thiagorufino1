# Microsoft 365 Agent for Teams

Ponto de partida para construir agentes no Microsoft Teams com Python. Usa o **Microsoft 365 Agents SDK** e o **Azure OpenAI** para entregar respostas em streaming, memória de conversa e metadados nativos do Teams, pronto para provisionar no Azure.

---

## Visão geral

Este projeto entrega:

- **Respostas em streaming**: tokens chegam progressivamente ao usuário, sem esperar a resposta completa
- **Memória de conversa**: o agente lembra das mensagens anteriores dentro da mesma conversa
- **Feedback loop**: botões de like/dislike aparecem ao final de cada resposta
- **Badge "Gerado por IA"**: indicação visual nativa do Teams na mensagem do agente
- **Sensitivity label**: metadado de sensibilidade configurável enviado junto com a resposta
- **Prompt e parâmetros externalizados**: sistema de prompt e configurações do modelo em arquivos separados do código
- **Identidade e branding configurável**: nome, descrição e informações do desenvolvedor via variáveis de ambiente, sem alterar o manifest diretamente

---

## Arquitetura

```
Usuário no Teams
      |
      v
Microsoft Teams (canal)
      |
      v
Azure Bot Service  <---  Autentica via Managed Identity
      |
      v
Python Bot (aiohttp)  <---  Microsoft 365 Agents SDK
      |
      v
Azure OpenAI (streaming)
      |
      v
Resposta incremental de volta ao Teams
```

### Arquivos principais

| Arquivo | Responsabilidade |
|---|---|
| [src/app.py](src/app.py) | Servidor HTTP aiohttp, expõe `/api/messages` |
| [src/agent.py](src/agent.py) | Handlers do agente, streaming, memória de conversa |
| [src/config.py](src/config.py) | Leitura e validação das variáveis de ambiente |
| [src/sdk_workarounds.py](src/sdk_workarounds.py) | Patches de compatibilidade para o SDK 0.8.x |
| [src/prompts/chat/skprompt.txt](src/prompts/chat/skprompt.txt) | Prompt de sistema do agente |
| [src/prompts/chat/config.json](src/prompts/chat/config.json) | Parâmetros de completion (temperatura, tokens, etc.) |
| [appPackage/manifest.json](appPackage/manifest.json) | Manifesto do app Teams com variáveis de branding |
| [infra/azure.bicep](infra/azure.bicep) | Provisionamento dos recursos Azure via Bicep |
| [infra/azure.parameters.json](infra/azure.parameters.json) | Parâmetros do Bicep injetados pelo toolkit |
| [m365agents.yml](m365agents.yml) | Workflow principal de provision/deploy/publish |

---

## Recursos implementados

### Streaming incremental
A resposta é enviada em chunks conforme o modelo gera tokens, usando `StreamingResponse` do SDK. O usuário vê o texto aparecer progressivamente, sem aguardar o término da geração.

### Memória de conversa
O histórico de mensagens é armazenado em `ConversationState` e persistido automaticamente pelo SDK por conversa (chave: `channel_id/conversations/conversation_id`).

A cada turno:
1. O histórico é carregado do estado
2. A mensagem do usuário é adicionada
3. O histórico completo é enviado ao modelo como contexto
4. A resposta do assistente é salva no histórico
5. O SDK persiste o estado automaticamente

O histórico é limitado a `M365_AGENT_MAX_HISTORY_TURNS` mensagens (padrão: 20) para controlar o consumo de tokens. O `MemoryStorage` padrão persiste enquanto o processo está rodando. Para persistência entre restarts, substitua por Azure Cosmos DB.

### Feedback loop
Botões de like/dislike aparecem ao final de cada resposta no Teams. Habilitado via `M365_AGENT_FEEDBACK_LOOP=true`.

### Badge "Gerado por IA"
Indicação visual nativa do Teams informando que a mensagem foi gerada por IA. Habilitado via `M365_AGENT_AI_LABEL=true`.

### Sensitivity label
Metadado de classificação de sensibilidade enviado junto com a resposta final. Configurável via `M365_AGENT_SENSITIVITY_NAME`.

### Prompt e parâmetros externalizados
O prompt de sistema fica em `src/prompts/chat/skprompt.txt` e os parâmetros do modelo (temperatura, max_tokens, etc.) em `src/prompts/chat/config.json`. Nenhum dos dois requer alteração de código Python.

### Patches de compatibilidade SDK
O arquivo `src/sdk_workarounds.py` aplica três patches no SDK 0.8.x em tempo de inicialização:

- **AI metadata**: garante que o badge "Gerado por IA" seja sempre emitido, mesmo sem citations
- **Feedback loop**: injeta `feedbackLoop` em `channel_data`, onde o Teams espera encontrá-lo
- **Cache JWKS**: evita um fetch HTTPS por turno na validação JWT, prevenindo timeouts em redes lentas

---

## Provisionamento Azure

O comando **Provision** no toolkit cria os seguintes recursos na sua subscription:

| Recurso Azure | Descrição |
|---|---|
| **App Service Plan** (Linux, B1) | Plano de hospedagem do bot |
| **Web App** (Python 3.11) | Instância do bot em execução |
| **User Assigned Managed Identity** | Identidade do app para autenticação sem senha |
| **Azure Bot Service** | Registro do bot no Bot Framework, vinculado ao Teams |

As variáveis de saída do Bicep (BOT_ID, BOT_DOMAIN, etc.) são gravadas automaticamente nos arquivos `env/` pelo toolkit.

---

## Pré-requisitos

- Python 3.10+
- VS Code com a extensão [Microsoft 365 Agents Toolkit](https://aka.ms/teams-toolkit)
- Conta Microsoft 365 Developer para teste no Teams
- Recurso Azure OpenAI com um deployment ativo

---

## Primeiros passos após clonar

**1. Instalar dependências**

```powershell
python -m venv venv
.\venv\Scripts\activate
pip install -r src/requirements.txt
```

**2. Criar os arquivos de ambiente a partir dos templates**

```bash
cp env/.env.local.example      env/.env.local
cp env/.env.local.user.example env/.env.local.user
```

**3. Preencher as credenciais em `env/.env.local.user`**

```env
SECRET_AZURE_OPENAI_API_KEY=sua_chave_aqui
AZURE_OPENAI_ENDPOINT=https://seu-recurso.openai.azure.com/
AZURE_OPENAI_DEPLOYMENT_NAME=gpt-4o
```

**4. (Opcional) Ajustar identidade do agente em `env/.env.local`**

```env
APP_SHORT_NAME=Meu Agente
APP_FULL_NAME=Nome completo do agente
APP_DEVELOPER_NAME=Nome da empresa
APP_DEVELOPER_WEBSITE=https://suaempresa.com
```

**5. Pressionar F5 no VS Code**

O toolkit provisiona o BOT_ID, TEAMS_APP_ID e todos os campos gerados automaticamente.

---

## Configuração

### Arquivos de ambiente

O arquivo `.env` na raiz é gerado automaticamente pelo toolkit durante o deploy. Não edite manualmente.

| Arquivo | Commitado | Conteúdo |
|---|---|---|
| `env/.env.local.example` | sim | template para `env/.env.local` |
| `env/.env.local.user.example` | sim | template para `env/.env.local.user` |
| `env/.env.local` | não | vars não-secretas: branding, IDs gerados pelo toolkit |
| `env/.env.local.user` | não | secrets: chave Azure OpenAI, senha do bot |
| `env/.env.dev` | sim | vars para deploy no Azure (subscription, resource group) |
| `.env` (raiz) | não | gerado automaticamente pelo toolkit |

### Identidade e branding

Definidos em `env/.env.local` e injetados no `appPackage/manifest.json` via substituição `${{VAR}}` pelo toolkit. Também usados no `azure.parameters.json` para nomear o Azure Bot.

| Variável | Onde aparece |
|---|---|
| `APP_SHORT_NAME` | Nome do bot no chat do Teams |
| `APP_FULL_NAME` | Nome na página de instalação |
| `APP_DESCRIPTION_SHORT` | Descrição curta na listagem de apps |
| `APP_DESCRIPTION_FULL` | Descrição completa na página do app |
| `APP_DEVELOPER_NAME` | "Desenvolvido por" na página do app |
| `APP_DEVELOPER_WEBSITE` | Link do desenvolvedor |
| `APP_DEVELOPER_PRIVACY_URL` | Link para política de privacidade |
| `APP_DEVELOPER_TERMS_URL` | Link para termos de uso |

### Variáveis de comportamento

Configuradas em `env/.env.local.user` ou `env/.env.local`.

| Variável | Padrão | Descrição |
|---|---|---|
| `AZURE_OPENAI_API_VERSION` | `2024-12-01-preview` | Versão da API Azure OpenAI |
| `M365_AGENT_FEEDBACK_LOOP` | `true` | Habilita botões like/dislike na resposta |
| `M365_AGENT_AI_LABEL` | `true` | Exibe badge "Gerado por IA" |
| `M365_AGENT_SENSITIVITY_NAME` | `Internal` | Nome do label de sensibilidade |
| `M365_AGENT_MAX_HISTORY_TURNS` | `20` | Número de turnos de histórico mantidos por conversa |

---

## Como executar

### Playground (validação rápida)

No VS Code, selecione a configuração **`Debug in Microsoft 365 Agents Playground`** e pressione F5.

Útil para validar:
- Recebimento e resposta de mensagens
- Streaming de texto
- Comportamento geral dos handlers

> O Playground não renderiza feedback loop, badge "Gerado por IA" e sensitivity label. Para validar esses recursos, use o Teams.

### Microsoft Teams

No VS Code, selecione uma das configurações abaixo e pressione F5:

- `Debug in Teams (Edge)`
- `Debug in Teams (Chrome)`
- `Debug in Teams (Desktop)`

Use o Teams para validar:
- Instalação e fluxo completo do app
- Streaming no cliente real
- Feedback loop, badge de IA e sensitivity label

---

## Estrutura do repositório

```
.
|-- appPackage/
|   |-- manifest.json
|   |-- color.png
|   `-- outline.png
|-- devTools/
|-- env/
|   |-- .env.local.example
|   |-- .env.local.user.example
|   `-- .env.dev
|-- infra/
|   |-- azure.bicep
|   |-- azure.parameters.json
|   `-- botRegistration/
|       `-- azurebot.bicep
|-- src/
|   |-- app.py
|   |-- agent.py
|   |-- config.py
|   |-- sdk_workarounds.py
|   |-- requirements.txt
|   `-- prompts/
|       `-- chat/
|           |-- skprompt.txt
|           `-- config.json
|-- m365agents.yml
`-- README.md
```

---

## Segurança

- Não commite chaves, tokens ou senhas reais
- Mantenha credenciais nos arquivos `env/*.user` (gitignored)
- Se um segredo foi commitado por engano, rotacione-o imediatamente
- Em produção, prefira Managed Identity no lugar de API keys

---

## Referências

- [Microsoft 365 Agents SDK for Python](https://github.com/microsoft/agents-for-python)
- [Microsoft 365 Agents Toolkit](https://aka.ms/teams-toolkit)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-services/openai/)
- [Bot Framework Documentation](https://learn.microsoft.com/azure/bot-service/)
