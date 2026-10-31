# Mede o consumo da aplicação sem tocar em teclado nem mouse: as ações são disparadas
# mandando WM_COMMAND direto para a janela, e não simulando teclas. Assim a medição pode
# rodar com a máquina em uso, sem disputar o cursor com quem estiver nela.
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class U {
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, IntPtr n);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetGuiResources(IntPtr h, uint f);
}
'@

$raiz = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$exe = Join-Path $raiz 'build/vshot.exe'
if (-not (Test-Path $exe)) {
  Write-Output "não encontrei $exe; compile antes com: v -prod -cc gcc -subsystem windows -o build/vshot.exe src"
  exit 1
}

# Identificadores do menu da bandeja e da barra de ações, como estão em main.v e editor.v.
$WM_COMMAND = 0x0111
$MENU_TELA = 1
$MENU_EDITOR = 3
$ID_FECHAR = 106

function Metrica($rotulo) {
  $p = Get-Process vshot -ErrorAction SilentlyContinue
  if (-not $p) { Write-Output ("{0,-28} processo ausente" -f $rotulo); return }
  $p.Refresh()
  Write-Output ("{0,-28} working={1,7} KB  pico={2,7} KB  privada={3,7} KB  gdi={4,3}  user={5,3}" -f `
    $rotulo, [math]::Round($p.WorkingSet64/1KB), [math]::Round($p.PeakWorkingSet64/1KB),
    [math]::Round($p.PrivateMemorySize64/1KB), [U]::GetGuiResources($p.Handle,0),
    [U]::GetGuiResources($p.Handle,1))
}

Get-Process vshot -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
Write-Output ("executável: {0} KB" -f [math]::Round((Get-Item $exe).Length/1KB))

Start-Process $exe
Start-Sleep -Seconds 5
Metrica 'parada, recém-aberta'

$app = [U]::FindWindow('VShot', [IntPtr]::Zero)
foreach ($i in 1..3) {
  [U]::PostMessage($app, $WM_COMMAND, [IntPtr]$MENU_TELA, [IntPtr]0) | Out-Null
  Start-Sleep -Seconds 2
}
Metrica 'depois de três capturas'

# A aplicação ignora comandos enquanto ainda está ocupada com a captura anterior, para não
# empilhar uma janela dentro da outra. Insistir até o editor aparecer evita medir um editor
# que nunca abriu e anotar o número errado.
$editor = [IntPtr]::Zero
foreach ($tentativa in 1..10) {
  [U]::PostMessage($app, $WM_COMMAND, [IntPtr]$MENU_EDITOR, [IntPtr]0) | Out-Null
  Start-Sleep -Seconds 3
  $editor = [U]::FindWindow('VShotEditor', [IntPtr]::Zero)
  if ($editor -ne [IntPtr]::Zero) { break }
}
if ($editor -eq [IntPtr]::Zero) {
  Write-Output 'o editor não abriu depois de dez tentativas; a medição abaixo não vale'
  Get-Process vshot -ErrorAction SilentlyContinue | Stop-Process -Force
  exit 1
}
Metrica 'com o editor aberto'

[U]::PostMessage($editor, $WM_COMMAND, [IntPtr]$ID_FECHAR, [IntPtr]0) | Out-Null
Start-Sleep -Seconds 5
Metrica 'parada, depois de usar'

Get-Process vshot -ErrorAction SilentlyContinue | Stop-Process -Force
