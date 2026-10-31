module main

fn C.UpdateWindow(hwnd voidptr) bool

fn C.Sleep(milliseconds u32)

// As coordenadas da tela e as da janela de teste têm de ser as físicas, as mesmas da aplicação.
fn testsuite_begin() {
	enable_dpi_awareness()
}

// A janela fica no centro do monitor, também num monitor à esquerda e acima do principal, que começa em coordenada negativa, e num à direita dele.
fn test_a_janela_centra_no_monitor() {
	assert centered_in(Rect{
		x: -1920
		y: -200
		width: 1920
		height: 1080
	}, 1000, 600) == Rect{
		x: -1460
		y: 40
		width: 1000
		height: 600
	}
	assert centered_in(Rect{
		x: 1920
		width: 2560
		height: 1440
	}, 1000, 600) == Rect{
		x: 2700
		y: 420
		width: 1000
		height: 600
	}
}

// Sem a opção, o editor congela só o monitor do ponteiro; com ela, a tela virtual inteira. O monitor principal começa na origem e tem o tamanho que o GetSystemMetrics dá a ele, e um ponto fora de todos os monitores fica com o mais próximo, que está dentro da tela virtual.
fn test_a_area_do_editor_e_o_monitor_do_ponteiro() {
	primary := Rect{
		width: C.GetSystemMetrics(0)
		height: C.GetSystemMetrics(1)
	}
	center := C.POINT{
		x: primary.width / 2
		y: primary.height / 2
	}
	assert editor_capture_area(false, center) == primary
	assert editor_capture_area(true, center) == virtual_screen()
	screen := virtual_screen()
	outside := editor_capture_area(false, C.POINT{
		x: screen.x + screen.width + 5000
		y: center.y
	})
	assert outside.width > 0 && outside.height > 0
	assert outside.x >= screen.x && outside.x + outside.width <= screen.x + screen.width
}

fn plain_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	return C.DefWindowProcW(hwnd, message, wparam, lparam)
}

// A área congelada é a pedida, e não a do canto da tela: uma janela de cor conhecida, posta longe da origem, aparece no congelado deslocada do canto da área, com o pixel de fora dela em outra cor. É o que vale para um monitor fora da origem, que a máquina dos testes pode não ter.
fn test_a_area_congelada_e_a_pedida() ! {
	color := u32(0x00346a1f)
	brush := C.CreateSolidBrush(color)
	defer {
		C.DeleteObject(brush)
	}
	name := 'VShotTesteArea'.to_wide()
	instance := C.GetModuleHandleW(unsafe { nil })
	class := C.WNDCLASSW{
		lpfnWndProc: voidptr(plain_proc)
		hInstance: instance
		hbrBackground: brush
		lpszClassName: voidptr(name)
	}
	C.RegisterClassW(&class)
	hwnd := C.CreateWindowExW(ws_ex_topmost | ws_ex_toolwindow | ws_ex_noactivate, name, name, ws_popup, 300, 200, 120, 80, unsafe { nil }, unsafe { nil }, instance, unsafe { nil })
	assert hwnd != unsafe { nil }
	defer {
		C.DestroyWindow(hwnd)
	}
	C.ShowWindow(hwnd, sw_shownoactivate)
	C.UpdateWindow(hwnd)
	// O DWM compõe a janela na tela um quadro depois de pintada.
	C.Sleep(300)
	frozen := freeze_area(Rect{
		x: 280
		y: 190
		width: 200
		height: 120
	})!
	defer {
		frozen.release()
	}
	assert frozen.left == 280 && frozen.top == 190
	assert frozen.width == 200 && frozen.height == 120
	// A janela começa em 20,10 dentro da área e termina em 139,89; as quinas ficam de fora, porque o Windows pode arredondá-las.
	assert C.GetPixel(frozen.dc, 22, 12) == color
	assert C.GetPixel(frozen.dc, 137, 87) == color
	assert C.GetPixel(frozen.dc, 18, 40) != color
	assert C.GetPixel(frozen.dc, 141, 40) != color
}
