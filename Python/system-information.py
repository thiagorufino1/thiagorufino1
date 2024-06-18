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

        if self.title_label.cget("text") == "CPU Usage": value = psutil.cpu_percent(interval=1)
        elif self.title_label.cget("text") == "Memory Usage": value = psutil.virtual_memory().percent
        elif self.title_label.cget("text") == "Disk Usage": value = psutil.disk_usage('/').percent

        self.value_label.configure(text="{:.2f}%".format(value))

        self.value_label.grid_configure(sticky="ew", pady=10)

        self.after(1000, self.update_info)

# Instanciando a aplicação
app = customtkinter.CTk()
app.title("System Information")
app.geometry("300x350")

# Criando instâncias de MyInfoFrame
frame1 = MyInfoFrame(app, "CPU Usage")
frame1.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame2 = MyInfoFrame(app, "Memory Usage")
frame2.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame3 = MyInfoFrame(app, "Disk Usage")
frame3.pack(side="top", padx=10, pady=10, fill="both", expand=True)

# Rodando a aplicação
app.mainloop()