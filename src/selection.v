module main

fn C.SetCursor(cursor voidptr) voidptr

// Grab é o que um arrasto está segurando: o corpo da marcação, uma das oito alças, ou
// nada. A ordem das alças é a horária a partir do canto superior esquerdo.
enum Grab {
	none
	body
	top_left
	top
	top_right
	right
	bottom_right
	bottom
	bottom_left
	left
	// A alça que gira a ponta do balão do numerador. Ela não está na lista das alças da
	// caixa: só o balão com ponta a tem.
	tip
	line_start
	line_end
}

// As alças na ordem em que são desenhadas e testadas.
const handles = [Grab.top_left, .top, .top_right, .right, .bottom_right, .bottom, .bottom_left,
	.left]

// Lado do quadrado da alça, em pixels do cliente.
const handle_size = 8
// Folga em volta da alça, para acertá-la sem precisar de pontaria.
const handle_reach = 3
const handle_fill = u32(0x00ffffff)
const handle_border = u32(0x00202020)
const selection_color = u32(0x00ffffff)

// Ponteiros do sistema, por índice. São compartilhados e não precisam ser liberados.
const idc_arrow = voidptr(32512)
const idc_sizenwse = voidptr(32642)
const idc_sizenesw = voidptr(32643)
const idc_sizewe = voidptr(32644)
const idc_sizens = voidptr(32645)
const idc_sizeall = voidptr(32646)

// handle_rect devolve o quadrado de uma alça sobre um retângulo já em coordenadas do
// cliente.
fn handle_rect(area Rect, grab Grab) Rect {
	x := match grab {
		.top_left, .left, .bottom_left { area.x }
		.top, .bottom { area.x + area.width / 2 }
		else { area.x + area.width }
	}
	y := match grab {
		.top_left, .top, .top_right { area.y }
		.left, .right { area.y + area.height / 2 }
		else { area.y + area.height }
	}
	return Rect{
		x: x - handle_size / 2
		y: y - handle_size / 2
		width: handle_size
		height: handle_size
	}
}

// grow devolve o retângulo afastado por `margin` para todos os lados.
fn grow(area Rect, margin int) Rect {
	return Rect{
		x: area.x - margin
		y: area.y - margin
		width: area.width + 2 * margin
		height: area.height + 2 * margin
	}
}

// grab_at diz o que um clique no ponto pegaria da marcação selecionada: uma alça, o corpo,
// ou nada. As alças vêm antes porque ficam meio para dentro e meio para fora da borda, e o
// corpo é testado pela mesma regra da escolha — na linha, perto do traço e não na caixa.
fn (e Editor) grab_at(x int, y int) Grab {
	grab, _ := e.part_at(x, y)
	return grab
}

// part_at é o grab_at que diz também se o que se pegou foi a lente da lupa. A lupa é a
// única marcação com duas pontas, e cada uma tem o seu corpo e as suas alças.
fn (e Editor) part_at(x int, y int) (Grab, bool) {
	if e.selected < 0 || e.selected >= e.scene.shapes.len {
		return Grab.none, false
	}
	mark := e.scene.shapes[e.selected]
	// A moldura não tem caixa: ela veste a imagem inteira, e a área dela fica zerada. As alças de uma caixa zerada cairiam todas no canto de dentro da moldura, e um arrasto dali só a estragaria.
	if mark.tool == .backdrop {
		return Grab.none, false
	}
	if e.on_tip_handle(mark, x, y) {
		return Grab.tip, false
	}
	area := e.to_client(mark.area)
	if mark.tool in diagonal_tools {
		return line_part_at(mark, area, x, y), false
	}
	// O balão não tem alças de caixa: o tamanho dele vem da espessura, e a caixa é sempre a do disco. Esticá-la por uma alça movia o disco sem mudar o raio, e as alças ficavam cercando o vazio.
	if mark.tool != .counter {
		handle := handle_on(area, x, y)
		if handle != .none {
			return handle, false
		}
	}
	if mark.tool == .magnifier {
		return e.lens_part_at(mark, area, x, y)
	}
	if e.hits(mark, x, y) {
		return Grab.body, false
	}
	return Grab.none, false
}

// lens_part_at resolve a lupa depois das alças da origem: as alças da lente, o corpo da
// lente, ou o corpo da origem.
fn (e Editor) lens_part_at(mark Shape, area Rect, x int, y int) (Grab, bool) {
	lens := e.to_client(lens_of(mark))
	handle := handle_on(lens, x, y)
	if handle != .none {
		return handle, true
	}
	if contains(lens, x, y) {
		return Grab.body, true
	}
	if contains(area, x, y) {
		return Grab.body, false
	}
	return Grab.none, false
}

// on_tip_handle diz se o ponto caiu na alça que gira a ponta do balão. Só o balão com
// ponta a tem, e ela vem antes das outras: fica fora da caixa, mas perto de um canto dela.
fn (e Editor) on_tip_handle(mark Shape, x int, y int) bool {
	if mark.tool != .counter || mark.style.tip == .none {
		return false
	}
	handle := tip_handle(mark)
	spot := e.to_client(Rect{
		x: handle.x
		y: handle.y
	})
	return contains(grow(point_handle(spot.x, spot.y), handle_reach), x, y)
}

// point_handle devolve o quadrado de uma alça centrada no ponto.
fn point_handle(x int, y int) Rect {
	return Rect{
		x: x - handle_size / 2
		y: y - handle_size / 2
		width: handle_size
		height: handle_size
	}
}

// handle_on devolve a alça do retângulo que está sob o ponto, ou none.
fn handle_on(area Rect, x int, y int) Grab {
	for handle in handles {
		if contains(grow(handle_rect(area, handle), handle_reach), x, y) {
			return handle
		}
	}
	return .none
}

// shape_at devolve o índice da marcação mais acima sob o ponto, ou -1 se não houver
// nenhuma. A busca vai do fim para o começo porque a última da lista é a que ficou por
// cima das outras.
fn (e Editor) shape_at(x int, y int) int {
	for index := e.scene.shapes.len - 1; index >= 0; index-- {
		if e.hits(e.scene.shapes[index], x, y) {
			return index
		}
	}
	return -1
}

// Quanto se pode errar o traço e ainda acertá-lo, em pixels da janela.
const line_reach = 6

// As ferramentas que atravessam a caixa em vez de ocupá-la.
const diagonal_tools = [Tool.line, .arrow, .ruler]

// hits diz se o ponto acerta a marcação. A linha e a seta ocupam uma diagonal da caixa
// delas, e quase toda a caixa é vazia: acertá-las é chegar perto do traço, não cair na
// caixa.
fn (e Editor) hits(mark Shape, x int, y int) bool {
	area := e.to_client(mark.area)
	// A moldura ocupa a imagem inteira e não se pega por clique: quem a escolhe é o botão
	// dela na barra, e ela não tem o que redimensionar com alças.
	if mark.tool == .backdrop {
		return false
	}
	if mark.tool == .magnifier {
		return magnifier_hits(area, e.to_client(lens_of(mark)), x, y)
	}
	if mark.tool == .counter {
		return near_counter(mark, area, e.view_scale(), x, y)
	}
	if mark.tool in stroke_tools {
		return near_stroke(mark, area, x, y)
	}
	if mark.tool !in diagonal_tools {
		return contains(area, x, y)
	}
	from_x, from_y, to_x, to_y := line_ends(area, mark.origin)
	return near_segment(from_x, from_y, to_x, to_y, x, y, line_reach)
}

// near_counter diz se o ponto caiu dentro do disco do balão. A ponta não conta: quem clica
// mira no número.
fn near_counter(mark Shape, area Rect, scale f64, x int, y int) bool {
	center := remap(mark.points[0], mark.area, area)
	radius := int(counter_radius(f32(mark.thickness)) * f32(scale))
	return (x - center.x) * (x - center.x) + (y - center.y) * (y - center.y) <= radius * radius
}

// near_stroke diz se o ponto chega perto de algum trecho do traço livre. A caixa dele é
// quase toda vazia, como a da linha.
fn near_stroke(mark Shape, area Rect, x int, y int) bool {
	if mark.points.len == 1 {
		first := remap(mark.points[0], mark.area, area)
		return near_segment(first.x, first.y, first.x, first.y, x, y, line_reach)
	}
	for index in 1 .. mark.points.len {
		from := remap(mark.points[index - 1], mark.area, area)
		to := remap(mark.points[index], mark.area, area)
		if near_segment(from.x, from.y, to.x, to.y, x, y, line_reach) {
			return true
		}
	}
	return false
}

// near_segment diz se o ponto está a menos de `reach` do segmento. A conta é a da projeção do ponto sobre o segmento, presa às pontas, sem raiz. Fica em f64 porque o zoom produz traço longo: em inteiros de 32 bits, uma linha de uns 1500 px na janela já estourava a conta, e o clique no fim dela não pegava a marcação.
fn near_segment(x1 int, y1 int, x2 int, y2 int, x int, y int, reach int) bool {
	dx := f64(x2 - x1)
	dy := f64(y2 - y1)
	length := dx * dx + dy * dy
	mut t := 0.0
	if length > 0 {
		t = (f64(x - x1) * dx + f64(y - y1) * dy) / length
	}
	t = if t < 0 { 0.0 } else if t > 1 { 1.0 } else { t }
	ex := f64(x - x1) - dx * t
	ey := f64(y - y1) - dy * t
	return ex * ex + ey * ey <= f64(reach * reach)
}

// crossed diz em quais eixos o arrasto de uma alça passou do lado oposto da caixa. É nesse eixo que a linha, a seta e a régua trocam o canto de partida, para a ponta pega continuar sob o ponteiro. Parar exatamente no lado oposto não é passar dele.
fn crossed(area Rect, grab Grab, dx int, dy int) (bool, bool) {
	across := (grab in [Grab.top_left, .left, .bottom_left] && dx > area.width)
		|| (grab in [Grab.top_right, .right, .bottom_right] && -dx > area.width)
	down := (grab in [Grab.top_left, .top, .top_right] && dy > area.height)
		|| (grab in [Grab.bottom_left, .bottom, .bottom_right] && -dy > area.height)
	return across, down
}

// resized aplica o deslocamento do arrasto à geometria, conforme a alça que foi pega.
fn resized(area Rect, grab Grab, dx int, dy int) Rect {
	if grab == .body {
		return Rect{
			x: area.x + dx
			y: area.y + dy
			width: area.width
			height: area.height
		}
	}
	mut left := area.x
	mut top := area.y
	mut right := area.x + area.width
	mut bottom := area.y + area.height
	if grab in [Grab.top_left, .left, .bottom_left] {
		left += dx
	}
	if grab in [Grab.top_right, .right, .bottom_right] {
		right += dx
	}
	if grab in [Grab.top_left, .top, .top_right] {
		top += dy
	}
	if grab in [Grab.bottom_left, .bottom, .bottom_right] {
		bottom += dy
	}
	// Normalizado, para o arrasto poder atravessar o lado oposto sem virar a marcação do
	// avesso e sair com largura negativa.
	return Rect{
		x: min(left, right)
		y: min(top, bottom)
		width: max(left, right) - min(left, right)
		height: max(top, bottom) - min(top, bottom)
	}
}

// cursor_for devolve o ponteiro que corresponde ao que está sob o cursor, para a alça
// dizer sozinha em que sentido ela estica.
fn cursor_for(grab Grab) voidptr {
	return match grab {
		.body, .tip, .line_start, .line_end { idc_sizeall }
		.top_left, .bottom_right { idc_sizenwse }
		.top_right, .bottom_left { idc_sizenesw }
		.top, .bottom { idc_sizens }
		.left, .right { idc_sizewe }
		.none { idc_arrow }
	}
}

// select_at trata o clique com a ferramenta de seleção: pega uma alça ou o corpo do que já
// está selecionado, ou escolhe outra marcação, ou desmarca.
fn (mut e Editor) select_at(x int, y int) {
	grab, lens := e.part_at(x, y)
	if grab != .none {
		e.start_grab(grab, lens)
		return
	}
	e.selected = e.shape_at(x, y)
	e.status = if e.selected < 0 { e.hint() } else { 'Marcação selecionada' }
}

// start_grab tira da cena a marcação que vai ser arrastada e passa a mostrá-la como
// prévia: assim cada movimento do mouse redesenha só a moldura, em vez de refazer a
// imagem inteira. `lens` diz se o que se pegou foi a lente da lupa, e não a origem.
fn (mut e Editor) start_grab(grab Grab, lens bool) {
	// Sem record(), que apagaria o refazer: um clique que não move nada não é edição. O refazer só sai em finish_grab, quando o arrasto muda de fato alguma coisa.
	e.past << e.scene.clone()
	e.grabbed = e.scene.shapes[e.selected]
	e.scene.shapes.delete(e.selected)
	// A pegada vale antes de a imagem ser refeita: é por ela que a montagem sabe que falta um balão ali.
	e.grab = grab
	e.grab_lens = lens
	e.apply() or {
		e.grab = .none
		e.grab_lens = false
		e.rollback()
		return
	}
}

// grabbed_shape devolve a marcação arrastada na geometria nova, em coordenadas da captura:
// a caixa movida ou esticada — ou, quando o que se pegou foi a lente da lupa, só a lente,
// com a origem parada.
fn (e Editor) grabbed_shape() Shape {
	// Dentro da folga do clique a soltura devolve a marcação como estava, e a prévia mostra o mesmo: um clique parado perto de um alinhamento a mostrava encaixada, e ela voltava ao soltar.
	if e.was_click() {
		return e.grabbed
	}
	dx := int(f64(e.cursor_x - e.origin_x) / e.view_scale())
	dy := int(f64(e.cursor_y - e.origin_y) / e.view_scale())
	// A alça da ponta anda com o mouse, e a ponta passa a apontar para onde ela está.
	if e.grab == .tip {
		handle := tip_handle(e.grabbed)
		return e.grabbed.aimed_at(Point{handle.x + dx, handle.y + dy})
	}
	if e.grab_lens {
		return e.grabbed.with_lens(resized(lens_of(e.grabbed), e.grab, dx, dy))
	}
	if e.grab in [Grab.line_start, .line_end] {
		end_x, end_y := e.snapped_endpoint(dx, dy)
		return e.grabbed.moved_endpoint(e.grab, end_x, end_y)
	}
	stretch_x, stretch_y := e.snapped_stretch(dx, dy)
	mut area := resized(e.grabbed.area, e.grab, stretch_x, stretch_y)
	// Movendo, a caixa inteira encaixa no alinhamento com outra marcação que estiver ao alcance, e as guias o mostram; esticando, só o lado pego, que já encaixou acima. No texto a alça decide só a largura, que é onde as linhas quebram, e a altura vem das linhas, como na troca de espessura: estreitada, a caixa deixava as linhas a mais saírem por baixo do balão.
	if e.grab == .body {
		area = snapped(area, e.guide_targets(), e.snap_reach())
	} else if e.grabbed.tool == .text {
		area = text_fit(e.current.dc, area, e.grabbed.text, e.grabbed.thickness)
	}
	across, down := crossed(e.grabbed.area, e.grab, stretch_x, stretch_y)
	return e.grabbed.fitted(area).flipped(across, down)
}

// finish_grab devolve a marcação à cena na geometria nova, no mesmo lugar da pilha em que
// estava, para arrastá-la não mudar o que fica por cima do quê.
fn (mut e Editor) finish_grab() string {
	grab := e.grab
	// Apertar e soltar sem sair do lugar não é edição: a marcação volta como estava, e a
	// entrada que o histórico guardou ao pegá-la sai.
	still := e.was_click()
	moved_shape := e.grabbed_shape()
	e.grab = .none
	e.grab_lens = false
	e.scene.shapes.insert(e.selected, if still { e.grabbed } else { moved_shape })
	e.apply() or {
		// A imagem na tela é a da cena sem a marcação, montada ao pegá-la, e a cena de antes do arrasto ficou no histórico: a marcação sai da cena, que volta a ser a da imagem, e desfazer a traz de volta. O rollback a devolvia à cena sem devolvê-la à imagem, e salvar a perdia sem aviso.
		e.scene.shapes.delete(e.selected)
		e.selected = -1
		return 'Falha ao mover: ${err}'
	}
	if still {
		e.past.delete_last()
		return 'Marcação selecionada'
	}
	e.future.clear()
	return match grab {
		.body { 'Marcação movida' }
		.tip { 'Ponta do balão virada' }
		else { 'Marcação redimensionada' }
	}
}

// delete_selected tira da cena a marcação selecionada.
fn (mut e Editor) delete_selected() string {
	e.record()
	e.scene.shapes.delete(e.selected)
	e.selected = -1
	e.apply() or {
		e.rollback()
		return 'Falha ao apagar: ${err}'
	}
	return 'Marcação apagada'
}

// draw_selection desenha a moldura e as oito alças em volta da marcação selecionada.
// Brancas com borda escura, para aparecerem sobre qualquer conteúdo da captura.
fn draw_selection(hdc voidptr, area Rect) {
	draw_frame(hdc, area, selection_color, 1, 2)
	draw_handle_boxes(hdc, handles.map(handle_rect(area, it)))
}

// draw_handle_boxes desenha as alças como discos brancos de borda escura, suavizados: aparecem sobre qualquer conteúdo da captura, e sem as quinas vivas dos quadrados.
fn draw_handle_boxes(hdc voidptr, boxes []Rect) {
	for box in boxes {
		x := box.x + box.width / 2
		y := box.y + box.height / 2
		radius := f32(box.width) / 2
		fill_circle(hdc, x, y, radius + 1, handle_border)
		fill_circle(hdc, x, y, radius, handle_fill)
	}
}

// draw_grabbed mostra a marcação em arrasto na posição nova, já com as alças, para o
// resultado ser visível antes de soltar o botão.
fn draw_grabbed(hdc voidptr, e &Editor) {
	// A marcação vai já na geometria nova, e não na de antes: é o que faz o rótulo da régua
	// acompanhar o arrasto em vez de mostrar a medida antiga até a soltura.
	moved := e.grabbed_shape()
	shown := if moved.tool == .magnifier { e.magnifier_in_window(moved) } else { moved }
	// O balão arrastado leva o número do lugar dele na lista, e não o do próximo balão.
	e.draw_mark_on_image(hdc, shown, e.to_client(moved.area), preview_thickness(e.grabbed.thickness,
		e.view_scale()), number_at(e.scene.shapes, e.selected))
	// A lente da lupa, que anda sozinha, não encaixa em nada, e girar a ponta do balão não mexe na caixa.
	if !e.grab_lens && e.grab != .tip {
		draw_guides(hdc, e, moved.area)
	}
	draw_selected(hdc, e, moved)
}

// magnifier_in_window devolve a lupa já em coordenadas da janela, com a lente pela mesma conta que desenha as alças dela. Remapeada pela razão entre a origem na captura e a origem na janela, cuja largura é truncada, a lente se afastava das alças durante o arrasto de uma origem pequena, e pulava ao soltar.
fn (e Editor) magnifier_in_window(mark Shape) Shape {
	return Shape{
		...mark
		area: e.to_client(mark.area)
		points: lens_points(e.to_client(lens_of(mark)))
	}
}

// draw_selected desenha a moldura e as alças da marcação escolhida — nas duas pontas, na lupa, que é a única com duas. O balão ganha só a moldura, porque não tem alças de caixa, e, quando tem ponta, a alça que a gira.
fn draw_selected(hdc voidptr, e &Editor, mark Shape) {
	if mark.tool in diagonal_tools {
		draw_handle_boxes(hdc, line_handles(mark, e.to_client(mark.area)))
		return
	}
	if mark.tool == .counter {
		draw_frame(hdc, e.to_client(mark.area), selection_color, 1, 2)
	} else {
		draw_selection(hdc, e.to_client(mark.area))
	}
	if mark.tool == .magnifier {
		draw_selection(hdc, e.to_client(lens_of(mark)))
	}
	if mark.tool == .counter && mark.style.tip != .none {
		handle := tip_handle(mark)
		spot := e.to_client(Rect{
			x: handle.x
			y: handle.y
		})
		draw_handle_boxes(hdc, [point_handle(spot.x, spot.y)])
	}
}
