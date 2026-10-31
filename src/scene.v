module main

// Shape é uma marcação desenhada sobre a captura. A geometria fica em coordenadas da
// captura original, e nunca da imagem recortada: assim um recorte não precisa mexer em
// nenhuma marcação já existente, e desfazê-lo devolve todas elas ao lugar certo.
struct Shape {
	tool      Tool
	area      Rect
	color     u32
	thickness int
	style     Style
	// De que canto o traço parte. Linhas, setas e réguas recuperam as duas extremidades pela caixa e por este canto; ao mover uma ponta, ambos são recalculados para preservar a direção.
	origin Corner
	// O caminho do traço livre, em coordenadas da captura. As outras ferramentas cabem na
	// caixa e deixam isto vazio.
	points []Point
	// O que está escrito. Só a ferramenta de texto usa.
	text string
}

// fitted devolve a marcação encaixada numa caixa nova, levando o traço livre junto. É o
// que faz mover e redimensionar valerem para ele como valem para as outras. A lente da
// lupa fica onde está: ela é independente da origem, e tem alças próprias.
fn (s Shape) fitted(area Rect) Shape {
	if s.points.len == 0 || s.tool == .magnifier {
		return Shape{
			...s
			area: area
		}
	}
	return Shape{
		...s
		area: area
		points: s.points.map(remap(it, s.area, area))
	}
}

// flipped espelha a marcação nos eixos em que o arrasto de uma alça passou do lado oposto. O canto de partida troca de lado, para a linha, a seta e a régua levarem a ponta pega junto em vez de inverter o traço, e o traço livre espelha o caminho dentro da caixa. A lupa e o balão guardam nos pontos a lente e a direção da ponta, que não se espelham.
fn (s Shape) flipped(across bool, down bool) Shape {
	if !across && !down {
		return s
	}
	origin := mirrored(s.origin, across, down)
	if s.tool !in stroke_tools {
		return Shape{
			...s
			origin: origin
		}
	}
	return Shape{
		...s
		origin: origin
		points: s.points.map(Point{
			x: if across { 2 * s.area.x + s.area.width - it.x } else { it.x }
			y: if down { 2 * s.area.y + s.area.height - it.y } else { it.y }
		})
	}
}

// mirrored devolve o canto espelhado nos eixos pedidos.
fn mirrored(corner Corner, across bool, down bool) Corner {
	left := (corner in [Corner.top_left, .bottom_left]) != across
	top := (corner in [Corner.top_left, .top_right]) != down
	if top {
		return if left { Corner.top_left } else { Corner.top_right }
	}
	return if left { Corner.bottom_left } else { Corner.bottom_right }
}

// remap leva um ponto de uma caixa para outra, proporcionalmente. Uma caixa sem lado — o
// traço reto, ou o ponto solto — não tem proporção, e aí o ponto só acompanha a origem.
fn remap(p Point, from Rect, to Rect) Point {
	return Point{
		x: if from.width > 0 {
			to.x + (p.x - from.x) * to.width / from.width
		} else {
			to.x
		}
		y: if from.height > 0 {
			to.y + (p.y - from.y) * to.height / from.height
		} else {
			to.y
		}
	}
}

// overlap devolve a parte comum de dois retângulos, sem largura ou altura quando eles não se tocam.
fn overlap(a Rect, b Rect) Rect {
	left := max(a.x, b.x)
	top := max(a.y, b.y)
	return Rect{
		x: left
		y: top
		width: max(min(a.x + a.width, b.x + b.width) - left, 0)
		height: max(min(a.y + a.height, b.y + b.height) - top, 0)
	}
}

// bounds devolve a caixa que envolve todos os pontos.
fn bounds(points []Point) Rect {
	if points.len == 0 {
		return Rect{}
	}
	mut left := points[0].x
	mut top := points[0].y
	mut right := left
	mut bottom := top
	for p in points {
		left = min(left, p.x)
		top = min(top, p.y)
		right = max(right, p.x)
		bottom = max(bottom, p.y)
	}
	return Rect{
		x: left
		y: top
		width: right - left
		height: bottom - top
	}
}

// Point é um ponto solto, que é o que o traço livre acumula.
struct Point {
	x int
	y int
}

// Corner é um dos quatro cantos da caixa de uma marcação.
enum Corner {
	top_left
	top_right
	bottom_right
	bottom_left
}

// Scene é tudo que se pode editar: que pedaço da captura está visível e o que foi
// desenhado sobre ela. Um recorte muda a janela, não a imagem, então nada é perdido e
// desfazê-lo devolve tudo ao lugar.
//
// A cena é pequena — um retângulo e algumas dezenas de bytes por marcação — e é por isso
// que o histórico guarda cópias inteiras dela. Guardar cópias da imagem custaria 8 MB por
// passo numa tela 1920x1080, e é o que impedia refazer até agora.
struct Scene {
mut:
	crop   Rect
	shapes []Shape
	// O fator de tamanho do resultado em relação à captura, aplicado depois de tudo.
	factor f64 = 1.0
}

// clone devolve uma cópia independente, para o histórico não dividir o vetor de
// marcações com a cena viva.
fn (s Scene) clone() Scene {
	// Por espalhamento, e não campo a campo: um campo novo da cena que ficasse de fora
	// aqui voltaria ao padrão a cada desfazer, sem ninguém ter pedido.
	return Scene{
		...s
		shapes: s.shapes.clone()
	}
}

// record guarda a cena atual antes de mudá-la, e descarta o futuro: quem desfaz e depois
// edita abre um caminho novo, e o que havia à frente deixa de fazer sentido.
// O futuro descartado fica guardado até a mudança pegar: se a imagem não se monta, rollback o devolve, e a edição que não pegou não apaga o refazer.
fn (mut e Editor) record() {
	e.discarded = e.future.clone()
	e.record_before(e.scene.clone())
}

// record_before guarda uma cena tirada antes da mudança, para quem só sabe se a mudança pegou depois de aplicá-la: guardada antes, uma mudança que falhava deixava no histórico uma entrada igual à cena atual e apagava o refazer.
fn (mut e Editor) record_before(before Scene) {
	e.past << before
	e.future.clear()
}

// rollback desfaz a mudança que não pôde ser aplicada, voltando à cena guardada. Sem
// nenhuma guardada a cena atual continua valendo: melhor uma edição que não pegou do que
// um editor que morre no meio de uma.
fn (mut e Editor) rollback() {
	if e.past.len > 0 {
		e.scene = e.past.pop()
	}
	if future := e.discarded {
		e.future = future
		e.discarded = none
	}
}

// undo volta uma edição. Um texto em digitação é fechado antes, como um clique fora da caixa faria: ele ainda não está na cena, e desfazer por baixo dele o duplicava — numa reescrita, a versão antiga voltava e a nova entrava ao lado — ou, ao desistir dele depois, apagava uma edição anterior.
fn (mut e Editor) undo() string {
	if e.typing {
		e.finish_text()
	}
	if e.past.len == 0 {
		return 'Não há nada para desfazer'
	}
	e.future << e.scene.clone()
	e.scene = e.past.pop()
	// Sem a imagem nova, a cena volta para a pilha de onde saiu e a atual continua valendo: senão o fator e a moldura seriam de uma imagem que não é a da tela, e as alças e os traços novos sairiam deslocados.
	e.apply() or {
		e.past << e.scene
		e.scene = e.future.pop()
		return 'Falha ao desfazer: ${err}'
	}
	return 'Desfeito'
}

// redo refaz a edição desfeita mais recentemente. Um texto em digitação é fechado antes, pelo mesmo motivo do desfazer.
fn (mut e Editor) redo() string {
	if e.typing {
		e.finish_text()
	}
	if e.future.len == 0 {
		return 'Não há nada para refazer'
	}
	e.past << e.scene.clone()
	e.scene = e.future.pop()
	// Pelo mesmo motivo do desfazer, a cena que não pôde ser montada volta para a pilha dela.
	e.apply() or {
		e.future << e.scene
		e.scene = e.past.pop()
		return 'Falha ao refazer: ${err}'
	}
	return 'Refeito'
}

// apply monta a imagem de trabalho: o pedaço visível da captura com as marcações por
// cima. É chamada sempre que a cena muda.
fn (mut e Editor) apply() ! {
	rebuilt := render_scene_without(e.source, e.scene, e.missing_counter())!
	// A imagem anterior só é descartada depois que a nova existe, para uma falha no meio
	// do caminho não deixar o editor sem nada para mostrar.
	if e.current.dc != unsafe { nil } {
		e.current.release()
	}
	e.current = rebuilt
	// A mudança pegou, e o futuro que o record apagou não volta mais.
	e.discarded = none
	e.layout()
}

// render_scene monta a imagem que a cena descreve: o pedaço visível da captura com as
// marcações por cima.
fn render_scene(source Frozen, scene Scene) !Frozen {
	return render_scene_without(source, scene, -1)
}

// render_scene_without monta a cena sabendo que falta um balão na posição `gap` da lista — o que está sendo arrastado, fora da cena e desenhado à parte como prévia —, para os que vêm depois dele manterem o número. Sem balão faltando, `gap` é -1.
fn render_scene_without(source Frozen, scene Scene, gap int) !Frozen {
	inner := source.cut(scene.crop)!
	mut number := 0
	for index, shape in scene.shapes {
		if index == gap {
			number++
		}
		if shape.tool == .counter {
			number++
		}
		draw_shape(inner, shape, scene.crop, number)
	}
	// A moldura vem depois das marcações, e não na vez dela na lista: ela não é uma
	// marcação sobre a imagem, é a imagem inteira dentro de outra. O tamanho vem por
	// último, sobre a imagem pronta, e leva junto a moldura e tudo que está desenhado.
	frame := backdrop_of(scene) or { return scaled_to(inner, scene.factor) }
	framed := wrap_backdrop(inner, frame) or {
		inner.release()
		return err
	}
	inner.release()
	return scaled_to(framed, scene.factor)
}

// draw_shape desenha uma marcação na imagem de trabalho, descontando a origem do recorte
// para sair das coordenadas da captura e entrar nas da imagem visível.
fn draw_shape(target Frozen, shape Shape, crop Rect, number int) {
	area := Rect{
		x: shape.area.x - crop.x
		y: shape.area.y - crop.y
		width: shape.area.width
		height: shape.area.height
	}
	if shape.tool in drawing_tools {
		draw_mark(target.dc, shape, area, f32(shape.thickness), number)
	}
}

// Menor arrasto, em pixels da janela, que a ferramenta de seleção aceita como recorte.
const crop_min_drag = 8
// Um arrasto que não passou desta distância, em pixels da janela, foi um clique.
const click_slop = 3
// As ferramentas que criam com um clique, e por isso não o cedem à seleção.
const click_tools = [Tool.counter, .text]

// was_click diz se o arrasto que terminou não saiu do lugar.
fn (e Editor) was_click() bool {
	return abs(e.cursor_x - e.origin_x) < click_slop && abs(e.cursor_y - e.origin_y) < click_slop
}

// crop_to recorta a imagem para a área arrastada com Selecionar. A seleção divide o botão com o recorte, e um clique que tremeu não pode cortar a imagem: só recorta o arrasto que cresceu nos dois sentidos. Com moldura, o arrasto pode ter começado ou terminado na folga dela, que não é captura, e por isso só vale o que cai dentro do recorte atual — o resto viraria faixa preta.
fn (mut e Editor) crop_to(area Rect) string {
	drag := e.area()
	if drag.width < crop_min_drag || drag.height < crop_min_drag {
		return e.hint()
	}
	cut := overlap(area, e.scene.crop)
	if cut.width < 1 || cut.height < 1 {
		return e.hint()
	}
	e.record()
	e.scene.crop = cut
	e.apply() or {
		e.rollback()
		return 'Falha ao recortar: ${err}'
	}
	return 'Recortado para ${e.current.width} x ${e.current.height}'
}

// finish_drag aplica o arrasto à cena e devolve o texto para a barra de ferramentas.
fn (mut e Editor) finish_drag() string {
	if picked := e.pick_on_click() {
		return picked
	}
	area := e.drag_area()
	if e.tool == .select {
		return e.crop_to(area)
	}
	if !usable(area, e.tool) {
		return e.hint()
	}
	if e.tool == .text {
		// O texto não nasce do arrasto: o arrasto só diz onde ele cabe, e o que ele diz
		// vem do teclado.
		e.start_text(area)
		return 'Escreva; Ctrl+Enter termina, Esc desiste'
	}
	if e.tool !in drawing_tools {
		return e.hint()
	}
	return e.add_shape(e.new_shape(area))
}

// pick_on_click escolhe a marcação sob um clique que não saiu do lugar, com qualquer ferramenta na mão — menos o numerador e o texto, para quem o clique é o próprio gesto de criar. Um arrasto que comece sobre ela continua desenhando: é assim que as formas se sobrepõem.
fn (mut e Editor) pick_on_click() ?string {
	if e.tool in click_tools || !e.was_click() {
		return none
	}
	index := e.shape_at(e.origin_x, e.origin_y)
	if index < 0 {
		return none
	}
	e.selected = index
	return 'Marcação selecionada'
}

// drag_area devolve a caixa do arrasto em coordenadas da captura: a do disco no balão, a que envolve o caminho no traço, e a arrastada nas outras ferramentas.
fn (e Editor) drag_area() Rect {
	if e.tool == .counter {
		return e.counter_shape().area
	}
	if e.tool in stroke_tools {
		return bounds(e.stroke_points())
	}
	return e.snapped_drag(e.to_source(e.to_image(e.area())))
}

// new_shape monta a marcação que o arrasto desenhou.
fn (e Editor) new_shape(area Rect) Shape {
	if e.tool == .counter {
		return e.counter_shape()
	}
	return Shape{
		tool: e.tool
		area: area
		color: e.color
		thickness: e.thickness
		style: e.style
		origin: e.drag_corner()
		points: e.drag_points(area)
	}
}

// add_shape põe a marcação na cena e no histórico. Ela nasce selecionada: o painel passa a governar o que acabou de ser desenhado, em vez de só o que vier a seguir.
fn (mut e Editor) add_shape(shape Shape) string {
	e.record()
	e.scene.shapes << shape
	e.selected = e.scene.shapes.len - 1
	e.apply() or {
		e.rollback()
		e.selected = -1
		return 'Falha ao aplicar: ${err}'
	}
	return '${tool_name(e.tool)} desenhado'
}

// usable descarta o arrasto que não deu em nada. Um retângulo ou uma elipse precisam dos
// dois lados, mas a linha e a seta atravessam a caixa: as duas horizontais e as duas
// verticais têm um dos lados zerado, e são justamente as que o Shift produz.
fn usable(area Rect, tool Tool) bool {
	if tool in stroke_tools || tool == .counter || tool == .text {
		// Um traço pode ser um ponto só, o balão numerado é posto por clique, e o texto
		// ganha uma caixa de partida: nos três casos um arrasto que não saiu do lugar
		// continua valendo.
		return true
	}
	if tool in diagonal_tools {
		return area.width >= 1 || area.height >= 1
	}
	return area.width >= 1 && area.height >= 1
}

// counter_shape monta o balão numerado a partir do arrasto: o centro onde ele começou e a
// direção da ponta, que aponta para onde ele terminou. A caixa é a do disco.
fn (e Editor) counter_shape() Shape {
	center := e.snapped_center(e.to_source_point(e.origin_x, e.origin_y))
	aim := e.to_source_point(e.cursor_x, e.cursor_y)
	radius := int(counter_radius(f32(e.thickness)))
	// Um arrasto que não sai do disco não aponta nada: a ponta fica embaixo à direita, como
	// na referência.
	outside := (aim.x - center.x) * (aim.x - center.x) + (aim.y - center.y) * (aim.y - center.y) > radius * radius
	return Shape{
		tool: .counter
		area: counter_box(center, e.thickness)
		color: e.color
		thickness: e.thickness
		// A forma do balão — círculo, ponta fina ou ponta grossa — vem do painel.
		style: e.style
		points: [center, if outside { aim } else { Point{center.x + radius, center.y + radius} }]
	}
}

// next_number é o número que o próximo balão vai receber. Ele sai da contagem na cena, e
// não de um contador guardado: apagar um do meio renumera os seguintes sozinho.
fn (e Editor) next_number() int {
	return number_at(e.scene.shapes, e.scene.shapes.len)
}

// number_at é o número do balão que estiver na posição dada da lista: um a mais do que os balões antes dele.
fn number_at(shapes []Shape, index int) int {
	mut count := 1
	for shape in shapes[..index] {
		if shape.tool == .counter {
			count++
		}
	}
	return count
}

// missing_counter é a posição do balão que está fora da cena durante o arrasto dele, ou -1. Sem saber dela, a montagem contaria um balão a menos, e os que vêm depois perderiam um número enquanto o botão estivesse apertado.
fn (e Editor) missing_counter() int {
	return if e.grab != .none && e.grabbed.tool == .counter { e.selected } else { -1 }
}

// to_source_point leva um ponto da janela para as coordenadas da captura.
fn (e Editor) to_source_point(x int, y int) Point {
	margin := e.margin()
	return Point{
		x: e.scene.crop.x + int(f64(x - e.view.x) / e.view_scale()) - margin
		y: e.scene.crop.y + int(f64(y - e.view.y) / e.view_scale()) - margin
	}
}

// stroke_points devolve o traço recolhido no arrasto, já em coordenadas da captura.
fn (e Editor) stroke_points() []Point {
	return e.stroke.map(e.to_source_point(it.x, it.y))
}

// drag_points devolve os pontos que a marcação nova guarda: o caminho do traço livre, ou,
// na lupa, os cantos da lente, que dali em diante é independente da origem.
fn (e Editor) drag_points(area Rect) []Point {
	if e.tool == .magnifier {
		return lens_points(lens_within(area, e.drag_corner(), e.scene.crop))
	}
	return e.stroke_points()
}

// to_source sai das coordenadas da imagem visível e entra nas da captura original, que é
// onde a cena guarda tudo.
fn (e Editor) to_source(area Rect) Rect {
	margin := e.margin()
	factor := e.scene.factor
	return Rect{
		x: e.scene.crop.x + round(f64(area.x) / factor) - margin
		y: e.scene.crop.y + round(f64(area.y) / factor) - margin
		width: round(f64(area.width) / factor)
		height: round(f64(area.height) / factor)
	}
}
