module main

fn C.SetCapture(hwnd voidptr) voidptr

fn C.ReleaseCapture() bool

fn C.GetCapture() voidptr

fn C.ScreenToClient(hwnd voidptr, point voidptr) bool

const wm_setcursor = u32(0x0020)
// A janela mudou de tamanho, e o Windows manda o tamanho novo do cliente no lparam.
const wm_size = u32(0x0005)
// Quanto a janela pode encolher e crescer. Chega antes do WM_CREATE, com a janela ainda sem estado.
const wm_getminmaxinfo = u32(0x0024)
// O código que o WM_SETCURSOR traz no lparam para a área de cliente. Os outros são da moldura — a borda que redimensiona, o título, os botões dele —, e o ponteiro deles é escolha do Windows.
const ht_client = 1
const wm_char = u32(0x0102)
const vk_delete = u32(0x2e)
// Avisa a janela que o mouse deixou de ser dela: outra janela o tomou, ou ela mesma o devolveu.
const wm_capturechanged = u32(0x0215)
// Avisa que o ponteiro saiu da janela, quando ela pediu o aviso com TrackMouseEvent.
const wm_mouseleave = u32(0x02a3)
const tme_leave = u32(0x00000002)

fn C.TrackMouseEvent(event voidptr) bool

// @[typedef] porque TRACKMOUSEEVENT é um typedef no windows.h. Sem isso o V gera a própria definição da struct, e o programa passa a trabalhar com um layout inventado.
@[typedef]
struct C.TRACKMOUSEEVENT {
	cbSize      u32
	dwFlags     u32
	hwndTrack   voidptr
	dwHoverTime u32
}

// editor_proc recebe as mensagens da janela do editor e fica com três: a criação, que é onde o estado se liga à janela; o menor tamanho, que o Windows pergunta antes disso, com a janela ainda sem estado; e o tamanho novo, que refaz o espaço da imagem antes de qualquer outra mensagem esbarrar nele. O resto vai para o dispatch_editor.
fn editor_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	if message == wm_create {
		create := unsafe { &C.CREATESTRUCTW(lparam) }
		C.SetWindowLongPtrW(hwnd, gwlp_userdata, isize(create.lpCreateParams))
		return 0
	}
	if message == wm_getminmaxinfo {
		limit_editor_size(lparam)
		return 0
	}
	pointer := voidptr(C.GetWindowLongPtrW(hwnd, gwlp_userdata))
	if pointer == unsafe { nil } {
		return C.DefWindowProcW(hwnd, message, wparam, lparam)
	}
	mut state := unsafe { &Editor(pointer) }
	if message == wm_size {
		editor_resized(hwnd, mut state, low_word(lparam), high_word(lparam))
		return 0
	}
	if handled := dispatch_editor(hwnd, mut state, message, wparam, lparam) {
		return handled
	}
	return C.DefWindowProcW(hwnd, message, wparam, lparam)
}

// dispatch_editor trata o que o editor trata e devolve none no que é do Windows.
fn dispatch_editor(hwnd voidptr, mut state Editor, message u32, wparam usize, lparam isize) ?isize {
	if message == wm_erasebkgnd {
		return isize(1)
	}
	if message == wm_paint {
		mut paint := C.PAINTSTRUCT{}
		hdc := C.BeginPaint(hwnd, &paint)
		paint_editor(hdc, mut state, paint.rcPaint)
		C.EndPaint(hwnd, &paint)
		return isize(0)
	}
	if message == wm_destroy {
		state.done = true
		return isize(0)
	}
	if message == wm_setcursor && editor_cursor(hwnd, state, wparam, lparam) {
		return isize(1)
	}
	if message == wm_mouseleave {
		editor_leave(hwnd, mut state)
		return isize(0)
	}
	// A paleta pende do painel de opções: quando o clique ou a tecla o levam embora, ela fecha junto.
	if editor_mouse(hwnd, mut state, message, lparam)
		|| editor_commands(hwnd, mut state, message, wparam) {
		state.settle_palette()
		return isize(0)
	}
	return none
}

// editor_commands reparte os atalhos, a roda e o teclado. Durante qualquer arrasto do botão esquerdo, o teclado e os atalhos esperam a soltura: desenhando, Esc fechava o editor, V trocava o retângulo em curso por um recorte, e desfazer mudava a vista debaixo do traço, que guarda a origem em pixels da janela; movendo, a marcação está fora da cena, e Esc, Delete, desfazer ou a tecla de uma ferramenta a apagariam, duplicariam ou perderiam. A roda só espera quando se move: desenhando, ela muda a espessura da prévia.
fn editor_commands(hwnd voidptr, mut state Editor, message u32, wparam usize) bool {
	if state.dragging && message in [wm_keydown, wm_command] {
		return true
	}
	if state.grab != .none && message == wm_mousewheel {
		return true
	}
	if message == wm_command {
		editor_command(hwnd, mut state, u32(wparam) & 0xffff)
		return true
	}
	if message == wm_mousewheel {
		editor_wheel(hwnd, mut state, wparam)
		return true
	}
	return editor_keyboard(hwnd, mut state, message, wparam)
}

// editor_keyboard reparte o que vem do teclado: o caractere do texto em digitação, a tecla
// apertada, a tecla solta, e a perda do foco — que solta tudo sem mandar tecla solta
// nenhuma, e deixaria a medida da régua presa na tela.
fn editor_keyboard(hwnd voidptr, mut state Editor, message u32, wparam usize) bool {
	if message == wm_char && state.typing {
		editor_char(hwnd, mut state, rune(wparam))
		return true
	}
	if message == wm_keydown {
		return editor_key(hwnd, mut state, u32(wparam))
	}
	if message == wm_keyup {
		return editor_key_up(hwnd, mut state, u32(wparam))
	}
	if message == wm_killfocus && state.probe != .none {
		state.probe = .none
		C.InvalidateRect(hwnd, unsafe { nil }, false)
	}
	return false
}

// editor_key_up cancela a prévia ao soltar a tecla; só o clique guarda uma régua.
fn editor_key_up(hwnd voidptr, mut state Editor, key u32) bool {
	probe := probe_for(key) or { return false }
	if state.probe == .none || probe != state.probe {
		return false
	}
	state.probe = .none
	state.status = state.hint()
	C.InvalidateRect(hwnd, unsafe { nil }, false)
	return true
}

// editor_cursor põe o ponteiro que o lugar sob o mouse pede, e diz se cuidou disso. Fora da área de cliente ele não responde, para a borda ficar com as setas de redimensionar que o Windows põe nela: respondendo por ela, o editor punha o ponteiro do lugar onde o mouse esteve por último, e quem viesse da barra encontrava a seta na borda. A posição vem do mouse agora, e não da última que chegou por mensagem, porque o Windows pergunta qual ponteiro usar antes de avisar que o mouse andou, e a resposta sairia sempre um movimento atrasada.
fn editor_cursor(hwnd voidptr, state &Editor, wparam usize, lparam isize) bool {
	if voidptr(wparam) != hwnd || low_word(lparam) != ht_client {
		return false
	}
	mut point := cursor_position()
	C.ScreenToClient(hwnd, &point)
	cursor := cursor_at(state, point.x, point.y) or { return false }
	C.SetCursor(C.LoadCursorW(unsafe { nil }, cursor))
	return true
}

// cursor_at escolhe o ponteiro do ponto, ou none para a cruz da classe da janela. Sobre a barra e sobre os painéis — o de opções, a paleta e os do tamanho e do zoom — fica a seta, porque ali se clica em botão em vez de desenhar; sobre eles ficava a cruz, como se o clique fosse desenhar. As alças e o corpo da marcação selecionada mudam o ponteiro com qualquer ferramenta na mão, para a alça dizer sozinha em que sentido estica. Em Selecionar, sobre outra marcação o clique a escolhe e fora da imagem não faz nada, e nos dois fica a seta; sobre a imagem vazia o arrasto recorta, e fica a cruz. Com uma ferramenta de desenho, o resto da imagem também é a cruz — menos no texto, que mostra o ponteiro de texto, alinhado ao lugar em que o texto nasce.
fn cursor_at(state &Editor, x int, y int) ?voidptr {
	if y < toolbar_height || state.covered(x, y) {
		return idc_arrow
	}
	grab := state.grab_at(x, y)
	if grab != .none {
		return cursor_for(grab)
	}
	inside := inside_view(state, x, y)
	if state.tool == .select {
		if state.shape_at(x, y) >= 0 || !inside {
			return idc_arrow
		}
		return none
	}
	if state.tool == .text && inside {
		return idc_ibeam
	}
	return none
}

// editor_mouse trata o começo do arrasto, o movimento e a soltura.
fn editor_mouse(hwnd voidptr, mut state Editor, message u32, lparam isize) bool {
	x := low_word(lparam)
	y := high_word(lparam)
	if message == wm_mousemove {
		editor_move(hwnd, mut state, x, y)
		return true
	}
	// Com CS_DBLCLKS, o segundo clique de um par rápido chega como duplo clique. Na imagem ele reabre um texto; fora disso é só mais um clique — engolido, o segundo aperto rápido para arrastar a marcação que o primeiro escolheu, ou para recortar, não fazia nada —, e sobre a barra e os painéis também: dois "+" rápidos no zoom sobem dois passos, e o clique não atravessa o painel até o texto que está embaixo dele.
	if message == wm_lbuttondblclk && y >= toolbar_height && !state.covered(x, y)
		&& editor_double(hwnd, mut state, x, y) {
		return true
	}
	if message == wm_lbuttondown || message == wm_lbuttondblclk {
		editor_left_down(hwnd, mut state, x, y)
		return true
	}
	if message == wm_rbuttondown {
		return editor_pan_start(hwnd, mut state, x, y)
	}
	if message == wm_capturechanged {
		editor_capture_lost(hwnd, mut state, voidptr(lparam))
		return true
	}
	return editor_button_up(hwnd, mut state, message, x, y)
}

// editor_left_down começa o que o clique esquerdo começa. Um arrasto que começa na janela é dela até o botão ser solto, mesmo que o ponteiro saia dela no caminho: sem a captura, soltar fora — em cima de outra janela — deixava o editor preso no meio do arrasto, sem nunca saber que ele terminou. Com o botão direito arrastando a imagem, o esquerdo não começa nada: o que ele desenhasse andaria junto com a vista.
fn editor_left_down(hwnd voidptr, mut state Editor, x int, y int) {
	if state.panning {
		return
	}
	editor_press(hwnd, mut state, x, y)
	if state.dragging || state.sliding {
		C.SetCapture(hwnd)
	}
}

// editor_pan_start começa a arrastar a imagem com o botão direito, que é o jeito de andar por ela ampliada. Não sobre a barra, e não com o esquerdo num arrasto ou no controle: a vista andaria debaixo do que está sendo desenhado, que guarda a origem em pixels da janela.
fn editor_pan_start(hwnd voidptr, mut state Editor, x int, y int) bool {
	if y < toolbar_height || state.dragging || state.sliding {
		return false
	}
	state.panning = true
	state.pan_from = Point{x, y}
	C.SetCapture(hwnd)
	return true
}

// editor_capture_lost trata o mouse tomado por outra janela no meio de um gesto — um Alt+Tab com o botão apertado, por exemplo. O botão solto nunca vai chegar, e o gesto termina onde está.
fn editor_capture_lost(hwnd voidptr, mut state Editor, taker voidptr) {
	if taker == hwnd {
		return
	}
	end_gesture(hwnd, mut state)
}

// end_gesture encerra o gesto em curso onde ele está: o controle de espessura e a imagem arrastada param onde estão, e o arrasto sobre a imagem termina onde o ponteiro estava, senão a marcação arrastada ficaria fora da cena para sempre. O mouse não é devolvido aqui, porque quem chama é justamente quem acabou de perdê-lo.
fn end_gesture(hwnd voidptr, mut state Editor) {
	state.sliding = false
	state.panning = false
	if state.dragging {
		editor_release(hwnd, mut state, state.cursor_x, state.cursor_y)
	}
}

// editor_resized acompanha a janela redimensionada ou maximizada: o espaço da imagem passa a ser o do cliente, e a janela inteira é redesenhada. A janela minimizada chega com o cliente zerado, e o tamanho que já está montado chega de novo a cada vez que ela é mostrada — nos dois casos não há o que fazer, e nem o gesto em curso é tocado.
fn editor_resized(hwnd voidptr, mut state Editor, width int, height int) {
	if !state.canvas_changes(width, height) {
		return
	}
	// Um gesto em curso guarda pixels da janela, e a vista mudando debaixo dele deixaria o traço escorregado: ele termina onde está, como quando outra janela toma o mouse. Lá o mouse já foi tomado; aqui ele ainda é da janela, e sem devolvê-lo o editor continuaria recebendo todo clique da área de trabalho. A devolução é só neste caso: arrastar a borda é o Windows que segura o mouse, e tirá-lo dele pararia o arrasto no meio.
	if state.dragging || state.sliding || state.panning {
		end_gesture(hwnd, mut state)
		if C.GetCapture() == hwnd {
			C.ReleaseCapture()
		}
	}
	// A janela é redesenhada mesmo quando as superfícies novas não nascem: o editor não apaga o fundo, e a faixa recém-exposta ficaria com lixo.
	state.resize_canvas(width, height)
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// editor_move acompanha o ponteiro: a imagem arrastada pelo botão direito, o traço, o controle de espessura, o botão aceso e a cor sob o ponteiro.
fn editor_move(hwnd voidptr, mut state Editor, x int, y int) {
	// A posição é guardada mesmo sem arrasto porque é dela que sai o ponteiro certo:
	// o Windows pergunta qual cursor usar antes de avisar que o mouse andou.
	state.cursor_x = x
	state.cursor_y = y
	// Com o botão direito apertado, a imagem acompanha o ponteiro.
	if state.panning {
		if state.pan_by(x - state.pan_from.x, y - state.pan_from.y) {
			state.background_ready = false
		}
		state.pan_from = Point{x, y}
	}
	if state.dragging && state.tool in stroke_tools {
		state.extend_stroke(x, y)
	}
	if state.sliding {
		editor_slide(mut state, x)
	}
	// O botão de ação sob o ponteiro acende, e a barra passa a dizer o nome dele.
	if state.track_hover(x, y) {
		state.background_ready = false
		watch_leave(hwnd, state)
	}
	// A cor sob o ponteiro vai para o bloco da barra, desenhado por cima da composição fixa.
	picked := state.sample_cursor(x, y)
	editor_repaint(hwnd, state, picked)
}

// editor_repaint pede o redesenho do que o movimento do ponteiro mudou, e só dele.
fn editor_repaint(hwnd voidptr, state &Editor, picked bool) {
	area := state.dirty_area(picked) or { return }
	rect := C.RECT{
		left:   area.x
		top:    area.y
		right:  area.x + area.width
		bottom: area.y + area.height
	}
	C.InvalidateRect(hwnd, &rect, false)
}

// dirty_area diz o que o movimento do ponteiro obriga a redesenhar: a janela inteira quando algo acompanha o ponteiro ou a composição fixa precisa ser refeita; só o bloco da cor quando só a cor sob o ponteiro mudou — sobre uma foto é quase todo movimento, e redesenhar a janela inteira custava duas cópias do tamanho dela a cada um —; ou nada.
fn (e Editor) dirty_area(picked bool) ?Rect {
	if e.following() || !e.background_ready {
		return Rect{
			width:  e.canvas_width
			height: toolbar_height + e.canvas_height
		}
	}
	if !picked {
		return none
	}
	return picker_rect(e.canvas_width)
}

// following diz se alguma coisa desenhada por cima da imagem acompanha o ponteiro: um arrasto ou a medida da régua. O controle de espessura não entra: ele está na composição fixa, que editor_slide manda refazer quando o passo muda.
fn (e Editor) following() bool {
	return e.dragging || e.probe != .none
}

// editor_slide leva o controle de espessura ao ponto. O botão anda de passo em passo, e só um passo novo muda o que a tela mostra: refazer a composição a cada movimento do mouse custava a redução da imagem inteira e o desenho da barra, para nada mudar.
fn editor_slide(mut state Editor, x int) {
	before := state.current_thickness()
	said := state.status
	state.status = state.slide_to(x)
	// A mensagem da barra também é da composição fixa: sem refazê-la, um passo que falhou não dizia nada, porque a espessura não muda.
	if state.current_thickness() != before || state.status != said {
		state.background_ready = false
	}
}

// watch_leave pede ao Windows um aviso de quando o ponteiro sair da janela, enquanto houver botão aceso: é o único jeito de apagá-lo quando o ponteiro sai sem passar por outro ponto dela — para a barra de título, que fica a poucos pixels dos botões, ou pela borda.
fn watch_leave(hwnd voidptr, state &Editor) {
	if !state.has_hover() {
		return
	}
	event := C.TRACKMOUSEEVENT{
		cbSize: sizeof(C.TRACKMOUSEEVENT)
		dwFlags: tme_leave
		hwndTrack: hwnd
	}
	C.TrackMouseEvent(&event)
}

// has_hover diz se há algum botão aceso pelo ponteiro: uma ação, uma ferramenta ou o do alinhamento.
fn (e Editor) has_hover() bool {
	return e.hovered >= 0 || e.hovered_tool >= 0 || e.hovered_snap
}

// editor_leave apaga o botão aceso quando o ponteiro sai da janela, e a barra volta à mensagem que estava lá. Um aviso com nada aceso — de uma troca de captura do mouse, por exemplo — não refaz nada.
fn editor_leave(hwnd voidptr, mut state Editor) {
	if !state.has_hover() {
		return
	}
	state.hovered = -1
	state.hovered_tool = -1
	state.hovered_snap = false
	state.background_ready = false
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// editor_button_up solta o que o botão apertado tinha começado: a imagem arrastada pelo botão direito, o controle de espessura ou o arrasto sobre a imagem.
fn editor_button_up(hwnd voidptr, mut state Editor, message u32, x int, y int) bool {
	// Os dois botões podem estar num gesto ao mesmo tempo, e o mouse só é devolvido quando o outro já terminou: devolvê-lo manda um WM_CAPTURECHANGED à própria janela, que encerraria o outro gesto no meio.
	if message == wm_rbuttonup && state.panning {
		state.panning = false
		if !state.dragging && !state.sliding {
			C.ReleaseCapture()
		}
		return true
	}
	if message == wm_lbuttonup && state.sliding {
		state.sliding = false
		if !state.panning {
			C.ReleaseCapture()
		}
		return true
	}
	if message == wm_lbuttonup && state.dragging {
		editor_release(hwnd, mut state, x, y)
		return true
	}
	return false
}

// editor_release termina o arrasto sobre a imagem no ponto dado. O mouse só é devolvido no fim, com o arrasto já fechado — o WM_CAPTURECHANGED que isso manda à própria janela, com o arrasto ainda aberto, o terminaria duas vezes —, e só se o botão direito não estiver arrastando a imagem.
fn editor_release(hwnd voidptr, mut state Editor, x int, y int) {
	state.cursor_x = x
	state.cursor_y = y
	state.dragging = false
	if state.tool in stroke_tools {
		state.extend_stroke(x, y)
	}
	state.status = if state.grab != .none { state.finish_grab() } else { state.finish_drag() }
	state.background_ready = false
	if !state.panning {
		C.ReleaseCapture()
	}
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// editor_press decide o que um clique começa: trocar de ferramenta, mexer numa marcação,
// ou abrir um arrasto novo sobre a imagem.
fn editor_press(hwnd voidptr, mut state Editor, x int, y int) {
	if y < toolbar_height {
		editor_toolbar_press(hwnd, mut state, x, y)
		return
	}
	if editor_popover_press(hwnd, mut state, x, y) {
		return
	}
	if editor_panel_press(hwnd, mut state, x, y) {
		return
	}
	// Um clique fora da caixa em que se está escrevendo termina o texto, inclusive no fundo em volta da imagem. Dentro dela não faz nada, e sobre a barra, o painel ou a paleta nem chega aqui: dá para trocar a cor ou o tamanho no meio da digitação.
	if state.typing {
		if !contains(state.to_client(state.typed_area), x, y) {
			state.status = state.finish_text()
			state.background_ready = false
			C.InvalidateRect(hwnd, unsafe { nil }, false)
		}
		return
	}
	// A alça de uma marcação na borda fica meio para fora da imagem, e o clique nesse lado também a pega, como o ponteiro já diz ali. O resto do fundo não começa nada.
	if !inside_view(state, x, y) && state.grab_at(x, y) == .none {
		return
	}
	state.origin_x = x
	state.origin_y = y
	state.cursor_x = x
	state.cursor_y = y
	state.stroke = [Point{x, y}]
	editor_grab_or_draw(mut state, x, y)
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// editor_toolbar_press trata o clique na barra: uma ação, o botão do alinhamento, o bloco da cor, o bloco do tamanho ou o do zoom, ou uma ferramenta.
fn editor_toolbar_press(hwnd voidptr, mut state Editor, x int, y int) {
	if action := action_at(x, y) {
		editor_command(hwnd, mut state, action_command(action))
		return
	}
	if on_snap_button(x, y) {
		state.toggle_snap()
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return
	}
	// Clicar no bloco da cor troca o formato em que o Tab a copia.
	if block := picker_rect(state.canvas_width) {
		if contains(block, x, y) {
			state.status = state.next_format()
			state.background_ready = false
			C.InvalidateRect(hwnd, unsafe { nil }, false)
			return
		}
	}
	// Clicar no bloco do tamanho ou no do zoom abre e fecha o painel dele, e fecha o
	// outro, se estiver aberto.
	if popover := popover_at(state.canvas_width, x, y) {
		state.popover = if state.popover == popover { Popover.none } else { popover }
		state.palette_open = false
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return
	}
	if chosen := tool_at(x, y) {
		state.choose(chosen)
		C.InvalidateRect(hwnd, unsafe { nil }, false)
	}
}

// editor_popover_press trata o clique com o painel do tamanho ou o do zoom aberto, os dois que pendem da barra. Devolve falso quando nenhum dos dois está aberto.
fn editor_popover_press(hwnd voidptr, mut state Editor, x int, y int) bool {
	// O painel de redimensionar funciona como a paleta: fica por cima de tudo enquanto está
	// aberto, e um clique fora dele só o fecha.
	if panel := state.resize_panel() {
		if index := state.resize_choice_at(x, y) {
			state.status = state.apply_resize(index)
			state.popover = .none
		} else if !contains(panel, x, y) {
			state.popover = .none
		}
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return true
	}
	// O painel do zoom fica aberto depois de − e +, que se apertam em sequência.
	if panel := state.zoom_panel() {
		if side := state.zoom_button_at(x, y) {
			state.status = state.zoom_by(side)
		} else if !contains(panel, x, y) {
			state.popover = .none
		}
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return true
	}
	return false
}

// editor_panel_press trata o clique com a paleta aberta, ou sobre o painel de opções. Devolve falso quando o clique é da imagem.
fn editor_panel_press(hwnd voidptr, mut state Editor, x int, y int) bool {
	// A paleta fica por cima de tudo enquanto está aberta, e um clique fora dela só a fecha.
	if palette := state.palette_rect() {
		if contains(palette, x, y) {
			editor_palette(hwnd, mut state, x, y)
		} else {
			state.close_palette(hwnd)
		}
		return true
	}
	if panel := state.options_panel() {
		if contains(panel, x, y) {
			editor_option(hwnd, mut state, x, y)
			return true
		}
	}
	return false
}

// editor_double reabre uma marcação de texto para reescrever o que está nela. Vale com a
// ferramenta Selecionar na mão: com a de texto, o primeiro clique do par já teria aberto
// uma caixa nova.
fn editor_double(hwnd voidptr, mut state Editor, x int, y int) bool {
	// Devolve se tratou o duplo clique. Fora de Selecionar sobre um texto ele é um clique comum, e quem chama o trata como tal; durante a digitação ele continua engolido, senão o segundo clique do par que abriu a caixa a fecharia vazia.
	if state.typing || state.tool != .select || !inside_view(state, x, y) {
		return state.typing
	}
	index := state.shape_at(x, y)
	if index < 0 || state.scene.shapes[index].tool != .text {
		return false
	}
	state.status = state.edit_text(index)
	state.background_ready = false
	C.InvalidateRect(hwnd, unsafe { nil }, false)
	return true
}

// editor_char acrescenta ao texto em digitação o que veio do teclado. `Enter` quebra a
// linha e `Ctrl+Enter` termina, que é o par que o Windows manda como retorno de carro e
// como avanço de linha.
fn editor_char(hwnd voidptr, mut state Editor, letter rune) {
	if letter == `\n` {
		state.status = state.finish_text()
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return
	}
	// Os demais caracteres de controle não são texto: o Esc entre eles, que o teclado trata antes de chegar aqui, e o DEL que o Ctrl+Backspace manda, que virava um quadradinho no fim do que foi escrito.
	if (letter < 0x20 && letter != `\b` && letter != `\r`) || letter == 0x7f {
		return
	}
	state.type_unit(letter)
	// O texto em digitação é desenhado por cima da composição fixa, que não muda a cada
	// tecla: só a janela precisa ser refeita.
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// editor_option trata o clique no painel de opções: o disco da cor, um botão de estilo, ou o começo de um arrasto do controle de espessura, que segue enquanto o botão do mouse estiver apertado. Um clique em qualquer parte do painel é dele, e por isso não chega à imagem — seria um traço começando debaixo do painel —, mas nos vãos entre os botões e na folga da borda ele não faz nada: antes virava arrasto do controle e levava a espessura a 1 ou a 12.
fn editor_option(hwnd voidptr, mut state Editor, x int, y int) {
	panel := state.options_panel() or { return }
	if has_swatch(state.options_tool()) && contains(swatch_rect(panel), x, y) {
		state.palette_open = !state.palette_open
	} else if index := state.style_at(x, y) {
		state.status = state.choose_style(index)
	} else if contains(slider_track(panel, state.options_tool()), x, y) {
		state.start_slide()
		state.status = state.slide_to(x)
	}
	state.background_ready = false
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// editor_grab_or_draw decide o que o clique sobre a imagem começa: mexer no que está
// selecionado, ou desenhar uma marcação nova.
fn editor_grab_or_draw(mut state Editor, x int, y int) {
	// Os painéis da barra seguram o clique antes de ele chegar aqui; o único que o deixa
	// passar é a ajuda da régua, que some no primeiro clique sobre a imagem.
	state.popover = .none
	if state.probe != .none {
		state.status = state.finish_probe()
		state.background_ready = false
		return
	}
	if state.tool == .select {
		state.select_at(x, y)
		// Um clique que pegou a marcação selecionada a move ou estica; um que só escolheu
		// outra não arrasta nada. Sobre a imagem vazia ele desmarca, e arrastar dali recorta.
		state.dragging = state.grab != .none || state.selected < 0
		state.background_ready = false
		return
	}
	// As alças e o corpo da marcação selecionada pegam antes da ferramenta: é o que permite
	// ajustar e mover o que acabou de ser desenhado sem trocar de ferramenta. Fora dela, o
	// arrasto desenha — e, se não sair do lugar, escolhe a marcação sob o clique.
	handle, lens := state.part_at(x, y)
	if handle == .none {
		state.dragging = true
		return
	}
	state.start_grab(handle, lens)
	state.dragging = state.grab != .none
	state.background_ready = false
}

// editor_palette trata o clique dentro da paleta: uma das oito cores, ou o botão que abre
// o seletor do Windows. Nos dois casos ela se fecha depois.
fn editor_palette(hwnd voidptr, mut state Editor, x int, y int) {
	palette := state.palette_rect() or { return }
	if color := state.palette_color_at(x, y) {
		state.status = state.apply_color(color)
	} else if contains(palette_custom_rect(palette), x, y) {
		state.status = state.choose_color(hwnd)
	} else {
		return
	}
	state.close_palette(hwnd)
}

// close_palette fecha a paleta e manda redesenhar.
fn (mut e Editor) close_palette(hwnd voidptr) {
	e.palette_open = false
	e.background_ready = false
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// editor_zoom_key trata as teclas do zoom, com o Ctrl apertado. Com o botão esquerdo num arrasto a vista fica parada: o arrasto guarda a origem em pixels da janela, e uma vista nova a poria noutro ponto da imagem.
fn editor_zoom_key(hwnd voidptr, mut state Editor, key u32) bool {
	if C.GetKeyState(vk_control) >= 0 || state.dragging {
		return false
	}
	message := state.zoom_key(key) or { return false }
	state.status = message
	state.background_ready = false
	C.InvalidateRect(hwnd, unsafe { nil }, false)
	return true
}

// editor_key reparte a tecla apertada: a desistência do texto, o conta-gotas, o zoom, a medida da régua, a tecla de uma ferramenta, e por fim Delete e Esc.
fn editor_key(hwnd voidptr, mut state Editor, key u32) bool {
	// Escrevendo, o Esc desiste do texto antes de qualquer outra coisa.
	if state.typing && key == vk_escape {
		state.status = state.cancel_text()
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return true
	}
	// Tab copia a cor sob o ponteiro, e Shift+Tab a mais escura em volta dele. Escrevendo,
	// o Tab não é dele.
	if key == vk_tab && !state.typing {
		state.status = state.copy_color(hwnd, C.GetKeyState(vk_shift) < 0)
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return true
	}
	if editor_zoom_key(hwnd, mut state, key) {
		return true
	}
	// Com a régua na mão, 1, 2 e as setas medem enquanto estiverem apertados.
	if state.start_probe(key) {
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return true
	}
	if state.choose_by_key(key) {
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return true
	}
	return editor_selection_key(hwnd, mut state, key)
}

// editor_selection_key trata Delete e Esc, que agem sobre a seleção antes de agirem sobre a janela.
fn editor_selection_key(hwnd voidptr, mut state Editor, key u32) bool {
	if key == vk_delete && state.selected >= 0 {
		state.status = state.delete_selected()
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return true
	}
	if key != vk_escape {
		return false
	}
	editor_escape(hwnd, mut state)
	return true
}

// editor_escape fecha primeiro o painel aberto — um dos da barra, a ajuda da régua ou a
// paleta —, depois desmarca, e só então fecha a janela.
fn editor_escape(hwnd voidptr, mut state Editor) {
	if state.popover != .none {
		state.popover = .none
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return
	}
	if state.palette_open {
		state.close_palette(hwnd)
		return
	}
	// O primeiro Esc desmarca, e só o seguinte fecha: quem acabou de selecionar algo por
	// engano não perde a edição inteira por causa disso.
	if state.selected >= 0 {
		state.selected = -1
		state.status = state.hint()
		state.background_ready = false
		C.InvalidateRect(hwnd, unsafe { nil }, false)
		return
	}
	C.DestroyWindow(hwnd)
}

// editor_command executa a ação pedida, seja pelo botão ou pelo atalho de teclado, que a
// tabela de aceleradores converte na mesma mensagem.
fn editor_command(hwnd voidptr, mut state Editor, id u32) {
	if state.text_entered(id) {
		match id {
			id_undo {
				state.status = state.undo()
				state.selected = -1
			}
			id_redo {
				state.status = state.redo()
				state.selected = -1
			}
			id_save {
				// Salvar e copiar encerram o editor: a tarefa dele acabou. O aviso passa a ser
				// o balão da bandeja, já que a barra de ferramentas some junto.
				if name := save_area(state) {
					tray_notify(state.owner, 'Captura salva', name)
					C.DestroyWindow(hwnd)
				} else {
					state.status = 'Falha ao salvar: ${err}'
				}
			}
			id_copy {
				if size := copy_area(state) {
					tray_notify(state.owner, 'Copiado para a área de transferência', size)
					C.DestroyWindow(hwnd)
				} else {
					state.status = 'Falha ao copiar: ${err}'
				}
			}
			id_close {
				C.DestroyWindow(hwnd)
			}
			else {}
		}
	}
	// O resultado do comando toma o lugar do nome do botão sob o ponteiro até ele sair dali: uma falha ao salvar ficaria escondida atrás de "Salvar e fechar".
	state.hover_muted = true
	// O texto de estado e o estado das ações fazem parte da composição fixa, então ela
	// precisa ser refeita.
	state.background_ready = false
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// text_entered fecha o texto em digitação antes de salvar ou copiar, como um Ctrl+Enter, e diz se o comando pode seguir. O texto ainda não está na cena, e sairia junto com o editor, que fecha; e se ele não entra na imagem, nada é salvo nem copiado, e a barra diz a falha — antes a imagem saía sem ele, e numa reescrita sem nenhuma das duas versões.
fn (mut e Editor) text_entered(id u32) bool {
	if !e.typing || id !in [id_save, id_copy] {
		return true
	}
	e.status = e.finish_text()
	return !e.status.starts_with('Falha')
}

// choose_by_key escolhe a ferramenta da tecla, se ela for de uma. Escrevendo, a tecla é
// texto; com Ctrl apertado, ela é de um atalho.
fn (mut e Editor) choose_by_key(key u32) bool {
	if e.typing || C.GetKeyState(vk_control) < 0 {
		return false
	}
	index := e.config.tools.index(key)
	if index < 0 {
		return false
	}
	e.choose(toolbar_tools[index])
	return true
}

// choose troca a ferramenta ativa. A seleção não sobrevive à troca: com outra ferramenta
// na mão, as alças seriam alças de nada.
fn (mut e Editor) choose(tool Tool) {
	// Um texto em digitação é fechado antes, com a aparência dele: logo abaixo a ferramenta nova troca a cor, a espessura e o estilo que o texto ainda usa.
	if e.typing {
		e.finish_text()
	}
	// Cada família começa com a cor e a espessura que lhe servem: o marca-texto largo e
	// amarelo, o numerador com raio confortável, e as demais com traço fino e vermelho.
	// Trocar de família leva as duas junto; dentro da mesma, o que o usuário escolher
	// continua valendo.
	if !same_family(tool, e.tool) {
		e.color = default_color(tool)
		e.thickness = default_thickness(tool)
	}
	// Duas ferramentas têm forma de partida própria, que é como a referência as mostra: o
	// texto começa em balão e a lupa começa redonda. Entrar numa delas ou sair leva o
	// campo junto, pela mesma regra da cor e da espessura; os demais campos ficam como
	// estavam.
	if (tool == .text) != (e.tool == .text) {
		e.style = Style{
			...e.style
			filled: tool == .text
		}
	}
	if (tool == .magnifier) != (e.tool == .magnifier) {
		e.style = Style{
			...e.style
			rounded: tool == .magnifier
		}
	}
	e.tool = tool
	e.selected = -1
	// A régua chega explicando as teclas dela, como na referência.
	e.popover = if tool == .ruler { Popover.ruler_help } else { Popover.none }
	e.probe = .none
	e.background_ready = false
	// A moldura não nasce de um arrasto: escolher a ferramenta já a põe, e o painel governa
	// o resto.
	e.status = if tool == .backdrop { e.use_backdrop() } else { e.hint() }
}

// Distância mínima entre dois pontos guardados do traço livre, em pixels da janela. O mouse
// manda dezenas de posições por segundo, e sem esta peneira a cena engorda sem o traço
// ficar melhor.
const stroke_step = 3

// extend_stroke acrescenta o ponto ao traço em curso, se ele já se afastou o bastante do
// anterior.
fn (mut e Editor) extend_stroke(x int, y int) {
	if e.stroke.len > 0 {
		last := e.stroke.last()
		if abs(x - last.x) + abs(y - last.y) < stroke_step {
			return
		}
	}
	e.stroke << Point{x, y}
}

// MK_SHIFT e MK_CONTROL: a mensagem da roda diz, na palavra baixa, quais teclas estavam
// apertadas quando ela girou.
const mk_shift = usize(0x0004)
const mk_control = usize(0x0008)

// editor_wheel trata a roda do mouse. Com Ctrl ou Shift ela muda o tamanho da ferramenta —
// ou da marcação selecionada —, como o controle do painel; sem tecla, ou sem tamanho a
// mudar, ela aproxima e afasta. No zoom o ponto de apoio é o ponteiro, e o que está sob ele
// fica parado — é o que faz a roda levar até o detalhe em vez de ao centro. A roda manda a
// posição em coordenadas de tela; a última posição conhecida do ponteiro já está em
// coordenadas da janela, e é ela que serve.
fn editor_wheel(hwnd voidptr, mut state Editor, wparam usize) {
	delta := wheel_delta(wparam)
	if delta == 0 {
		return
	}
	if wheel_of(wparam) != state.config.zoom && state.has_options() {
		state.status = state.size_by(wheel_steps(delta))
	} else {
		// Com o botão esquerdo num arrasto a vista fica parada, pelo mesmo motivo do zoom pelo teclado.
		if state.dragging {
			return
		}
		factor := if delta > 0 { zoom_step } else { 1.0 / zoom_step }
		state.status = state.zoom_at(state.zoom * factor, state.cursor_x, state.cursor_y)
	}
	state.background_ready = false
	C.InvalidateRect(hwnd, unsafe { nil }, false)
}

// wheel_of diz com que combinação a roda girou: sem tecla, com Ctrl ou com Shift. A que a
// configuração escolheu para o zoom aproxima; as outras mudam o tamanho.
fn wheel_of(wparam usize) Wheel {
	if wparam & mk_control != 0 {
		return .ctrl
	}
	if wparam & mk_shift != 0 {
		return .shift
	}
	return .plain
}

// wheel_steps converte o giro em passos de tamanho: um por dente da roda, e ao menos um
// para as rodas de giro fino, que mandam frações de dente.
fn wheel_steps(delta int) int {
	steps := delta / 120
	if steps != 0 {
		return steps
	}
	return if delta > 0 { 1 } else { -1 }
}

// wheel_delta tira o giro da roda da palavra alta do wparam, com sinal: positivo é a roda
// girada para longe de quem usa.
fn wheel_delta(wparam usize) int {
	return int(i16(u16((wparam >> 16) & 0xffff)))
}
