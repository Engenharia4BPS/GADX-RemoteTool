Set WshShell = CreateObject("WScript.Shell")
Set FSO = CreateObject("Scripting.FileSystemObject")

baseDir = FSO.GetParentFolderName(WScript.ScriptFullName)

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & baseDir & "\AnyDesk-GADX-Launcher.ps1" & """"

WshShell.Run cmd, 0, False