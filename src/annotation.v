module main

import math

fn C.SetTextAlign(hdc voidptr, mode u32) u32

// TA_CENTER, para o número ficar centrado no disco sem medir a largura dele.
const ta_center = u32(6)
const counter_text_color = u32(0x00ffffff)

// Vermelho, no formato COLORREF, que é 0x00bbggrr.
const annotation_color = u32(0x000000ff)
// Espessura do traço em pixels da imagem original.
const annotation_width = 3

// draw_frame desenha uma moldura vazada em volta da área, afastada por `offset` pixels.
fn draw_frame(hdc voidptr, area Rect, color u32, thickness int, offset int) {
	pen := C.CreatePen(ps_solid, thickness, color)
	old_pen := C.SelectObject(hdc, pen)
	old_brush := C.SelectObject(hdc, C.GetStockObject(null_brush))
	C.Rectangle(hdc, area.x - offset, area.y - offset, area.x + area.width + offset, area.y + area.height + offset)
	C.SelectObject(hdc, old_brush)
	C.SelectObject(hdc, old_pen)
	C.DeleteObject(pen)
}

// draw_drag_marker marca a área arrastada com duas molduras encaixadas, clara por dentro
// e escura por fora, para continuar visível sobre qualquer conteúdo da captura.
fn draw_drag_marker(hdc voidptr, area Rect) {
	draw_frame(hdc, area, border_color, 1, 0)
	draw_frame(hdc, area, 0x00000000, 1, 1)
}

// draw_mark desenha uma marcação na área dada, seja ela a de verdade ou a prévia do
// arrasto. É o único
// lugar que sabe qual primitiva cada ferramenta usa.
fn draw_mark(hdc voidptr, mark Shape, area Rect, thickness f32, number int) {
	match mark.tool {
		.ruler {
			draw_ruler(hdc, mark, area, thickness)
		}
		.magnifier {
			draw_magnifier(hdc, mark, area, thickness)
		}
		.blur {
			draw_blur(hdc, mark, area)
		}
		.text {
			draw_text(hdc, mark, area, thickness)
		}
		.counter {
			draw_counter(hdc, mark, area, thickness, number)
		}
		.oval {
			draw_oval(hdc, area, mark.style, mark.color, thickness)
		}
		.line {
			from_x, from_y, to_x, to_y := line_ends(area, mark.origin)
			draw_line(hdc, f64(from_x), f64(from_y), f64(to_x), f64(to_y), mark.style, mark.color, thickness)
		}
		.freehand, .highlighter {
			draw_stroke(hdc, mark.points.map(remap(it, mark.area, area)).map(point(f64(it.x), f64(it.y))), mark.color, thickness, stroke_alpha(mark.tool))
		}
		.arrow {
			from_x, from_y, to_x, to_y := line_ends(area, mark.origin)
			draw_arrow(hdc, from_x, from_y, to_x, to_y, mark.style, mark.color, thickness)
		}
		else {
			draw_outline(hdc, area, mark.style, mark.color, thickness, mark_corner(mark, thickness))
		}
	}
}

// mark_corner é o raio do canto arredondado na escala em que a marcação está sendo desenhada. A espessura desenhada sobre a da marcação é essa escala, a mesma conta que dá o tamanho do rótulo da régua: com o raio fixo em pixels de quem desenha, a prévia com zoom saía de canto quase reto, e o resultado, redondo.
fn mark_corner(mark Shape, thickness f32) int {
	return int(math.round(f64(corner_radius) * f64(thickness) / f64(max(mark.thickness, 1))))
}

// line_ends devolve as duas pontas do traço que atravessa a caixa: a primeira no canto de
// onde o arrasto partiu, a segunda no canto oposto.
fn line_ends(area Rect, origin Corner) (int, int, int, int) {
	right := area.x + area.width
	bottom := area.y + area.height
	if origin == .top_left {
		return area.x, area.y, right, bottom
	}
	if origin == .top_right {
		return right, area.y, area.x, bottom
	}
	if origin == .bottom_right {
		return right, bottom, area.x, area.y
	}
	return area.x, bottom, right, area.y
}

// O raio do balão sai da espessura, e não de uma constante somada a ela: assim ele encolhe
// junto com a imagem na prévia, do mesmo jeito que o traço.
fn counter_radius(thickness f32) f32 {
	return thickness * 4
}

// counter_box é a caixa do balão: a do disco em volta do centro, com o raio que a espessura dá. É a mesma conta ao pôr o balão e ao trocar a espessura dele.
fn counter_box(center Point, thickness int) Rect {
	radius := int(counter_radius(f32(thickness)))
	return Rect{
		x: center.x - radius
		y: center.y - radius
		width: 2 * radius
		height: 2 * radius
	}
}

// A espessura com que o numerador começa, que vira um balão de raio confortável.
const counter_thickness = 6
// Onde a ponta fina começa, por dentro do disco, e até onde ela vai, em raios; e quanto
// ela abre para cada lado da direção, em radianos.
const thin_tip_base = 0.8
const thin_tip_reach = 1.5
const thin_tip_spread = 0.45
// A distância da alça que gira a ponta, em raios: além da ponta, fora do disco.
const tip_handle_reach = 2.2

// draw_counter desenha o balão: o disco com o número e, conforme o estilo, a ponta — fina
// ou grossa — virada para a direção guardada.
fn draw_counter(hdc voidptr, mark Shape, area Rect, thickness f32, number int) {
	center := remap(mark.points[0], mark.area, area)
	radius := counter_radius(thickness)
	draw_tip(hdc, center, radius, tip_angle(mark), mark.style.tip, mark.color)
	fill_circle(hdc, center.x, center.y, radius, mark.color)
	draw_counter_number(hdc, center, radius, number)
}

// tip_angle devolve para onde a ponta aponta, em radianos: do centro ao segundo ponto do
// balão. Sem ele — ou com ele em cima do centro —, a ponta fica embaixo à direita, como na
// referência.
fn tip_angle(mark Shape) f64 {
	if mark.points.len < 2 {
		return math.pi / 4
	}
	dx := f64(mark.points[1].x - mark.points[0].x)
	dy := f64(mark.points[1].y - mark.points[0].y)
	if dx == 0 && dy == 0 {
		return math.pi / 4
	}
	return math.atan2(dy, dx)
}

// tip_handle devolve onde fica a alça que gira a ponta, em coordenadas da captura: na
// direção da ponta, além dela.
fn tip_handle(mark Shape) Point {
	reach := f64(counter_radius(f32(mark.thickness))) * tip_handle_reach
	angle := tip_angle(mark)
	return Point{
		x: mark.points[0].x + int(math.round(reach * math.cos(angle)))
		y: mark.points[0].y + int(math.round(reach * math.sin(angle)))
	}
}

// aimed_at devolve o balão com a ponta virada para o ponto, e o resto como estava.
fn (s Shape) aimed_at(target Point) Shape {
	return Shape{
		...s
		points: [s.points[0], target]
	}
}

// draw_tip desenha a ponta do balão, antes do disco: a base dela fica por dentro dele, e o
// disco cobre a emenda.
fn draw_tip(hdc voidptr, center Point, radius f32, angle f64, tip Tip, color u32) {
	match tip {
		.thin { fill_polygon(hdc, thin_tip(center, radius, angle), color) }
		.thick { fill_polygon(hdc, thick_tip(center, radius, angle), color) }
		.none {}
	}
}

// along devolve o ponto a `reach` do centro, na direção `angle`.
fn along(center Point, reach f64, angle f64) C.GdipPointF {
	return pointf(f64(center.x) + reach * math.cos(angle), f64(center.y) + reach * math.sin(angle))
}

// thin_tip é a ponta fina: um triângulo estreito, com a base por dentro do disco e o bico
// um pouco além da borda.
fn thin_tip(center Point, radius f32, angle f64) []C.GdipPointF {
	r := f64(radius)
	return [along(center, r * thin_tip_base, angle - thin_tip_spread),
		along(center, r * thin_tip_reach, angle),
		along(center, r * thin_tip_base, angle + thin_tip_spread)]
}

// thick_tip é a ponta grossa, a gota: o quadrado que troca um quarto do disco por um canto
// vivo, girado para a direção pedida. Dois lados dele ficam sobre os raios e somem dentro
// do disco; os outros dois fecham o canto.
fn thick_tip(center Point, radius f32, angle f64) []C.GdipPointF {
	r := f64(radius)
	return [along(center, 0.0, angle), along(center, r, angle - math.pi / 4),
		along(center, r * math.sqrt(2.0), angle), along(center, r, angle + math.pi / 4)]
}

// draw_counter_sample desenha a miniatura de um botão de estilo do numerador: o balão na
// forma dele, com a ponta embaixo à direita, e sem número, que num botão de trinta pixels
// não se leria.
fn draw_counter_sample(hdc voidptr, button Rect, tip Tip, color u32) {
	center := Point{button.x + button.width / 2 - 2, button.y + button.height / 2 - 2}
	radius := f32(button.width) / 2 - 8
	draw_tip(hdc, center, radius, math.pi / 4, tip, color)
	fill_circle(hdc, center.x, center.y, radius, color)
}

// draw_counter_number escreve o número no meio do disco, em branco, com a fonte
// dimensionada pelo raio.
fn draw_counter_number(hdc voidptr, center Point, radius f32, number int) {
	// Com piso: o corpo zero, numa prévia muito reduzida, faz o Windows escolher o tamanho padrão da fonte, e o número saía maior que o balão.
	height := max(int(radius * 1.2), 1)
	font := C.CreateFontW(-height, 0, 0, 0, 700, 0, 0, 0, default_charset, 0, 0, antialiased_quality, 0, 'Segoe UI'.to_wide())
	old_font := C.SelectObject(hdc, font)
	old_align := C.SetTextAlign(hdc, ta_center)
	C.SetBkMode(hdc, transparent_bk)
	C.SetTextColor(hdc, counter_text_color)
	label := number.str()
	C.TextOutW(hdc, center.x, center.y - int(f64(height) * 0.62), label.to_wide(), utf16_length(label))
	C.SetTextAlign(hdc, old_align)
	C.SelectObject(hdc, old_font)
	C.DeleteObject(font)
}

// draw_preview mostra a marcação enquanto ela é arrastada, com a espessura reduzida junto
// com a imagem para corresponder ao resultado.
fn draw_preview(hdc voidptr, area Rect, state &Editor) {
	if state.tool == .text {
		// O arrasto do texto só delimita onde ele vai caber; o que aparece ali ainda não
		// existe, então a prévia é a moldura e não uma marcação vazia.
		draw_drag_marker(hdc, area)
		return
	}
	if state.tool in stroke_tools {
		// O traço não cabe na caixa: a prévia sai dos pontos recolhidos até agora. Ela é recortada pela imagem, como as outras: o que passava da borda, para o fundo ou para a moldura, aparecia no arrasto e sumia ao soltar.
		saved := state.clip_to_image(hdc)
		draw_stroke(hdc, state.stroke.map(point(f64(it.x), f64(it.y))), state.color, preview_thickness(state.thickness, state.view_scale()), stroke_alpha(state.tool))
		C.RestoreDC(hdc, saved)
		return
	}
	if state.tool == .counter {
		// O balão é posto por clique: a prévia sai da própria origem do arrasto.
		state.draw_mark_on_image(hdc, state.counter_shape(), state.to_client(state.counter_shape().area), preview_thickness(state.thickness, state.view_scale()), state.next_number())
		return
	}
	// A caixa em pixels da captura: é dela que a régua tira o comprimento que escreve, e dela a lupa tira a lente pela mesma conta da soltura, para a lente da prévia ser a que vai ficar.
	source := state.drag_area()
	state.draw_mark_on_image(hdc, Shape{
		tool: state.tool
		area: source
		style: state.style
		color: state.color
		// A espessura da marcação, sem escala: é a razão entre ela e a da prévia que leva o rótulo da régua ao tamanho que ele vai ter.
		thickness: state.thickness
		origin: state.drag_corner()
		points: if state.tool == .magnifier { state.drag_points(source) } else { []Point{} }
	}, area, preview_thickness(state.thickness, state.view_scale()), 0)
}

// preview_thickness reduz a espessura junto com a imagem, para a prévia corresponder ao
// que vai ser desenhado. Antes isto era um arredondamento para inteiro, e a prévia saía
// mais fina que o resultado; a caneta do GDI+ aceita a fração.
//
// Não há piso aqui: desta espessura saem também o canto, o balão, a ponta da seta e a etiqueta da régua, e um piso de um pixel os inflava na captura muito reduzida — a marcação encolhia ao soltar. O traço não some da vista mesmo assim: a caneta do GDI+ nunca desenha menos de um pixel, e o disco do clique no traço livre tem piso próprio.
fn preview_thickness(thickness int, scale f64) f32 {
	return f32(f64(thickness) * scale)
}

// Quanto do fundo o traço deixa passar. O marca-texto é translúcido de propósito, para
// destacar sem esconder; o traço livre é opaco.
const highlight_alpha = u8(110)

// A cor e a largura com que o marca-texto começa, que não são as das outras ferramentas.
const highlight_color = u32(0x0000d7ff)
const highlight_thickness = 12

// stroke_alpha devolve a opacidade do traço de cada ferramenta.
fn stroke_alpha(tool Tool) u8 {
	return if tool == .highlighter { highlight_alpha } else { u8(255) }
}

// default_color e default_thickness são com o que cada ferramenta começa.
fn default_color(tool Tool) u32 {
	return if tool == .highlighter { highlight_color } else { annotation_color }
}

fn default_thickness(tool Tool) int {
	return match tool {
		.highlighter { highlight_thickness }
		.counter { counter_thickness }
		.text { text_thickness }
		.blur { blur_thickness }
		.ruler { ruler_thickness }
		else { annotation_width }
	}
}

// same_family diz se duas ferramentas dividem a cor e a espessura: a mesma ferramenta, ou duas sem padrão próprio, que começam todas com o traço fino e vermelho. Cada uma das que têm padrão próprio é uma família só dela: o numerador e o borrar começam os dois no 6, mas no numerador o número é o raio, e no borrar é o bloco.
fn same_family(a Tool, b Tool) bool {
	return a == b || (plain_tool(a) && plain_tool(b))
}

// plain_tool diz se a ferramenta começa com o traço de sempre, sem cor nem espessura próprias.
fn plain_tool(tool Tool) bool {
	return default_thickness(tool) == annotation_width && default_color(tool) == annotation_color
}
