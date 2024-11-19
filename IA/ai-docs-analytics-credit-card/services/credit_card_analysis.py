from azure.core.credentials import AzureKeyCredential
from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.ai.documentintelligence.models import AnalyzeDocumentRequest
import os
from dotenv import load_dotenv

load_dotenv()

# Carregar variáveis de ambiente para autenticação do Form Recognizer
FORM_RECOGNIZER_ENDPOINT = os.getenv("AZURE_FORM_RECOGNIZER_ENDPOINT")
FORM_RECOGNIZER_KEY = os.getenv("AZURE_FORM_RECOGNIZER_KEY")

# Verificar se as variáveis de ambiente foram carregadas corretamente
if not FORM_RECOGNIZER_ENDPOINT or not FORM_RECOGNIZER_KEY:
    raise ValueError("As variáveis de ambiente AZURE_FORM_RECOGNIZER_ENDPOINT ou AZURE_FORM_RECOGNIZER_KEY não estão configuradas.")

document_analysis_client = DocumentIntelligenceClient(
    endpoint=FORM_RECOGNIZER_ENDPOINT, credential=AzureKeyCredential(FORM_RECOGNIZER_KEY)
)

def analyze_credit_card_document(file_url: str):
    try:
        # Iniciando o processamento do documento
        credit_card_info = document_analysis_client.begin_analyze_document("prebuilt-creditCard", AnalyzeDocumentRequest(url_source=file_url))
        result = credit_card_info.result()

        for document in result.documents:
            fields = document.get('fields', {})

        return {
            "card_name": fields.get('CardHolderName', {}).get('content'),
            "card_number": fields.get('CardNumber', {}).get('content'),
            "card_expiry_date": fields.get('ExpirationDate', {}).get('content'),
            "card_bank": fields.get('IssuingBank', {}).get('content'),
        }

    except Exception as e:
        return {"error": f"Erro ao analisar o documento: {str(e)}"}