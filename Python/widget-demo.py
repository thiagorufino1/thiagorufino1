"""A demo script to showcase the Sun Valley ttk theme."""

import tkinter
from tkinter import ttk

import sv_ttk


class CheckBoxDemo(ttk.LabelFrame):
    def __init__(self, parent):
        super().__init__(parent, text="Checkbuttons", padding=15)

        self.var_1 = tkinter.BooleanVar(self, False)
        self.var_2 = tkinter.BooleanVar(self, True)

        self.add_widgets()

    def add_widgets(self):
        self.checkbox_1 = ttk.Checkbutton(self, text="Europe")
        self.checkbox_1.grid(row=0, column=0, pady=(0, 10), sticky="w")

        self.checkbox_2 = ttk.Checkbutton(self, text="France", variable=self.var_1)
        self.checkbox_2.grid(row=1, column=0, padx=(30, 0), pady=(5, 10), sticky="w")

        self.checkbox_3 = ttk.Checkbutton(self, text="Germany", variable=self.var_2)
        self.checkbox_3.grid(row=2, column=0, padx=(30, 0), pady=10, sticky="w")

        self.checkbox_4 = ttk.Checkbutton(self, text="Fooland")
        self.checkbox_4.state({"disabled", "!alternate"})
        self.checkbox_4.grid(row=3, column=0, padx=(30, 0), pady=(10, 0), sticky="w")


class RadioButtonDemo(ttk.LabelFrame):
    def __init__(self, parent):
        super().__init__(parent, text="Radiobuttons", padding=15)

        self.var = tkinter.IntVar()

        self.add_widgets()

    def add_widgets(self):
        self.radio_1 = ttk.Radiobutton(self, text="Dog", variable=self.var, value=0)
        self.radio_1.grid(row=0, column=0, pady=(0, 10), sticky="w")

        self.radio_1 = ttk.Radiobutton(self, text="Cat", variable=self.var, value=1)
        self.radio_1.grid(row=1, column=0, pady=10, sticky="w")

        self.radio_1 = ttk.Radiobutton(self, text="Neither", state="disabled")
        self.radio_1.grid(row=2, column=0, pady=(10, 0), sticky="w")


class InputsAndButtonsDemo(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, style="Card.TFrame", padding=15)

        self.columnconfigure(0, weight=1)

        self.add_widgets()

    def add_widgets(self):
        self.entry = ttk.Entry(self)
        self.entry.insert(0, "Type here")
        self.entry.grid(row=0, column=0, padx=5, pady=(0, 10), sticky="ew")

        self.spinbox = ttk.Spinbox(self, from_=0, to=100, increment=0.01)
        self.spinbox.insert(0, "3.14")
        self.spinbox.grid(row=1, column=0, padx=5, pady=10, sticky="ew")

        combo_list = ["Lorem", "Ipsum", "Dolor"]

        self.combobox = ttk.Combobox(self, values=combo_list)
        self.combobox.current(0)
        self.combobox.grid(row=2, column=0, padx=5, pady=10, sticky="ew")

        self.readonly_combo = ttk.Combobox(self, state="readonly", values=combo_list)
        self.readonly_combo.current(1)
        self.readonly_combo.grid(row=3, column=0, padx=5, pady=10, sticky="ew")

        self.menu = tkinter.Menu(self)
        for n in range(1, 5):
            self.menu.add_command(label=f"Menu item {n}")

        self.menubutton = ttk.Menubutton(self, text="Dropdown", menu=self.menu)
        self.menubutton.grid(row=4, column=0, padx=5, pady=10, sticky="nsew")

        self.separator = ttk.Separator(self)
        self.separator.grid(row=5, column=0, pady=10, sticky="ew")

        self.button = ttk.Button(self, text="Click me!")
        self.button.grid(row=6, column=0, padx=5, pady=10, sticky="ew")

        self.accentbutton = ttk.Button(self, text=" I love it!", style="Accent.TButton")
        self.accentbutton.grid(row=7, column=0, padx=5, pady=10, sticky="ew")

        self.togglebutton = ttk.Checkbutton(self, text="Toggle me!", style="Toggle.TButton")
        self.togglebutton.grid(row=8, column=0, padx=5, pady=10, sticky="nsew")


class PanedDemo(ttk.PanedWindow):
    def __init__(self, parent):
        super().__init__(parent)

        self.pane_1 = ttk.Frame(self, padding=(0, 0, 0, 10))
        self.pane_2 = ttk.Frame(self, padding=(0, 10, 5, 0))
        self.add(self.pane_1, weight=1)
        self.add(self.pane_2, weight=3)

        self.var = tkinter.IntVar(self, 47)

        self.add_widgets()

    def add_widgets(self):
        self.scrollbar = ttk.Scrollbar(self.pane_1)
        self.scrollbar.pack(side="right", fill="y")

        self.tree = ttk.Treeview(
            self.pane_1,
            columns=(1, 2),
            height=11,
            selectmode="browse",
            show=("tree",),
            yscrollcommand=self.scrollbar.set,
        )
        self.scrollbar.config(command=self.tree.yview)

        self.tree.pack(expand=True, fill="both")

        self.tree.column("#0", anchor="w", width=140)
        self.tree.column(1, anchor="w", width=100)
        self.tree.column(2, anchor="w", width=100)

        tree_data = [
            *[("", x, "Foo", ("Bar", "Baz")) for x in range(1, 7)],
            (6, 7, "Kali", ("2013", "Rolling")),
            (6, 8, "Ubuntu", ("2004", "Fixed")),
            (8, 9, "Mint", ("2006", "Fixed")),
            (8, 10, "Zorin", ("2008", "Fixed")),
            (8, 11, "Pop!_OS", ("2017", "Fixed")),
            (6, 12, "MX", ("2014", "Semi-rolling")),
            (6, 13, "Devuan", ("2016", "Semi-rolling")),
            ("", 14, "Arch", ("2002", "Rolling, btw")),
            (14, 15, "Manjaro", ("2011", "Rolling")),
            (14, 16, "Arco", ("2018", "Rolling")),
            (14, 17, "EndeavourOS", ("2019", "Rolling")),
            *[("", x, "Foo", ("Bar", "Baz")) for x in range(18, 26)],
        ]

        for item in tree_data:
            parent, iid, text, values = item
            self.tree.insert(parent=parent, index="end", iid=iid, text=text, values=values)

            if not parent or iid in {8, 21}:
                self.tree.item(iid, open=True)

        self.tree.selection_set(14)
        self.tree.see(7)

        self.notebook = ttk.Notebook(self.pane_2)
        self.notebook.pack(expand=True, fill="both")

        for n in range(1, 4):
            setattr(self, f"tab_{n}", ttk.Frame(self.notebook))
            self.notebook.add(getattr(self, f"tab_{n}"), text=f"Tab {n}")

        for index in range(2):
            self.tab_1.columnconfigure(index, weight=1)
            self.tab_1.rowconfigure(index, weight=1)

        self.scale = ttk.Scale(
            self.tab_1,
            from_=100,
            to=0,
            variable=self.var,
        )
        self.scale.grid(row=0, column=0, padx=(20, 10), pady=(20, 10), sticky="ew")

        self.progress = ttk.Progressbar(self.tab_1, value=0, variable=self.var, mode="determinate")
        self.progress.grid(row=0, column=1, padx=(10, 20), pady=(20, 10), sticky="ew")

        self.switch = ttk.Checkbutton(
            self.tab_1, text="Dark theme", style="Switch.TCheckbutton", command=sv_ttk.toggle_theme
        )
        self.switch.grid(row=1, column=0, columnspan=2, pady=10)


class App(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent, padding=15)

        for index in range(2):
            self.columnconfigure(index, weight=1)
            self.rowconfigure(index, weight=1)

        CheckBoxDemo(self).grid(row=0, column=0, padx=(0, 10), pady=(0, 20), sticky="nsew")
        RadioButtonDemo(self).grid(row=1, column=0, padx=(0, 10), sticky="nsew")
        InputsAndButtonsDemo(self).grid(
            row=0, column=1, rowspan=2, padx=10, pady=(10, 0), sticky="nsew"
        )
        PanedDemo(self).grid(row=0, column=3, rowspan=2, padx=10, pady=(10, 0), sticky="nsew")


def main():
    root = tkinter.Tk()
    root.title("")

    sv_ttk.set_theme("light")

    App(root).pack(expand=True, fill="both")

    root.mainloop()


if __name__ == "__main__":
    main()