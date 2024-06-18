import customtkinter

# Classe para mostrar informações do dispositivo
class DeviceInfoFrame(customtkinter.CTkFrame):
    def __init__(self, master, title, value):
        super().__init__(master)
        self.grid_columnconfigure(0, weight=1)

        self.title_label = customtkinter.CTkLabel(self, text=title, fg_color="#22272E", corner_radius=6, font=("Arial", 16, "bold"))
        self.title_label.grid(row=0, column=0, padx=10, pady=(10, 0), sticky="ew")

        self.value_label = customtkinter.CTkLabel(self, text=value, fg_color="transparent", font=("Arial", 14))
        self.value_label.grid(row=1, column=0, padx=10, pady=(5, 0), sticky="w")

        self.value_label.grid_configure(sticky="ew", pady=10)

# Instanciando a aplicação
app = customtkinter.CTk()
app.title("Device Information")
app.geometry("300x450")

# Criando instâncias de DeviceInfoFrame para cada informação
device_name_frame = DeviceInfoFrame(app, "Device Name", "Example Device Name")
device_name_frame.pack(side="top", padx=10, pady=10, fill="both", expand=True)

user_principal_name_frame = DeviceInfoFrame(app, "User Principal Name", "example@domain.com")
user_principal_name_frame.pack(side="top", padx=10, pady=10, fill="both", expand=True)

compliance_state_frame = DeviceInfoFrame(app, "Compliance State", "Compliant")
compliance_state_frame.pack(side="top", padx=10, pady=10, fill="both", expand=True)

device_registration_state_frame = DeviceInfoFrame(app, "Device Registration State", "Registered")
device_registration_state_frame.pack(side="top", padx=10, pady=10, fill="both", expand=True)

# Rodando a aplicação
app.mainloop()