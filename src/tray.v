module main

#flag windows -lshell32

#include <shellapi.h>

fn C.Shell_NotifyIconW(message u32, data voidptr) bool

fn C.LoadIconW(instance voidptr, name voidptr) voidptr

fn C.LoadImageW(instance voidptr, name voidptr, kind u32, width int, height int, flags u32) voidptr

fn C.CreatePopupMenu() voidptr

fn C.AppendMenuW(menu voidptr, flags u32, id usize, item &u16) bool

fn C.TrackPopupMenu(menu voidptr, flags u32, x int, y int, reserved int, hwnd voidptr, area voidptr) bool

fn C.DestroyMenu(menu voidptr) bool

fn C.GetCursorPos(point voidptr) bool

fn C.SetForegroundWindow(hwnd voidptr) bool

fn C.ShellExecuteW(hwnd voidptr, operation &u16, file &u16, parameters &u16, directory &u16, show int) voidptr

fn C.PostMessageW(hwnd voidptr, message u32, wparam usize, lparam isize) bool

const wm_null = u32(0)
const sw_shownormal = 1
const mf_separator = u32(0x0800)

const nim_add = u32(0)
const nim_modify = u32(1)
const nim_delete = u32(2)
const nif_message = u32(0x01)
const nif_icon = u32(0x02)
const nif_tip = u32(0x04)
const nif_info = u32(0x10)
const niif_info = u32(0x01)
const idi_application = voidptr(32512)
// O ícone da aplicação é o recurso 1 do executável, compilado de `assets/vshot.rc`.
const app_icon_id = voidptr(1)
const image_icon = u32(1)
// LR_SHARED: o sistema guarda o ícone e o devolve sozinho, sem DestroyIcon.
const lr_shared = u32(0x8000)
// Os lados do ícone pequeno, o da bandeja, e do grande, o da barra de tarefas e do Alt+Tab.
const sm_cxicon = 11
const sm_cxsmicon = 49
const mf_string = u32(0x0000)
const tpm_rightbutton = u32(0x0002)
const tpm_bottomalign = u32(0x0020)

// Identificador do ícone dentro desta aplicação. Só existe um, então é constante.
const tray_icon_id = u32(1)

// @[typedef] porque POINT é um typedef no windows.h: sem isso o V escreve
// `struct POINT`, que não existe.
@[typedef]
struct C.POINT {
mut:
	x int
	y int
}

// Campos de NOTIFYICONDATAW que esta aplicação usa.
// @[typedef] porque NOTIFYICONDATAW é um typedef no windows.h. Sem isso o V gera a própria
// definição da struct, e o programa passa a trabalhar com um layout inventado.
@[typedef]
struct C.NOTIFYICONDATAW {
mut:
	cbSize           u32
	hWnd             voidptr
	uID              u32
	uFlags           u32
	uCallbackMessage u32
	hIcon            voidptr
	szTip            [128]u16
	szInfo           [256]u16
	szInfoTitle      [64]u16
	dwInfoFlags      u32
}

// tray_add põe o ícone na área de notificação da barra de tarefas.
fn tray_add(hwnd voidptr, config Config) bool {
	mut data := new_icon_data(hwnd)
	data.uFlags = nif_message | nif_icon | nif_tip
	data.uCallbackMessage = wm_trayicon
	data.hIcon = app_icon(C.GetSystemMetrics(sm_cxsmicon))
	put_wide(&data.szTip[0], data.szTip.len, tray_tip(config))
	return C.Shell_NotifyIconW(nim_add, &data)
}

// tray_tip é o texto que aparece com o ponteiro parado sobre o ícone: os atalhos em vigor.
fn tray_tip(config Config) string {
	return 'VShot — ${config.screen} tela, ${config.region} área, ${config.editor} editor, ${config.ocr} texto'
}

// tray_retip troca esse texto, quando a configuração muda os atalhos, e diz se o ícone estava lá para recebê-lo.
fn tray_retip(hwnd voidptr, config Config) bool {
	mut data := new_icon_data(hwnd)
	data.uFlags = nif_tip
	put_wide(&data.szTip[0], data.szTip.len, tray_tip(config))
	return C.Shell_NotifyIconW(nim_modify, &data)
}

// open_settings abre o arquivo de configuração no Bloco de Notas. Quando ele é salvo, a
// aplicação o relê sozinha.
fn open_settings(hwnd voidptr) {
	C.ShellExecuteW(hwnd, 'open'.to_wide(), 'notepad.exe'.to_wide(), '"${config_path()}"'.to_wide(),
		unsafe { nil }, sw_shownormal)
}

// tray_remove tira o ícone. Sem isto ele fica como um fantasma na barra até alguém
// passar o mouse por cima.
fn tray_remove(hwnd voidptr) {
	mut data := new_icon_data(hwnd)
	C.Shell_NotifyIconW(nim_delete, &data)
}

// tray_notify mostra um balão de aviso saindo do ícone.
fn tray_notify(hwnd voidptr, title string, text string) {
	mut data := new_icon_data(hwnd)
	data.uFlags = nif_info
	data.dwInfoFlags = niif_info
	put_wide(&data.szInfoTitle[0], data.szInfoTitle.len, title)
	put_wide(&data.szInfo[0], data.szInfo.len, text)
	C.Shell_NotifyIconW(nim_modify, &data)
}

// show_menu abre o menu de contexto do ícone na posição atual do cursor.
fn show_menu(hwnd voidptr) {
	menu := C.CreatePopupMenu()
	if menu == unsafe { nil } {
		return
	}
	defer {
		C.DestroyMenu(menu)
	}
	C.AppendMenuW(menu, mf_string, usize(menu_screen), 'Capturar tela'.to_wide())
	C.AppendMenuW(menu, mf_string, usize(menu_region), 'Capturar área'.to_wide())
	C.AppendMenuW(menu, mf_string, usize(menu_editor), 'Capturar e editar'.to_wide())
	C.AppendMenuW(menu, mf_string, usize(menu_text), 'Capturar texto'.to_wide())
	C.AppendMenuW(menu, mf_separator, 0, unsafe { nil })
	C.AppendMenuW(menu, mf_string, usize(menu_settings), 'Configurações…'.to_wide())
	C.AppendMenuW(menu, mf_string, usize(menu_exit), 'Sair'.to_wide())

	mut cursor := C.POINT{}
	C.GetCursorPos(&cursor)
	// O menu só fecha ao clicar fora se a janela dona estiver em primeiro plano.
	C.SetForegroundWindow(hwnd)
	C.TrackPopupMenu(menu, tpm_rightbutton | tpm_bottomalign, cursor.x, cursor.y, 0, hwnd, unsafe { nil })
	// O que a documentação do TrackPopupMenu pede para janelas da bandeja: sem uma mensagem qualquer depois dele, o menu aberto de novo pode fechar sozinho na hora.
	C.PostMessageW(hwnd, wm_null, 0, 0)
}

// app_icon carrega o ícone da aplicação, embutido no executável, no lado pedido: o Windows
// escolhe, entre as imagens do `.ico`, a do tamanho certo para a escala da tela. Sem o
// recurso — os testes, que são compilados sem ele —, vale o ícone genérico do Windows.
fn app_icon(size int) voidptr {
	icon := C.LoadImageW(C.GetModuleHandleW(unsafe { nil }), app_icon_id, image_icon, size, size,
		lr_shared)
	if icon != unsafe { nil } {
		return icon
	}
	return C.LoadIconW(unsafe { nil }, idi_application)
}

// new_icon_data monta a identificação do ícone, que é o mínimo que toda chamada exige.
fn new_icon_data(hwnd voidptr) C.NOTIFYICONDATAW {
	return C.NOTIFYICONDATAW{
		cbSize: u32(sizeof(C.NOTIFYICONDATAW))
		hWnd: hwnd
		uID: tray_icon_id
	}
}

// put_wide copia o texto para um campo Win32 de largura fixa, truncando se não couber e
// sempre terminando em zero.
fn put_wide(dst &u16, capacity int, text string) {
	source := text.to_wide()
	unsafe {
		mut target := dst
		mut i := 0
		for i < capacity - 1 && source[i] != 0 {
			target[i] = source[i]
			i++
		}
		target[i] = 0
	}
}
