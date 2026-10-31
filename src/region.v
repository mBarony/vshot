module main

fn C.LoadCursorW(instance voidptr, name voidptr) voidptr

fn C.CreateSolidBrush(color u32) voidptr

fn C.PatBlt(hdc voidptr, x int, y int, width int, height int, rop u32) bool

fn C.AlphaBlend(dst voidptr, x int, y int, width int, height int, src voidptr, src_x int, src_y int, src_width int, src_height int, blend C.BLENDFUNCTION) bool

fn C.BeginPaint(hwnd voidptr, paint voidptr) voidptr

fn C.EndPaint(hwnd voidptr, paint voidptr) bool

fn C.InvalidateRect(hwnd voidptr, area voidptr, erase bool) bool

fn C.SetWindowLongPtrW(hwnd voidptr, index int, value isize) isize

fn C.GetWindowLongPtrW(hwnd voidptr, index int) isize

fn C.ShowWindow(hwnd voidptr, command int) bool

fn C.SetFocus(hwnd voidptr) voidptr

fn C.CreatePen(style int, width int, color u32) voidptr

fn C.GetStockObject(index int) voidptr

fn C.Rectangle(hdc voidptr, left int, top int, right int, bottom int) bool

const wm_create = u32(0x0001)
const wm_paint = u32(0x000f)
const wm_erasebkgnd = u32(0x0014)
const wm_keydown = u32(0x0100)
const wm_mousemove = u32(0x0200)
const wm_lbuttondown = u32(0x0201)
const wm_lbuttonup = u32(0x0202)
const wm_rbuttondown = u32(0x0204)

const ws_popup = u32(0x80000000)
const ws_ex_topmost = u32(0x00000008)
// WS_EX_TOOLWINDOW mantém a janela de seleção fora da barra de tarefas e do Alt+Tab.
const ws_ex_toolwindow = u32(0x00000080)
const sw_show = 5
const gwlp_userdata = -21
const vk_escape = u32(0x1b)
const idc_cross = voidptr(32515)
const null_brush = 5
const ps_solid = 0
const blackness = u32(0x00000042)

// Quanto do preto entra na parte não escolhida da tela, de 0 a 255.
const shade_alpha = u8(110)
// COLORREF é 0x00bbggrr, então este é o branco da borda da seleção.
const border_color = u32(0x00ffffff)

const region_class = 'VShotRegion'

// @[typedef] porque BLENDFUNCTION é um typedef no windows.h: sem isso o V escreve
// `struct BLENDFUNCTION`, que não existe.
@[typedef]
struct C.BLENDFUNCTION {
	BlendOp             u8
	BlendFlags          u8
	SourceConstantAlpha u8
	AlphaFormat         u8
}

// @[typedef] porque PAINTSTRUCT é um typedef no windows.h. Sem isso o V gera a própria
// definição da struct, e o programa passa a trabalhar com um layout inventado.
@[typedef]
struct C.PAINTSTRUCT {
mut:
	hdc     voidptr
	rcPaint C.RECT
}

// @[typedef] porque CREATESTRUCTW é um typedef no windows.h. Sem isso o V gera a própria
// definição da struct, e o programa passa a trabalhar com um layout inventado.
@[typedef]
struct C.CREATESTRUCTW {
	lpCreateParams voidptr
}

// Selection é o estado do arrasto, vivo apenas enquanto a janela de seleção existe.
struct Selection {
mut:
	frozen    voidptr
	shaded    voidptr
	width     int
	height    int
	origin_x  int
	origin_y  int
	cursor_x  int
	cursor_y  int
	dragging  bool
	done      bool
	confirmed bool
}

// area devolve o retângulo escolhido já normalizado, porque o arrasto pode ir para qualquer um dos quatro lados. As duas pontas entram, a origem e o pixel sob o ponteiro: o ponteiro nunca chega à largura nem à altura da tela, e sem isso a última coluna e a última linha nunca poderiam ser escolhidas.
fn (s Selection) area() Rect {
	left := if s.origin_x < s.cursor_x { s.origin_x } else { s.cursor_x }
	top := if s.origin_y < s.cursor_y { s.origin_y } else { s.cursor_y }
	right := if s.origin_x > s.cursor_x { s.origin_x } else { s.cursor_x }
	bottom := if s.origin_y > s.cursor_y { s.origin_y } else { s.cursor_y }
	return Rect{
		x: left
		y: top
		width: right - left + 1
		height: bottom - top + 1
	}
}

// select_region mostra a tela congelada e deixa o usuário arrastar um retângulo sobre
// ela. Devolve none se ele desistir com Esc, com o botão direito ou com um clique seco.
fn select_region(frozen Frozen, instance voidptr) ?Rect {
	shaded := shade(frozen) or { return none }
	defer {
		shaded.release()
	}

	// O estado fica na pilha desta função, que só retorna depois que a janela morre.
	// Assim o coletor do V continua enxergando o ponteiro que o Windows guarda.
	mut state := Selection{
		frozen: frozen.dc
		shaded: shaded.dc
		width: frozen.width
		height: frozen.height
	}

	class_name := region_class.to_wide()
	class := C.WNDCLASSW{
		lpfnWndProc: voidptr(region_proc)
		hInstance: instance
		hCursor: C.LoadCursorW(unsafe { nil }, idc_cross)
		lpszClassName: voidptr(class_name)
	}
	// Registrar de novo falha da segunda captura em diante, e tudo bem: só interessa que
	// a classe exista. Um problema de verdade aparece no CreateWindowExW logo abaixo.
	C.RegisterClassW(&class)

	hwnd := C.CreateWindowExW(ws_ex_topmost | ws_ex_toolwindow, class_name, class_name, ws_popup, frozen.left, frozen.top, frozen.width, frozen.height, unsafe { nil }, unsafe { nil }, instance, &state)
	if hwnd == unsafe { nil } {
		return none
	}
	C.ShowWindow(hwnd, sw_show)
	C.SetForegroundWindow(hwnd)
	C.SetFocus(hwnd)

	// Laço próprio, separado do laço principal: a seleção é modal e termina sozinha, pelo done que o WM_DESTROY liga. Um Sair escolhido na bandeja no meio dela é repassado ao laço principal.
	mut message := C.MSG{}
	for !state.done && C.GetMessageW(&message, unsafe { nil }, 0, 0) > 0 {
		C.TranslateMessage(&message)
		C.DispatchMessageW(&message)
	}
	end_nested_loop(hwnd, state.done)

	// Um clique seco, ou um arrasto que não saiu do lugar num dos eixos, desiste.
	if !state.confirmed || state.origin_x == state.cursor_x || state.origin_y == state.cursor_y {
		return none
	}
	return state.area()
}

// region_proc trata o arrasto sobre a tela congelada.
fn region_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	if message == wm_create {
		create := unsafe { &C.CREATESTRUCTW(lparam) }
		C.SetWindowLongPtrW(hwnd, gwlp_userdata, isize(create.lpCreateParams))
		return 0
	}
	pointer := voidptr(C.GetWindowLongPtrW(hwnd, gwlp_userdata))
	if pointer == unsafe { nil } {
		return C.DefWindowProcW(hwnd, message, wparam, lparam)
	}
	mut state := unsafe { &Selection(pointer) }

	if message == wm_erasebkgnd {
		// O fundo é sempre repintado por inteiro no WM_PAINT; apagar antes só piscaria.
		return 1
	}
	if message == wm_paint {
		mut paint := C.PAINTSTRUCT{}
		hdc := C.BeginPaint(hwnd, &paint)
		paint_selection(hdc, state)
		C.EndPaint(hwnd, &paint)
		return 0
	}
	if message == wm_destroy {
		// Toda saída passa por aqui, Alt+F4 incluído: sem o done o laço de select_region não terminaria, e a aplicação ficaria ocupada para sempre.
		state.done = true
		return 0
	}
	if region_mouse(hwnd, mut state, message, lparam) {
		return 0
	}
	if message == wm_rbuttondown || (message == wm_keydown && u32(wparam) == vk_escape) {
		C.DestroyWindow(hwnd)
		return 0
	}
	return C.DefWindowProcW(hwnd, message, wparam, lparam)
}

// region_mouse trata o arrasto: o botão apertado marca a origem, o movimento estica a área e o botão solto confirma. Devolve falso no que não é do arrasto.
fn region_mouse(hwnd voidptr, mut state Selection, message u32, lparam isize) bool {
	if message == wm_lbuttondown {
		// Um arrasto cujo botão solto não chegou deixou o retângulo dele desenhado.
		invalidate_area(hwnd, state.area())
		state.origin_x = low_word(lparam)
		state.origin_y = high_word(lparam)
		state.cursor_x = state.origin_x
		state.cursor_y = state.origin_y
		state.dragging = true
		return true
	}
	if message == wm_mousemove && state.dragging {
		before := state.area()
		state.cursor_x = low_word(lparam)
		state.cursor_y = high_word(lparam)
		// Só o que mudou é repintado: o retângulo antigo, que volta a escurecer, e o novo. Repintar a tela virtual inteira a cada movimento copiava dezenas de megabytes por quadro em dois monitores grandes.
		invalidate_area(hwnd, before)
		invalidate_area(hwnd, state.area())
		return true
	}
	if message == wm_lbuttonup && state.dragging {
		state.cursor_x = low_word(lparam)
		state.cursor_y = high_word(lparam)
		state.dragging = false
		state.confirmed = true
		C.DestroyWindow(hwnd)
		return true
	}
	return false
}

// invalidate_area pede que só aquele retângulo da janela seja repintado. A borda branca fica dentro dele, porque o Rectangle do GDI não pinta a última coluna nem a última linha.
fn invalidate_area(hwnd voidptr, area Rect) {
	rect := C.RECT{
		left: area.x
		top: area.y
		right: area.x + area.width
		bottom: area.y + area.height
	}
	C.InvalidateRect(hwnd, &rect, false)
}

// paint_selection cobre a tela com a cópia escurecida e devolve o brilho original só
// dentro da área escolhida, que ganha uma borda para ficar visível sobre qualquer fundo.
fn paint_selection(hdc voidptr, state &Selection) {
	C.BitBlt(hdc, 0, 0, state.width, state.height, state.shaded, 0, 0, srccopy)
	// Só há seleção durante o arrasto: antes do primeiro clique, o retângulo de um pixel na origem seria um ponto branco no canto da tela.
	if !state.dragging {
		return
	}
	area := state.area()
	C.BitBlt(hdc, area.x, area.y, area.width, area.height, state.frozen, area.x, area.y, srccopy)

	pen := C.CreatePen(ps_solid, 1, border_color)
	old_pen := C.SelectObject(hdc, pen)
	old_brush := C.SelectObject(hdc, C.GetStockObject(null_brush))
	C.Rectangle(hdc, area.x, area.y, area.x + area.width, area.y + area.height)
	C.SelectObject(hdc, old_brush)
	C.SelectObject(hdc, old_pen)
	C.DeleteObject(pen)
}

// shade devolve uma cópia da tela congelada com uma camada preta translúcida por cima.
fn shade(source Frozen) !Frozen {
	copy := new_surface(source.dc, source.width, source.height)!
	if !C.BitBlt(copy.dc, 0, 0, source.width, source.height, source.dc, 0, 0, srccopy) {
		copy.release()
		return error('BitBlt da cópia escurecida falhou')
	}
	// Um único pixel preto esticado sobre tudo: é o AlphaBlend que faz o escurecimento,
	// e ele não se importa com o tamanho da origem.
	dot := new_surface(source.dc, 1, 1) or {
		copy.release()
		return err
	}
	defer {
		dot.release()
	}
	C.PatBlt(dot.dc, 0, 0, 1, 1, blackness)
	C.AlphaBlend(copy.dc, 0, 0, source.width, source.height, dot.dc, 0, 0, 1, 1, C.BLENDFUNCTION{
		SourceConstantAlpha: shade_alpha
	})
	return copy
}

// As coordenadas do mouse chegam empacotadas nos dois meios de lParam, e são com sinal
// porque um monitor à esquerda do principal tem coordenadas negativas.
fn low_word(value isize) int {
	return int(i16(u16(value & 0xffff)))
}

fn high_word(value isize) int {
	return int(i16(u16((value >> 16) & 0xffff)))
}
