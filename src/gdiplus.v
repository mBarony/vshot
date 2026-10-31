module main

import math

#flag windows -lgdiplus

#include "gdipflat.h"

fn C.GdiplusStartup(token &usize, input voidptr, output voidptr) int

fn C.GdiplusShutdown(token usize)

fn C.GdipCreateFromHDC(hdc voidptr, graphics &voidptr) int

fn C.GdipDeleteGraphics(graphics voidptr) int

fn C.GdipSetSmoothingMode(graphics voidptr, mode int) int

fn C.GdipCreatePen1(argb u32, width f32, unit int, pen &voidptr) int

fn C.GdipDeletePen(pen voidptr) int

fn C.GdipDrawRectangle(graphics voidptr, pen voidptr, x f32, y f32, width f32, height f32) int

fn C.GdipCreateSolidFill(argb u32, brush &voidptr) int

fn C.GdipDeleteBrush(brush voidptr) int

fn C.GdipFillEllipse(graphics voidptr, brush voidptr, x f32, y f32, width f32, height f32) int

fn C.GdipDrawEllipse(graphics voidptr, pen voidptr, x f32, y f32, width f32, height f32) int

fn C.GdipDrawLine(graphics voidptr, pen voidptr, x1 f32, y1 f32, x2 f32, y2 f32) int

fn C.GdipSetPenDashStyle(pen voidptr, style int) int

fn C.GdipSetPenStartCap(pen voidptr, cap int) int

fn C.GdipDrawCurveI(graphics voidptr, pen voidptr, points voidptr, count int) int

fn C.GdipSetPenEndCap(pen voidptr, cap int) int

// O número faz parte do nome que a gdiplus.dll exporta.
fn C.GdipSetPenDashCap197819(pen voidptr, cap int) int

fn C.GdipSetClipRectI(graphics voidptr, x int, y int, width int, height int, mode int) int

// CombineModeReplace: o recorte novo toma o lugar do anterior, em vez de se somar a ele.
const combine_mode_replace = 0
// CombineModeExclude: o recorte passa a ser tudo, menos o retângulo dado.
const combine_mode_exclude = 4

fn C.GdipFillPolygon(graphics voidptr, brush voidptr, points voidptr, count int, mode int) int

fn C.GdipFillRectangleI(graphics voidptr, brush voidptr, x int, y int, width int, height int) int

fn C.GdipCreatePath(mode int, path &voidptr) int

fn C.GdipDeletePath(path voidptr) int

fn C.GdipAddPathArcI(path voidptr, x int, y int, width int, height int, start f32, sweep f32) int

fn C.GdipClosePathFigure(path voidptr) int

fn C.GdipDrawPath(graphics voidptr, pen voidptr, path voidptr) int

fn C.GdipFillPath(graphics voidptr, brush voidptr, path voidptr) int

fn C.GdipStartPathFigure(path voidptr) int

fn C.GdipAddPathLine(path voidptr, x1 f32, y1 f32, x2 f32, y2 f32) int

fn C.GdipAddPathBezier(path voidptr, x1 f32, y1 f32, x2 f32, y2 f32, x3 f32, y3 f32, x4 f32, y4 f32) int

fn C.GdipAddPathEllipse(path voidptr, x f32, y f32, width f32, height f32) int

fn C.GdipAddPathArc(path voidptr, x f32, y f32, width f32, height f32, start f32, sweep f32) int

fn C.GdipSetPenLineJoin(pen voidptr, join int) int

fn C.GdipTranslateWorldTransform(graphics voidptr, dx f32, dy f32, order int) int

fn C.GdipResetWorldTransform(graphics voidptr) int

@[typedef]
struct C.GdipPointI {
	X int
	Y int
}

// GdipPointF é o ponto de coordenadas fracionárias do GDI+, o que os polígonos suavizados recebem: arredondado para inteiro, cada vértice anda até meio pixel, e numa seta fina isso muda a forma.
@[typedef]
struct C.GdipPointF {
	X f32
	Y f32
}

@[typedef]
struct C.GdiplusStartupInputC {
	GdiplusVersion           u32
	DebugEventCallback       voidptr
	SuppressBackgroundThread int
	SuppressExternalCodecs   int
}

// SmoothingModeAntiAlias. É o que o GDI não tem: sem ele a borda de tudo que não for
// horizontal ou vertical sai escadeada.
const smoothing_antialias = 4
// UnitPixel, para a espessura da caneta ser lida em pixels e não em pontos.
const unit_pixel = 2

// start_gdiplus liga a camada de desenho e devolve o testemunho que a desliga.
//
// Ela é ligada na abertura do editor e desligada no fechamento, em vez de na partida da
// aplicação: o GDI+ sobe uma thread e alguns megabytes, e esta aplicação passa quase todo
// o tempo parada na bandeja sem editor nenhum aberto.
fn start_gdiplus() !usize {
	mut token := usize(0)
	input := C.GdiplusStartupInputC{
		GdiplusVersion: 1
	}
	if C.GdiplusStartup(&token, &input, unsafe { nil }) != 0 {
		return error('GdiplusStartup falhou')
	}
	return token
}

// stop_gdiplus desliga a camada de desenho. Só pode ser chamada depois que todo objeto do
// GDI+ já foi devolvido, e é por isso que ela é a última coisa a acontecer no editor.
fn stop_gdiplus(token usize) {
	C.GdiplusShutdown(token)
}

// to_argb converte a cor do formato do GDI, que é 0x00bbggrr, para o do GDI+, que é
// 0xaarrggbb, e a devolve opaca.
fn to_argb(color u32) u32 {
	return to_argb_alpha(color, 255)
}

// to_argb_alpha faz o mesmo com a opacidade que se pedir.
fn to_argb_alpha(color u32, alpha u8) u32 {
	return (u32(alpha) << 24) | ((color & 0x000000ff) << 16) | (color & 0x0000ff00) | ((color & 0x00ff0000) >> 16)
}

// Style é a aparência de uma marcação além da cor e da espessura.
// Head é o feitio da ponta da seta, entre os quatro da referência.
enum Head {
	block
	tapered
	simple
	double
}

// Tip é a ponta do balão do numerador: nenhuma, que é o círculo, a fina, ou a grossa, que
// deixa o balão em forma de gota. A direção dela é guardada à parte, na marcação.
enum Tip {
	none
	thin
	thick
}

struct Style {
	// O canto da ponta do balão do numerador.
	tip     Tip
	rounded bool
	filled  bool
	// Com preenchimento, se ele cobre por inteiro em vez de deixar a imagem passar.
	opaque bool
	dashed bool
	head    Head
	// Borrar reduz a blocos; apagar cobre com a média das cores.
	erase bool
	// A moldura projeta sombra sob a imagem.
	shadow bool
}

// DashStyleDot com DashCapRound em cada ponto: o LineCapRound só arredonda as duas pontas da linha inteira, e sem o DashCap cada ponto sai quadrado, uma fila de tijolinhos.
const dash_style_dot = 2
const dash_cap_round = 2
const line_cap_round = 2

// Raio do canto arredondado, em pixels da imagem. Preso a um terço do lado menor para uma
// marcação pequena não virar uma cápsula.
const corner_radius = 12
// Quanto do preenchimento translúcido deixa a imagem passar. O traço continua opaco: esse
// preenchimento serve para destacar a área, não para escondê-la — quem quer esconder
// escolhe o opaco.
const fill_alpha = u8(64)

// fill_opacity devolve a opacidade do preenchimento: total no opaco, parcial no translúcido.
fn fill_opacity(style Style) u8 {
	return if style.opaque { u8(255) } else { fill_alpha }
}

// draw_outline desenha um retângulo com o GDI+. A caneta fica centrada na borda, como no
// GDI, mas aqui a espessura é fracionária e a borda é suavizada.
fn draw_outline(hdc voidptr, area Rect, style Style, color u32, thickness f32, radius int) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	if style.filled {
		fill_area(graphics, area, style, color, radius)
	}
	mut pen := voidptr(unsafe { nil })
	if C.GdipCreatePen1(to_argb(color), thickness, unit_pixel, &pen) != 0 {
		return
	}
	defer {
		C.GdipDeletePen(pen)
	}
	if !style.rounded {
		C.GdipDrawRectangle(graphics, pen, f32(area.x), f32(area.y), f32(area.width), f32(area.height))
		return
	}
	// Com o lado menor abaixo de 3 px o raio dá zero e não há caminho: sai o retângulo reto, que nessa largura é o mesmo desenho, em vez de nada.
	path := rounded_path(area, radius) or {
		C.GdipDrawRectangle(graphics, pen, f32(area.x), f32(area.y), f32(area.width), f32(area.height))
		return
	}
	defer {
		C.GdipDeletePath(path)
	}
	C.GdipDrawPath(graphics, pen, path)
}

// fill_area preenche o miolo da marcação, respeitando o canto escolhido.
fn fill_area(graphics voidptr, area Rect, style Style, color u32, radius int) {
	mut brush := voidptr(unsafe { nil })
	if C.GdipCreateSolidFill(to_argb_alpha(color, fill_opacity(style)), &brush) != 0 {
		return
	}
	defer {
		C.GdipDeleteBrush(brush)
	}
	if !style.rounded {
		C.GdipFillRectangleI(graphics, brush, area.x, area.y, area.width, area.height)
		return
	}
	path := rounded_path(area, radius) or {
		C.GdipFillRectangleI(graphics, brush, area.x, area.y, area.width, area.height)
		return
	}
	defer {
		C.GdipDeletePath(path)
	}
	C.GdipFillPath(graphics, brush, path)
}

// rounded_path monta o contorno de canto arredondado com quatro arcos. O GDI+ liga um
// arco ao seguinte com uma reta por conta própria, então os lados saem de graça.
fn rounded_path(area Rect, radius int) ?voidptr {
	side := min(area.width, area.height)
	return corner_path(area, min(radius, side / 3))
}

// corner_path monta o caminho de um retângulo com o raio pedido, preso à metade do lado menor: com o diâmetro maior que o lado, os arcos se cruzavam, e o preenchimento alternado virava buracos — a sombra da moldura saía em lóbulos em volta de uma imagem pequena.
fn corner_path(area Rect, wanted int) ?voidptr {
	radius := min(wanted, min(area.width, area.height) / 2)
	mut path := voidptr(unsafe { nil })
	if C.GdipCreatePath(0, &path) != 0 {
		return none
	}
	if radius < 1 {
		C.GdipDeletePath(path)
		return none
	}
	diameter := radius * 2
	right := area.x + area.width - diameter
	bottom := area.y + area.height - diameter
	C.GdipAddPathArcI(path, area.x, area.y, diameter, diameter, 180, 90)
	C.GdipAddPathArcI(path, right, area.y, diameter, diameter, 270, 90)
	C.GdipAddPathArcI(path, right, bottom, diameter, diameter, 0, 90)
	C.GdipAddPathArcI(path, area.x, bottom, diameter, diameter, 90, 90)
	C.GdipClosePathFigure(path)
	return path
}

// fill_circle preenche um disco suavizado. É o primeiro desenho desta aplicação que o GDI
// não daria conta: um círculo pequeno feito por ele sai com a borda em degraus.
fn fill_circle(hdc voidptr, center_x int, center_y int, radius f32, color u32) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	mut brush := voidptr(unsafe { nil })
	if C.GdipCreateSolidFill(to_argb(color), &brush) != 0 {
		return
	}
	defer {
		C.GdipDeleteBrush(brush)
	}
	C.GdipFillEllipse(graphics, brush, f32(center_x) - radius, f32(center_y) - radius, radius * 2, radius * 2)
}

// fill_polygon preenche um polígono suavizado. FillModeAlternate, que é o zero, basta para
// as formas convexas desta aplicação.
fn fill_polygon(hdc voidptr, points []C.GdipPointF, color u32) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	mut brush := voidptr(unsafe { nil })
	if C.GdipCreateSolidFill(to_argb(color), &brush) != 0 {
		return
	}
	defer {
		C.GdipDeleteBrush(brush)
	}
	C.GdipFillPolygon(graphics, brush, points.data, points.len, 0)
}

// fill_round_rect preenche um retângulo com o raio e a opacidade pedidos. É o que a sombra
// da moldura empilha, camada sobre camada.
fn fill_round_rect(hdc voidptr, area Rect, radius int, color u32, alpha u8) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	path := corner_path(area, radius) or { return }
	defer {
		C.GdipDeletePath(path)
	}
	mut brush := voidptr(unsafe { nil })
	if C.GdipCreateSolidFill(to_argb_alpha(color, alpha), &brush) != 0 {
		return
	}
	defer {
		C.GdipDeleteBrush(brush)
	}
	C.GdipFillPath(graphics, brush, path)
}

// fill_rounded preenche um retângulo de cantos arredondados, opaco e suavizado. É o disco
// de cor do painel: com o GDI ele sairia com os cantos em degraus.
fn fill_rounded(hdc voidptr, area Rect, color u32, radius int) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	mut brush := voidptr(unsafe { nil })
	if C.GdipCreateSolidFill(to_argb(color), &brush) != 0 {
		return
	}
	defer {
		C.GdipDeleteBrush(brush)
	}
	path := rounded_path(area, radius) or {
		C.GdipFillRectangleI(graphics, brush, area.x, area.y, area.width, area.height)
		return
	}
	defer {
		C.GdipDeletePath(path)
	}
	C.GdipFillPath(graphics, brush, path)
}

// draw_oval desenha a elipse inscrita no retângulo. Ela não tem canto, então o estilo aqui
// se resume ao preenchimento.
fn draw_oval(hdc voidptr, area Rect, style Style, color u32, thickness f32) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	if style.filled {
		mut brush := voidptr(unsafe { nil })
		if C.GdipCreateSolidFill(to_argb_alpha(color, fill_opacity(style)), &brush) == 0 {
			C.GdipFillEllipse(graphics, brush, f32(area.x), f32(area.y), f32(area.width), f32(area.height))
			C.GdipDeleteBrush(brush)
		}
	}
	mut pen := voidptr(unsafe { nil })
	if C.GdipCreatePen1(to_argb(color), thickness, unit_pixel, &pen) != 0 {
		return
	}
	defer {
		C.GdipDeletePen(pen)
	}
	C.GdipDrawEllipse(graphics, pen, f32(area.x), f32(area.y), f32(area.width), f32(area.height))
}

// draw_line desenha o segmento entre dois pontos. Só ela usa as pontas do arrasto: as
// outras ferramentas cabem inteiras na caixa que o arrasto descreve.
// As pontas vêm em frações, que o GDI+ aceita: as asas da seta saem exatas, sem arredondar.
fn draw_line(hdc voidptr, from_x f64, from_y f64, to_x f64, to_y f64, style Style, color u32, thickness f32) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	mut pen := voidptr(unsafe { nil })
	if C.GdipCreatePen1(to_argb(color), thickness, unit_pixel, &pen) != 0 {
		return
	}
	defer {
		C.GdipDeletePen(pen)
	}
	C.GdipSetPenStartCap(pen, line_cap_round)
	C.GdipSetPenEndCap(pen, line_cap_round)
	if style.dashed {
		C.GdipSetPenDashStyle(pen, dash_style_dot)
		C.GdipSetPenDashCap197819(pen, dash_cap_round)
	}
	C.GdipDrawLine(graphics, pen, f32(from_x), f32(from_y), f32(to_x), f32(to_y))
}

// arrow_head devolve a base da ponta e as duas asas dela. Tudo sai de um vetor unitário e
// do seu perpendicular: nenhuma das quatro pontas precisa de ângulo nem de trigonometria.
fn arrow_head(from_x int, from_y int, to_x int, to_y int, thickness f32) (f64, f64, f64, f64, f64, f64) {
	dx := f64(to_x - from_x)
	dy := f64(to_y - from_y)
	length := math.sqrt(dx * dx + dy * dy)
	if length < 1 {
		return f64(to_x), f64(to_y), f64(to_x), f64(to_y), f64(to_x), f64(to_y)
	}
	along_x := dx / length
	along_y := dy / length
	// O perpendicular, girado noventa graus.
	across_x := -along_y
	across_y := along_x
	// Numa seta mais curta que a ponta, a ponta encolhe na mesma proporção em vez de passar da cauda: passando, ela se estendia antes do ponto em que o arrasto começou, e a seta cheia saía com um entalhe no meio.
	reach := math.min(f64(thickness) * head_reach, length * head_share)
	spread := reach * head_spread / head_reach
	base_x := f64(to_x) - along_x * reach
	base_y := f64(to_y) - along_y * reach
	return base_x, base_y, base_x + across_x * spread, base_y + across_y * spread, base_x - across_x * spread, base_y - across_y * spread
}

// Comprimento e meia-largura da ponta, em múltiplos da espessura do traço.
const head_reach = 3.5
const head_spread = 2.0
// Maior fração do comprimento da seta que a ponta pode ocupar.
const head_share = 0.8
// Meia-largura da haste, na cauda e junto à ponta, para a seta cheia e a afunilada.
const shaft_tail = 0.6
const shaft_neck = 0.6
const tapered_tail = 0.12

// draw_arrow desenha a seta da cauda até a ponta, no feitio que o estilo pedir.
fn draw_arrow(hdc voidptr, from_x int, from_y int, to_x int, to_y int, style Style, color u32, thickness f32) {
	match style.head {
		.block { fill_arrow(hdc, from_x, from_y, to_x, to_y, color, thickness, shaft_tail) }
		.tapered { fill_arrow(hdc, from_x, from_y, to_x, to_y, color, thickness, tapered_tail) }
		else { stroke_arrow(hdc, from_x, from_y, to_x, to_y, style, color, thickness) }
	}
}

// fill_arrow desenha a seta como um polígono de sete pontos: a haste, os ombros e a ponta.
// `tail` é a meia-largura da haste na cauda, e é só ela que separa a seta cheia da
// afunilada.
fn fill_arrow(hdc voidptr, from_x int, from_y int, to_x int, to_y int, color u32, thickness f32, tail f64) {
	base_x, base_y, wing_x, wing_y, other_x, other_y := arrow_head(from_x, from_y, to_x, to_y, thickness)
	dx := f64(to_x - from_x)
	dy := f64(to_y - from_y)
	length := math.sqrt(dx * dx + dy * dy)
	if length < 1 {
		return
	}
	across_x := -dy / length
	across_y := dx / length
	tail_half := f64(thickness) * tail
	neck_half := f64(thickness) * shaft_neck
	// Em coordenadas fracionárias: com a meia-largura da haste abaixo de um pixel, arredondar para inteiro juntava os dois cantos da cauda num ponto só, e a haste da seta cheia virava cunha e mudava de largura com o ângulo.
	fill_polygon(hdc, [
		pointf(f64(from_x) + across_x * tail_half, f64(from_y) + across_y * tail_half),
		pointf(base_x + across_x * neck_half, base_y + across_y * neck_half),
		pointf(wing_x, wing_y),
		pointf(f64(to_x), f64(to_y)),
		pointf(other_x, other_y),
		pointf(base_x - across_x * neck_half, base_y - across_y * neck_half),
		pointf(f64(from_x) - across_x * tail_half, f64(from_y) - across_y * tail_half),
	], color)
}

// stroke_arrow desenha a seta como traço: a haste mais o V da ponta, e um segundo V na
// cauda quando ela é dupla.
fn stroke_arrow(hdc voidptr, from_x int, from_y int, to_x int, to_y int, style Style, color u32, thickness f32) {
	draw_line(hdc, f64(from_x), f64(from_y), f64(to_x), f64(to_y), Style{}, color, thickness)
	_, _, wing_x, wing_y, other_x, other_y := arrow_head(from_x, from_y, to_x, to_y, thickness)
	// As asas vão com as frações: arredondadas, cada uma andava até meio pixel, por tantos diferentes, e o V pequeno da prévia saía com um braço mais longo e ângulos desiguais.
	draw_line(hdc, f64(to_x), f64(to_y), wing_x, wing_y, Style{}, color, thickness)
	draw_line(hdc, f64(to_x), f64(to_y), other_x, other_y, Style{}, color, thickness)
	if style.head != .double {
		return
	}
	_, _, back_x, back_y, back_other_x, back_other_y := arrow_head(to_x, to_y, from_x, from_y, thickness)
	draw_line(hdc, f64(from_x), f64(from_y), back_x, back_y, Style{}, color, thickness)
	draw_line(hdc, f64(from_x), f64(from_y), back_other_x, back_other_y, Style{}, color, thickness)
}

// pointf monta o ponto fracionário do GDI+, sem arredondar: é o que os polígonos suavizados recebem.
fn pointf(x f64, y f64) C.GdipPointF {
	return C.GdipPointF{
		X: f32(x)
		Y: f32(y)
	}
}

// point arredonda para o inteiro que o GDI+ espera na curva do traço livre.
fn point(x f64, y f64) C.GdipPointI {
	return C.GdipPointI{
		X: round(x)
		Y: round(y)
	}
}

// round arredonda para o inteiro mais próximo. Somar meio e truncar erra do lado negativo,
// onde truncar puxa para cima: -7,5 viraria -7 em vez de -8.
fn round(value f64) int {
	return if value < 0 { int(value - 0.5) } else { int(value + 0.5) }
}

// draw_stroke desenha o traço livre pelos pontos recolhidos no arrasto. É uma curva
// cardinal, e não uma polilinha: o traço da mão sai trêmulo, e a curva passa por todos os
// pontos suavizando o caminho entre eles.
fn draw_stroke(hdc voidptr, points []C.GdipPointI, color u32, thickness f32, alpha u8) {
	if points.len == 0 {
		return
	}
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	// Um clique sem arrasto é um ponto só, e um arrasto que não saiu do lugar deixa pontos todos iguais — com zoom, alguns pixels na janela são o mesmo pixel da captura —, que a curva desenharia como nada. Nos dois casos sai um disco do tamanho da ponta, com a mesma opacidade do traço: o do marca-texto também deixa a imagem passar.
	if points.all(it.X == points[0].X && it.Y == points[0].Y) {
		mut brush := voidptr(unsafe { nil })
		if C.GdipCreateSolidFill(to_argb_alpha(color, alpha), &brush) != 0 {
			return
		}
		defer {
			C.GdipDeleteBrush(brush)
		}
		// O disco é preenchimento, e não caneta: sem piso, na prévia muito reduzida ele quase sumia, enquanto a caneta do GDI+ nunca desenha menos de um pixel.
		width := if thickness < 1 { f32(1) } else { thickness }
		radius := width / 2
		C.GdipFillEllipse(graphics, brush, f32(points[0].X) - radius, f32(points[0].Y) - radius, width, width)
		return
	}
	mut pen := voidptr(unsafe { nil })
	if C.GdipCreatePen1(to_argb_alpha(color, alpha), thickness, unit_pixel, &pen) != 0 {
		return
	}
	defer {
		C.GdipDeletePen(pen)
	}
	C.GdipSetPenStartCap(pen, line_cap_round)
	C.GdipSetPenEndCap(pen, line_cap_round)
	C.GdipDrawCurveI(graphics, pen, points.data, points.len)
}
