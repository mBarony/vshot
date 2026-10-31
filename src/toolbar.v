module main

fn C.MoveToEx(hdc voidptr, x int, y int, point voidptr) bool

fn C.LineTo(hdc voidptr, x int, y int) bool

fn C.Ellipse(hdc voidptr, left int, top int, right int, bottom int) bool

// Action é uma das ações que entregam a imagem e encerram o editor. Elas abrem a barra, antes
// das ferramentas e separadas delas por um traço: são o que se faz com a imagem, e não com
// o desenho. Desfazer, refazer e fechar ficam só no teclado.
enum Action {
	copy
	save
}

// As ações na ordem em que aparecem na barra.
const toolbar_actions = [Action.copy, .save]

// action_command devolve o identificador que a ação manda para a janela, o mesmo que o
// atalho de teclado manda pela tabela de aceleradores.
fn action_command(action Action) u32 {
	return match action {
		.copy { id_copy }
		.save { id_save }
	}
}

// action_name devolve o rótulo da ação, que a barra mostra quando o ponteiro para sobre
// ela: o botão é só um ícone, e sem isso não haveria como saber o que ele faz.
fn action_name(action Action) string {
	return match action {
		.copy { 'Copiar e fechar' }
		.save { 'Salvar e fechar' }
	}
}

// action_shortcut devolve o atalho de teclado da ação.
fn action_shortcut(action Action) string {
	return match action {
		.copy { 'Ctrl+C' }
		.save { 'Ctrl+S' }
	}
}

// Tool é a ferramenta ativa. A ordem aqui é a ordem da barra. A primeira seleciona com um
// clique e recorta com um arrasto sobre a imagem vazia: as duas dividem o mesmo botão.
enum Tool {
	select
	arrow
	text
	ruler
	rectangle
	backdrop
	freehand
	magnifier
	blur
	highlighter
	counter
	oval
	line
}

// As ferramentas que produzem marcação. As demais existem na barra para o layout poder ser
// avaliado antes de custar implementação.
const drawing_tools = [Tool.rectangle, .oval, .line, .arrow, .freehand, .highlighter, .counter,
	.text, .blur, .magnifier, .ruler]

// As ferramentas que guardam um caminho em vez de caberem na caixa.
const stroke_tools = [Tool.freehand, .highlighter]

// As ferramentas na ordem em que aparecem, e a tecla que as escolhe.
const toolbar_tools = [Tool.select, .arrow, .text, .ruler, .rectangle, .backdrop, .freehand,
	.magnifier, .blur, .highlighter, .counter, .oval, .line]

// ToolInfo reúne o que cada ferramenta mostra e guarda: o rótulo, para a dica e para o texto de estado; a tecla de fábrica, seguindo a referência; o desenho do botão; e o nome da opção da tecla no vshot.ini.
struct ToolInfo {
	name    string
	key     string
	icon    string
	setting string
}

// tool_info tem uma linha por ferramenta, na ordem do enum Tool, que é também a da barra, e é por essa ordem que as consultas a leem. Uma tabela, e não um match de treze braços em cada consulta, que passava do limite de complexidade e repetia a mesma lista quatro vezes.
const tool_info = [
	ToolInfo{
		name:    'Selecionar; arraste na imagem para recortar'
		key:     'V'
		icon:    'cursor'
		setting: 'selecionar'
	},
	ToolInfo{
		name:    'Seta'
		key:     'A'
		icon:    'arrow'
		setting: 'seta'
	},
	ToolInfo{
		name:    'Texto'
		key:     'T'
		icon:    'text'
		setting: 'texto'
	},
	ToolInfo{
		name:    'Régua'
		key:     'U'
		icon:    'measure'
		setting: 'regua'
	},
	ToolInfo{
		name:    'Retângulo'
		key:     'R'
		icon:    'rect'
		setting: 'retangulo'
	},
	ToolInfo{
		name:    'Moldura'
		key:     'K'
		icon:    'frame'
		setting: 'moldura'
	},
	ToolInfo{
		name:    'Traço livre'
		key:     'D'
		icon:    'pencil'
		setting: 'traco_livre'
	},
	ToolInfo{
		name:    'Lupa'
		key:     'M'
		icon:    'circle-handle'
		setting: 'lupa'
	},
	ToolInfo{
		name:    'Borrar'
		key:     'B'
		icon:    'droplet'
		setting: 'borrar'
	},
	ToolInfo{
		name:    'Marca-texto'
		key:     'H'
		icon:    'highlighter'
		setting: 'marca_texto'
	},
	ToolInfo{
		name:    'Numerador'
		key:     'C'
		icon:    'counter'
		setting: 'numerador'
	},
	ToolInfo{
		name:    'Elipse'
		key:     'O'
		icon:    'ellipse'
		setting: 'elipse'
	},
	ToolInfo{
		name:    'Linha'
		key:     'L'
		icon:    'line'
		setting: 'linha'
	},
]

// tool_name devolve o rótulo da ferramenta, para a dica e para o texto de estado.
fn tool_name(tool Tool) string {
	return tool_info[int(tool)].name
}

// tool_shortcut devolve a tecla da ferramenta, seguindo a referência.
fn tool_shortcut(tool Tool) string {
	return tool_info[int(tool)].key
}

const tool_button_size = 34
const tool_button_gap = 2
const toolbar_margin = 6
// Vão de cada lado do traço que separa as ações das ferramentas.
const toolbar_group_gap = 14
// O topo do botão, que centra o quadrado do botão na altura da barra.
const tool_button_top = (toolbar_height - tool_button_size) / 2

const toolbar_color = u32(0x002d2d2d)
const toolbar_text_color = u32(0x00d8d8d8)
const toolbar_dim_text_color = u32(0x00909090)
const toolbar_icon_color = u32(0x00c8c8c8)
const toolbar_icon_active_color = u32(0x00ffffff)
const toolbar_active_color = u32(0x00505050)
const toolbar_separator_color = u32(0x003c3c3c)

// Larguras dos três blocos de estado da direita: cor, tamanho e zoom. O da cor cabe o rótulo mais largo, "Tab copia Android", que tem 131 pixels e começa 28 depois do início do bloco: com 150, ele passava do traço e cobria o começo de "Tamanho".
const status_color_width = 180
const status_size_width = 130
const status_zoom_width = 80
const status_block_width = status_color_width + status_size_width + status_zoom_width
// Vão mínimo para a mensagem caber sem encostar nos vizinhos.
const status_message_room = 170
// Folga entre o fim da mensagem e o primeiro bloco da direita.
const status_message_gap = 20
// DT_END_ELLIPSIS troca o fim que não coube por reticências.
const dt_end_ellipsis = u32(0x8000)

// row_width é o quanto uma fila de `count` botões ocupa.
fn row_width(count int) int {
	return if count == 0 { 0 } else { count * tool_button_size + (count - 1) * tool_button_gap }
}

// action_button_left devolve onde começa a ação de índice `index`.
fn action_button_left(index int) int {
	return toolbar_margin + index * (tool_button_size + tool_button_gap)
}

// toolbar_tools_left é onde a fila de ferramentas começa: depois das ações e do traço.
fn toolbar_tools_left() int {
	return toolbar_margin + row_width(toolbar_actions.len) + 2 * toolbar_group_gap
}

// tool_button_left devolve onde começa o botão de índice `index`.
fn tool_button_left(index int) int {
	return toolbar_tools_left() + index * (tool_button_size + tool_button_gap)
}

// snap_button_left é onde começa o botão do alinhamento: depois das ferramentas e de outro traço, porque ele liga uma opção, e não escolhe o que desenhar.
fn snap_button_left() int {
	return toolbar_tools_left() + row_width(toolbar_tools.len) + 2 * toolbar_group_gap
}

// toolbar_tools_width é o quanto a barra ocupa até o fim dos botões.
fn toolbar_tools_width() int {
	return snap_button_left() + tool_button_size + toolbar_margin
}

// on_button_row diz se a altura do ponto é a dos botões, que é a mesma nos dois grupos.
fn on_button_row(y int) bool {
	return y >= tool_button_top && y < tool_button_top + tool_button_size
}

// action_at devolve a ação sob o ponto, ou none se o ponto caiu fora da fila.
fn action_at(x int, y int) ?Action {
	if !on_button_row(y) {
		return none
	}
	for index, action in toolbar_actions {
		left := action_button_left(index)
		if x >= left && x < left + tool_button_size {
			return action
		}
	}
	return none
}

// tool_at devolve a ferramenta sob o ponto, ou none se o ponto caiu fora da fila.
fn tool_at(x int, y int) ?Tool {
	if !on_button_row(y) {
		return none
	}
	for index, tool in toolbar_tools {
		left := tool_button_left(index)
		if x >= left && x < left + tool_button_size {
			return tool
		}
	}
	return none
}

// on_snap_button diz se o ponto caiu no botão do alinhamento.
fn on_snap_button(x int, y int) bool {
	return on_button_row(y) && x >= snap_button_left() && x < snap_button_left() + tool_button_size
}

// toolbar_message é o texto que a barra mostra: o da ação sob o ponteiro, enquanto houver
// uma, e o estado da edição no resto do tempo. Passar o mouse não apaga o que a barra
// estava dizendo, porque quando o ponteiro sai a mensagem anterior volta.
// Depois de um comando, o resultado dele passa na frente do nome até o ponteiro sair do botão: é o clique que acabou de falhar, e o nome esconderia a falha.
fn (e Editor) toolbar_message() string {
	if !e.hover_muted && e.hovered >= 0 && e.hovered < toolbar_actions.len {
		action := toolbar_actions[e.hovered]
		return '${action_name(action)}  (${e.action_key(action)})'
	}
	if e.hovered_tool >= 0 && e.hovered_tool < toolbar_tools.len {
		tool := toolbar_tools[e.hovered_tool]
		return '${tool_name(tool)}  (${e.tool_key(tool)})'
	}
	if e.hovered_snap {
		state := if e.config.snap_edges { 'ligado' } else { 'desligado' }
		return 'Alinhar às bordas: ${state}'
	}
	return e.status
}

// action_key é a combinação que dispara a ação: a da configuração, ou a de fábrica num
// editor montado sem ela, como nos testes.
fn (e Editor) action_key(action Action) string {
	key := match action {
		.copy { e.config.copy }
		.save { e.config.save }
	}
	return if key.key == 0 { action_shortcut(action) } else { key.str() }
}

// track_hover guarda qual ação está sob o ponteiro e diz se isso mudou, que é quando a
// barra precisa ser redesenhada.
fn (mut e Editor) track_hover(x int, y int) bool {
	mut found := -1
	if action := action_at(x, y) {
		found = toolbar_actions.index(action)
	}
	// A ferramenta sob o ponteiro também, para o botão dela ganhar o fundo e a barra dizer o nome e a tecla dela.
	mut tool := -1
	if under := tool_at(x, y) {
		tool = toolbar_tools.index(under)
	}
	snap := on_snap_button(x, y)
	if found == e.hovered && tool == e.hovered_tool && snap == e.hovered_snap {
		return false
	}
	e.hover_muted = false
	e.hovered = found
	e.hovered_tool = tool
	e.hovered_snap = snap
	return true
}

// draw_toolbar desenha a barra inteira: o fundo, a fila de ferramentas e o estado.
fn draw_toolbar(hdc voidptr, width int, state &Editor) {
	mut background := C.RECT{
		right: width
		bottom: toolbar_height
	}
	C.FillRect(hdc, &background, state.toolbar_bg)

	for index, action in toolbar_actions {
		hovered := index == state.hovered
		face := if hovered { toolbar_active_color } else { toolbar_color }
		color := if hovered { toolbar_icon_active_color } else { toolbar_icon_color }
		draw_toolbar_button(hdc, action_button_left(index), face, action_icon(action), state,
			color)
	}
	draw_status_separator(hdc, toolbar_margin + row_width(toolbar_actions.len) + toolbar_group_gap)

	// A ferramenta na mão fica acesa; a que está sob o ponteiro ganha um fundo mais discreto, que diz onde o clique vai cair.
	for index, tool in toolbar_tools {
		active := tool == state.tool
		hovered := index == state.hovered_tool
		face := if active {
			toolbar_active_color
		} else if hovered {
			button_face_color
		} else {
			toolbar_color
		}
		color := if active || hovered { toolbar_icon_active_color } else { toolbar_icon_color }
		draw_toolbar_button(hdc, tool_button_left(index), face, tool_icon(tool), state, color)
	}

	draw_status_separator(hdc, snap_button_left() - toolbar_group_gap)
	draw_snap_button(hdc, state)

	draw_toolbar_status(hdc, width, state)
}

// draw_snap_button desenha o botão do alinhamento: aceso enquanto o alinhamento está ligado, como a ferramenta na mão.
fn draw_snap_button(hdc voidptr, state &Editor) {
	face := if state.config.snap_edges {
		toolbar_active_color
	} else if state.hovered_snap {
		button_face_color
	} else {
		toolbar_color
	}
	lit := state.config.snap_edges || state.hovered_snap
	draw_toolbar_button(hdc, snap_button_left(), face, 'snap', state, if lit { toolbar_icon_active_color } else { toolbar_icon_color })
}

// draw_toolbar_button desenha um botão da barra: o fundo arredondado, quando ele tem um, e o ícone centrado nele. A cor da própria barra é a do botão sem fundo.
fn draw_toolbar_button(hdc voidptr, left int, face u32, icon string, state &Editor, color u32) {
	if face != toolbar_color {
		fill_button(hdc, Rect{
			x: left
			y: tool_button_top
			width: tool_button_size
			height: tool_button_size
		}, face)
	}
	offset := (tool_button_size - icon_size) / 2
	draw_icon(hdc, icon, left + offset, tool_button_top + offset, state.icons, color)
}

// draw_toolbar_status desenha os três blocos da direita, cada um com um valor em cima e
// o seu rótulo embaixo, como na referência.
fn draw_toolbar_status(hdc voidptr, width int, state &Editor) {
	old_font := C.SelectObject(hdc, state.font)
	C.SetBkMode(hdc, transparent_bk)
	defer {
		C.SelectObject(hdc, old_font)
	}

	mut left := width - status_block_width
	if left < toolbar_tools_width() {
		// Numa janela estreita o estado é omitido em vez de escrever por cima das
		// ferramentas.
		return
	}

	// A mensagem ocupa o vão entre a última ferramenta e o primeiro bloco, e some quando
	// esse vão fica curto demais para valer a pena. Uma mensagem mais comprida que o vão é
	// cortada com reticências antes do traço que abre os blocos — sem o corte, uma cor
	// copiada em formato longo passava por baixo do bloco da cor.
	message := state.toolbar_message()
	if left - toolbar_tools_width() >= status_message_room {
		C.SetTextColor(hdc, toolbar_text_color)
		mut room := C.RECT{
			left: toolbar_tools_width()
			right: left - status_message_gap
			bottom: toolbar_height
		}
		C.DrawTextW(hdc, message.to_wide(), -1, &room, dt_singleline | dt_vcenter | dt_noprefix | dt_end_ellipsis)
	}

	// O bloco da cor muda a cada movimento do mouse e não é desenhado aqui, que é a
	// composição fixa: ele vem por cima, em draw_picker.
	draw_status_separator(hdc, left - 10)

	left += status_color_width
	draw_status_separator(hdc, left - 10)
	draw_status_block(hdc, left, '${state.current.width}x${state.current.height}px', 'Tamanho')

	left += status_size_width
	draw_status_separator(hdc, left - 10)
	// Arredondado como na mensagem do zoom e no painel dele, para os três dizerem o mesmo número.
	draw_status_block(hdc, left, '${int(state.scale * 100 + 0.5)}%', 'Zoom')
}

// draw_status_block escreve o valor e o seu rótulo, um sobre o outro.
fn draw_status_block(hdc voidptr, left int, value string, label string) {
	C.SetTextColor(hdc, toolbar_text_color)
	C.TextOutW(hdc, left, 6, value.to_wide(), utf16_length(value))
	C.SetTextColor(hdc, toolbar_dim_text_color)
	C.TextOutW(hdc, left, 24, label.to_wide(), utf16_length(label))
}

// draw_status_separator desenha o traço vertical que divide os blocos de estado.
fn draw_status_separator(hdc voidptr, x int) {
	pen := C.CreatePen(ps_solid, 1, toolbar_separator_color)
	old_pen := C.SelectObject(hdc, pen)
	stroke(hdc, x, 10, x, toolbar_height - 10)
	C.SelectObject(hdc, old_pen)
	C.DeleteObject(pen)
}

// stroke liga dois pontos com a caneta corrente.
fn stroke(hdc voidptr, x1 int, y1 int, x2 int, y2 int) {
	C.MoveToEx(hdc, x1, y1, unsafe { nil })
	C.LineTo(hdc, x2, y2)
}
