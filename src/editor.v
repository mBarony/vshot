module main

import os

fn C.CreateFontW(height int, width int, escapement int, orientation int, weight int, italic u32, underline u32, strikeout u32, charset u32, out_precision u32, clip_precision u32, quality u32, pitch u32, face &u16) voidptr

fn C.GetClientRect(hwnd voidptr, area voidptr) bool

fn C.AdjustWindowRect(area voidptr, style u32, menu bool) bool

// @[typedef] porque MINMAXINFO é um typedef no windows.h: sem isso o V escreve `struct MINMAXINFO`, que não existe. Só ptMinTrackSize é escrito, mas os outros campos precisam estar aqui para o layout bater com o do Windows.
@[typedef]
struct C.MINMAXINFO {
mut:
	ptReserved     C.POINT
	ptMaxSize      C.POINT
	ptMaxPosition  C.POINT
	ptMinTrackSize C.POINT
	ptMaxTrackSize C.POINT
}

fn C.FillRect(hdc voidptr, area voidptr, brush voidptr) int

fn C.SetStretchBltMode(hdc voidptr, mode int) int

fn C.SetBrushOrgEx(hdc voidptr, x int, y int, previous voidptr) bool

fn C.StretchBlt(dst voidptr, x int, y int, width int, height int, src voidptr, src_x int, src_y int, src_width int, src_height int, rop u32) bool

fn C.SetBkMode(hdc voidptr, mode int) int

fn C.SetTextColor(hdc voidptr, color u32) u32

fn C.TextOutW(hdc voidptr, x int, y int, text &u16, length int) bool

fn C.CreateAcceleratorTableW(entries voidptr, count int) voidptr

fn C.TranslateAcceleratorW(hwnd voidptr, table voidptr, message voidptr) int

fn C.DestroyAcceleratorTable(table voidptr) bool

const ws_caption = u32(0x00c00000)
const ws_sysmenu = u32(0x00080000)
const ws_minimizebox = u32(0x00020000)
const ws_maximizebox = u32(0x00010000)
// A borda que se arrasta. Com ela e o botão de maximizar, a janela muda de tamanho, e o WM_SIZE refaz o espaço da imagem, as superfícies e a escala.
const ws_thickframe = u32(0x00040000)
// O estilo da janela do editor, num lugar só: a montagem, a conta do tamanho externo e o menor tamanho que o Windows pergunta antes de a janela existir precisam ser o mesmo.
const editor_style = ws_caption | ws_sysmenu | ws_minimizebox | ws_maximizebox | ws_thickframe
// HALFTONE faz a média dos pixels ao reduzir a imagem. O modo padrão simplesmente joga
// linhas fora, e o texto da captura vira sujeira ilegível.
const stretch_halftone = 4
const transparent_bk = 1
const fvirtkey = u8(0x01)
const fcontrol = u8(0x08)
const fshift = u8(0x04)
const falt = u8(0x10)
// ANTIALIASED_QUALITY suaviza em tons de cinza. O ClearType suavizaria por subpixel, que
// num glifo pequeno sobre fundo escuro deixa franjas alaranjadas e azuladas bem visíveis.
const antialiased_quality = u32(4)
const default_charset = u32(1)

const editor_class = 'VShotEditor'
const id_undo = u32(103)
const id_redo = u32(107)
const id_save = u32(104)
const id_copy = u32(105)
const id_close = u32(106)

const cs_dblclks = u32(0x0008)

const toolbar_height = 44
// Largura mínima do cliente, para a barra nunca ficar apertada. Cabem nela as duas ações, as treze ferramentas, o botão do alinhamento, a mensagem e os três blocos de estado — um teste confere essa soma, para a largura não ficar para trás quando a barra crescer. É também o piso da janela redimensionável.
const min_client_width = 1250
// A menor faixa de imagem que a janela aceita. Abaixo disso não sobra o que editar, e os painéis que pendem da barra não cabem.
const min_canvas_height = 240

// Fundo atrás da imagem, que aparece em volta dela depois de um recorte. Um tom abaixo da barra, para a imagem e a sombra dela se destacarem.
const canvas_color = u32(0x00202020)

@[typedef]
struct C.RECT {
mut:
	left   int
	top    int
	right  int
	bottom int
}

@[typedef]
struct C.ACCEL {
	fVirt u8
	key   u16
	cmd   u16
}

// Editor é o estado da janela de edição, vivo apenas enquanto ela existe.
struct Editor {
	// A captura como veio da tela. Nunca é alterada: é dela que o histórico é refeito.
	source Frozen
	// Janela principal da aplicação. É ela que avisa pelo balão da bandeja e que figura
	// como dona da área de transferência, porque sobrevive ao fechamento do editor.
	owner voidptr
mut:
	// O espaço da janela: canvas_width é a largura do cliente inteiro, e canvas_height, a altura dele abaixo da barra. Os dois mudam quando a janela é redimensionada, e o resize_canvas refaz as superfícies e a escala junto com eles.
	canvas_width  int
	canvas_height int
	// A imagem depois de todas as edições, que é o que aparece e o que é salvo.
	current Frozen
	// A janela é montada fora da tela e entregue de uma vez: background guarda a parte
	// que não muda durante um arrasto, buffer recebe a moldura por cima.
	background       Frozen
	buffer           Frozen
	background_ready bool
	// Se o que fica abaixo da barra, em background, ainda mostra a imagem e a vista em vigor.
	canvas_ready bool
	// O que está sendo editado, e as cenas de antes e de depois para desfazer e refazer.
	scene  Scene
	past   []Scene
	future []Scene
	// O futuro que o último record() apagou, guardado até a mudança ser aplicada: se a imagem não se monta, o rollback o devolve junto com a cena, e a edição que não pegou não apaga o refazer.
	discarded ?[]Scene
	// O refazer de antes de reabrir um texto, que volta se a reescrita for abandonada.
	rewrite_future []Scene
	// Onde a imagem é desenhada, em coordenadas do cliente, e por quanto ela foi reduzida.
	view     Rect
	scale    f64
	origin_x int
	origin_y int
	cursor_x int
	cursor_y int
	tool     Tool
	dragging bool
	done     bool
	// Índice da marcação selecionada na cena, ou -1 quando não há nenhuma. Durante um
	// arrasto ela sai da cena e passa a viver em `grabbed`, para o movimento redesenhar só
	// a moldura em vez de refazer a imagem a cada passo do mouse.
	selected int = -1
	grab     Grab
	grabbed  Shape
	// Verdadeiro enquanto a paleta de cores está aberta sob o disco do painel.
	palette_open bool
	// A cor dos próximos traços, pela mesma regra da espessura.
	color u32 = annotation_color
	// A espessura que os próximos traços vão usar. Trocá-la com algo selecionado troca
	// também a da marcação, mas o padrão fica valendo daí em diante.
	thickness int = annotation_width
	// Verdadeiro enquanto o botão do controle de espessura está sendo arrastado.
	sliding bool
	// Verdadeiro depois que o arrasto do controle já guardou a cena no histórico.
	slide_recorded bool
	// Os pontos do traço livre em curso, em coordenadas da janela. Vazio fora do arrasto.
	stroke []Point
	// O estilo que os próximos traços vão usar, pela mesma regra da espessura.
	style      Style
	status     string
	toolbar_bg voidptr
	canvas_bg  voidptr
	font       voidptr
	// Os desenhos da barra, montados uma vez na abertura. A cor é dada na hora de
	// desenhar, então uma cópia serve para a ferramenta ativa e para as demais.
	icons IconSet
	// A digitação em curso: o que já foi escrito, onde ele cabe, e qual marcação está
	// sendo reescrita — -1 quando é uma nova.
	typing     bool
	typed      string
	typed_area Rect
	typed_at   int = -1
	// A metade alta de um caractere fora do plano básico — um emoji —, à espera da metade baixa, que chega noutro WM_CHAR.
	high_surrogate rune
	// A cor, a espessura e o estilo padrão de antes de reabrir um texto, que voltam quando a reescrita termina.
	before_rewrite Shape
	// A ação sob o ponteiro, ou -1. É o que acende o botão e o que faz a barra dizer o
	// nome dele, já que o botão não tem rótulo.
	hovered int = -1
	// A ferramenta sob o ponteiro, pelo lugar dela na barra, ou -1 quando o ponteiro não está sobre nenhuma.
	hovered_tool int = -1
	// Se o ponteiro está sobre o botão do alinhamento.
	hovered_snap bool
	// Verdadeiro depois que um comando deu o resultado dele: o resultado toma o lugar do nome do botão sob o ponteiro até o ponteiro sair dali.
	hover_muted bool
	// A última cor lida sob o ponteiro, e o formato em que o Tab a copia.
	sampled      u32
	color_format int
	// O painel que pende de um bloco da barra, se algum estiver aberto.
	popover Popover
	// O zoom da vista, em relação a caber na janela, e o deslocamento da imagem quando ela
	// passa da área visível. O arrasto com o botão direito guarda de onde partiu.
	zoom     f64 = 1.0
	pan_x    int
	pan_y    int
	panning  bool
	pan_from Point
	// O ponto da imagem que a roda está mirando, onde o ponteiro estava e a vista que o zoom
	// deixou. Enquanto nenhum dos dois muda, passos seguidos miram o mesmo ponto.
	zoom_anchor  Point
	zoom_view    Rect
	zoom_focus_x f64
	zoom_focus_y f64
	// A medida em curso pelo teclado, enquanto a tecla dela estiver apertada.
	probe Probe
	// Se o arrasto em curso segura a lente da lupa, e não a origem.
	grab_lens bool
	// A configuração da aplicação: as teclas, a roda do zoom e a pasta.
	config Config
}

// editor_open_size preserva 100% quando a imagem cabe na área útil do monitor, descontando título, bordas e barra de ferramentas. Só reduz quando falta espaço.
fn editor_open_size(image_width int, image_height int, monitor Rect) (int, int) {
	outer_width, outer_height := editor_min_size(editor_style)
	limit_width := max(1, monitor.width - (outer_width - min_client_width))
	limit_height := max(1, monitor.height - (outer_height - min_canvas_height))
	scale := fit_within(image_width, image_height, limit_width, limit_height)
	return min(max(int(f64(image_width) * scale), min_client_width), limit_width), min(max(int(f64(image_height) * scale), min_canvas_height), limit_height)
}

// editor_min_size é o menor tamanho da janela inteira, borda e título incluídos, que é o que o Windows pergunta: o cliente mínimo mais a moldura que o estilo pede.
fn editor_min_size(style u32) (int, int) {
	mut outer := C.RECT{
		right: min_client_width
		bottom: toolbar_height + min_canvas_height
	}
	C.AdjustWindowRect(&outer, style, false)
	return outer.right - outer.left, outer.bottom - outer.top
}

// limit_editor_size responde ao Windows o menor tamanho que a janela aceita. Ele pergunta isso antes do WM_CREATE, quando o estado ainda não está ligado à janela: por isso o mínimo sai das constantes da barra, e não do editor.
fn limit_editor_size(lparam isize) {
	mut info := unsafe { &C.MINMAXINFO(lparam) }
	width, height := editor_min_size(editor_style)
	_, work := monitor_at(cursor_position())
	info.ptMinTrackSize = C.POINT{
		x: min(width, work.width)
		y: min(height, work.height)
	}
}

// editor_start é o editor recém-aberto, antes das superfícies e dos pincéis: com a seleção na mão, porque o primeiro gesto sobre uma captura costuma ser recortar, e a barra dizendo qual é a ferramenta e a tecla dela.
fn editor_start(frozen Frozen, owner voidptr, config Config, canvas_width int, canvas_height int) Editor {
	mut state := Editor{
		source: frozen
		tool: .select
		owner: owner
		config: config
		canvas_width: canvas_width
		canvas_height: canvas_height
	}
	state.status = state.hint()
	return state
}

// open_editor mostra a captura numa janela com barra de ferramentas, onde o usuário
// recorta, marca e manda salvar ou copiar.
fn open_editor(frozen Frozen, instance voidptr, owner voidptr, mut config Config) ! {
	// O editor abre no monitor em que o ponteiro está, que na captura de um monitor só é o da própria captura.
	_, monitor := monitor_at(cursor_position())
	client_width, canvas_height := editor_open_size(frozen.width, frozen.height, monitor)
	snap_at_open := config.snap_edges

	// Antes de qualquer desenho, e desligado depois de tudo devolvido: como os `defer`
	// correm na ordem inversa da declaração, este é o primeiro a ser escrito e o último a
	// acontecer.
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}

	mut state := Editor{
		...editor_start(frozen, owner, config, client_width, canvas_height)
		toolbar_bg: C.CreateSolidBrush(toolbar_color)
		canvas_bg: C.CreateSolidBrush(canvas_color)
		font: C.CreateFontW(-15, 0, 0, 0, 400, 0, 0, 0, default_charset, 0, 0, antialiased_quality, 0, 'Segoe UI'.to_wide())
	}
	defer {
		state.current.release()
		state.background.release()
		state.buffer.release()
		C.DeleteObject(state.toolbar_bg)
		C.DeleteObject(state.canvas_bg)
		C.DeleteObject(state.font)
		state.icons.release()
	}
	state.scene = Scene{
		crop: Rect{
			width: frozen.width
			height: frozen.height
		}
	}
	// Sem imagem de trabalho, superfícies de desenho ou ícones não há o que editar.
	state.apply()!
	state.icons = load_icons()
	surface_height := toolbar_height + canvas_height
	state.background = new_surface(frozen.dc, client_width, surface_height)!
	state.buffer = new_surface(frozen.dc, client_width, surface_height)!

	class_name := editor_class.to_wide()
	class := C.WNDCLASSW{
		// CS_DBLCLKS, para o duplo clique chegar como mensagem própria em vez de dois
		// cliques soltos: é ele que reabre um texto para reescrever.
		style: cs_dblclks
		lpfnWndProc: voidptr(editor_proc)
		hInstance: instance
		// O ícone da aplicação, que a barra de tarefas e o Alt+Tab mostram para o editor.
		hIcon: app_icon(C.GetSystemMetrics(sm_cxicon))
		hCursor: C.LoadCursorW(unsafe { nil }, idc_cross)
		lpszClassName: voidptr(class_name)
	}
	C.RegisterClassW(&class)

	// A janela abre do tamanho da imagem, e daí em diante é do usuário: a borda se arrasta, o botão de maximizar a estende pelo monitor, e cada mudança de tamanho refaz o espaço da imagem, as superfícies e a escala.
	mut outer := C.RECT{
		right: client_width
		bottom: toolbar_height + canvas_height
	}
	C.AdjustWindowRect(&outer, editor_style, false)

	// Centrada no monitor, em vez de onde o Windows escolher: a janela tem tamanho conhecido
	// e em cascata ela acabaria com uma das bordas para fora.
	place := centered_in(monitor, outer.right - outer.left, outer.bottom - outer.top)
	hwnd := C.CreateWindowExW(0, class_name, 'VShot — recorte e marque'.to_wide(), editor_style, place.x, place.y, place.width, place.height, unsafe { nil }, unsafe { nil }, instance, &state)
	if hwnd == unsafe { nil } {
		return error('CreateWindowExW falhou')
	}
	C.ShowWindow(hwnd, sw_show)
	C.SetForegroundWindow(hwnd)
	C.SetFocus(hwnd)

	entries := [accel(config.undo, id_undo), accel(config.redo, id_redo),
		accel(config.save, id_save), accel(config.copy, id_copy)]
	accelerators := C.CreateAcceleratorTableW(entries.data, entries.len)
	defer {
		C.DestroyAcceleratorTable(accelerators)
	}

	mut message := C.MSG{}
	for !state.done && C.GetMessageW(&message, unsafe { nil }, 0, 0) > 0 {
		// O atalho tem de ser traduzido antes do despacho, senão vira só uma tecla solta.
		if C.TranslateAcceleratorW(hwnd, accelerators, &message) == 0 {
			C.TranslateMessage(&message)
			C.DispatchMessageW(&message)
		}
	}
	// Só o clique no botão do alinhamento volta à aplicação: sem ele, o vshot.ini salvo com o editor aberto continua valendo.
	if state.config.snap_edges != snap_at_open {
		config.snap_edges = state.config.snap_edges
	}
	end_nested_loop(hwnd, state.done)
}

// accel monta a entrada da tabela de atalhos do editor para uma combinação da
// configuração. A tabela usa outros valores para os modificadores, e não aceita o Win.
fn accel(key Hotkey, command u32) C.ACCEL {
	mut flags := fvirtkey
	if key.modifiers & mod_control != 0 {
		flags |= fcontrol
	}
	if key.modifiers & mod_shift != 0 {
		flags |= fshift
	}
	if key.modifiers & mod_alt != 0 {
		flags |= falt
	}
	return C.ACCEL{
		fVirt: flags
		key: u16(key.key)
		cmd: u16(command)
	}
}

// hint devolve o nome e a tecla da ferramenta ativa, que é o que a barra mostra quando
// não há nada mais recente para dizer.
fn (e Editor) hint() string {
	return '${tool_name(e.tool)} (${e.tool_key(e.tool)})'
}

// tool_key é o nome da tecla que escolhe a ferramenta: a da configuração, ou a de fábrica
// num editor montado sem ela, como nos testes.
fn (e Editor) tool_key(tool Tool) string {
	index := toolbar_tools.index(tool)
	if index < 0 || index >= e.config.tools.len {
		return tool_shortcut(tool)
	}
	return key_name(e.config.tools[index])
}

// save_area grava a imagem de trabalho em arquivo e devolve o nome do arquivo.
fn save_area(state &Editor) !string {
	shot := state.current.region(Rect{
		width: state.current.width
		height: state.current.height
	})!
	defer {
		shot.release()
	}
	path := save(shot, state.config.output_path())!
	return os.base(path)
}

// copy_area põe a imagem de trabalho na área de transferência e devolve o tamanho.
fn copy_area(state &Editor) !string {
	bitmap := state.current.crop(Rect{
		width: state.current.width
		height: state.current.height
	})!
	copy_bitmap(state.owner, bitmap)!
	return '${state.current.width} x ${state.current.height}'
}
