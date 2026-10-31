module main

#flag windows -ldwmapi

// A faixa do texto copiado. Depois da captura de texto, uma faixa discreta aparece no topo central da tela: à esquerda, o começo do que foi copiado; à direita, um botão só, que copia o texto de novo sem as quebras de linha. Ela não toma o foco de quem estava digitando, fica por cima das outras janelas e some sozinha, a não ser enquanto o ponteiro está sobre ela.

fn C.GetWindowRect(hwnd voidptr, area &C.RECT) bool

fn C.RoundRect(hdc voidptr, left int, top int, right int, bottom int, width int, height int) bool

fn C.DwmFlush() int

fn C.DwmSetWindowAttribute(hwnd voidptr, attribute u32, value voidptr, size u32) int

const text_popup_class = 'VShotTexto'
const text_popup_width = 560
const text_popup_height = 64
const text_popup_padding = 12
const text_button_width = 190
const text_button_height = 34
const text_button_label = 'Remover quebras de linha'
// Quanto a faixa fica na tela e, quando o ponteiro está sobre ela, de quanto em quanto ela confere de novo se ele saiu.
const text_popup_timer = usize(1)
const text_popup_life = u32(8000)
const text_popup_linger = u32(1000)
const ws_ex_noactivate = u32(0x08000000)
const sw_shownoactivate = 4
const wm_mouseactivate = u32(0x0021)
const ma_noactivate = 3
// DT_EDITCONTROL faz a reticência cair no fim da última linha que cabe, e não cortar uma linha pela metade.
const dt_editcontrol = u32(0x2000)
// As quinas arredondadas do Windows 11: quem arredonda e desenha a borda é o DWM, suavizando as duas, o que uma região recortada à mão não faria.
const dwmwa_window_corner_preference = u32(33)
const dwmwa_border_color = u32(34)
const dwmwcp_round = u32(2)

// TextPopup é o estado da faixa. Ele mora na App, que vive na pilha do main: a janela guarda um ponteiro para ele, e o coletor do V precisa continuar enxergando o texto.
struct TextPopup {
mut:
	hwnd  voidptr
	owner voidptr
	text  string
}

// show_text_popup mostra a faixa para o texto que acabou de ser copiado, no monitor do ponteiro, fechando antes a que ainda estivesse aberta.
fn show_text_popup(mut popup TextPopup, owner voidptr, text string) {
	close_text_popup(mut popup)
	popup.owner = owner
	popup.text = text
	instance := C.GetModuleHandleW(unsafe { nil })
	class_name := text_popup_class.to_wide()
	class := C.WNDCLASSW{
		lpfnWndProc: voidptr(text_popup_proc)
		hInstance: instance
		hCursor: C.LoadCursorW(unsafe { nil }, idc_arrow)
		lpszClassName: voidptr(class_name)
	}
	// Registrar de novo falha da segunda faixa em diante, e tudo bem: só interessa que a classe exista.
	C.RegisterClassW(&class)
	area := text_popup_rect(work_area_at_cursor())
	popup.hwnd = C.CreateWindowExW(ws_ex_topmost | ws_ex_toolwindow | ws_ex_noactivate, class_name,
		class_name, ws_popup, area.x, area.y, area.width, area.height, unsafe { nil }, unsafe { nil },
		instance, &popup)
	if popup.hwnd == unsafe { nil } {
		return
	}
	round_corners(popup.hwnd)
	C.ShowWindow(popup.hwnd, sw_shownoactivate)
	C.SetTimer(popup.hwnd, text_popup_timer, text_popup_life, unsafe { nil })
}

// close_text_popup fecha a faixa, se houver uma aberta, e espera o Windows tirá-la da tela: logo em seguida pode vir uma captura, e a faixa não pode sair na imagem.
fn close_text_popup(mut popup TextPopup) {
	if popup.hwnd == unsafe { nil } {
		return
	}
	C.DestroyWindow(popup.hwnd)
	popup.hwnd = unsafe { nil }
	C.DwmFlush()
}

// round_corners pede ao DWM as quinas arredondadas e a borda na cor das caixas do editor. Num Windows sem esse recurso a faixa sai de quinas retas e sem borda, e continua funcionando.
fn round_corners(hwnd voidptr) {
	mut corner := dwmwcp_round
	C.DwmSetWindowAttribute(hwnd, dwmwa_window_corner_preference, &corner, sizeof(u32))
	mut border := options_border_color
	C.DwmSetWindowAttribute(hwnd, dwmwa_border_color, &border, sizeof(u32))
}

// text_popup_rect põe a faixa no centro da área de trabalho, encostada na borda de cima.
fn text_popup_rect(work Rect) Rect {
	return Rect{
		x: work.x + (work.width - text_popup_width) / 2
		y: work.y
		width: text_popup_width
		height: text_popup_height
	}
}

// work_area_at_cursor é a área de trabalho — a tela sem a barra de tarefas — do monitor em que o ponteiro está, que é onde a área do texto acabou de ser escolhida.
fn work_area_at_cursor() Rect {
	_, work := monitor_at(cursor_position())
	return work
}

// text_button_rect é o botão, na ponta direita da faixa e centrado na altura dela.
fn text_button_rect() Rect {
	return Rect{
		x: text_popup_width - text_popup_padding - text_button_width
		y: (text_popup_height - text_button_height) / 2
		width: text_button_width
		height: text_button_height
	}
}

// text_preview_rect é onde a amostra do texto cabe: da borda esquerda até perto do botão, em até duas linhas.
fn text_preview_rect() Rect {
	return Rect{
		x: text_popup_padding
		y: text_popup_padding
		width: text_button_rect().x - 2 * text_popup_padding
		height: text_popup_height - 2 * text_popup_padding
	}
}

// text_popup_proc trata a faixa: o desenho, o clique que não a ativa, o clique no botão e o tempo de vida.
fn text_popup_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	if message == wm_create {
		create := unsafe { &C.CREATESTRUCTW(lparam) }
		C.SetWindowLongPtrW(hwnd, gwlp_userdata, isize(create.lpCreateParams))
		return 0
	}
	pointer := voidptr(C.GetWindowLongPtrW(hwnd, gwlp_userdata))
	if pointer == unsafe { nil } {
		return C.DefWindowProcW(hwnd, message, wparam, lparam)
	}
	mut popup := unsafe { &TextPopup(pointer) }
	if message == wm_paint {
		mut paint := C.PAINTSTRUCT{}
		hdc := C.BeginPaint(hwnd, &paint)
		paint_text_popup(hdc, popup)
		C.EndPaint(hwnd, &paint)
		return 0
	}
	// Um clique na faixa não tira o foco de quem estava digitando.
	if message == wm_mouseactivate {
		return ma_noactivate
	}
	if message == wm_lbuttonup {
		popup.press(int(i16(u16(lparam & 0xffff))), int(i16(u16((lparam >> 16) & 0xffff))))
		return 0
	}
	if message == wm_timer {
		popup.expire()
		return 0
	}
	return C.DefWindowProcW(hwnd, message, wparam, lparam)
}

// press trata o clique na faixa: no botão, o texto é copiado de novo sem as quebras de linha, e a faixa fecha; no resto dela, nada acontece.
fn (mut popup TextPopup) press(x int, y int) {
	if !contains(text_button_rect(), x, y) {
		return
	}
	copy_text(popup.owner, joined_lines(popup.text)) or { tray_notify(popup.owner, app_name, err.msg()) }
	close_text_popup(mut popup)
}

// expire fecha a faixa quando o tempo dela acaba — a não ser que o ponteiro esteja sobre ela, e aí ela confere de novo daqui a pouco.
fn (mut popup TextPopup) expire() {
	mut cursor := C.POINT{}
	C.GetCursorPos(&cursor)
	mut box := C.RECT{}
	C.GetWindowRect(popup.hwnd, &box)
	if cursor.x >= box.left && cursor.x < box.right && cursor.y >= box.top && cursor.y < box.bottom {
		C.SetTimer(popup.hwnd, text_popup_timer, text_popup_linger, unsafe { nil })
		return
	}
	close_text_popup(mut popup)
}

// paint_text_popup desenha a faixa: o fundo, a amostra do texto — até onde couber, com reticências — e o botão. A borda não é desenhada aqui: quem a desenha, junto com as quinas arredondadas, é o DWM.
fn paint_text_popup(hdc voidptr, popup &TextPopup) {
	mut whole := C.RECT{
		right: text_popup_width
		bottom: text_popup_height
	}
	background := C.CreateSolidBrush(options_color)
	C.FillRect(hdc, &whole, background)
	C.DeleteObject(background)
	font := C.CreateFontW(-14, 0, 0, 0, 400, 0, 0, 0, default_charset, 0, 0, antialiased_quality,
		0, 'Segoe UI'.to_wide())
	old_font := C.SelectObject(hdc, font)
	defer {
		C.SelectObject(hdc, old_font)
		C.DeleteObject(font)
	}
	C.SetBkMode(hdc, transparent_bk)
	C.SetTextColor(hdc, toolbar_text_color)
	preview := text_preview_rect()
	mut place := C.RECT{
		left: preview.x
		top: preview.y
		right: preview.x + preview.width
		bottom: preview.y + preview.height
	}
	C.DrawTextW(hdc, popup.text.to_wide(), -1, &place, dt_wordbreak | dt_noprefix | dt_end_ellipsis | dt_editcontrol)
	draw_text_button(hdc)
}

// draw_text_button desenha o botão num cinza escuro, discreto: o dos botões acesos da barra do editor, um tom acima do fundo da faixa, só o bastante para ele se ler como botão.
fn draw_text_button(hdc voidptr) {
	button := text_button_rect()
	brush := C.CreateSolidBrush(toolbar_active_color)
	pen := C.CreatePen(ps_solid, 1, toolbar_active_color)
	old_brush := C.SelectObject(hdc, brush)
	old_pen := C.SelectObject(hdc, pen)
	C.RoundRect(hdc, button.x, button.y, button.x + button.width, button.y + button.height, 8, 8)
	C.SelectObject(hdc, old_brush)
	C.SelectObject(hdc, old_pen)
	C.DeleteObject(brush)
	C.DeleteObject(pen)
	C.SetTextColor(hdc, toolbar_icon_active_color)
	mut place := C.RECT{
		left: button.x
		top: button.y
		right: button.x + button.width
		bottom: button.y + button.height
	}
	C.DrawTextW(hdc, text_button_label.to_wide(), -1, &place, dt_singleline | dt_noprefix | dt_center | dt_vcenter)
}
