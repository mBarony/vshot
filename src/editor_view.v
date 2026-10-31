module main

fn C.GetKeyState(key int) i16

// A tecla que prende a linha aos ângulos redondos.
const vk_shift = 0x10

// paint_editor entrega a janela pronta em uma única passada. Desenhar as camadas direto
// no DC da tela faz a imagem piscar: entre o preenchimento do fundo e o desenho da imagem
// existe um instante em que só o fundo está lá, e a cada movimento do mouse o monitor
// pega justamente esse instante.
fn paint_editor(hdc voidptr, mut state Editor, dirty C.RECT) {
	if !state.background_ready {
		state.compose_background()
		state.background_ready = true
	}
	width := state.canvas_width
	height := toolbar_height + state.canvas_height

	// A composição fixa é reaproveitada durante o arrasto, quando só a moldura muda. Sem
	// isso cada movimento do mouse repetiria a redução da imagem, que é a parte cara.
	// Só a parte a redesenhar vem da composição: quando só a cor sob o ponteiro mudou, é o bloco dela, e não a janela inteira. Fora dela o buffer guarda o quadro anterior, que não chega à tela, porque a cópia final é recortada pelo BeginPaint à mesma parte.
	C.BitBlt(state.buffer.dc, dirty.left, dirty.top, dirty.right - dirty.left, dirty.bottom - dirty.top,
		state.background.dc, dirty.left, dirty.top, srccopy)
	// A prévia e os painéis ficam abaixo da barra. Quando só a barra vai para a tela — é o bloco da cor, a cada movimento do mouse sobre uma foto —, desenhá-los custava milissegundos para nada aparecer.
	if dirty.bottom > toolbar_height {
		// As marcações e as prévias ficam presas à área visível: com zoom, uma delas pode passar
		// da borda de cima e cairia sobre a barra.
		saved := C.SaveDC(state.buffer.dc)
		C.IntersectClipRect(state.buffer.dc, 0, toolbar_height, width, height)
		draw_overlay(mut state)
		C.RestoreDC(state.buffer.dc, saved)
		draw_panels(state)
	}
	draw_picker(state.buffer.dc, state)
	C.BitBlt(hdc, 0, 0, width, height, state.buffer.dc, 0, 0, srccopy)
}

// draw_overlay desenha por cima da composição fixa o que não pertence à imagem: a prévia
// do arrasto, as alças da marcação selecionada e o painel de opções. Nada disso entra no
// que salvar e copiar levam.
fn draw_overlay(mut state Editor) {
	if state.typing {
		// O texto em digitação já aparece como vai ficar — mesma fonte, mesma cor, mesmo
		// balão —, com a moldura do arrasto em volta para dizer onde ele quebra a linha.
		box := state.to_client(state.typed_area)
		state.draw_mark_on_image(state.buffer.dc, state.typed_shape(), box, preview_thickness(state.thickness,
			state.view_scale()), 0)
		draw_drag_marker(state.buffer.dc, box)
		return
	}
	if state.grab != .none {
		draw_grabbed(state.buffer.dc, state)
		return
	}
	// A medida pelo teclado acompanha o ponteiro enquanto a tecla está apertada.
	if shape := state.probe_shape() {
		state.draw_mark_on_image(state.buffer.dc, shape, state.to_client(shape.area), preview_thickness(state.thickness,
			state.view_scale()), 0)
		return
	}
	if state.dragging {
		draw_dragged(state.buffer.dc, state)
		return
	}
	if state.selected >= 0 && state.selected < state.scene.shapes.len
		&& state.scene.shapes[state.selected].tool != .backdrop {
		draw_selected(state.buffer.dc, state, state.scene.shapes[state.selected])
	}
}

// draw_dragged desenha o arrasto sobre a imagem: a marcação que ele está criando, com as guias de quem encaixa, ou a moldura do recorte.
fn draw_dragged(hdc voidptr, e &Editor) {
	area := e.area()
	if !previewable(area, e.tool) {
		return
	}
	if e.tool !in drawing_tools {
		draw_drag_marker(hdc, area)
		return
	}
	draw_preview(hdc, e.snapped_area(), e)
	if e.tool in snap_tools || e.tool == .counter {
		draw_guides(hdc, e, e.drag_area())
	}
}

// draw_mark_on_image desenha a prévia de uma marcação recortada pela imagem, como o resultado a recorta: lá ela é desenhada sobre o bitmap da imagem, e o que passa da borda some. O recorte também é o limite em que a etiqueta da régua procura lugar, e sem ele a prévia a mostrava fora da imagem, onde o resultado não a teria.
fn (e Editor) draw_mark_on_image(hdc voidptr, mark Shape, box Rect, thickness f32, number int) {
	saved := e.clip_to_image(hdc)
	draw_mark(hdc, mark, box, thickness, number)
	C.RestoreDC(hdc, saved)
}

// clip_to_image recorta pela imagem o que for desenhado a seguir, e devolve o estado anterior do contexto, que quem chama restaura com RestoreDC.
fn (e Editor) clip_to_image(hdc voidptr) int {
	image := e.to_client(e.scene.crop)
	saved := C.SaveDC(hdc)
	C.IntersectClipRect(hdc, image.x, image.y, image.x + image.width, image.y + image.height)
	return saved
}

// previewable diz se o arrasto já tem prévia para mostrar. Uma caixa precisa dos dois
// lados, mas a linha, a seta e a régua atravessam a caixa: deitadas ou em pé, que é onde o
// Shift as prende, a caixa delas não tem altura ou não tem largura, e a prévia sumia.
fn previewable(area Rect, tool Tool) bool {
	if tool in diagonal_tools {
		return area.width > 0 || area.height > 0
	}
	return area.width > 0 && area.height > 0
}

// draw_panels desenha os painéis por cima de tudo: o de opções, a paleta e os que pendem da
// barra. Eles ficavam no fim de draw_overlay, e sumiam junto com o que ele devolvia antes:
// durante a digitação o painel de opções não aparecia, embora continuasse respondendo.
fn draw_panels(state &Editor) {
	if panel := state.options_panel() {
		draw_options(state.buffer.dc, state, panel)
	}
	if palette := state.palette_rect() {
		draw_palette(state.buffer.dc, state, palette)
	}
	if panel := state.resize_panel() {
		draw_resize_panel(state.buffer.dc, state, panel)
	}
	if panel := state.zoom_panel() {
		draw_zoom_panel(state.buffer.dc, state, panel)
	}
	if box := state.ruler_help_rect() {
		draw_ruler_help(state.buffer.dc, state, box)
	}
}

// compose_background monta a parte que não muda durante um arrasto: a barra, o fundo, a
// imagem de trabalho e o texto de estado. A imagem só é refeita quando ela ou a vista mudaram: um botão aceso ou uma mensagem nova mudam só a barra, e reduzir a imagem inteira de novo por causa deles é a parte cara.
fn (mut e Editor) compose_background() {
	if !e.canvas_ready {
		e.compose_canvas()
		e.canvas_ready = true
	}
	// A barra vem por último: a imagem ampliada pode passar da borda de cima da área
	// visível, e a barra desenhada depois cobre o que passou.
	draw_toolbar(e.background.dc, e.canvas_width, e)
}

// compose_canvas monta o que fica abaixo da barra: o fundo, a sombra e a imagem de trabalho.
fn (e Editor) compose_canvas() {
	// Depois de um recorte a imagem deixa de ocupar todo o espaço, e o que sobra precisa
	// de um fundo próprio.
	mut canvas := C.RECT{
		top: toolbar_height
		right: e.canvas_width
		bottom: toolbar_height + e.canvas_height
	}
	C.FillRect(e.background.dc, &canvas, e.canvas_bg)
	// Uma sombra difusa destaca a imagem do fundo quando ela não ocupa o espaço todo; ampliada além da janela, a sombra cai toda fora do que se vê.
	fill_shadow(e.background.dc, e.view, 0)
	e.blit_visible()
}

// blit_visible desenha só o pedaço da imagem que aparece na área visível. Com zoom a vista
// pode ser muitas vezes maior que a janela, e esticar a imagem inteira para jogar quase tudo
// fora custaria um quadro enorme a cada movimento. O pedaço é tomado em pixels inteiros da
// imagem, e o destino sai deles, para a imagem não escorregar em relação às marcações
// desenhadas por cima. Ampliada, ela é esticada sem interpolar, para o pixel aparecer.
fn (e Editor) blit_visible() {
	left := max(e.view.x, 0)
	top := max(e.view.y, toolbar_height)
	right := min(e.view.x + e.view.width, e.canvas_width)
	bottom := min(e.view.y + e.view.height, toolbar_height + e.canvas_height)
	if right <= left || bottom <= top || e.scale <= 0 {
		return
	}
	sx0 := clamp(int(f64(left - e.view.x) / e.scale), 0, e.current.width)
	sy0 := clamp(int(f64(top - e.view.y) / e.scale), 0, e.current.height)
	sx1 := clamp(int(f64(right - e.view.x) / e.scale) + 1, 0, e.current.width)
	sy1 := clamp(int(f64(bottom - e.view.y) / e.scale) + 1, 0, e.current.height)
	if sx1 <= sx0 || sy1 <= sy0 {
		return
	}
	dx0 := e.view.x + round(f64(sx0) * e.scale)
	dy0 := e.view.y + round(f64(sy0) * e.scale)
	dx1 := e.view.x + round(f64(sx1) * e.scale)
	dy1 := e.view.y + round(f64(sy1) * e.scale)
	mode := if e.scale >= 1.0 { stretch_coloroncolor } else { stretch_halftone }
	C.SetStretchBltMode(e.background.dc, mode)
	C.SetBrushOrgEx(e.background.dc, 0, 0, unsafe { nil })
	C.StretchBlt(e.background.dc, dx0, dy0, dx1 - dx0, dy1 - dy0, e.current.dc, sx0, sy0,
		sx1 - sx0, sy1 - sy0, srccopy)
}

// layout centraliza a imagem no espaço disponível e recalcula a escala, porque um recorte
// muda o tamanho dela.
fn (mut e Editor) layout() {
	// A escala é a que faz a imagem caber, vezes o zoom. O zoom é refeito dentro dos
	// limites a cada vez porque um recorte muda o que é caber.
	e.zoom = e.clamp_zoom(e.zoom)
	e.scale = e.fit_scale() * e.zoom
	width := int(f64(e.current.width) * e.scale)
	height := int(f64(e.current.height) * e.scale)
	e.pan_x = clamp_pan(e.pan_x, width, e.canvas_width)
	e.pan_y = clamp_pan(e.pan_y, height, e.canvas_height)
	e.view = Rect{
		x: (e.canvas_width - width) / 2 + e.pan_x
		y: toolbar_height + (e.canvas_height - height) / 2 + e.pan_y
		width: width
		height: height
	}
	// A imagem mudou de tamanho ou de lugar, então a composição fixa precisa ser refeita.
	e.background_ready = false
	e.canvas_ready = false
}

// canvas_changes diz se o cliente pedido muda o espaço da imagem. A janela minimizada chega com ele zerado, e o tamanho que já está montado chega de novo a cada vez que a janela é mostrada: refazer as superfícies nesses dois casos custaria dois bitmaps do tamanho da janela à toa.
fn (e Editor) canvas_changes(width int, height int) bool {
	canvas := height - toolbar_height
	return width > 0 && canvas > 0 && (width != e.canvas_width || canvas != e.canvas_height)
}

// resize_canvas refaz o espaço da imagem quando a janela muda de tamanho: o cliente inteiro passa a ser a área de desenho, as superfícies passam a ter o tamanho dele e a imagem é recolocada. Devolve falso quando não há o que fazer, ou quando uma superfície não nasceu.
fn (mut e Editor) resize_canvas(width int, height int) bool {
	if !e.canvas_changes(width, height) {
		return false
	}
	// As superfícies novas são montadas antes de as antigas saírem, como a imagem de trabalho faz no apply(): uma falha no meio deixaria o editor sem onde desenhar.
	background := new_surface(e.source.dc, width, height) or { return false }
	buffer := new_surface(e.source.dc, width, height) or {
		background.release()
		return false
	}
	e.background.release()
	e.buffer.release()
	e.background = background
	e.buffer = buffer
	e.canvas_width = width
	e.canvas_height = height - toolbar_height
	// O encaixe muda junto com o espaço, e o zoom é relativo a ele.
	e.zoom = zoom_after_resize(e.zoom, e.scale, e.fit_scale())
	e.layout()
	return true
}

// fit_within reduz o quanto for preciso para caber no limite, e nunca amplia: uma imagem
// menor que o espaço aparece no tamanho real, sem borrão de interpolação.
fn fit_within(width int, height int, max_width int, max_height int) f64 {
	mut scale := f64(max_width) / f64(width)
	vertical := f64(max_height) / f64(height)
	if vertical < scale {
		scale = vertical
	}
	return if scale < 1.0 { scale } else { 1.0 }
}

// drag_cursor devolve a ponta do arrasto: a do ponteiro, ou, com Shift apertado, a que a
// ferramenta na mão pede.
fn (e Editor) drag_cursor() (int, int) {
	if C.GetKeyState(vk_shift) >= 0 {
		return e.cursor_x, e.cursor_y
	}
	return shift_snap(e.tool, e.origin_x, e.origin_y, e.cursor_x, e.cursor_y)
}

// shift_snap é o que o Shift faz com a ponta do arrasto em cada ferramenta: a linha, a seta
// e a régua se prendem a 0°, 45° e 90°, o retângulo e a elipse viram quadrado e círculo, e
// as demais seguem o ponteiro.
fn shift_snap(tool Tool, x0 int, y0 int, x int, y int) (int, int) {
	if tool in diagonal_tools {
		return snap_to_angle(x0, y0, x, y)
	}
	if tool in [Tool.rectangle, .oval] {
		return snap_to_square(x0, y0, x, y)
	}
	return x, y
}

// snap_to_square prende a ponta para a caixa do arrasto virar um quadrado: o lado é o maior
// dos dois lados do arrasto, e a ponta fica do lado para onde ele foi.
fn snap_to_square(x0 int, y0 int, x int, y int) (int, int) {
	side := max(abs(x - x0), abs(y - y0))
	return x0 + (if x < x0 { -side } else { side }), y0 + (if y < y0 { -side } else { side })
}

// snap_to_angle prende a ponta ao ângulo mais próximo entre 0°, 45° e 90°. A comparação é
// com a tangente de 22,5°, que é o meio do caminho entre um ângulo e o seguinte, e fica
// toda em inteiros para não trazer trigonometria por causa de três casos.
fn snap_to_angle(x0 int, y0 int, x int, y int) (int, int) {
	dx := x - x0
	dy := y - y0
	across := abs(dx)
	down := abs(dy)
	if down * 1000 < across * 414 {
		return x, y0
	}
	if across * 1000 < down * 414 {
		return x0, y
	}
	reach := (across + down) / 2
	return x0 + sign(dx) * reach, y0 + sign(dy) * reach
}

// drag_corner diz de que canto da caixa o arrasto partiu, que é onde a cauda de uma seta
// fica.
fn (e Editor) drag_corner() Corner {
	x, y := e.drag_cursor()
	if x >= e.origin_x {
		return if y >= e.origin_y { Corner.top_left } else { Corner.bottom_left }
	}
	return if y >= e.origin_y { Corner.top_right } else { Corner.bottom_right }
}

// area devolve o arrasto em coordenadas do cliente, normalizado e preso aos limites da
// imagem, porque o ponteiro pode sair dela.
fn (e Editor) area() Rect {
	cursor_x, cursor_y := e.drag_cursor()
	left := clamp(min(e.origin_x, cursor_x), e.view.x, e.view.x + e.view.width)
	right := clamp(max(e.origin_x, cursor_x), e.view.x, e.view.x + e.view.width)
	top := clamp(min(e.origin_y, cursor_y), e.view.y, e.view.y + e.view.height)
	bottom := clamp(max(e.origin_y, cursor_y), e.view.y, e.view.y + e.view.height)
	return Rect{
		x: left
		y: top
		width: right - left
		height: bottom - top
	}
}

// margin é a folga que a moldura acrescentou em volta da imagem. Ela desloca a origem da
// imagem de trabalho, e por isso entra em todas as conversões entre a janela e a captura.
// Sem moldura vale zero, e as contas ficam como eram.
fn (e Editor) margin() int {
	return scene_margin(e.scene)
}

// view_scale é quanto um pixel da captura mede na janela: o fator de tamanho do resultado
// vezes a redução com que a imagem é exibida. É a escala das prévias e das alças; a
// redução sozinha, `scale`, leva só da imagem de trabalho até a janela.
fn (e Editor) view_scale() f64 {
	return e.scene.factor * e.scale
}

// to_image converte um retângulo das coordenadas do cliente para as da imagem de trabalho,
// desfazendo a redução com que ela é exibida.
fn (e Editor) to_image(area Rect) Rect {
	return Rect{
		x: int(f64(area.x - e.view.x) / e.scale)
		y: int(f64(area.y - e.view.y) / e.scale)
		width: int(f64(area.width) / e.scale)
		height: int(f64(area.height) / e.scale)
	}
}

// to_client faz o caminho inverso: sai das coordenadas da captura e chega às da janela,
// que é onde as alças e as prévias são desenhadas.
fn (e Editor) to_client(area Rect) Rect {
	margin := e.margin()
	return Rect{
		x: e.view.x + int(f64(area.x - e.scene.crop.x + margin) * e.view_scale())
		y: e.view.y + int(f64(area.y - e.scene.crop.y + margin) * e.view_scale())
		width: int(f64(area.width) * e.view_scale())
		height: int(f64(area.height) * e.view_scale())
	}
}

// contains diz se o ponto caiu dentro do retângulo.
fn contains(area Rect, x int, y int) bool {
	return x >= area.x && x < area.x + area.width && y >= area.y && y < area.y + area.height
}

// inside_view diz se o ponto do clique caiu sobre a imagem, e não sobre a barra ou o fundo.
fn inside_view(state &Editor, x int, y int) bool {
	return contains(state.view, x, y)
}

// utf16_length conta as unidades de 16 bits do texto, que é o que o TextOutW espera —
// não os bytes do UTF-8 nem os caracteres.
fn utf16_length(text string) int {
	mut count := 0
	wide := text.to_wide()
	unsafe {
		for wide[count] != 0 {
			count++
		}
	}
	return count
}

fn min(a int, b int) int {
	return if a < b { a } else { b }
}

fn max(a int, b int) int {
	return if a > b { a } else { b }
}

fn abs(value int) int {
	return if value < 0 { -value } else { value }
}

fn sign(value int) int {
	return if value < 0 {
		-1
	} else if value > 0 { 1 } else { 0 }
}

fn clamp(value int, low int, high int) int {
	return if value < low {
		low
	} else if value > high { high } else { value }
}
