from azure.storage.blob import BlobServiceClient
import os
from dotenv import load_dotenv

load_dotenv()

connection_string = os.getenv("AZURE_STORAGE_CONNECTION_STRING")
container_name = os.getenv("AZURE_CONTAINER_NAME")

blob_service_client = BlobServiceClient.from_connection_string(connection_string)

def upload_file_to_blob(file, filename):
    try:
        blob_client = blob_service_client.get_blob_client(container=container_name, blob=filename)
        blob_client.upload_blob(file, overwrite=True)

        return {
            "url": blob_client.url,
            "container": container_name,
            "filename": filename
        }
    
    except Exception as e:
        return f"Erro ao fazer upload: {str(e)}"