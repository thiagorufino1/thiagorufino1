from tkinter import *

# Conexão ao Intune (replace with your actual logic)
# username = "SEU_USUÁRIO_INTUNE"
# password = "SUA_SENHA_INTUNE"
# tenant_id = "SEU_TENANT_ID"
# client = intune.Client(username, password, tenant_id)

# Dados fictícios (replace with data from Intune)
device_name = "Dispositivo de Teste"
device_os = "Windows 10 Pro"
device_serial = "1234567890"
user_name = "João Silva"
user_email = "[endereço de email removido]"

# Criação da interface gráfica
janela = Tk()
janela.title("Dados do Computador no Intune")

# Exibição de informações do dispositivo
label_nome = Label(text="Nome do Dispositivo:")
label_nome.pack()
entry_nome = Entry(textvariable=device_name)
entry_nome.pack()

label_os = Label(text="Sistema Operacional:")
label_os.pack()
entry_os = Entry(textvariable=device_os)
entry_os.pack()

label_serial = Label(text="Número de Série:")
label_serial.pack()
entry_serial = Entry(textvariable=device_serial)
entry_serial.pack()

# Exibição de informações do usuário
label_usuario = Label(text="Nome do Usuário:")
label_usuario.pack()
entry_usuario = Entry(textvariable=user_name)
entry_usuario.pack()

label_email = Label(text="Email do Usuário:")
label_email.pack()
entry_email = Entry(textvariable=user_email)
entry_email.pack()

# Botão para atualizar dados (for demonstration only)
def atualizar_dados():
    pass

botao_atualizar = Button(text="Atualizar Dados", command=atualizar_dados)
botao_atualizar.pack()

# Exibição de imagem (replace with desired image)
#imagem = PhotoImage(file=r"C:\Users\thiag\Downloads\abacaxi.png")
#label_imagem = Label(image=imagem)
#label_imagem.pack()

janela.mainloop()
