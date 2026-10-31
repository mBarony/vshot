module main

import math

// O conta-gotas: o primeiro bloco da direita da barra mostra a cor do pixel sob o ponteiro,
// e o `Tab` a copia como texto, no formato escolhido. `Shift+Tab` copia a cor mais escura
// em volta do ponteiro, que sobre texto é a da letra e não a do fundo — mirar num traço de
// um pixel não é preciso. Clicar no bloco troca o formato.
//
// A leitura é feita na imagem de trabalho em tamanho real, e não no que a janela mostra
// reduzido: a redução mistura os pixels vizinhos, e a cor que ela daria não existe na
// captura.

const vk_tab = u32(0x09)
// Metade do lado do quadro em que o `Shift+Tab` procura a cor mais escura, em pixels da
// janela: vinte pixels em volta do ponteiro, como na referência.
const picker_reach = 10
// O anel em volta do disco, para uma cor escura continuar visível sobre a barra escura.
const picker_ring_color = u32(0x00808080)

// Os formatos em que a cor pode ser copiada, na ordem da referência, pelo nome curto que o
// bloco mostra.
const color_format_names = ['#HEX', 'HEX', 'CSS', 'RGB', 'Android', 'UIColor', 'C#', 'OKLCH']

// channels_of reparte o COLORREF, que é 0x00bbggrr, nos três canais.
fn channels_of(color u32) (int, int, int) {
	return int(color & 0xff), int((color >> 8) & 0xff), int((color >> 16) & 0xff)
}

// hex2 escreve o canal em dois dígitos hexadecimais maiúsculos.
fn hex2(value int) string {
	digits := '0123456789ABCDEF'
	return digits[value >> 4].ascii_str() + digits[value & 15].ascii_str()
}

// unit escreve o canal como fração de um, com duas casas.
fn unit(value int) string {
	return '${f64(value) / 255:.2f}'
}

// color_text escreve a cor no formato pedido.
fn color_text(color u32, format int) string {
	r, g, b := channels_of(color)
	return match format {
		1 { '${hex2(r)}${hex2(g)}${hex2(b)}' }
		2 { 'rgba(${r}, ${g}, ${b}, 1)' }
		3 { '(${unit(r)}, ${unit(g)}, ${unit(b)})' }
		4 { '0xFF${hex2(r)}${hex2(g)}${hex2(b)}' }
		5 { 'UIColor(red: ${unit(r)}, green: ${unit(g)}, blue: ${unit(b)}, alpha: 1.00)' }
		6 { 'Color.FromArgb(255, ${r}, ${g}, ${b})' }
		7 { oklch_text(r, g, b) }
		else { '#${hex2(r)}${hex2(g)}${hex2(b)}' }
	}
}

// oklch_text escreve a cor como o `oklch()` do CSS: claridade de zero a um, croma e matiz.
fn oklch_text(r int, g int, b int) string {
	lightness, chroma, hue := oklch(r, g, b)
	return 'oklch(${lightness:.3f} ${chroma:.3f} ${hue:.1f})'
}

// linear desfaz a curva do sRGB, que é o que as contas de cor esperam receber.
fn linear(channel int) f64 {
	c := f64(channel) / 255
	return if c <= 0.04045 { c / 12.92 } else { math.pow((c + 0.055) / 1.055, 2.4) }
}

// oklch converte a cor para o espaço OKLCH, pelas matrizes publicadas com o OKLab.
fn oklch(r int, g int, b int) (f64, f64, f64) {
	red := linear(r)
	green := linear(g)
	blue := linear(b)
	l := math.cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
	m := math.cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
	s := math.cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)
	lightness := 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
	a := 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
	bb := 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
	chroma := math.sqrt(a * a + bb * bb)
	mut hue := math.atan2(bb, a) * 180 / math.pi
	if hue < 0 {
		hue += 360
	}
	// Um cinza não tem matiz: o ângulo que sairia da conta seria ruído de arredondamento.
	if chroma < 0.0005 {
		hue = 0
	}
	return lightness, chroma, hue
}

// luminance é o brilho percebido da cor, na escala inteira em que só a ordem importa.
fn luminance(color u32) int {
	r, g, b := channels_of(color)
	return 299 * r + 587 * g + 114 * b
}

// shows_image diz se o ponto da janela mostra a imagem: dentro dela, abaixo da barra e fora dos painéis que ficam por cima. Com zoom, a imagem passa por baixo da barra; onde ela está coberta, a cor lida não seria a que se vê, e fora da imagem à vista a última cor lida continua valendo.
fn (e Editor) shows_image(x int, y int) bool {
	if y < toolbar_height || !contains(e.view, x, y) {
		return false
	}
	// A ajuda da régua também fica por cima da imagem, mas fora de covered: o clique nela passa para a imagem, e o ponteiro sobre ela continua o da régua. Para o conta-gotas, porém, a cor debaixo dela não é a que se vê.
	if help := e.ruler_help_rect() {
		if contains(help, x, y) {
			return false
		}
	}
	return !e.covered(x, y)
}

// covered diz se um dos painéis que ficam por cima da imagem cobre o ponto: o de opções, a paleta, o do tamanho ou o do zoom.
fn (e Editor) covered(x int, y int) bool {
	if panel := e.options_panel() {
		if contains(panel, x, y) {
			return true
		}
	}
	if panel := e.palette_rect() {
		if contains(panel, x, y) {
			return true
		}
	}
	if panel := e.resize_panel() {
		if contains(panel, x, y) {
			return true
		}
	}
	if panel := e.zoom_panel() {
		if contains(panel, x, y) {
			return true
		}
	}
	return false
}

// sample_at devolve a cor da captura sob o ponto da janela, ou none fora da imagem.
fn (e Editor) sample_at(x int, y int) ?u32 {
	if !e.shows_image(x, y) {
		return none
	}
	spot := e.to_image(Rect{
		x: x
		y: y
	})
	if spot.x < 0 || spot.y < 0 || spot.x >= e.current.width || spot.y >= e.current.height {
		return none
	}
	return C.GetPixel(e.current.dc, spot.x, spot.y)
}

// darkest_near devolve a cor mais escura no quadro em volta do ponto, ou none fora da
// imagem. O quadro é medido na janela e convertido para a imagem, para cobrir o mesmo
// pedaço do que se vê em qualquer escala.
fn (e Editor) darkest_near(x int, y int) ?u32 {
	if !e.shows_image(x, y) {
		return none
	}
	spot := e.to_image(Rect{
		x: x
		y: y
	})
	reach := max(int(f64(picker_reach) / e.scale), 1)
	mut best := u32(0)
	mut best_light := 1 << 30
	for row in max(spot.y - reach, 0) .. min(spot.y + reach + 1, e.current.height) {
		for column in max(spot.x - reach, 0) .. min(spot.x + reach + 1, e.current.width) {
			color := C.GetPixel(e.current.dc, column, row)
			light := luminance(color)
			if light < best_light {
				best_light = light
				best = color
			}
		}
	}
	if best_light == 1 << 30 {
		return none
	}
	return best
}

// sample_cursor guarda a cor sob o ponteiro e diz se ela mudou, que é quando o bloco
// precisa ser redesenhado. Fora da imagem a última cor lida continua valendo.
fn (mut e Editor) sample_cursor(x int, y int) bool {
	color := e.sample_at(x, y) or { return false }
	if color == e.sampled {
		return false
	}
	e.sampled = color
	return true
}

// next_format passa para o formato seguinte, voltando ao primeiro depois do último.
fn (mut e Editor) next_format() string {
	e.color_format = (e.color_format + 1) % color_format_names.len
	return 'Tab copia em ${color_format_names[e.color_format]}: ${color_text(e.sampled,
		e.color_format)}'
}

// copy_color copia a cor sob o ponteiro, ou a mais escura em volta dele, no formato
// escolhido. A cor copiada passa a ser a do bloco, para ele mostrar o que foi copiado.
fn (mut e Editor) copy_color(hwnd voidptr, darkest bool) string {
	// Relida na hora, e não a última lida pelo movimento do mouse: zoom, desfazer ou redimensionar mudam o pixel sob o ponteiro parado.
	e.sampled = if darkest {
		e.darkest_near(e.cursor_x, e.cursor_y) or { e.sampled }
	} else {
		e.sample_at(e.cursor_x, e.cursor_y) or { e.sampled }
	}
	text := color_text(e.sampled, e.color_format)
	copy_text(hwnd, text) or { return 'Falha ao copiar a cor: ${err}' }
	return 'Copiado ${text}'
}

// picker_rect devolve o bloco da cor na barra, ou none quando a janela é estreita demais
// para os blocos da direita aparecerem.
fn picker_rect(width int) ?Rect {
	left := width - status_block_width
	if left < toolbar_tools_width() {
		return none
	}
	return Rect{
		x: left
		y: 0
		width: status_color_width - 10
		height: toolbar_height
	}
}

// draw_picker desenha o bloco da cor: o disco, o valor em hexadecimal e o formato em que o
// Tab copia. Ele não entra na composição fixa da barra porque muda a cada movimento do
// mouse, e refazer a composição a cada pixel repetiria a redução da imagem inteira — ele
// vem por cima, junto com a prévia do arrasto.
fn draw_picker(hdc voidptr, e &Editor) {
	block := picker_rect(e.canvas_width) or { return }
	middle := block.y + block.height / 2
	fill_circle(hdc, block.x + 10, middle, 10.5, picker_ring_color)
	fill_circle(hdc, block.x + 10, middle, 9.5, e.sampled)
	old_font := C.SelectObject(hdc, e.font)
	C.SetBkMode(hdc, transparent_bk)
	draw_status_block(hdc, block.x + 28, color_text(e.sampled, 0), 'Tab copia ${color_format_names[e.color_format]}')
	C.SelectObject(hdc, old_font)
}
