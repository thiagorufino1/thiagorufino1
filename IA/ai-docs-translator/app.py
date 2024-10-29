from dotenv import load_dotenv
import os
import pdfplumber
import requests
import uuid
from azure.core.credentials import AzureKeyCredential
from azure.ai.textanalytics import TextAnalyticsClient
import gradio as gr

def read_file_content(file_path):
    content = ""
    if file_path.endswith('.txt'):
        with open(file_path, encoding='utf8') as f:
            content = f.read()
    elif file_path.endswith('.pdf'):
        with pdfplumber.open(file_path) as pdf:
            for page in pdf.pages:
                content += page.extract_text()
    return content

def process_file(uploaded_file, selected_language):
    try:
        load_dotenv()
        ai_endpoint = os.getenv('AI_SERVICE_ENDPOINT')
        ai_key = os.getenv('AI_SERVICE_KEY')
        translator_endpoint = os.getenv('TRANSLATOR_ENDPOINT')
        translator_key = os.getenv('TRANSLATOR_KEY')
        translator_location = os.getenv('TRANSLATOR_REGION')

        ai_credential = AzureKeyCredential(ai_key)
        ai_client = TextAnalyticsClient(endpoint=ai_endpoint, credential=ai_credential)

        file_path = uploaded_file.name
        text = read_file_content(file_path)

        if not text:
            return "Nenhum conteúdo foi encontrado no arquivo.", "", "", "", "", ""

        detected_language = ai_client.detect_language(documents=[text])[0]
        language_detected_id = detected_language.primary_language.iso6391_name
        language_detected_name = detected_language.primary_language.name
        language_detected_confidence = f"{detected_language.primary_language.confidence_score * 100:.1f}%"

        sentiment_analysis = ai_client.analyze_sentiment(documents=[text])[0]
        sentiment_detected = sentiment_analysis.sentiment

        language_mapping = {
            "Árabe": "ar",
            "Espanhol": "es",
            "Inglês": "en",
            "Japonês": "ja",
            "Mandarim": "zh-Hans",
            "Português (Brasil)": "pt",
            "Russo": "ru",
            "Turco": "tr"
        }

        target_language = language_mapping.get(selected_language, "pt")

        path = '/translate'
        constructed_url = translator_endpoint + path

        params = {
            'api-version': '3.0',
            'from': language_detected_id,
            'to': target_language
        }

        headers = {
            'Ocp-Apim-Subscription-Key': translator_key,
            'Ocp-Apim-Subscription-Region': translator_location,
            'Content-type': 'application/json',
            'X-ClientTraceId': str(uuid.uuid4())
        }

        body = [{'text': text}]
        request = requests.post(constructed_url, params=params, headers=headers, json=body)
        response = request.json()

        if request.status_code == 200:
            translated_text = response[0]['translations'][0]['text']
            return "Arquivo processado com sucesso!", text, translated_text, sentiment_detected, language_detected_name, language_detected_confidence
        else:
            error_message = response.get("error", {}).get("message", "Erro desconhecido.")
            return f"Erro na tradução: {error_message}", "", "", "", "", ""

    except Exception as ex:
        return f"Erro: {ex}", "", "", "", "", ""

def clear_fields():
    return None, "", "", "", "", "", "", "Inglês"

with gr.Blocks() as app:
    with gr.Row():
        with gr.Column():
            with gr.Row():
                gr.Image(value="Img/logo2.png", label="Logo", elem_id="logo", interactive=False)
                gr.Image(value="Img/logo3.png", label="Logo", elem_id="logo", interactive=False)
        with gr.Column():
            gr.Markdown(
                "<h1 style='text-align: center; font-size: 36px; color: #2D333B;'>Aplicativo de Tradução de Documentos</h1>",
                elem_classes=["text"]
            )

    with gr.Row():
        with gr.Column():
            upload_arquivo = gr.File(label="Upload do Arquivo", file_count="single", file_types=[".txt", ".pdf"])
        with gr.Column():
            resultado_upload = gr.Textbox(label="Status", interactive=False)
            idioma_selecionado = gr.Dropdown(
                choices=["Árabe", "Espanhol", "Inglês", "Japonês", "Mandarim", "Português (Brasil)", "Russo", "Turco"],
                value="Inglês",
                label="Selecionar Idioma para Tradução",
                multiselect=False
            )
            with gr.Row():
                botao_processar = gr.Button("Processar Arquivo", elem_id="process-button", elem_classes=["blue-button"])
                botao_limpar = gr.Button("Limpar Campos", elem_id="clear-button", elem_classes=["clear-button"])

    gr.Markdown("### Resultados:")
    with gr.Row():
        with gr.Column():
            campo_sentimentos = gr.Textbox(label="Análise de Sentimentos", placeholder="Sentimento detectado será exibido aqui.", interactive=False)
        with gr.Column():
            campo_linguagem_detectada = gr.Textbox(label="Linguagem Detectada", placeholder="Nome da linguagem detectada.", interactive=False)
        with gr.Column():
            campo_confiança_detectada = gr.Textbox(label="Pontuações de Confiança", placeholder="Confiança da detecção.", interactive=False)

    with gr.Row():
        campo_original = gr.Textbox(label="Original", placeholder="Conteúdo original do documento.", interactive=False)
        campo_traducao = gr.Textbox(label="Tradução", placeholder="Tradução será exibida aqui.", interactive=False)

    botao_processar.click(
        process_file, 
        inputs=[upload_arquivo, idioma_selecionado], 
        outputs=[resultado_upload, campo_original, campo_traducao, campo_sentimentos, campo_linguagem_detectada, campo_confiança_detectada]
    )
    
    botao_limpar.click(
        clear_fields, 
        outputs=[upload_arquivo, resultado_upload, campo_original, campo_traducao, campo_sentimentos, campo_linguagem_detectada, campo_confiança_detectada, idioma_selecionado]
    )

app.css = """
    .blue-button {
        background-color: #215F9A;
        color: white;
    }
    .clear-button {
        background-color: #FF4D4D;
        color: white;
    }
    .text {
        color: #2D333B;
    }
"""

app.launch()