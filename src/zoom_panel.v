module main

// O painel do zoom: − e + em volta da ampliação em vigor, e embaixo os atalhos, que são o
// jeito de usar o zoom sem abrir painel nenhum.

const zoom_panel_width = 380
const zoom_button_size = 34
const zoom_line_height = 20
const zoom_help = ['Ctrl +  e  Ctrl −   aproximam e afastam',
	'Ctrl 0   a imagem inteira  ·  Ctrl 1   tamanho real', 'Ctrl 2   aproxima a marcação escolhida',
	'Roda do mouse aproxima  ·  botão direito arrasta']
const zoom_panel_height = 3 * resize_padding + zoom_button_size + zoom_help.len * zoom_line_height

// zoom_panel devolve onde o painel fica, ou none quando ele está fechado.
fn (e Editor) zoom_panel() ?Rect {
	if e.popover != .zoom {
		return none
	}
	block := zoom_rect(e.canvas_width)?
	return Rect{
		x: clamp(block.x + block.width / 2 - zoom_panel_width / 2, options_margin, e.canvas_width - zoom_panel_width - options_margin)
		y: toolbar_height + options_margin
		width: zoom_panel_width
		height: zoom_panel_height
	}
}

// zoom_button_rect devolve o botão de afastar, com `side` negativo, ou o de aproximar.
fn zoom_button_rect(panel Rect, side int) Rect {
	return Rect{
		x: if side < 0 {
			panel.x + resize_padding
		} else {
			panel.x + panel.width - resize_padding - zoom_button_size
		}
		y: panel.y + resize_padding
		width: zoom_button_size
		height: zoom_button_size
	}
}

// zoom_button_at devolve -1 sobre o botão de afastar, 1 sobre o de aproximar, ou none.
fn (e Editor) zoom_button_at(x int, y int) ?int {
	panel := e.zoom_panel()?
	for side in [-1, 1] {
		if contains(zoom_button_rect(panel, side), x, y) {
			return side
		}
	}
	return none
}

// draw_zoom_panel desenha o painel: os dois botões, a ampliação no meio e os atalhos.
fn draw_zoom_panel(hdc voidptr, e &Editor, panel Rect) {
	draw_panel(hdc, panel, options_color)
	old_font := C.SelectObject(hdc, e.font)
	defer {
		C.SelectObject(hdc, old_font)
	}
	C.SetBkMode(hdc, transparent_bk)
	for side in [-1, 1] {
		button := zoom_button_rect(panel, side)
		fill_button(hdc, button, button_face_color)
		C.SetTextColor(hdc, style_icon_active_color)
		label := if side < 0 { '−' } else { '+' }
		centered_text(hdc, button, label)
	}
	C.SetTextColor(hdc, toolbar_text_color)
	centered_text(hdc, Rect{
		x: panel.x
		y: panel.y + resize_padding
		width: panel.width
		height: zoom_button_size
	}, '${int(e.scale * 100 + 0.5)}%')
	C.SetTextColor(hdc, toolbar_dim_text_color)
	top := panel.y + 2 * resize_padding + zoom_button_size
	for index, line in zoom_help {
		text := if index == zoom_help.len - 1 { wheel_help(e.config.zoom) } else { line }
		C.TextOutW(hdc, panel.x + resize_padding, top + index * zoom_line_height, text.to_wide(),
			utf16_length(text))
	}
}

// wheel_help é a última linha da ajuda, que diz qual roda aproxima: a da configuração.
fn wheel_help(zoom Wheel) string {
	wheel := match zoom {
		.plain { 'Roda do mouse' }
		.ctrl { 'Ctrl + roda' }
		.shift { 'Shift + roda' }
	}
	return '${wheel} aproxima  ·  botão direito arrasta'
}

// centered_text escreve o texto no meio do retângulo, numa linha só.
fn centered_text(hdc voidptr, area Rect, text string) {
	mut place := C.RECT{
		left: area.x
		top: area.y
		right: area.x + area.width
		bottom: area.y + area.height
	}
	C.DrawTextW(hdc, text.to_wide(), -1, &place, dt_singleline | dt_center | dt_vcenter | dt_noprefix)
}

// popover_at devolve o painel cujo bloco da barra está sob o ponto, ou none.
fn popover_at(width int, x int, y int) ?Popover {
	if block := size_rect(width) {
		if contains(block, x, y) {
			return Popover.resize
		}
	}
	if block := zoom_rect(width) {
		if contains(block, x, y) {
			return Popover.zoom
		}
	}
	return none
}
