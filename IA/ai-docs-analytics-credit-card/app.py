import streamlit as st
from services.storage import upload_file_to_blob
from services.credit_card_analysis import analyze_credit_card_document

st.set_page_config(page_title="Aplicativo de Identificação de Cartões de Crédito", layout="wide")

logo = "Img/logo.png"
st.image(logo, use_column_width=False, width=400)

st.subheader("Aplicativo para identificar Cartões de Créditos", divider="green")

uploaded_file = st.file_uploader("", type=["pdf", "jpg", "png"], key="uploaded_file")

if uploaded_file is not None:
    file_content = uploaded_file.getvalue()
    filename = uploaded_file.name
    
    result = upload_file_to_blob(file_content, filename)

    if "url" in result:
        st.success(f"Arquivo {filename} enviado com sucesso.", icon="✅")

        analysis_result = analyze_credit_card_document(result["url"])

        if "error" in analysis_result:
            st.error(analysis_result["error"])
        else:
            if analysis_result['card_number']:
                st.success(f"Cartão de Crédito identificado", icon="✅")

                code = (
                    f"Nome do Titular: {analysis_result['card_name']}\n"
                    f"Número do Cartão: {analysis_result['card_number']}\n"
                    f"Data de Validade: {analysis_result['card_expiry_date']}\n"
                )
                st.code(code, language=None)

            else:
                st.warning("Cartão de Crédito não foi identificado.", icon="⚠️")
    else:
        st.error(result)
else:
    st.info("Por favor, carregue um arquivo.", icon="ℹ️")