Option Explicit
Dim fso, sh, base
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
base = fso.GetParentFolderName(WScript.ScriptFullName)
sh.Run """" & base & "\python\python.exe"" -X utf8 """ & base & "\injector.py"" --port 9223 --script """ & base & "\bilibili-accelerator.user.js"" --logfile """ & base & "\injector.log""", 0, False
