@echo off
set Folder=C:\Windows\RapidScripts\UtilityScripts\Recommendations
schtasks /create /sc ONLOGON /tn "HideRecommended" /tr "wscript %Folder%\RunHide.vbs" /ru "SYSTEM" /rl HIGHEST /f
