module main

fn C.CreateEllipticRgn(left int, top int, right int, bottom int) voidptr

fn C.CreateRectRgn(left int, top int, right int, bottom int) voidptr

fn C.SelectClipRgn(hdc voidptr, region voidptr) int

fn C.CombineRgn(dest voidptr, first voidptr, second voidptr, mode int) int

// RGN_DIFF tira da primeira região o que está na segunda.
const rgn_diff = 4

// A lupa: um pedaço da imagem repetido maior em outro lugar dela, ligado à origem por uma
// linha. É a única marcação que desenha um pedaço da própria imagem, e não uma forma.
//
// O arrasto delimita a região de origem. A lente nasce na diagonal oposta à do arrasto:
// quem arrasta para a direita e para baixo a coloca em cima e à esquerda, e vice-versa. É o
// mesmo canto de origem que a seta usa para saber para onde apontar.
//
// Depois de nascer, a lente é dela: a posição e o tamanho ficam guardados na marcação, nos
// dois pontos que ela carrega, e cada ponta tem as suas alças. Mover ou esticar uma não
// mexe na outra, e o tamanho da lente é o que decide quanto ela amplia.

// Quantas vezes a lente amplia a região de origem.
const magnifier_zoom = 3
// Vão entre a região de origem e a lente, para a linha entre as duas aparecer.
const magnifier_gap = 10

// magnifier_lens devolve onde a lente fica, a partir da região de origem e do canto de
// onde o arrasto partiu.
fn magnifier_lens(area Rect, origin Corner) Rect {
	across, down := magnifier_direction(origin)
	return lens_toward(area, across, down)
}

// lens_within põe a lente como magnifier_lens, mas dentro do recorte: num eixo em que ela não cabe na diagonal do arrasto, vai para o outro lado da origem, e se não couber em nenhum dos dois fica presa à borda do recorte. Fora dele a lente não aparecia no resultado, e as alças dela, fora da imagem, não podiam ser pegas para trazê-la de volta.
fn lens_within(area Rect, origin Corner, bounds Rect) Rect {
	mut across, mut down := magnifier_direction(origin)
	first := lens_toward(area, across, down)
	if first.x < bounds.x || first.x + first.width > bounds.x + bounds.width {
		across = -across
	}
	if first.y < bounds.y || first.y + first.height > bounds.y + bounds.height {
		down = -down
	}
	lens := lens_toward(area, across, down)
	return Rect{
		...lens
		x: clamp(lens.x, bounds.x, bounds.x + bounds.width - lens.width)
		y: clamp(lens.y, bounds.y, bounds.y + bounds.height - lens.height)
	}
}

// lens_toward põe a lente ao lado da origem, três vezes maior, no sentido pedido em cada eixo: -1 para a esquerda ou para cima, 1 para a direita ou para baixo.
fn lens_toward(area Rect, across int, down int) Rect {
	width := area.width * magnifier_zoom
	height := area.height * magnifier_zoom
	return Rect{
		x: area.x + (area.width - width) / 2 + across * ((area.width + width) / 2 + magnifier_gap)
		y: area.y + (area.height - height) / 2 + down * ((area.height + height) / 2 + magnifier_gap)
		width: width
		height: height
	}
}

// magnifier_direction devolve para que lado a lente sai: de volta na direção de onde o
// arrasto partiu, que é o lado que o usuário deixou livre.
fn magnifier_direction(origin Corner) (int, int) {
	return match origin {
		.top_left { -1, -1 }
		.top_right { 1, -1 }
		.bottom_right { 1, 1 }
		.bottom_left { -1, 1 }
	}
}

// center_of devolve o meio do retângulo.
fn center_of(area Rect) Point {
	return Point{
		x: area.x + area.width / 2
		y: area.y + area.height / 2
	}
}

// lens_points guarda a lente como os dois cantos dela, que é como a marcação carrega
// pontos: a lupa usa esse campo para a lente, e não para um traço.
fn lens_points(lens Rect) []Point {
	return [Point{lens.x, lens.y}, Point{lens.x + lens.width, lens.y + lens.height}]
}

// corners_rect monta o retângulo entre dois cantos.
fn corners_rect(first Point, last Point) Rect {
	return Rect{
		x: first.x
		y: first.y
		width: last.x - first.x
		height: last.y - first.y
	}
}

// lens_of devolve a lente em coordenadas da captura. Uma lupa sem lente guardada — a prévia
// do arrasto, que ainda não nasceu — tem a lente na diagonal da origem.
fn lens_of(mark Shape) Rect {
	if mark.points.len != 2 {
		return magnifier_lens(mark.area, mark.origin)
	}
	return corners_rect(mark.points[0], mark.points[1])
}

// target_lens devolve a lente no espaço em que a origem está sendo desenhada: a mesma conta
// que leva a origem da captura até `area`, aplicada aos dois cantos da lente.
fn target_lens(mark Shape, area Rect) Rect {
	if mark.points.len != 2 {
		return magnifier_lens(area, mark.origin)
	}
	return corners_rect(remap(mark.points[0], mark.area, area), remap(mark.points[1], mark.area,
		area))
}

// with_lens devolve a lupa com a lente num lugar novo, e a origem onde estava.
fn (s Shape) with_lens(lens Rect) Shape {
	return Shape{
		...s
		points: lens_points(lens)
	}
}

// draw_magnifier desenha a marcação inteira: o conteúdo ampliado dentro da lente, a linha
// que liga as duas pontas, e o contorno das duas.
//
// A ordem importa em duas frentes. A região de origem é copiada antes de qualquer traço,
// senão a própria linha de ligação apareceria ampliada dentro da lente. E a linha é
// desenhada antes das duas formas, para sair de trás delas em vez de atravessá-las.
fn draw_magnifier(hdc voidptr, mark Shape, area Rect, thickness f32) {
	lens := target_lens(mark, area)
	if area.width < 1 || area.height < 1 || lens.width < 1 || lens.height < 1 {
		return
	}
	piece := new_surface(hdc, area.width, area.height) or { return }
	defer {
		piece.release()
	}
	C.BitBlt(piece.dc, 0, 0, area.width, area.height, hdc, area.x, area.y, srccopy)

	connect(hdc, area, lens, mark.style.rounded, mark.color, thickness)
	magnify(hdc, piece, area, lens, mark.style.rounded)
	corner := mark_corner(mark, thickness)
	outline_lens(hdc, lens, mark.style.rounded, mark.color, thickness, corner)
	outline_lens(hdc, area, mark.style.rounded, mark.color, thickness, corner)
}

// connect liga as duas pontas por uma linha de borda a borda. Ela é traçada do meio de uma
// ao meio da outra, com o miolo das duas recortado fora: sem o recorte sobrava um toco de
// reta dentro da origem, que na lente a ampliação cobre, mas na origem nada cobre.
fn connect(hdc voidptr, area Rect, lens Rect, rounded bool, color u32, thickness f32) {
	outside := C.CreateRectRgn(-32768, -32768, 32767, 32767)
	for part in [area, lens] {
		inside := shape_region(part, rounded)
		C.CombineRgn(outside, outside, inside, rgn_diff)
		C.DeleteObject(inside)
	}
	saved := C.SaveDC(hdc)
	C.ExtSelectClipRgn(hdc, outside, rgn_and)
	from := center_of(area)
	to := center_of(lens)
	draw_line(hdc, f64(from.x), f64(from.y), f64(to.x), f64(to.y), Style{}, color, thickness)
	C.RestoreDC(hdc, saved)
	C.DeleteObject(outside)
}

// shape_region devolve a região na forma de uma ponta: a elipse inscrita, ou o retângulo.
fn shape_region(area Rect, rounded bool) voidptr {
	if rounded {
		return C.CreateEllipticRgn(area.x, area.y, area.x + area.width, area.y + area.height)
	}
	return C.CreateRectRgn(area.x, area.y, area.x + area.width, area.y + area.height)
}

// magnify põe o pedaço já recolhido dentro da lente, ampliado e recortado na forma dela.
fn magnify(hdc voidptr, piece Frozen, area Rect, lens Rect, rounded bool) {
	region := shape_region(lens, rounded)
	// O recorte da lente se soma ao que já havia, e não o troca: na prévia, a janela prende
	// o desenho à área visível, e trocar o recorte soltaria o que vem depois.
	saved := C.SaveDC(hdc)
	C.ExtSelectClipRgn(hdc, region, rgn_and)
	// Sem interpolação: ampliar é para ver o pixel, e a média só deixaria o resultado
	// embaçado.
	C.SetStretchBltMode(hdc, stretch_coloroncolor)
	C.StretchBlt(hdc, lens.x, lens.y, lens.width, lens.height, piece.dc, 0, 0, area.width,
		area.height, srccopy)
	C.RestoreDC(hdc, saved)
	C.DeleteObject(region)
}

// outline_lens contorna a forma escolhida, que é a mesma nas duas pontas.
fn outline_lens(hdc voidptr, area Rect, rounded bool, color u32, thickness f32, radius int) {
	if rounded {
		draw_oval(hdc, area, Style{}, color, thickness)
		return
	}
	draw_outline(hdc, area, Style{ rounded: true }, color, thickness, radius)
}

// magnifier_hits diz se o ponto caiu na origem ou na lente. A caixa da marcação é só a
// origem, mas quem clica mira no que vê, e o que se vê maior é a lente.
fn magnifier_hits(area Rect, lens Rect, x int, y int) bool {
	return contains(area, x, y) || contains(lens, x, y)
}
