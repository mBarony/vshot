@echo off
chcp 65001 >nul
rem Instala o reconhecimento óptico de caracteres do português, que o VShot usa no Ctrl+Shift+5.
rem Sem ele, o OCR do Windows lê com o reconhecimento do inglês e erra os acentos.
rem Instalar um recurso do Windows pede administrador: sem isso, o arquivo se abre de novo pedindo a permissão.

fltmc >nul 2>&1
if errorlevel 1 (
    echo Pedindo permissão de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

echo Procurando o reconhecimento de caracteres do português no Windows Update...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$recurso = Get-WindowsCapability -Online | Where-Object { $_.Name -like 'Language.OCR*pt-BR*' } | Select-Object -First 1;" ^
  "if (-not $recurso) { Write-Host 'Esta versão do Windows não oferece o reconhecimento do português.'; exit 2 }" ^
  "if ($recurso.State -eq 'Installed') { Write-Host 'O reconhecimento do português já está instalado.'; exit 0 }" ^
  "Write-Host 'Baixando e instalando. Pode levar alguns minutos...';" ^
  "Add-WindowsCapability -Online -Name $recurso.Name | Out-Null;" ^
  "if ((Get-WindowsCapability -Online -Name $recurso.Name).State -eq 'Installed') { Write-Host 'Pronto: o VShot passa a ler o português no próximo Ctrl+Shift+5.'; exit 0 }" ^
  "Write-Host 'A instalação não terminou. Confira a conexão com a internet e tente de novo.'; exit 1"

echo.
pause
