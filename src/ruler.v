module main

import math

// A régua: um traço com as duas pontas marcadas e o comprimento escrito ao lado, em pixels
// da captura. Ela se desenha como a linha — mesma geometria, mesmas alças, mesmo `Shift`
// para prender o ângulo — e acrescenta as marcas de ponta e o rótulo.
//
// Ela também mede sozinha, pelo teclado, achando onde começa e onde termina a faixa de cor
// sob o ponteiro — a largura de um botão ou a altura de uma barra, sem mirar nas bordas
// dele. As teclas estão em ruler_probe.v; a leitura da faixa está aqui.

// A espessura com que a régua começa. Ela é um instrumento, e não um destaque: o traço
// fino atrapalha menos o que está sendo medido.
const ruler_thickness = 2
// Quanto um canal pode variar e o pixel ainda contar como a mesma cor. Sem folga, o
// serrilhado suavizado de uma borda ou um degradê quase imperceptível cortariam a faixa no
// meio; com folga demais, dois tons vizinhos de uma interface viram um só.
const ruler_tolerance = 12
const dt_singleline = u32(0x0020)
const vk_control = 0x11

// ruler_length devolve o comprimento do traço, em pixels da captura.
fn ruler_length(area Rect) int {
	return int(math.round(math.sqrt(f64(area.width * area.width + area.height * area.height))))
}

// ruler_label é o que o rótulo escreve.
fn ruler_label(area Rect) string {
	return '${ruler_length(area)}px'
}

// draw_ruler desenha o traço, as duas marcas de ponta e o rótulo. O comprimento sai da
// caixa da marcação, que está em pixels da captura, e não da área de desenho — que na
// prévia está reduzida junto com a imagem.
fn draw_ruler(hdc voidptr, mark Shape, area Rect, thickness f32) {
	from_x, from_y, to_x, to_y := line_ends(area, mark.origin)
	draw_line(hdc, f64(from_x), f64(from_y), f64(to_x), f64(to_y), Style{}, mark.color, thickness)
	dx := f64(to_x - from_x)
	dy := f64(to_y - from_y)
	length := math.sqrt(dx * dx + dy * dy)
	// A prévia recebe a espessura já na escala da vista, e as constantes das marcas e do rótulo passam pela mesma escala: sem isso o rótulo mudava de tamanho no instante em que a régua era solta.
	ratio := thickness / f32(max(mark.thickness, 1))
	if length >= 1 {
		// As marcas são perpendiculares ao traço, do mesmo tamanho nas duas pontas.
		reach := (f64(mark.thickness) * 2 + 3) * f64(ratio)
		across_x := -dy / length * reach
		across_y := dx / length * reach
		for end in [[from_x, from_y], [to_x, to_y]] {
			draw_line(hdc, f64(end[0]) + across_x, f64(end[1]) + across_y, f64(end[0]) - across_x,
				f64(end[1]) - across_y, Style{}, mark.color, thickness)
		}
	}
	draw_ruler_label(hdc, ruler_label(mark.area), (from_x + to_x) / 2, (from_y + to_y) / 2,
		area.width >= area.height, mark.color, thickness, ratio)
}

// draw_ruler_label escreve o comprimento numa etiqueta da cor da régua, ao lado do meio do
// traço: em cima quando ele é deitado, à direita quando é em pé, para nunca ficar por cima
// da linha que mede.
// `ratio` é a escala da vista em que a etiqueta é desenhada: um no resultado, e a da prévia na janela.
fn draw_ruler_label(hdc voidptr, label string, x int, y int, lying bool, color u32, thickness f32, ratio f32) {
	// Com piso, pelo mesmo motivo do número do balão: o corpo zero é o tamanho padrão da fonte.
	height := max(int(10 * ratio + thickness * 2), 1)
	font := C.CreateFontW(-height, 0, 0, 0, 700, 0, 0, 0, default_charset, 0, 0, antialiased_quality,
		0, 'Segoe UI'.to_wide())
	old_font := C.SelectObject(hdc, font)
	defer {
		C.SelectObject(hdc, old_font)
		C.DeleteObject(font)
	}
	mut measured := C.RECT{}
	C.DrawTextW(hdc, label.to_wide(), -1, &measured, dt_singleline | dt_noprefix | dt_calcrect)
	pad := max(height / 4, 2)
	gap := int(thickness + f32(pad) + 2 * ratio)
	box := label_box(hdc, x, y, lying, gap, measured.right + 2 * pad, measured.bottom + pad)
	fill_round_rect(hdc, box, max(pad, 2), color, 255)
	C.SetBkMode(hdc, transparent_bk)
	C.SetTextColor(hdc, text_label_color)
	mut place := C.RECT{
		left: box.x
		top: box.y
		right: box.x + box.width
		bottom: box.y + box.height
	}
	C.DrawTextW(hdc, label.to_wide(), -1, &place, dt_singleline | dt_noprefix | dt_center | dt_vcenter)
}

fn C.GetClipBox(hdc voidptr, area &C.RECT) int

// label_box põe a etiqueta ao lado do meio do traço e, quando ali ela sairia da imagem, a vira para o outro lado — para baixo a deitada, para a esquerda a em pé — e por fim a prende dentro dela. Os limites são os do recorte do DC: no resultado, o bitmap da imagem; na janela, a imagem que a prévia recortou. Rente à borda de cima, a etiqueta de uma régua deitada saía cortada, ou nem aparecia.
fn label_box(hdc voidptr, x int, y int, lying bool, gap int, width int, height int) Rect {
	mut bounds := C.RECT{}
	C.GetClipBox(hdc, &bounds)
	mut left := x + gap
	mut top := y - height / 2
	if lying {
		left = x - width / 2
		top = y - gap - height
		if top < bounds.top {
			top = y + gap
		}
	} else if left + width > bounds.right {
		left = x - gap - width
	}
	// Uma etiqueta maior que a imagem fica encostada à esquerda e em cima, onde começa a leitura.
	return Rect{
		x: max(min(left, bounds.right - width), bounds.left)
		y: max(min(top, bounds.bottom - height), bounds.top)
		width: width
		height: height
	}
}

// DT_CENTER e DT_VCENTER centram o texto na etiqueta nos dois sentidos.
const dt_center = u32(0x0001)
const dt_vcenter = u32(0x0004)

// measure_run devolve onde começa e onde termina a faixa de cor que passa pelo ponto, ao
// longo da linha ou da coluna dele. O fim é exclusivo: uma faixa que ocupa os pixels vinte
// a sessenta e nove devolve vinte e setenta, e a diferença é a largura.
fn measure_run(hdc voidptr, width int, height int, x int, y int, vertical bool) (int, int) {
	line := read_line(hdc, width, height, x, y, vertical)
	at := if vertical { y } else { x }
	// Sem a cópia da linha — o GDI sem memória para ela — a medida é só o pixel do ponto.
	if at < 0 || at >= line.len {
		return at, at + 1
	}
	seed := line[at]
	mut start := at
	for start > 0 && same_color(line[start - 1], seed) {
		start--
	}
	mut end := at + 1
	for end < line.len && same_color(line[end], seed) {
		end++
	}
	return start, end
}

fn C.CreateDIBSection(hdc voidptr, info voidptr, usage u32, bits &voidptr, section voidptr, offset u32) voidptr

fn C.GdiFlush() bool

// read_line copia para a memória, numa tacada só, a linha ou a coluna inteira do ponto. A medida roda a cada quadro enquanto a tecla está apertada, e ler pixel a pixel era uma ida ao GDI por pixel: milhares numa imagem de trabalho grande, a cada movimento do mouse e a cada repetição da tecla. Os pixels saem como 0x00RRGGBB, na ordem inversa da do GetPixel, o que não muda nada para same_color, que compara canal a canal.
fn read_line(hdc voidptr, width int, height int, x int, y int, vertical bool) []u32 {
	limit := if vertical { height } else { width }
	header := BitmapInfoHeader{
		bi_size: bitmap_info_header_size
		bi_width: if vertical { 1 } else { limit }
		// Altura negativa pede as linhas de cima para baixo.
		bi_height: if vertical { -limit } else { -1 }
		bi_planes: 1
		bi_bit_count: 32
		bi_compression: bi_rgb
	}
	mut bits := voidptr(unsafe { nil })
	dib := C.CreateDIBSection(hdc, voidptr(&header), dib_rgb_colors, &bits, unsafe { nil }, 0)
	if dib == unsafe { nil } {
		return []u32{}
	}
	dc := C.CreateCompatibleDC(hdc)
	previous := C.SelectObject(dc, dib)
	if vertical {
		C.BitBlt(dc, 0, 0, 1, limit, hdc, x, 0, srccopy)
	} else {
		C.BitBlt(dc, 0, 0, limit, 1, hdc, 0, y, srccopy)
	}
	// O GDI pode estar com a cópia pela metade até ser esvaziado.
	C.GdiFlush()
	mut line := []u32{len: limit}
	unsafe { vmemcpy(line.data, bits, limit * 4) }
	C.SelectObject(dc, previous)
	C.DeleteDC(dc)
	C.DeleteObject(dib)
	return line
}

// same_color diz se duas cores estão dentro da folga em todos os canais. Os deslocamentos são um vetor fixo, na pilha: um vetor comum seria uma alocação a cada pixel comparado.
fn same_color(a u32, b u32) bool {
	for shift in [u32(0), 8, 16]! {
		if abs(int((a >> shift) & 0xff) - int((b >> shift) & 0xff)) > ruler_tolerance {
			return false
		}
	}
	return true
}
