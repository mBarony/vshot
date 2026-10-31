module main

// A medida pelo teclado, como na referência: com a régua na mão, segurar `1` mede na
// vertical a faixa de cor sob o ponteiro, `2` mede na horizontal, e uma seta mede do
// ponteiro até a borda da faixa naquela direção. Enquanto a tecla está apertada a medida acompanha o mouse; um clique guarda a régua, e soltar a tecla cancela a prévia.
// Escolher a régua abre a caixa que ensina isso, pendurada no botão dela.

const wm_keyup = u32(0x0101)
const wm_killfocus = u32(0x0008)
const vk_left = u32(0x25)
const vk_up = u32(0x26)
const vk_right = u32(0x27)
const vk_down = u32(0x28)

const ruler_help_title = 'Use o teclado'
const ruler_help_text = 'Segure 1, 2 ou uma seta para medir. Clique para adicionar; solte a tecla para cancelar.'
const ruler_help_width = 320
const ruler_help_padding = 12
const ruler_help_line = 24
// O texto da ajuda quebra em duas linhas de 20 pixels na largura da caixa. A altura é fixa, e não medida no desenho, porque o conta-gotas precisa dela para saber que a caixa cobre a imagem, e ali não há contexto em que medir o texto.
const ruler_help_text_height = 40
const ruler_help_height = 2 * ruler_help_padding + ruler_help_line + ruler_help_text_height

// Probe é a medida em curso pelo teclado: a faixa inteira em pé ou deitada, ou um dos
// quatro lados dela a partir do ponteiro.
enum Probe {
	none
	vertical
	horizontal
	left
	right
	up
	down
}

// probe_for traduz a tecla na medida que ela faz, ou devolve none para as outras.
fn probe_for(key u32) ?Probe {
	return match key {
		0x31 { Probe.vertical }
		0x32 { Probe.horizontal }
		vk_left { Probe.left }
		vk_right { Probe.right }
		vk_up { Probe.up }
		vk_down { Probe.down }
		else { none }
	}
}

// start_probe começa a medir quando a tecla é de medida e a régua está na mão, e diz se a
// tecla foi dela. A repetição automática do teclado só confirma a mesma medida.
fn (mut e Editor) start_probe(key u32) bool {
	if e.tool != .ruler || e.typing || e.dragging {
		return false
	}
	probe := probe_for(key) or { return false }
	e.probe = probe
	// Quem já está medindo aprendeu: a caixa de ajuda sai da frente.
	if e.popover == .ruler_help {
		e.popover = .none
	}
	return true
}

// probe_spot devolve o pixel da imagem de trabalho sob o ponteiro, ou none fora dela.
fn (e Editor) probe_spot() ?Rect {
	// Fora da imagem à vista não há o que medir: no fundo cinza que o zoom mostra junto da borda, to_image truncaria o ponto para dentro da imagem, e sob a barra, com a imagem ampliada passando por baixo dela, a medida sairia de pixels escondidos.
	if e.cursor_y < toolbar_height || !contains(e.view, e.cursor_x, e.cursor_y) {
		return none
	}
	// Na folga da moldura também não: ela não é captura, e a medida da faixa chapada da cor dela gravava uma régua fora do recorte, com a etiqueta presa na borda da imagem.
	point := e.to_source_point(e.cursor_x, e.cursor_y)
	if !contains(e.scene.crop, point.x, point.y) {
		return none
	}
	spot := e.to_image(Rect{
		x: e.cursor_x
		y: e.cursor_y
	})
	if spot.x < 0 || spot.y < 0 || spot.x >= e.current.width || spot.y >= e.current.height {
		return none
	}
	return spot
}

// probe_span recorta a faixa [start, end) para a medida pedida: inteira, ou só do começo
// até o ponteiro, ou só do ponteiro até o fim.
fn probe_span(probe Probe, start int, end int, at int) (int, int) {
	from := if probe in [Probe.right, .down] { at } else { start }
	to := if probe in [Probe.left, .up] { at } else { end }
	return from, to
}

// probe_shape devolve a régua que a medida em curso daria, ou none quando não há medida ou
// o ponteiro está fora da imagem. A leitura é feita na imagem de trabalho, que já tem as
// marcações anteriores: mede-se o que se vê.
fn (e Editor) probe_shape() ?Shape {
	if e.probe == .none {
		return none
	}
	spot := e.probe_spot()?
	vertical := e.probe in [Probe.vertical, .up, .down]
	start, end := measure_run(e.current.dc, e.current.width, e.current.height, spot.x,
		spot.y, vertical)
	from, to := probe_span(e.probe, start, end, if vertical { spot.y } else { spot.x })
	image := if vertical {
		Rect{
			x: spot.x
			y: from
			height: to - from
		}
	} else {
		Rect{
			x: from
			y: spot.y
			width: to - from
		}
	}
	// A régua fica no recorte: rente à borda, uma faixa da cor da moldura na imagem emenda com a folga, e a medida somava a folga.
	return Shape{
		tool: .ruler
		area: overlap(e.to_source(image), e.scene.crop)
		color: e.color
		thickness: e.thickness
		origin: .top_left
	}
}

// finish_probe guarda a medida em curso como uma régua comum — selecionada, com alças,
// ajustável depois — e encerra a medida.
fn (mut e Editor) finish_probe() string {
	shape := e.probe_shape() or {
		e.probe = .none
		return e.hint()
	}
	e.probe = .none
	if ruler_length(shape.area) == 0 {
		return e.hint()
	}
	e.record()
	e.scene.shapes << shape
	e.selected = e.scene.shapes.len - 1
	e.apply() or {
		e.rollback()
		e.selected = -1
		return 'Falha ao medir: ${err}'
	}
	return 'Medido: ${ruler_label(shape.area)}'
}

// ruler_help_left devolve onde a caixa de ajuda começa, ou none quando ela está fechada.
// Ela pende do botão da régua e fica sempre inteira dentro do editor.
fn (e Editor) ruler_help_left() ?int {
	if e.popover != .ruler_help || e.tool != .ruler {
		return none
	}
	button := tool_button_left(toolbar_tools.index(Tool.ruler))
	return clamp(button + tool_button_size / 2 - ruler_help_width / 2, options_margin,
		e.canvas_width - ruler_help_width - options_margin)
}

// ruler_help_rect devolve a caixa de ajuda, ou none quando ela está fechada.
fn (e Editor) ruler_help_rect() ?Rect {
	left := e.ruler_help_left()?
	return Rect{
		x: left
		y: toolbar_height + options_margin
		width: ruler_help_width
		height: ruler_help_height
	}
}

// draw_ruler_help desenha a caixa: o título e, embaixo, o texto quebrado na largura dela.
fn draw_ruler_help(hdc voidptr, e &Editor, box Rect) {
	old_font := C.SelectObject(hdc, e.font)
	defer {
		C.SelectObject(hdc, old_font)
	}
	draw_panel(hdc, box, options_color)
	C.SetBkMode(hdc, transparent_bk)
	C.SetTextColor(hdc, toolbar_icon_active_color)
	C.TextOutW(hdc, box.x + ruler_help_padding, box.y + ruler_help_padding, ruler_help_title.to_wide(),
		utf16_length(ruler_help_title))
	C.SetTextColor(hdc, toolbar_text_color)
	mut place := C.RECT{
		left: box.x + ruler_help_padding
		top: box.y + ruler_help_padding + ruler_help_line
		right: box.x + box.width - ruler_help_padding
		bottom: box.y + box.height - ruler_help_padding
	}
	C.DrawTextW(hdc, ruler_help_text.to_wide(), -1, &place, dt_wordbreak | dt_noprefix)
}
