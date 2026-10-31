module main

// O redimensionamento da imagem: o bloco do meio da barra mostra o tamanho do resultado, e
// clicar nele abre um painel com os fatores da referência — 25%, 33%, 50%, 1×, 2× e 4×,
// sempre em relação à captura.
//
// A referência avisa que redimensionar não se desfaz. Aqui se desfaz: o fator é um campo
// da cena, entra no histórico como qualquer edição, e é aplicado por último, depois das
// marcações e da moldura, sobre a imagem pronta. As marcações continuam guardadas em
// coordenadas da captura, e quem leva um ponto da captura até a janela passa a multiplicar
// pelo fator.

// Os fatores do painel, e o rótulo de cada um.
const resize_factors = [0.25, 1.0 / 3.0, 0.5, 1.0, 2.0, 4.0]
const resize_labels = ['25%', '33%', '50%', '1×', '2×', '4×']

const resize_button_width = 52
const resize_button_height = 30
const resize_gap = 4
const resize_padding = 12
const resize_title_height = 22
const resize_panel_height = 2 * resize_padding + resize_title_height + resize_button_height

// resize_panel_width é a largura do painel, que é a da fila de botões com a folga.
fn resize_panel_width() int {
	return 2 * resize_padding + resize_factors.len * resize_button_width +
		(resize_factors.len - 1) * resize_gap
}

// size_rect devolve o bloco do tamanho na barra, ou none quando os blocos da direita não
// cabem.
fn size_rect(width int) ?Rect {
	colour := picker_rect(width)?
	return Rect{
		x: colour.x + status_color_width
		y: 0
		width: status_size_width - 10
		height: toolbar_height
	}
}

// resize_panel devolve onde o painel fica, ou none quando ele está fechado. Ele pende do
// bloco do tamanho e fica sempre inteiro dentro do editor.
fn (e Editor) resize_panel() ?Rect {
	if e.popover != .resize {
		return none
	}
	block := size_rect(e.canvas_width)?
	width := resize_panel_width()
	return Rect{
		x: clamp(block.x + block.width / 2 - width / 2, options_margin, e.canvas_width - width - options_margin)
		y: toolbar_height + options_margin
		width: width
		height: resize_panel_height
	}
}

// resize_button_rect devolve o botão do fator de índice `index`.
fn resize_button_rect(panel Rect, index int) Rect {
	return Rect{
		x: panel.x + resize_padding + index * (resize_button_width + resize_gap)
		y: panel.y + resize_padding + resize_title_height
		width: resize_button_width
		height: resize_button_height
	}
}

// resize_choice_at devolve o fator sob o ponto, ou none.
fn (e Editor) resize_choice_at(x int, y int) ?int {
	panel := e.resize_panel()?
	for index in 0 .. resize_factors.len {
		if contains(resize_button_rect(panel, index), x, y) {
			return index
		}
	}
	return none
}

// scaled_side é o lado da imagem no fator dado. A mesma conta vale para o que o painel
// anuncia e para o que a imagem de fato vira, para os dois nunca discordarem.
fn scaled_side(side int, factor f64) int {
	return max(round(f64(side) * factor), 1)
}

// scaled_to devolve a imagem no fator pedido e devolve a original ao Windows. No fator um é
// a própria imagem que volta, sem cópia nenhuma.
fn scaled_to(image Frozen, factor f64) !Frozen {
	if factor == 1.0 {
		return image
	}
	width := scaled_side(image.width, factor)
	height := scaled_side(image.height, factor)
	result := new_surface(image.dc, width, height) or {
		image.release()
		return err
	}
	C.SetStretchBltMode(result.dc, stretch_halftone)
	C.SetBrushOrgEx(result.dc, 0, 0, unsafe { nil })
	C.StretchBlt(result.dc, 0, 0, width, height, image.dc, 0, 0, image.width, image.height,
		srccopy)
	image.release()
	return result
}

// apply_resize muda o fator da imagem. Escolher o fator em que ela já está não é uma
// edição, e não entra no histórico.
fn (mut e Editor) apply_resize(index int) string {
	factor := resize_factors[index]
	if factor == e.scene.factor {
		return 'A imagem já está em ${resize_labels[index]}'
	}
	// Um texto em digitação é fechado antes, pelo mesmo motivo do desfazer: o histórico não pode andar por baixo dele, e desistir do texto depois apagaria o redimensionamento junto.
	if e.typing {
		e.finish_text()
	}
	e.record()
	e.scene.factor = factor
	e.apply() or {
		e.rollback()
		return 'Falha ao redimensionar: ${err}'
	}
	return 'Imagem em ${resize_labels[index]}: ${e.current.width}x${e.current.height}px'
}

// draw_resize_panel desenha o painel: o título e a fila de fatores, com o fator em vigor
// aceso.
fn draw_resize_panel(hdc voidptr, e &Editor, panel Rect) {
	draw_panel(hdc, panel, options_color)
	old_font := C.SelectObject(hdc, e.font)
	defer {
		C.SelectObject(hdc, old_font)
	}
	C.SetBkMode(hdc, transparent_bk)
	C.SetTextColor(hdc, toolbar_text_color)
	title := 'Redimensionar a imagem'
	C.TextOutW(hdc, panel.x + resize_padding, panel.y + resize_padding - 2, title.to_wide(),
		utf16_length(title))

	for index, label in resize_labels {
		button := resize_button_rect(panel, index)
		active := resize_factors[index] == e.scene.factor
		fill_button(hdc, button, if active { toolbar_active_color } else { button_face_color })
		C.SetTextColor(hdc, if active { style_icon_active_color } else { style_icon_color })
		mut place := C.RECT{
			left: button.x
			top: button.y
			right: button.x + button.width
			bottom: button.y + button.height
		}
		C.DrawTextW(hdc, label.to_wide(), -1, &place, dt_singleline | dt_center | dt_vcenter | dt_noprefix)
	}
}
