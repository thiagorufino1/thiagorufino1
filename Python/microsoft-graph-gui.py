import requests
import customtkinter

# Função para obter informações do dispositivo Microsoft Graph
def get_device_info():
    client_id = '27f044fd-dffc-4c75-a5d9-bca69affff22'
    client_secret = 'jdk8Q~81LeJ9ieXDKWzBptocCaR3H5Btvcbq2dA7'
    tenant_id = '144ac447-f91a-4a05-96f3-caa37e9d992f'
    device_id = '32083bd6-801f-4865-b67a-cfc96030bfa7'

    token_url = f"https://login.microsoftonline.com/{tenant_id}/oauth2/v2.0/token"
    token_data = {
        'grant_type': 'client_credentials',
        'client_id': client_id,
        'client_secret': client_secret,
        'scope': 'https://graph.microsoft.com/.default'
    }
    token_response = requests.post(token_url, data=token_data)
    token = token_response.json().get('access_token')

    graph_api_url = f"https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/{device_id}"
    headers = {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json'
    }

    response = requests.get(graph_api_url, headers=headers)

    if response.status_code == 200:
        device_info = response.json()
        return device_info
    else:
        return None

# Classe para mostrar informações do dispositivo
class DeviceInfoFrame(customtkinter.CTkFrame):
    def __init__(self, master, title):
        super().__init__(master)
        self.grid_columnconfigure(0, weight=1)

        self.title_label = customtkinter.CTkLabel(self, text=title, fg_color="#22272E", corner_radius=6, font=("Arial", 16, "bold"))
        self.title_label.grid(row=0, column=0, padx=10, pady=(10, 0), sticky="ew")

        self.value_label = customtkinter.CTkLabel(self, text="", fg_color="transparent", font=("Arial", 14))
        self.value_label.grid(row=1, column=0, padx=10, pady=(5, 0), sticky="w")

        self.update_info()

    def update_info(self):
        device_info = get_device_info()

        if device_info:
            device_name = device_info.get('deviceName', 'N/A')
            device_userPrincipalName = device_info.get('userPrincipalName', 'N/A')
            device_complianceState = device_info.get('complianceState', 'N/A')
            device_deviceRegistrationState = device_info.get('deviceRegistrationState', 'N/A')

            if self.title_label.cget("text") == "Device Name":
                self.value_label.configure(text=device_name, font=("Arial", 16, "bold"))
            elif self.title_label.cget("text") == "User Principal Name":
                self.value_label.configure(text=device_userPrincipalName, font=("Arial", 16, "bold"))
            elif self.title_label.cget("text") == "Compliance State":

                if device_complianceState.lower() == "compliant":
                    self.value_label.configure(text=device_complianceState, fg_color="#00B050", bg_color="#00B050", font=("Arial", 16, "bold"))
                else:
                    self.value_label.configure(text=device_complianceState, font=("Arial", 16, "bold"))

            elif self.title_label.cget("text") == "Device Registration State":

                if device_deviceRegistrationState.lower() == "registered":
                    self.value_label.configure(text=device_deviceRegistrationState, fg_color="#00B050", bg_color="#00B050", font=("Arial", 16, "bold"))
                else:
                    self.value_label.configure(text=device_deviceRegistrationState, font=("Arial", 16, "bold"))

        else:
            self.value_label.configure(text="Failed to fetch device information.")

        self.value_label.grid_configure(sticky="ew", pady=10)

        self.after(10000, self.update_info)  # Atualiza a cada 10 segundos

# Instanciando a aplicação
app = customtkinter.CTk()
app.title("Device Information")
app.geometry("300x450")

# Criando instâncias de DeviceInfoFrame para cada informação
device_name_frame = DeviceInfoFrame(app, "Device Name")
device_name_frame.pack(side="top", padx=10, pady=10, fill="both", expand=True)

user_principal_name_frame = DeviceInfoFrame(app, "User Principal Name")
user_principal_name_frame.pack(side="top", padx=10, pady=10, fill="both", expand=True)

compliance_state_frame = DeviceInfoFrame(app, "Compliance State")
compliance_state_frame.pack(side="top", padx=10, pady=10, fill="both", expand=True)

device_registration_state_frame = DeviceInfoFrame(app, "Device Registration State")
device_registration_state_frame.pack(side="top", padx=10, pady=10, fill="both", expand=True)

# Rodando a aplicação
app.mainloop()