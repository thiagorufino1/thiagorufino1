import customtkinter
import psutil
import platform
import socket
import subprocess

class MyInfoFrame(customtkinter.CTkFrame):
    def __init__(self, master, title):
        super().__init__(master)
        self.grid_columnconfigure(0, weight=1)

        self.title_label = customtkinter.CTkLabel(self, text=title, fg_color="#22272E", corner_radius=6, font=("Arial", 16, "bold"))
        self.title_label.grid(row=0, column=0, padx=10, pady=(10, 0), sticky="ew")

        self.value_label = customtkinter.CTkLabel(self, text="", fg_color="transparent", font=("Arial", 12))
        self.value_label.grid(row=1, column=0, padx=10, pady=(5, 0), sticky="w")

        self.value_label.grid_configure(sticky="ew", pady=10)  

        self.update_info()

    def update_info(self):
        if self.title_label.cget("text") == "CPU Usage":
            value = psutil.cpu_percent(interval=1)
        elif self.title_label.cget("text") == "Memory Usage":
            value = psutil.virtual_memory().percent
        elif self.title_label.cget("text") == "Disk Usage":
            value = psutil.disk_usage('/').percent
        elif self.title_label.cget("text") == "Computer Name":
            value = platform.node()
        elif self.title_label.cget("text") == "Serial Number":
            value = self.get_serial_number()
        elif self.title_label.cget("text") == "OS Details":
            value = platform.platform()
        elif self.title_label.cget("text") == "Manufacturer":
            value = self.get_manufacturer()
        elif self.title_label.cget("text") == "Model":
            value = self.get_model()
        elif self.title_label.cget("text") == "IP Address":
            value = socket.gethostbyname(socket.gethostname())

        self.value_label.configure(text=value)

        self.after(1000, self.update_info)
    
    def get_serial_number(self):
        # Retrieve serial number based on the operating system
        if platform.system() == 'Windows':
            # For Windows, you can use wmic command
            result = subprocess.run(['wmic', 'bios', 'get', 'serialnumber'], stdout=subprocess.PIPE, universal_newlines=True)
            return result.stdout.split('\n')[1].strip()
        elif platform.system() == 'Linux':
            # For Linux, you can read from a file that contains the serial number
            try:
                with open('/sys/class/dmi/id/product_serial') as f:
                    return f.readline().strip()
            except FileNotFoundError:
                return "Not Available"
        elif platform.system() == 'Darwin':
            # For macOS, you can use system_profiler command
            result = subprocess.run(['system_profiler', 'SPHardwareDataType'], stdout=subprocess.PIPE, universal_newlines=True)
            for line in result.stdout.split('\n'):
                if "Serial Number" in line:
                    return line.split(':')[1].strip()
            return "Not Available"
        else:
            return "Not Available"

    def get_manufacturer(self):
        # Retrieve manufacturer based on the operating system
        if platform.system() == 'Windows':
            # For Windows, you can use wmic command
            result = subprocess.run(['wmic', 'computersystem', 'get', 'manufacturer'], stdout=subprocess.PIPE, universal_newlines=True)
            return result.stdout.split('\n')[1].strip()
        elif platform.system() == 'Linux':
            # For Linux, you can read from a file that contains the manufacturer
            try:
                with open('/sys/class/dmi/id/sys_vendor') as f:
                    return f.readline().strip()
            except FileNotFoundError:
                return "Not Available"
        elif platform.system() == 'Darwin':
            # For macOS, you can use system_profiler command
            result = subprocess.run(['system_profiler', 'SPHardwareDataType'], stdout=subprocess.PIPE, universal_newlines=True)
            for line in result.stdout.split('\n'):
                if "Manufacturer" in line:
                    return line.split(':')[1].strip()
            return "Not Available"
        else:
            return "Not Available"

    def get_model(self):
        # Retrieve model based on the operating system
        if platform.system() == 'Windows':
            # For Windows, you can use wmic command
            result = subprocess.run(['wmic', 'computersystem', 'get', 'model'], stdout=subprocess.PIPE, universal_newlines=True)
            return result.stdout.split('\n')[1].strip()
        elif platform.system() == 'Linux':
            # For Linux, you can read from a file that contains the model
            try:
                with open('/sys/class/dmi/id/product_name') as f:
                    return f.readline().strip()
            except FileNotFoundError:
                return "Not Available"
        elif platform.system() == 'Darwin':
            # For macOS, you can use system_profiler command
            result = subprocess.run(['system_profiler', 'SPHardwareDataType'], stdout=subprocess.PIPE, universal_newlines=True)
            for line in result.stdout.split('\n'):
                if "Model Identifier" in line:
                    return line.split(':')[1].strip()
            return "Not Available"
        else:
            return "Not Available"

# Instanciando a aplicação
app = customtkinter.CTk()
app.title("System Information")
app.geometry("300x500")  

# Criando instâncias de MyInfoFrame
frame1 = MyInfoFrame(app, "CPU Usage")
frame1.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame2 = MyInfoFrame(app, "Memory Usage")
frame2.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame3 = MyInfoFrame(app, "Disk Usage")
frame3.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame4 = MyInfoFrame(app, "Computer Name")
frame4.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame5 = MyInfoFrame(app, "Serial Number")
frame5.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame6 = MyInfoFrame(app, "OS Details")
frame6.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame7 = MyInfoFrame(app, "Manufacturer")
frame7.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame8 = MyInfoFrame(app, "Model")
frame8.pack(side="top", padx=10, pady=10, fill="both", expand=True)

frame9 = MyInfoFrame(app, "IP Address")
frame9.pack(side="top", padx=10, pady=10, fill="both", expand=True)

# Rodando a aplicação
app.mainloop()
