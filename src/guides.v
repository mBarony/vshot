module main

// As guias de alinhamento. Ao mover, redimensionar ou criar uma marcação, uma linha fina e tracejada aparece quando ela fica alinhada com outra: pela esquerda, pelo centro ou pela direita, e por cima, pelo meio ou por baixo. Perto do alinhamento a marcação encaixa nele, para a guia dizer a verdade: com a imagem reduzida, cada pixel do mouse vale mais de um da captura, e acertar o alinhamento exato na mão ficaria quase impossível.

// Até quantos pixels da janela o encaixe alcança.
const guide_reach = 5
// Um magenta, em COLORREF 0x00bbggrr: aparece sobre quase qualquer captura e não se confunde com a moldura branca da seleção.
const guide_color = u32(0x00ff00ff)
// PS_DASH: o tracejado do GDI, que só existe na caneta de um pixel — é a linha fina e discreta que a guia pede.
const ps_dash = 1

// As ferramentas cuja caixa nova encaixa nas outras marcações enquanto é arrastada. O traço segue o caminho do mouse, e o balão se põe pelo centro, em snapped_center.
const snap_tools = [Tool.rectangle, .oval, .line, .arrow, .text, .blur, .magnifier, .ruler]

// Guide é uma guia em coordenadas da captura: em pé, na coluna `at`, de `from` a `to` na vertical, ou deitada, na linha `at`, de `from` a `to` na horizontal.
struct Guide {
	standing bool
	at       int
	from     int
	to       int
}

// edges devolve as três posições da caixa num eixo — o começo, o meio e o fim —, na ordem em que as de outra caixa são comparadas: começo com começo, meio com meio, fim com fim.
fn edges(start int, size int) []int {
	return [start, start + size / 2, start + size]
}

// nearest_offset devolve o deslocamento que leva uma posição da caixa movida à de mesmo tipo de outra caixa: o menor deles dentro do alcance, ou zero quando nenhuma está perto.
fn nearest_offset(moving []int, others [][]int, reach int) int {
	mut best := reach + 1
	mut offset := 0
	for other in others {
		for kind, position in other {
			delta := position - moving[kind]
			if abs(delta) < best {
				best = abs(delta)
				offset = delta
			}
		}
	}
	return offset
}

// snapped devolve a caixa movida encaixada, em cada eixo, no alinhamento mais próximo ao alcance.
fn snapped(area Rect, others []Rect, reach int) Rect {
	dx := nearest_offset(edges(area.x, area.width), others.map(edges(it.x, it.width)), reach)
	dy := nearest_offset(edges(area.y, area.height), others.map(edges(it.y, it.height)), reach)
	return Rect{
		...area
		x: area.x + dx
		y: area.y + dy
	}
}

// snapped_side devolve onde fica o lado em movimento de uma caixa, num eixo, dado o lado parado: encaixado no lado de mesmo tipo mais próximo de outra caixa, como no mover. O meio fica de fora, porque ele anda à metade da velocidade do lado. Um encaixe que encostaria o lado no parado, ou o passaria dele, não vale: a marcação sumiria ou viraria do avesso.
fn snapped_side(fixed int, moved int, others [][]int, reach int) int {
	kind := if moved > fixed { 2 } else { 0 }
	side := moved + nearest_offset([moved], others.map([it[kind]]), reach)
	return if sign(side - fixed) == sign(moved - fixed) { side } else { moved }
}

// snapped_box devolve a caixa nova com os quatro lados encaixados: os do começo do arrasto e os da ponta dele.
fn snapped_box(area Rect, others []Rect, reach int) Rect {
	columns := others.map(edges(it.x, it.width))
	rows := others.map(edges(it.y, it.height))
	left := snapped_side(area.x + area.width, area.x, columns, reach)
	right := snapped_side(left, area.x + area.width, columns, reach)
	top := snapped_side(area.y + area.height, area.y, rows, reach)
	bottom := snapped_side(top, area.y + area.height, rows, reach)
	return Rect{
		x:      left
		y:      top
		width:  right - left
		height: bottom - top
	}
}

// stretched devolve o deslocamento de uma alça num eixo depois do encaixe. Num eixo em que a alça não mexe, ele fica como veio.
fn stretched(start int, size int, delta int, at_start bool, at_end bool, others [][]int, reach int) int {
	if at_start {
		return snapped_side(start + size, start + delta, others, reach) - start
	}
	if at_end {
		return snapped_side(start, start + size + delta, others, reach) - start - size
	}
	return delta
}

// guides devolve uma guia por posição da caixa movida que coincide com a de mesmo tipo de outra caixa. A guia atravessa as duas caixas de ponta a ponta, para mostrar com quem a marcação está alinhada.
fn guides(area Rect, others []Rect) []Guide {
	mut found := []Guide{}
	columns := edges(area.x, area.width)
	rows := edges(area.y, area.height)
	for other in others {
		other_columns := edges(other.x, other.width)
		other_rows := edges(other.y, other.height)
		for kind in 0 .. 3 {
			if columns[kind] == other_columns[kind] {
				found << Guide{
					standing: true
					at:       columns[kind]
					from:     min(area.y, other.y)
					to:       max(area.y + area.height, other.y + other.height)
				}
			}
			if rows[kind] == other_rows[kind] {
				found << Guide{
					at:   rows[kind]
					from: min(area.x, other.x)
					to:   max(area.x + area.width, other.x + other.width)
				}
			}
		}
	}
	return found
}

// guide_targets são as caixas com que a marcação em movimento se alinha: as das outras marcações que aparecem na imagem, que durante o arrasto são todas as da cena, porque a movida sai dela. A moldura fica de fora, porque veste a imagem inteira e não é uma figura; e as marcações que o recorte deixou de fora também, porque não se veem: encaixar nelas alinhava a marcação com o nada, e a guia saía da imagem.
fn (e Editor) guide_targets() []Rect {
	// Com o alinhamento desligado não há com quem alinhar: nada encaixa e nenhuma guia aparece.
	if !e.config.snap_edges {
		return []Rect{}
	}
	crop := e.scene.crop
	return e.scene.shapes.filter(it.tool != .backdrop && touches(it.area, crop)).map(it.area)
}

// touches diz se a caixa encosta no recorte ou cai dentro dele. As bordas contam, porque a linha, a seta e a régua deitadas ou em pé não têm altura ou largura, e ainda assim aparecem.
fn touches(area Rect, crop Rect) bool {
	return area.x <= crop.x + crop.width && crop.x <= area.x + area.width
		&& area.y <= crop.y + crop.height && crop.y <= area.y + area.height
}

// snap_reach é o alcance do encaixe em pixels da captura. Ele é medido na janela, e por isso encolhe com zoom e cresce com a imagem reduzida: a distância na mão é a mesma.
fn (e Editor) snap_reach() int {
	return int(f64(guide_reach) / e.view_scale())
}

// snapped_stretch devolve o deslocamento do arrasto de uma alça da caixa, com o lado pego encaixado.
fn (e Editor) snapped_stretch(dx int, dy int) (int, int) {
	area := e.grabbed.area
	targets := e.guide_targets()
	reach := e.snap_reach()
	x := stretched(area.x, area.width, dx, e.grab in [Grab.top_left, .left, .bottom_left], e.grab in [Grab.top_right, .right, .bottom_right], targets.map(edges(it.x, it.width)), reach)
	y := stretched(area.y, area.height, dy, e.grab in [Grab.top_left, .top, .top_right], e.grab in [Grab.bottom_left, .bottom, .bottom_right], targets.map(edges(it.y, it.height)), reach)
	return x, y
}

// snapped_endpoint devolve o deslocamento do arrasto de uma ponta da linha, com a ponta encaixada e a outra parada.
fn (e Editor) snapped_endpoint(dx int, dy int) (int, int) {
	x1, y1, x2, y2 := line_ends(e.grabbed.area, e.grabbed.origin)
	targets := e.guide_targets()
	columns := targets.map(edges(it.x, it.width))
	rows := targets.map(edges(it.y, it.height))
	reach := e.snap_reach()
	if e.grab == .line_start {
		return snapped_side(x2, x1 + dx, columns, reach) - x1, snapped_side(y2, y1 + dy, rows, reach) - y1
	}
	return snapped_side(x1, x2 + dx, columns, reach) - x2, snapped_side(y1, y2 + dy, rows, reach) - y2
}

// snapped_drag devolve a caixa do arrasto que cria uma marcação, encaixada. O clique parado fica fora, como no mover. Com Shift também, porque ali a ponta já está presa ao ângulo ou ao quadrado, e o encaixe desfaria isso.
fn (e Editor) snapped_drag(area Rect) Rect {
	if e.tool !in snap_tools || e.was_click() || C.GetKeyState(vk_shift) < 0 {
		return area
	}
	return snapped_box(area, e.guide_targets(), e.snap_reach())
}

// snapped_area é a caixa do arrasto na janela, para a prévia. Sem encaixe ela é a do próprio arrasto, sem passar pela ida e volta até a captura, que arredonda.
fn (e Editor) snapped_area() Rect {
	area := e.area()
	plain := e.to_source(e.to_image(area))
	fitted := e.snapped_drag(plain)
	return if fitted == plain { area } else { e.to_client(fitted) }
}

// snapped_center devolve o centro do balão novo, com o disco encaixado como uma caixa movida. Ele vale também no clique, que é o gesto de criar o balão.
fn (e Editor) snapped_center(center Point) Point {
	box := counter_box(center, e.thickness)
	fit := snapped(box, e.guide_targets(), e.snap_reach())
	return Point{center.x + fit.x - box.x, center.y + fit.y - box.y}
}

// toggle_snap liga ou desliga o alinhamento. A escolha fica na configuração do editor, e ao fechar ele a devolve à aplicação.
fn (mut e Editor) toggle_snap() {
	e.config.snap_edges = !e.config.snap_edges
	e.status = if e.config.snap_edges { 'Alinhamento ligado' } else { 'Alinhamento desligado' }
	e.background_ready = false
}

// draw_guides desenha as guias da marcação em arrasto, finas e tracejadas, com os vãos do tracejado deixando a imagem aparecer. Elas não passam da imagem: a guia até a parte escondida de uma marcação cortada pelo recorte, ou a de uma marcação movida para além da borda, sairia sobre o fundo em volta dela.
fn draw_guides(hdc voidptr, e &Editor, area Rect) {
	found := guides(area, e.guide_targets())
	if found.len == 0 {
		return
	}
	saved := e.clip_to_image(hdc)
	pen := C.CreatePen(ps_dash, 1, guide_color)
	old_pen := C.SelectObject(hdc, pen)
	old_mode := C.SetBkMode(hdc, transparent_bk)
	for guide in found {
		line := e.to_client(guide_rect(guide))
		C.MoveToEx(hdc, line.x, line.y, unsafe { nil })
		C.LineTo(hdc, line.x + line.width, line.y + line.height)
	}
	C.SetBkMode(hdc, old_mode)
	C.SelectObject(hdc, old_pen)
	C.DeleteObject(pen)
	C.RestoreDC(hdc, saved)
}

// guide_rect é a guia como um retângulo sem largura, ou sem altura, para passar pela mesma conversão para a janela que as caixas.
fn guide_rect(guide Guide) Rect {
	if guide.standing {
		return Rect{
			x:      guide.at
			y:      guide.from
			height: guide.to - guide.from
		}
	}
	return Rect{
		x:     guide.from
		y:     guide.at
		width: guide.to - guide.from
	}
}
