module main

import os

fn C.GetModuleHandleW(name voidptr) voidptr

fn C.RegisterClassW(class voidptr) u16

fn C.CreateWindowExW(ex_style u32, class_name &u16, window_name &u16, style u32, x int, y int, width int, height int, parent voidptr, menu voidptr, instance voidptr, param voidptr) voidptr

fn C.DefWindowProcW(hwnd voidptr, message u32, wparam usize, lparam isize) isize

fn C.DestroyWindow(hwnd voidptr) bool

fn C.GetMessageW(message voidptr, hwnd voidptr, min u32, max u32) int

fn C.TranslateMessage(message voidptr) bool

fn C.DispatchMessageW(message voidptr) isize

fn C.PostQuitMessage(code int)

fn C.RegisterHotKey(hwnd voidptr, id int, modifiers u32, key u32) bool

fn C.UnregisterHotKey(hwnd voidptr, id int) bool

fn C.MessageBoxW(hwnd voidptr, text &u16, caption &u16, kind u32) int

fn C.GetCurrentProcess() voidptr

fn C.SetProcessWorkingSetSize(process voidptr, minimum isize, maximum isize) bool

fn C.SetTimer(hwnd voidptr, id usize, milliseconds u32, callback voidptr) usize

fn C.RegisterWindowMessageW(name &u16) u32

const wm_destroy = u32(0x0002)
const wm_command = u32(0x0111)
const wm_hotkey = u32(0x0312)
const wm_rbuttonup = u32(0x0205)
const wm_lbuttondblclk = u32(0x0203)
// Mensagem própria desta aplicação, avisando que alguém mexeu no ícone da bandeja.
// A faixa a partir de WM_APP (0x8000) é reservada para uso interno do programa.
const wm_trayicon = u32(0x8001)

const mod_control = u32(0x0002)
const mod_shift = u32(0x0004)
// MOD_NOREPEAT evita uma enxurrada de capturas enquanto o atalho fica pressionado.
const mod_norepeat = u32(0x4000)
const hotkey_screen = 1
const hotkey_region = 2
const hotkey_editor = 3
const hotkey_text = 4

const menu_screen = u32(1)
const menu_region = u32(2)
const menu_editor = u32(3)
const menu_exit = u32(4)
const menu_settings = u32(5)
const menu_text = u32(6)

// A cada tanto a aplicação olha se o arquivo de configuração foi salvo. É uma consulta à
// data do arquivo, que não custa nada perto de um intervalo desses.
const wm_timer = u32(0x0113)
const config_timer = usize(1)
const config_interval = u32(2000)

const mb_iconerror = u32(0x10)
const mb_iconwarning = u32(0x30)

const app_name = 'VShot'

fn main() {
	// Precisa vir antes de qualquer janela: define de uma vez a consciência de DPI do
	// processo, sem a qual a captura sairia reescalada em telas com zoom.
	enable_dpi_awareness()

	instance := C.GetModuleHandleW(unsafe { nil })
	class_name := app_name.to_wide()

	// O estado fica na pilha do main, que só retorna quando a aplicação encerra. Assim o
	// coletor do V continua enxergando o ponteiro que o Windows guarda para nós.
	// O número da mensagem do Explorer vem antes da janela, para o campo nunca valer zero — que é o WM_NULL — enquanto ela já recebe mensagens.
	mut app := App{
		taskbar_created: C.RegisterWindowMessageW('TaskbarCreated'.to_wide())
	}

	mut class := C.WNDCLASSW{
		lpfnWndProc: voidptr(wnd_proc)
		hInstance: instance
		lpszClassName: voidptr(class_name)
	}
	if C.RegisterClassW(&class) == 0 {
		fatal('Não foi possível registrar a janela da aplicação.')
	}

	// Janela sem tamanho e nunca exibida: existe só para receber o atalho global e os
	// cliques no ícone da bandeja, que precisam de um destino para suas mensagens.
	hwnd := C.CreateWindowExW(0, class_name, class_name, 0, 0, 0, 0, 0, unsafe { nil }, unsafe { nil }, instance, &app)
	if hwnd == unsafe { nil } {
		fatal('Não foi possível criar a janela da aplicação.')
	}

	// Um arquivo com erro não impede a partida: valem as configurações de fábrica até ele
	// ser corrigido, e a correção é aplicada assim que o arquivo for salvo.
	path := config_path()
	mut config_read := true
	app.config = load_config(path) or {
		C.MessageBoxW(unsafe { nil }, 'O arquivo ${config_file} tem um erro — ${err}. Valem as configurações de fábrica até ele ser corrigido.'.to_wide(),
			app_name.to_wide(), mb_iconwarning)
		config_read = false
		default_config()
	}
	app.config_stamp = os.file_last_mod_unix(path)

	register_hotkeys(hwnd, app.config) or {
		fatal('${err}. Troque o atalho em ${config_file}, ao lado do executável, ou feche o outro programa e tente de novo.')
	}
	defer {
		unregister_hotkeys(hwnd)
	}

	// Sem a barra de tarefas pronta — no login, com o Explorer ainda subindo, ou ocupado demais para responder a tempo —, o ícone não entra agora, e a aplicação segue: os atalhos já valem, e o ícone é posto quando a barra aparecer, ou numa próxima tentativa do temporizador.
	app.tray_ok = tray_add(hwnd, app.config)
	// Com o arquivo errado não se sabe o que ele pede: os valores de fábrica tirariam a aplicação da inicialização do Windows por causa de um erro de digitação em outra linha.
	if config_read {
		apply_autostart(app.config.autostart) or { tray_notify(hwnd, app_name, err.msg()) }
	}
	C.SetTimer(hwnd, config_timer, config_interval, unsafe { nil })

	mut message := C.MSG{}
	for C.GetMessageW(&message, unsafe { nil }, 0, 0) > 0 {
		C.TranslateMessage(&message)
		C.DispatchMessageW(&message)
	}
}

// wnd_proc recebe as mensagens da janela oculta: o atalho global, os cliques no ícone e
// as escolhas do menu.
fn wnd_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	if message == wm_create {
		create := unsafe { &C.CREATESTRUCTW(lparam) }
		C.SetWindowLongPtrW(hwnd, gwlp_userdata, isize(create.lpCreateParams))
		return 0
	}
	pointer := voidptr(C.GetWindowLongPtrW(hwnd, gwlp_userdata))
	if pointer == unsafe { nil } {
		return C.DefWindowProcW(hwnd, message, wparam, lparam)
	}
	mut app := unsafe { &App(pointer) }

	if message == app.taskbar_created {
		// O Explorer reiniciou, e o ícone da bandeja sumiu com ele. Sem ícone não há a quem avisar se falhar de novo.
		app.tray_ok = tray_add(hwnd, app.config)
		return 0
	}
	if message == wm_hotkey {
		// O identificador do atalho vem em wParam e é o que separa os modos.
		hotkey_pressed(hwnd, mut app, int(wparam))
		return 0
	}
	if message == wm_timer {
		keep_tray(hwnd, mut app)
		reload_config(hwnd, mut app)
		return 0
	}
	if message == wm_trayicon {
		tray_event(hwnd, mut app, u32(lparam))
		return 0
	}
	if message == wm_command {
		// O identificador do item escolhido vem nos 16 bits baixos de wParam.
		menu_chosen(hwnd, mut app, u32(wparam) & 0xffff)
		return 0
	}
	if message == wm_destroy {
		tray_remove(hwnd)
		C.PostQuitMessage(0)
		return 0
	}
	return C.DefWindowProcW(hwnd, message, wparam, lparam)
}

// hotkey_pressed abre o modo de captura do atalho global apertado.
fn hotkey_pressed(hwnd voidptr, mut app App, id int) {
	match id {
		hotkey_region { capture_region(hwnd, mut app) }
		hotkey_editor { capture_to_editor(hwnd, mut app) }
		hotkey_text { capture_text(hwnd, mut app) }
		else { capture_screen(hwnd, mut app) }
	}
	trim_working_set()
}

// tray_event trata o ícone da bandeja: o clique direito abre o menu, e o duplo clique captura a tela inteira.
fn tray_event(hwnd voidptr, mut app App, event u32) {
	if event == wm_rbuttonup {
		show_menu(hwnd)
	} else if event == wm_lbuttondblclk {
		capture_screen(hwnd, mut app)
		// Como depois do atalho e do menu. Só neste ramo: o ícone manda uma mensagem a cada movimento do mouse sobre ele.
		trim_working_set()
	}
}

// menu_chosen executa o item escolhido no menu da bandeja.
fn menu_chosen(hwnd voidptr, mut app App, id u32) {
	match id {
		menu_screen { capture_screen(hwnd, mut app) }
		menu_region { capture_region(hwnd, mut app) }
		menu_editor { capture_to_editor(hwnd, mut app) }
		menu_text { capture_text(hwnd, mut app) }
		menu_settings { open_settings(hwnd) }
		menu_exit { C.DestroyWindow(hwnd) }
		else {}
	}
	trim_working_set()
}

// end_nested_loop fecha a janela de um laço aninhado — o do editor ou o da seleção — que terminou por ter consumido o WM_QUIT do Sair, e não pelo done. O pedido volta ao laço principal, que é quem encerra a aplicação; sem isso o processo ficaria vivo, sem ícone, com a janela apontando para um estado que já saiu da pilha.
fn end_nested_loop(hwnd voidptr, done bool) {
	if done {
		return
	}
	C.DestroyWindow(hwnd)
	C.PostQuitMessage(0)
}

// capture_screen salva a tela inteira, sem pedir nada ao usuário.
fn capture_screen(hwnd voidptr, mut app App) {
	if app.busy {
		return
	}
	frozen := app.freeze(virtual_screen()) or {
		tray_notify(hwnd, app_name, 'Falha ao capturar a tela: ${err}')
		return
	}
	defer {
		frozen.release()
	}
	store(hwnd, frozen, Rect{
		width: frozen.width
		height: frozen.height
	}, 'Captura salva', app.config.output_path())
}

// capture_region congela a tela, deixa o usuário escolher um pedaço dela e salva só isso.
fn capture_region(hwnd voidptr, mut app App) {
	if app.busy {
		return
	}
	app.busy = true
	defer {
		app.busy = false
	}
	frozen := app.freeze(virtual_screen()) or {
		tray_notify(hwnd, app_name, 'Falha ao capturar a tela: ${err}')
		return
	}
	defer {
		frozen.release()
	}
	// Sem área escolhida o usuário desistiu, e desistir não merece aviso nenhum.
	area := select_region(frozen, C.GetModuleHandleW(unsafe { nil })) or { return }
	store(hwnd, frozen, area, 'Área salva', app.config.output_path())
}

// capture_to_editor congela a tela e abre o editor, de onde o usuário recorta, salva e
// copia. Aqui a aplicação não salva nada por conta própria: quem decide é o editor. Congela só o monitor em que o ponteiro está, a não ser que a configuração peça todos.
fn capture_to_editor(hwnd voidptr, mut app App) {
	if app.busy {
		return
	}
	app.busy = true
	defer {
		app.busy = false
	}
	frozen := app.freeze(editor_capture_area(app.config.all_monitors, cursor_position())) or {
		tray_notify(hwnd, app_name, 'Falha ao capturar a tela: ${err}')
		return
	}
	defer {
		frozen.release()
	}
	snap_edges := app.config.snap_edges
	open_editor(frozen, C.GetModuleHandleW(unsafe { nil }), hwnd, mut app.config) or {
		tray_notify(hwnd, app_name, 'Falha ao abrir o editor: ${err}')
		return
	}
	if app.config.snap_edges != snap_edges {
		save_snap(hwnd, mut app)
	}
}

// save_snap grava no arquivo a escolha do botão do alinhamento, para ela valer também depois de reabrir a aplicação. A data nova é guardada junto: relê-lo daria um balão de configurações aplicadas por causa de um clique.
fn save_snap(hwnd voidptr, mut app App) {
	path := config_path()
	text := os.read_file(path) or { app.config.text() }
	os.write_file(path, text_with_snap(text, app.config.snap_edges)) or {
		tray_notify(hwnd, app_name, 'Falha ao guardar o alinhamento: ${err}')
		return
	}
	app.config_stamp = os.file_last_mod_unix(path)
}

// register_hotkeys registra os quatro atalhos globais, com os identificadores na ordem dos
// modos. Se um falha, os que já tinham entrado saem, para não sobrar metade registrada.
fn register_hotkeys(hwnd voidptr, config Config) ! {
	for index, key in [config.screen, config.region, config.editor, config.ocr] {
		if !C.RegisterHotKey(hwnd, hotkey_screen + index, key.modifiers | mod_norepeat, key.key) {
			unregister_hotkeys(hwnd)
			return error('${key} já está em uso por outro programa, ou repetido na configuração')
		}
	}
}

// unregister_hotkeys solta os quatro atalhos. Soltar um que não foi registrado não faz mal.
fn unregister_hotkeys(hwnd voidptr) {
	for id in hotkey_screen .. hotkey_text + 1 {
		C.UnregisterHotKey(hwnd, id)
	}
}

// keep_tray tenta de novo pôr o ícone, a cada tique do temporizador, enquanto ele não entrou. Um NIM_ADD que estourou o tempo pode ter posto o ícone mesmo assim, e aí um novo NIM_ADD falha para sempre: o NIM_MODIFY, que só dá certo com o ícone lá, é o que mostra que ele já está.
fn keep_tray(hwnd voidptr, mut app App) {
	if !app.tray_ok {
		app.tray_ok = tray_add(hwnd, app.config) || tray_retip(hwnd, app.config)
	}
}

// reload_config relê o arquivo quando ele foi salvo desde a última leitura, e aplica o que
// mudou. Com erro — no arquivo, ou um atalho que outro programa já usa —, a configuração
// anterior continua valendo inteira, e o balão diz o que corrigir.
fn reload_config(hwnd voidptr, mut app App) {
	path := config_path()
	stamp := os.file_last_mod_unix(path)
	if stamp == app.config_stamp {
		return
	}
	app.config_stamp = stamp
	config := load_config(path) or {
		tray_notify(hwnd, 'Configuração com erro', err.msg())
		return
	}
	// Um vshot.ini apagado volta de fábrica pelo load_config, e a data dele só existe agora: guardada antes, como 0, o tique seguinte relia o arquivo recém-criado e repetia o balão.
	if stamp == 0 {
		app.config_stamp = os.file_last_mod_unix(path)
	}
	unregister_hotkeys(hwnd)
	register_hotkeys(hwnd, config) or {
		register_hotkeys(hwnd, app.config) or {}
		tray_notify(hwnd, 'Configuração com erro', '${err}. Os atalhos anteriores continuam valendo.')
		return
	}
	app.config = config
	tray_retip(hwnd, config)
	apply_autostart(config.autostart) or {
		tray_notify(hwnd, app_name, err.msg())
		return
	}
	tray_notify(hwnd, 'Configurações aplicadas', tray_tip(config))
}

// store recorta, grava na pasta pedida e avisa pelo balão da bandeja.
fn store(hwnd voidptr, frozen Frozen, area Rect, title string, dir string) {
	shot := frozen.region(area) or {
		tray_notify(hwnd, app_name, 'Falha ao recortar a captura: ${err}')
		return
	}
	// Os pixels vêm do alocador do sistema e não do coletor: liberar aqui é o que impede
	// a aplicação residente de carregar 8 MB por captura pelo resto da execução.
	defer {
		shot.release()
	}
	path := save(shot, dir) or {
		tray_notify(hwnd, app_name, 'Falha ao salvar a captura: ${err}')
		return
	}
	tray_notify(hwnd, title, os.base(path))
}

// trim_working_set devolve ao Windows as páginas que a captura usou e não usa mais.
// Comprimir o PNG deixa dezenas de megabytes de arena no alocador da runtime C, que não
// os devolve sozinho, e esta aplicação passa quase todo o tempo parada esperando um
// atalho. As páginas voltam por falta de página na próxima captura, o que custa alguns
// milissegundos uma vez, contra carregar a área de trabalho cheia por horas.
fn trim_working_set() {
	// -1 nos dois limites é como se pede ao Windows que recolha a área de trabalho.
	C.SetProcessWorkingSetSize(C.GetCurrentProcess(), -1, -1)
}

// fatal avisa numa caixa de diálogo e encerra. A aplicação não tem console para escrever.
fn fatal(text string) {
	C.MessageBoxW(unsafe { nil }, text.to_wide(), app_name.to_wide(), mb_iconerror)
	exit(1)
}

// Campos de WNDCLASSW e MSG que esta aplicação usa.
// @[typedef] porque WNDCLASSW é um typedef no windows.h. Sem isso o V gera a própria
// definição da struct, e o programa passa a trabalhar com um layout inventado.
@[typedef]
struct C.WNDCLASSW {
	style         u32
	lpfnWndProc   voidptr
	cbClsExtra    int
	cbWndExtra    int
	hInstance     voidptr
	hIcon         voidptr
	hCursor       voidptr
	hbrBackground voidptr
	lpszMenuName  voidptr
	lpszClassName voidptr
}

// @[typedef] porque MSG é um typedef no windows.h. Sem isso o V gera a própria
// definição da struct, e o programa passa a trabalhar com um layout inventado.
@[typedef]
struct C.MSG {
mut:
	hwnd    voidptr
	message u32
	wParam  usize
	lParam  isize
	time    u32
	pt      C.POINT
}

// App é o estado da aplicação, vivo enquanto a janela principal existir.
struct App {
mut:
	// Verdadeiro enquanto uma seleção ou o editor estiverem abertos. Os dois rodam um
	// laço de mensagens aninhado, e sem esta trava um novo atalho empilharia uma janela
	// dentro da outra.
	busy bool
	// A configuração em vigor, e a data do arquivo quando ela foi lida.
	config       Config
	config_stamp i64
	// Mensagem que o Explorer transmite ao reiniciar, pedindo que cada programa recoloque o ícone da bandeja.
	taskbar_created u32
	// Se o ícone está na bandeja. Na partida a barra de tarefas pode ainda não existir, e o ícone entra depois.
	tray_ok bool
	// A faixa do texto copiado. Mora aqui, na pilha do main, para o coletor do V continuar enxergando o que a janela dela aponta.
	text_popup TextPopup
}

// freeze tira da tela a faixa do texto copiado, que sairia na imagem, e congela a área pedida da tela.
fn (mut app App) freeze(area Rect) !Frozen {
	close_text_popup(mut app.text_popup)
	return freeze_area(area)
}
