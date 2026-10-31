module main

fn C.OpenClipboard(owner voidptr) bool

fn C.EmptyClipboard() bool

fn C.SetClipboardData(format u32, handle voidptr) voidptr

fn C.CloseClipboard() bool

fn C.GlobalAlloc(flags u32, bytes usize) voidptr

fn C.GlobalLock(handle voidptr) voidptr

fn C.GlobalUnlock(handle voidptr) bool

fn C.GlobalFree(handle voidptr) voidptr

const cf_bitmap = u32(2)
const cf_unicodetext = u32(13)
const gmem_moveable = u32(0x0002)
// Quantas vezes pedir a área de transferência, e a pausa entre os pedidos.
const clipboard_tries = 10
const clipboard_pause = u32(20)

// open_clipboard abre a área de transferência, insistindo por um instante. Outro programa a segura por alguns milissegundos sempre que ela muda — o histórico do Windows e os gerenciadores de área de transferência fazem isso a cada cópia —, e uma tentativa só falhava à toa.
fn open_clipboard(hwnd voidptr) bool {
	for attempt in 0 .. clipboard_tries {
		if C.OpenClipboard(hwnd) {
			return true
		}
		if attempt < clipboard_tries - 1 {
			C.Sleep(clipboard_pause)
		}
	}
	return false
}

// copy_bitmap entrega a imagem à área de transferência. O bitmap não é liberado em caso
// de sucesso, e isso é proposital: quem recebe CF_BITMAP passa a ser o dono dele. Em caso
// de falha, quem libera é esta função, para o bitmap não ficar órfão.
//
// CF_BITMAP é um bitmap dependente do dispositivo, e o Windows deriva dele sozinho os
// formatos independentes que a maioria dos programas espera ao colar.
fn copy_bitmap(hwnd voidptr, bitmap voidptr) ! {
	if !open_clipboard(hwnd) {
		C.DeleteObject(bitmap)
		return error('A área de transferência está ocupada por outro programa')
	}
	C.EmptyClipboard()
	if C.SetClipboardData(cf_bitmap, bitmap) == unsafe { nil } {
		C.CloseClipboard()
		C.DeleteObject(bitmap)
		return error('Falha ao copiar para a área de transferência')
	}
	C.CloseClipboard()
}

// copy_text entrega um texto à área de transferência. O texto vai numa memória global que,
// entregue, passa a ser da área de transferência; só numa falha quem a devolve é esta
// função.
fn copy_text(hwnd voidptr, text string) ! {
	// A área de transferência do Windows espera as linhas separadas por CRLF: com o LF solto que o OCR e o QR code trazem, um campo de texto clássico, que não o aceita, colava as linhas grudadas.
	windows_text := text.replace('\r\n', '\n').replace('\n', '\r\n')
	units := utf16_length(windows_text) + 1
	handle := C.GlobalAlloc(gmem_moveable, usize(units * 2))
	if handle == unsafe { nil } {
		return error('Sem memória para a área de transferência')
	}
	target := C.GlobalLock(handle)
	unsafe { vmemcpy(target, windows_text.to_wide(), units * 2) }
	C.GlobalUnlock(handle)
	if !open_clipboard(hwnd) {
		C.GlobalFree(handle)
		return error('A área de transferência está ocupada por outro programa')
	}
	C.EmptyClipboard()
	if C.SetClipboardData(cf_unicodetext, handle) == unsafe { nil } {
		C.CloseClipboard()
		C.GlobalFree(handle)
		return error('Falha ao copiar para a área de transferência')
	}
	C.CloseClipboard()
}
