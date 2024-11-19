# Aplicativo de Identificação de Cartões de Crédito

## Descrição

Este aplicativo foi desenvolvido para identificar informações de cartões de crédito a partir de documentos em formato PDF, JPG ou PNG.

O sistema utiliza o recurso **Document Intelligence** do **Azure AI** para analisar os documentos e extrair as informações dos cartões de crédito, como o nome do titular, número do cartão, data de validade e banco emissor.

![App](Img/app.png)

## Requisitos

Para executar este aplicativo, é necessário instalar as dependências listadas no arquivo `requirements.txt`.

Execute o seguinte comando para instalar as dependências:

```
pip install -r requirements.txt
```

## Estrutura do Projeto

O projeto possui a seguinte estrutura de arquivos:

```
/project-root
    /Img
        logo.png
    app.py
    storage.py
    credit_card_analysis.py
    requirements.txt
    .env
```

### Descrição dos Arquivos:

- **`app.py`**: O arquivo principal que contém a lógica do aplicativo. Ele configura o Streamlit para o upload de arquivos e exibe os resultados da análise dos documentos.
- **`storage.py`**: Contém a função `upload_file_to_blob` para fazer upload dos arquivos para o Azure Blob Storage. Ele utiliza a biblioteca `azure-storage-blob` para interagir com o serviço de armazenamento da Azure.

- **`credit_card_analysis.py`**: Contém a função `analyze_credit_card_document` que interage com o **Azure Form Recognizer** para analisar o documento carregado e extrair as informações do cartão de crédito.

- **`requirements.txt`**: Lista as dependências necessárias para o projeto.

- **`.env`**: Contém as variáveis de ambiente para as chaves e URLs do Azure, necessárias para a autenticação e interações com o Azure Blob Storage e o Azure Form Recognizer.

## Como Configurar

### Passo 1: Configurar Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto e adicione as variáveis de ambiente necessárias. O arquivo deve conter as seguintes linhas:

```env
AZURE_STORAGE_CONNECTION_STRING=your_blob_storage_connection_string
AZURE_CONTAINER_NAME=your_blob_container_name
AZURE_FORM_RECOGNIZER_ENDPOINT=your_form_recognizer_endpoint
AZURE_FORM_RECOGNIZER_KEY=your_form_recognizer_key
```

Substitua os valores de `your_blob_storage_connection_string`, `your_blob_container_name`, `your_form_recognizer_endpoint` e `your_form_recognizer_key` pelos valores reais que você obteve ao configurar os serviços no Azure.

### Passo 2: Executar o Aplicativo

Execute o aplicativo Streamlit com o seguinte comando:

```
streamlit run app.py
```

O aplicativo será aberto em um navegador e permitirá que você carregue arquivos para análise.

## Funcionalidade do Aplicativo

1. **Upload de Arquivos**: O usuário pode carregar um arquivo de imagem (JPG, PNG) ou PDF através da interface do Streamlit.
2. **Envio para o Azure Blob Storage**: O arquivo é enviado para o Azure Blob Storage.
3. **Análise do Documento**: Após o upload, o aplicativo usa o **Azure Form Recognizer** para analisar o documento e identificar informações relacionadas ao cartão de crédito.
4. **Exibição dos Resultados**: Se o cartão de crédito for identificado, as informações como o nome do titular, número do cartão e data de validade serão exibidas. Caso contrário, será exibida uma mensagem informando que o cartão não foi encontrado.

## Detalhes das Funções

### Função: `upload_file_to_blob(file, filename)`

**Arquivo**: `storage.py`

- **Descrição**: Realiza o upload de um arquivo para o Azure Blob Storage.
- **Parâmetros**:
  - `file`: O conteúdo do arquivo a ser carregado.
  - `filename`: O nome do arquivo.
- **Retorno**: Retorna um dicionário com a URL do arquivo carregado ou uma mensagem de erro caso ocorra um problema.

### Função: `analyze_credit_card_document(file_url: str)`

**Arquivo**: `credit_card_analysis.py`

- **Descrição**: Usa o Azure Form Recognizer para analisar um documento de cartão de crédito e extrair as informações.
- **Parâmetros**:
  - `file_url`: A URL do arquivo carregado no Blob Storage.
- **Retorno**: Retorna um dicionário contendo o nome do titular do cartão, número do cartão, data de validade e banco emissor ou uma mensagem de erro caso a análise falhe.

## Exemplos de Uso

Após fazer o upload de um arquivo de cartão de crédito, o aplicativo exibirá algo similar a isso:

```
Nome do Titular: João da Silva
Número do Cartão: 1234 5678 9876 5432
Data de Validade: 12/24
```

Ou, caso o cartão não seja identificado:

```
⚠️ Cartão de Crédito não foi identificado.
```

## Considerações Finais

- Certifique-se de que as variáveis de ambiente estão configuradas corretamente no arquivo `.env`.
- O aplicativo funciona com arquivos de imagem (JPG, PNG) ou PDFs que contenham informações visíveis do cartão de crédito.

## Licença

Este projeto está licenciado sob a [Licença MIT](https://opensource.org/licenses/MIT).
