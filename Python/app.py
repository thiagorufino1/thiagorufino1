import customtkinter
import psutil

class MyInfoFrame(customtkinter.CTkFrame):
    def __init__(self, master, title):
        super().__init__(master)
        self.grid_columnconfigure(0, weight=1)

        self.title_label = customtkinter.CTkLabel(self, text=title, fg_color="#22272E", corner_radius=6, font=("Arial", 16, "bold"))
        self.title_label.grid(row=0, column=0, padx=10, pady=(10, 0), sticky="ew")

        self.value_label = customtkinter.CTkLabel(self, text="", fg_color="transparent", font=("Arial", 30, "bold"))
        self.value_label.grid(row=1, column=0, padx=10, pady=(5, 0), sticky="w")

        self.update_info()

    def update_info(self):
        if self.title_label.cget("text") == "CPU Usage":
            value = psutil.cpu_percent(interval=1)
        elif self.title_label.cget("text") == "Memory Usage":
            value = psutil.virtual_memory().percent
        elif self.title_label.cget("text") == "Disk Usage":
            value = psutil.disk_usage('/').percent

        self.value_label.configure(text="{:.2f}%".format(value))
        self.value_label.grid_configure(sticky="ew", pady=10)
        self.after(1000, self.update_info)

# Instanciando a aplicação
app = customtkinter.CTk()
app.title("System Information")
app.geometry("600x600")  # Ajustando o tamanho da janela para acomodar as colunas duplicadas
app.grid_columnconfigure((0, 1), weight=1)  # Configurando duas colunas de igual peso
app.grid_rowconfigure((0, 1, 2), weight=1)  # Configurando três linhas de igual peso

# Criando instâncias de MyInfoFrame e posicionando-as na grade
titles = ["CPU Usage", "Memory Usage", "Disk Usage"]
for i in range(3):  # Três linhas
    for j in range(3):  # Duas colunas
        frame = MyInfoFrame(app, titles[i])
        frame.grid(row=i, column=j, padx=10, pady=10, sticky="nsew")

# Rodando a aplicação
app.mainloop()