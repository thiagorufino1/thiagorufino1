import customtkinter

class MyCheckboxFrame(customtkinter.CTkFrame):
    def __init__(self, master, title, values):
        super().__init__(master)
        self.grid_columnconfigure(0, weight=1)
        self.values = values

        self.title_label = customtkinter.CTkLabel(self, text=title, fg_color="gray30", corner_radius=6)
        self.title_label.grid(row=0, column=0, padx=10, pady=(10, 0), sticky="ew")

        self.checkboxes = []
        for i, value in enumerate(values):
            checkbox = customtkinter.CTkCheckBox(self, text=value)
            checkbox.grid(row=i+1, column=0, padx=10, pady=(10, 0), sticky="w")
            self.checkboxes.append(checkbox)

    def get(self):
        checked_checkboxes = []
        for checkbox in self.checkboxes:
            if checkbox.get() == 1:
                checked_checkboxes.append(checkbox.cget("text"))
        return checked_checkboxes

# Instanciando a aplicação
app = customtkinter.CTk()
app.title("My Checkbox Frame")
app.geometry("400x400")

# Criando instância de MyCheckboxFrame
checkbox_frame = MyCheckboxFrame(app, "Checkbox Frame", ["Option 1", "Option 2", "Option 3"])
checkbox_frame.pack(padx=10, pady=10, fill="both", expand=True)

# Rodando a aplicação
app.mainloop()