module main

// Os monitores: a tela virtual, que envolve todos eles, e o monitor em que o ponteiro está. As coordenadas são as da tela virtual, em pixels físicos, e um monitor à esquerda ou acima do principal começa em coordenada negativa.

fn C.MonitorFromPoint(point C.POINT, flags u32) voidptr

fn C.GetMonitorInfoW(monitor voidptr, info voidptr) bool

@[typedef]
struct C.MONITORINFO {
mut:
	cbSize    u32
	rcMonitor C.RECT
	rcWork    C.RECT
	dwFlags   u32
}

// Índices de GetSystemMetrics para a tela virtual: o retângulo que envolve todos os monitores.
const sm_xvirtualscreen = 76
const sm_yvirtualscreen = 77
const sm_cxvirtualscreen = 78
const sm_cyvirtualscreen = 79

const monitor_defaulttonearest = u32(2)

// virtual_screen devolve a tela virtual inteira, com todos os monitores.
fn virtual_screen() Rect {
	return Rect{
		x: C.GetSystemMetrics(sm_xvirtualscreen)
		y: C.GetSystemMetrics(sm_yvirtualscreen)
		width: C.GetSystemMetrics(sm_cxvirtualscreen)
		height: C.GetSystemMetrics(sm_cyvirtualscreen)
	}
}

// cursor_position devolve onde o ponteiro está, na tela virtual.
fn cursor_position() C.POINT {
	mut cursor := C.POINT{}
	C.GetCursorPos(&cursor)
	return cursor
}

// monitor_at devolve o monitor que contém o ponto, ou o mais próximo dele: a tela inteira do monitor e a área de trabalho, sem a barra de tarefas.
fn monitor_at(point C.POINT) (Rect, Rect) {
	mut info := C.MONITORINFO{
		cbSize: u32(sizeof(C.MONITORINFO))
	}
	C.GetMonitorInfoW(C.MonitorFromPoint(point, monitor_defaulttonearest), &info)
	return rect_from(info.rcMonitor), rect_from(info.rcWork)
}

// rect_from traduz um RECT, de bordas, num Rect, de canto e tamanho.
fn rect_from(area C.RECT) Rect {
	return Rect{
		x: area.left
		y: area.top
		width: area.right - area.left
		height: area.bottom - area.top
	}
}

// editor_capture_area é o que a captura para o editor congela: a tela virtual inteira, com a opção de capturar todos os monitores, ou só o monitor em que o ponteiro está.
fn editor_capture_area(all_monitors bool, cursor C.POINT) Rect {
	if all_monitors {
		return virtual_screen()
	}
	monitor, _ := monitor_at(cursor)
	return monitor
}

// centered_in devolve o lugar de uma janela do tamanho dado no centro do monitor, que pode começar em coordenada negativa.
fn centered_in(monitor Rect, width int, height int) Rect {
	return Rect{
		x: monitor.x + (monitor.width - width) / 2
		y: monitor.y + (monitor.height - height) / 2
		width: width
		height: height
	}
}
