module main

// A faixa de espessuras que o controle percorre, em pixels da captura original.
const min_thickness = 1
const max_thickness = 12

const options_height = 44
const options_padding = 12
// O disco de cor, que abre o seletor do Windows. Fica à esquerda do controle, como na
// referência.
const swatch_size = 24
const swatch_gap = 12
const slider_width = 190
// Os botões de estilo, que variam com a ferramenta.
const style_button = 30
const style_gap = 4
const style_group_gap = 14
// O retângulo escolhe o canto e o preenchimento — só o contorno, translúcido ou opaco —; a
// elipse não tem canto; a linha não tem nem um nem outro, e escolhe entre traço contínuo e
// pontilhado.
const style_slots_area = [0, 1, 2, 3, 18]
const style_slots_round = [2, 3, 18]
const style_slots_stroke = [4, 5]
const style_slots_head = [6, 7, 8, 9]
// O texto escolhe entre o balão preenchido e a palavra solta, como na referência.
const style_slots_text = [10, 11]
// Borrar escolhe entre reduzir a blocos e cobrir com a média das cores.
const style_slots_blur = [12, 13]
// A lupa escolhe a forma das duas pontas: retangular ou redonda.
const style_slots_lens = [14, 15]
// A moldura escolhe o canto da imagem e se ela projeta sombra.
const style_slots_backdrop = [0, 1, 16, 17]
// O numerador escolhe a forma do balão, como na referência: o círculo, a ponta fina e a
// ponta grossa. A direção da ponta não é estilo: ela tem alça própria no balão.
const style_slots_counter = [19, 20, 21]
// A cunha vai desta altura, à esquerda, até esta outra, à direita: é ela que diz para que
// lado o traço engrossa, sem precisar de rótulo.
const wedge_thin = 2
const wedge_thick = 16
const knob_radius = f32(8.0)
// Folga entre o painel e as bordas do editor.
const options_margin = 8

const options_color = u32(0x00343434)
const options_border_color = u32(0x00565656)
const wedge_color = u32(0x00707070)
const knob_color = u32(0x00f0f0f0)
const knob_border_color = u32(0x00202020)
const style_icon_color = u32(0x00d8d8d8)
const style_icon_active_color = u32(0x00ffffff)

// style_slots devolve os botões de estilo que a ferramenta oferece.
fn style_slots(tool Tool) []int {
	return match tool {
		.oval { style_slots_round }
		.line { style_slots_stroke }
		.arrow { style_slots_head }
		.text { style_slots_text }
		.blur { style_slots_blur }
		.magnifier { style_slots_lens }
		.backdrop { style_slots_backdrop }
		.counter { style_slots_counter }
		.freehand, .highlighter, .ruler { [] }
		else { style_slots_area }
	}
}

// style_group_width é o quanto a fila de botões de estilo ocupa.
fn style_group_width(tool Tool) int {
	count := style_slots(tool).len
	if count == 0 {
		return 0
	}
	return count * style_button + (count - 1) * style_gap
}

// has_swatch diz se a ferramenta tem cor para escolher. Borrar não tem: os dois modos dela
// tiram a cor da própria imagem, e a referência mostra o painel dela sem o disco.
fn has_swatch(tool Tool) bool {
	return tool != .blur
}

// swatch_span é o quanto o disco de cor ocupa à esquerda do controle, com o vão dele.
fn swatch_span(tool Tool) int {
	return if has_swatch(tool) { swatch_size + swatch_gap } else { 0 }
}

// options_width é o quanto o painel ocupa, que muda com o número de botões da ferramenta.
fn options_width(tool Tool) int {
	group := style_group_width(tool)
	gap := if group == 0 { 0 } else { style_group_gap }
	return 2 * options_padding + swatch_span(tool) + slider_width + gap + group
}

// swatch_rect devolve o disco de cor, o primeiro item do painel.
fn swatch_rect(panel Rect) Rect {
	return Rect{
		x: panel.x + options_padding
		y: panel.y + (options_height - swatch_size) / 2
		width: swatch_size
		height: swatch_size
	}
}

// style_button_rect devolve o quadrado do botão que ocupa a posição `slot` na fila. A fila
// é encostada na direita do painel, e não medida a partir do controle: assim o número de
// botões muda sem mexer no resto do painel.
fn style_button_rect(panel Rect, tool Tool, slot int) Rect {
	first := panel.x + panel.width - options_padding - style_group_width(tool)
	return Rect{
		x: first + slot * (style_button + style_gap)
		y: panel.y + (options_height - style_button) / 2
		width: style_button
		height: style_button
	}
}

// style_at devolve o botão de estilo sob o ponto, ou none.
fn (e Editor) style_at(x int, y int) ?int {
	panel := e.options_panel()?
	tool := e.options_tool()
	for slot, index in style_slots(tool) {
		if contains(style_button_rect(panel, tool, slot), x, y) {
			return index
		}
	}
	return none
}

// StyleField nomeia os campos do estilo que um botão escreve ou lê.
@[flag]
enum StyleField {
	tip
	rounded
	filled
	opaque
	dashed
	head
	erase
	shadow
}

// StyleButton é um botão de estilo: o nome que a barra mostra, o estilo que ele põe — que é também a miniatura dele —, os campos que ele escreve ao ser apertado e os que decidem se ele está aceso. Os dois conjuntos só diferem no "Só o contorno", que apaga o opaco junto com o preenchimento mas acende por não haver preenchimento.
struct StyleButton {
	name   string
	sets   Style
	writes StyleField
	reads  StyleField
}

// Os botões de estilo, na ordem dos números que style_slots_* e os testes usam. Cada grupo é exclusivo — os dois do canto, os três do preenchimento, as quatro pontas — porque os botões de um grupo escrevem o mesmo campo.
const style_buttons = [
	// 0
	StyleButton{
		name:   'Cantos arredondados'
		sets:   Style{
			rounded: true
		}
		writes: .rounded
		reads:  .rounded
	},
	// 1
	StyleButton{
		name:   'Cantos retos'
		writes: .rounded
		reads:  .rounded
	},
	// 2
	StyleButton{
		name:   'Só o contorno'
		writes: StyleField.filled | StyleField.opaque
		reads:  .filled
	},
	// 3
	StyleButton{
		name:   'Preenchimento translúcido'
		sets:   Style{
			filled: true
		}
		writes: StyleField.filled | StyleField.opaque
		reads:  StyleField.filled | StyleField.opaque
	},
	// 4
	StyleButton{
		name:   'Traço contínuo'
		writes: .dashed
		reads:  .dashed
	},
	// 5
	StyleButton{
		name:   'Traço pontilhado'
		sets:   Style{
			dashed: true
		}
		writes: .dashed
		reads:  .dashed
	},
	// 6
	StyleButton{
		name:   'Ponta cheia'
		sets:   Style{
			head: .block
		}
		writes: .head
		reads:  .head
	},
	// 7
	StyleButton{
		name:   'Ponta afunilada'
		sets:   Style{
			head: .tapered
		}
		writes: .head
		reads:  .head
	},
	// 8
	StyleButton{
		name:   'Ponta simples'
		sets:   Style{
			head: .simple
		}
		writes: .head
		reads:  .head
	},
	// 9
	StyleButton{
		name:   'Ponta dupla'
		sets:   Style{
			head: .double
		}
		writes: .head
		reads:  .head
	},
	// 10
	StyleButton{
		name:   'Texto em balão'
		sets:   Style{
			filled: true
		}
		writes: .filled
		reads:  .filled
	},
	// 11
	StyleButton{
		name:   'Texto solto'
		writes: .filled
		reads:  .filled
	},
	// 12
	StyleButton{
		name:   'Borrar em blocos'
		writes: .erase
		reads:  .erase
	},
	// 13
	StyleButton{
		name:   'Apagar com a média'
		sets:   Style{
			erase: true
		}
		writes: .erase
		reads:  .erase
	},
	// 14
	StyleButton{
		name:   'Lupa retangular'
		writes: .rounded
		reads:  .rounded
	},
	// 15
	StyleButton{
		name:   'Lupa redonda'
		sets:   Style{
			rounded: true
		}
		writes: .rounded
		reads:  .rounded
	},
	// 16
	StyleButton{
		name:   'Com sombra'
		sets:   Style{
			shadow: true
		}
		writes: .shadow
		reads:  .shadow
	},
	// 17
	StyleButton{
		name:   'Sem sombra'
		writes: .shadow
		reads:  .shadow
	},
	// 18
	StyleButton{
		name:   'Preenchimento opaco'
		sets:   Style{
			filled: true
			opaque: true
		}
		writes: StyleField.filled | StyleField.opaque
		reads:  StyleField.filled | StyleField.opaque
	},
	// 19
	StyleButton{
		name:   'Balão redondo'
		writes: .tip
		reads:  .tip
	},
	// 20
	StyleButton{
		name:   'Balão de ponta fina'
		sets:   Style{
			tip: .thin
		}
		writes: .tip
		reads:  .tip
	},
	// 21
	StyleButton{
		name:   'Balão de ponta grossa'
		sets:   Style{
			tip: .thick
		}
		writes: .tip
		reads:  .tip
	},
]

// overlay devolve `base` com os campos pedidos trocados pelos de `from`.
fn overlay(base Style, from Style, fields StyleField) Style {
	mut s := base
	if fields.has(.tip) {
		s = Style{
			...s
			tip: from.tip
		}
	}
	if fields.has(.rounded) {
		s = Style{
			...s
			rounded: from.rounded
		}
	}
	if fields.has(.filled) {
		s = Style{
			...s
			filled: from.filled
		}
	}
	if fields.has(.opaque) {
		s = Style{
			...s
			opaque: from.opaque
		}
	}
	if fields.has(.dashed) {
		s = Style{
			...s
			dashed: from.dashed
		}
	}
	if fields.has(.head) {
		s = Style{
			...s
			head: from.head
		}
	}
	if fields.has(.erase) {
		s = Style{
			...s
			erase: from.erase
		}
	}
	if fields.has(.shadow) {
		s = Style{
			...s
			shadow: from.shadow
		}
	}
	return s
}

// style_pressed devolve o estilo que resulta de apertar o botão de índice `index`: o estilo em vigor com os campos do botão trocados pelos dele.
fn style_pressed(current Style, index int) Style {
	button := style_buttons[index]
	return overlay(current, button.sets, button.writes)
}

// style_is_active diz se o botão de índice `index` representa o estilo em vigor: nos campos que ele lê, o estilo em vigor é o dele.
fn style_is_active(current Style, index int) bool {
	button := style_buttons[index]
	return overlay(Style{}, current, button.reads) == overlay(Style{}, button.sets, button.reads)
}

// options_panel devolve onde o painel está, ou none quando não há o que oferecer.
//
// Ele fica parado no canto superior direito, logo abaixo da barra, como na referência.
// Acompanhar a marcação selecionada parecia mais direto, mas o painel então pulava de
// lugar a cada clique e cobria justamente o que estava sendo editado.
fn (e Editor) options_panel() ?Rect {
	// Com o painel do tamanho ou o do zoom aberto, o de opções cede o canto: os dois pendem da direita da barra e ocupariam o mesmo lugar. A ajuda da régua pende do botão dela, à esquerda, e não disputa o canto: escondê-lo tirava a cor e a espessura da régua enquanto ela estava aberta, e a paleta sumia e voltava sozinha.
	if e.dragging || e.popover in [Popover.resize, .zoom] || !e.has_options() {
		return none
	}
	width := options_width(e.options_tool())
	return Rect{
		x: e.canvas_width - width - options_margin
		y: toolbar_height + options_margin
		width: width
		height: options_height
	}
}

// has_options diz se há o que oferecer: uma marcação selecionada, um texto em digitação — inclusive numa reescrita com Selecionar na mão, senão Ctrl+roda aproximaria a imagem em vez de mudar o corpo da letra —, ou uma ferramenta que desenha, para dar para escolher a espessura antes de traçar e não só depois. A moldura só tem painel selecionada: com a ferramenta na mão e ela não escolhida — depois de um Esc, de um desfazer ou de um Delete —, o painel mostrava e mudava valores que moldura nenhuma usa. Apertar K de novo a escolhe.
fn (e Editor) has_options() bool {
	if e.typing {
		return true
	}
	if e.selected >= 0 && e.selected < e.scene.shapes.len {
		return true
	}
	return e.tool in drawing_tools
}

// options_tool é a ferramenta que o painel está governando: a da marcação selecionada, ou
// a que está na mão. É ela que decide quais botões de estilo aparecem.
// Um texto em digitação é governado como texto, qualquer que seja a ferramenta na mão.
fn (e Editor) options_tool() Tool {
	if e.typing {
		return .text
	}
	if e.selected >= 0 && e.selected < e.scene.shapes.len {
		return e.scene.shapes[e.selected].tool
	}
	return e.tool
}

// sets_default diz se a troca feita no painel vale também para as próximas marcações. Escrevendo, vale sempre: a cor e a espessura em vigor são as do texto em digitação, e a reescrita devolve o padrão ao terminar. Sem nada escolhido, vale. Com uma marcação escolhida, só quando ela é da família da ferramenta na mão — com o retângulo na mão, engrossar um texto escolhido engrossava o próximo retângulo —, e nunca na moldura: o número dela é a folga, e não traço, a cor é só dela, e não há próxima moldura que os herde.
fn (e Editor) sets_default() bool {
	if e.typing || e.selected < 0 || e.selected >= e.scene.shapes.len {
		return true
	}
	mark := e.scene.shapes[e.selected]
	return mark.tool != .backdrop && same_family(mark.tool, e.tool)
}

// slider_track devolve a faixa em que o botão do controle corre.
fn slider_track(panel Rect, tool Tool) Rect {
	return Rect{
		x: panel.x + options_padding + swatch_span(tool)
		y: panel.y
		width: slider_width
		height: panel.height
	}
}

// knob_center devolve onde fica o centro do botão para uma dada espessura. O botão não
// chega às pontas da faixa: ele tem raio, e metade dele sairia fora.
fn knob_center(track Rect, thickness int) int {
	span := f64(track.width) - 2 * knob_radius
	fraction := f64(thickness - min_thickness) / f64(max_thickness - min_thickness)
	return track.x + int(knob_radius + fraction * span)
}

// thickness_at devolve a espessura que corresponde a um ponto da faixa.
fn thickness_at(track Rect, x int) int {
	span := f64(track.width) - 2 * knob_radius
	fraction := (f64(x - track.x) - knob_radius) / span
	steps := f64(max_thickness - min_thickness)
	value := min_thickness + int(fraction * steps + 0.5)
	return clamp(value, min_thickness, max_thickness)
}

// current_thickness, current_style e current_color são o que o painel mostra: o da
// marcação selecionada, ou o que os próximos traços vão usar.
fn (e Editor) current_thickness() int {
	if e.selected >= 0 && e.selected < e.scene.shapes.len {
		return e.scene.shapes[e.selected].thickness
	}
	return e.thickness
}

fn (e Editor) current_style() Style {
	if e.selected >= 0 && e.selected < e.scene.shapes.len {
		return e.scene.shapes[e.selected].style
	}
	return e.style
}

fn (e Editor) current_color() u32 {
	if e.selected >= 0 && e.selected < e.scene.shapes.len {
		return e.scene.shapes[e.selected].color
	}
	return e.color
}

// choose_color abre o seletor do Windows e aplica a cor escolhida. Com uma marcação
// selecionada a troca vale para ela e entra no histórico; sem nenhuma, vale para as
// próximas.
fn (mut e Editor) choose_color(owner voidptr) string {
	color := ask_color(owner, e.current_color()) or { return e.status }
	return e.apply_color(color)
}

// start_slide começa a arrastar o botão do controle. A cena não é guardada aqui: um toque que dá o valor que já estava não é edição, e guardá-la antes apagaria o refazer. Quem guarda é slide_to, no primeiro passo de verdade.
fn (mut e Editor) start_slide() {
	e.sliding = true
	e.slide_recorded = false
}

// slide_to leva a espessura ao valor sob o ponto e redesenha a marcação com ela. Com uma marcação selecionada, a cena é guardada uma vez só, no primeiro passo que pega de verdade: sem isso o arrasto empilharia uma entrada de histórico por movimento do mouse, e desfazer teria de ser apertado cinquenta vezes.
fn (mut e Editor) slide_to(x int) string {
	panel := e.options_panel() or { return e.status }
	thickness := thickness_at(slider_track(panel, e.options_tool()), x)
	first := !e.slide_recorded && e.selected >= 0 && e.selected < e.scene.shapes.len
		&& thickness != e.scene.shapes[e.selected].thickness
	before := if first { e.scene.clone() } else { Scene{} }
	message := e.set_thickness(thickness) or { return 'Falha ao trocar a espessura: ${err}' }
	if first {
		e.record_before(before)
		e.slide_recorded = true
	}
	return message
}

// size_by muda o tamanho da ferramenta em `steps` passos, que é o que Ctrl ou Shift com a
// roda do mouse fazem. Numa marcação selecionada cada passo entra no histórico: são passos
// deliberados, um por dente da roda, e de uma ponta à outra da faixa não passam de onze.
fn (mut e Editor) size_by(steps int) string {
	// No meio de um desenho a roda muda só a marcação que vai nascer: a selecionada é outra, e mexer nela gravava o histórico e refazia a imagem debaixo do traço.
	if e.dragging {
		e.thickness = clamp(e.thickness + steps, min_thickness, max_thickness)
		return 'Espessura ${e.thickness}'
	}
	thickness := clamp(e.current_thickness() + steps, min_thickness, max_thickness)
	if thickness == e.current_thickness() {
		return 'Espessura ${thickness}'
	}
	selected := e.selected >= 0 && e.selected < e.scene.shapes.len
	before := if selected { e.scene.clone() } else { Scene{} }
	message := e.set_thickness(thickness) or { return 'Falha ao trocar a espessura: ${err}' }
	if selected {
		e.record_before(before)
	}
	return message
}

// set_thickness leva a espessura ao valor pedido e redesenha a marcação selecionada com
// ela; quem chama decide se isso entra no histórico, e só depois de ela pegar. Com um texto
// em digitação, a caixa é medida de novo, porque ali a espessura é o corpo da letra.
fn (mut e Editor) set_thickness(thickness int) !string {
	previous := e.thickness
	if e.sets_default() {
		e.thickness = thickness
	}
	if e.typing {
		e.typed_area = e.text_box(e.typed + '|')
	}
	if e.selected < 0 || e.selected >= e.scene.shapes.len {
		// Um passo que não mudou nada não é notícia, como com a marcação selecionada: a barra continua dizendo o que dizia.
		return if previous == thickness { e.status } else { 'Espessura ${thickness}' }
	}
	mark := e.scene.shapes[e.selected]
	if mark.thickness == thickness {
		return e.status
	}
	e.scene.shapes[e.selected] = Shape{
		...mark
		thickness: thickness
		area: e.refit(mark, thickness)
	}
	// Sem a imagem nova, a marcação e o padrão voltam ao que a imagem ainda mostra: senão o painel mostrava a espessura nova sobre a imagem velha, e a próxima edição a aplicava de repente.
	e.apply() or {
		e.scene.shapes[e.selected] = mark
		e.thickness = previous
		return err
	}
	return 'Espessura ${thickness}'
}

// refit é a caixa da marcação com a espessura nova. No texto a espessura é o corpo da letra, e no balão é o raio: a caixa acompanha, senão o texto transbordava por baixo do balão, e a moldura da seleção não cercava mais o disco. A largura do texto e a direção da ponta ficam.
fn (e Editor) refit(mark Shape, thickness int) Rect {
	return match mark.tool {
		.text { text_fit(e.current.dc, mark.area, mark.text, thickness) }
		.counter { counter_box(mark.points[0], thickness) }
		else { mark.area }
	}
}

// choose_style aplica o botão de estilo apertado. Com uma marcação selecionada a troca vale para ela e entra no histórico, e vale também para as próximas quando a marcação é da ferramenta na mão; sem nenhuma, vale para as próximas. Só o campo do botão apertado vai para o padrão: o estilo inteiro da marcação levava o canto ou o preenchimento de outra ferramenta — da moldura, da lupa ou do texto — para o próximo retângulo.
fn (mut e Editor) choose_style(index int) string {
	if e.selected < 0 || e.selected >= e.scene.shapes.len {
		e.style = style_pressed(e.style, index)
		return style_name(index)
	}
	shape := e.scene.shapes[e.selected]
	previous := e.style
	// A moldura não tem próximas: ela nasce sempre do mesmo estilo.
	if shape.tool == e.tool && e.tool != .backdrop {
		e.style = style_pressed(e.style, index)
	}
	pressed := style_pressed(shape.style, index)
	// O botão que já estava aceso não é troca: guardá-lo no histórico deixaria um desfazer que não desfaz nada, e apagaria o refazer.
	if pressed == shape.style {
		return style_name(index)
	}
	e.record()
	e.scene.shapes[e.selected] = Shape{
		...shape
		style: pressed
	}
	// Sem a imagem nova, o padrão volta junto com a cena, como na espessura: senão as próximas marcações sairiam com o estilo que a barra acabou de dizer que falhou.
	e.apply() or {
		e.rollback()
		e.style = previous
		return 'Falha ao trocar o estilo: ${err}'
	}
	return style_name(index)
}

// style_name devolve o texto que a barra mostra ao trocar o estilo.
fn style_name(index int) string {
	return style_buttons[index].name
}

// draw_options desenha o painel: o fundo, a cunha das espessuras e o botão sobre ela.
fn draw_options(hdc voidptr, e &Editor, panel Rect) {
	draw_panel(hdc, panel, options_color)

	tool := e.options_tool()
	if has_swatch(tool) {
		fill_rounded(hdc, swatch_rect(panel), e.current_color(), corner_radius)
	}

	track := slider_track(panel, tool)
	middle := track.y + track.height / 2
	left := track.x + int(knob_radius)
	right := track.x + track.width - int(knob_radius)
	fill_polygon(hdc, [
		pointf(left, middle - wedge_thin / 2),
		pointf(right, middle - wedge_thick / 2),
		pointf(right, middle + wedge_thick / 2),
		pointf(left, middle + wedge_thin / 2),
	], wedge_color)

	knob := knob_center(track, e.current_thickness())
	fill_circle(hdc, knob, middle, knob_radius, knob_border_color)
	fill_circle(hdc, knob, middle, knob_radius - 1, knob_color)

	draw_style_buttons(hdc, e, panel)
}

// draw_style_buttons desenha os quatro botões de estilo, cada um mostrando em miniatura o
// que ele faz com a marcação.
fn draw_style_buttons(hdc voidptr, e &Editor, panel Rect) {
	current := e.current_style()
	tool := e.options_tool()
	for slot, index in style_slots(tool) {
		box := style_button_rect(panel, tool, slot)
		active := style_is_active(current, index)
		if active {
			fill_button(hdc, box, toolbar_active_color)
		}
		color := if active { style_icon_active_color } else { style_icon_color }
		sample := Rect{
			x: box.x + 7
			y: box.y + 9
			width: box.width - 14
			height: box.height - 18
		}
		if tool == .text {
			draw_text_sample(hdc, box, style_sample(index).filled, color)
			continue
		}
		if tool == .counter {
			draw_counter_sample(hdc, box, style_sample(index).tip, color)
			continue
		}
		// Os dois botões de sombra mostram um quadro com e sem a mancha atrás dele.
		if index in [16, 17] {
			draw_shadow_sample(hdc, sample, index == 16, color)
			continue
		}
		if tool == .blur {
			draw_blur_sample(hdc, sample, style_sample(index).erase, color)
			continue
		}
		// A miniatura da lupa é a forma dela: quadro de cantos arredondados ou elipse. Não
		// há o que ampliar num quadro de dezesseis pixels.
		if tool == .magnifier {
			lens := style_sample(index).rounded
			draw_mark(hdc, Shape{
				tool: if lens { Tool.oval } else { Tool.rectangle }
				style: Style{
					rounded: true
				}
				color: color
			}, sample, 1.5, 1)
			continue
		}
		draw_mark(hdc, Shape{
			tool: tool
			style: style_sample(index)
			color: color
		}, sample, 1.5, 1)
	}
}

// style_sample é o estilo que a miniatura de cada botão mostra: o que ele põe.
fn style_sample(index int) Style {
	return style_buttons[index].sets
}
