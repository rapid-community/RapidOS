Path = "C:\Windows\RapidScripts\UtilityScripts\Recommendations"
CreateObject("Wscript.Shell").Run "powershell.exe -nop -ep bypass -F """ & Path & "\HideRecommended.ps1""", 0, False
