module main

// A janela do editor deixou de ser fixa: a borda se arrasta e o botão de maximizar a estende pelo monitor. Os testes daqui olham o que isso exige — o tamanho com que ela abre, o menor tamanho que ela aceita, o espaço refeito a cada mudança com as superfícies no tamanho novo, e o gesto em curso encerrado com o mouse devolvido.

// GR_GDIOBJECTS conta os objetos do GDI que o processo tem abertos: é por ele que um vazamento aparece.
fn C.GetGuiResources(process voidptr, flags u32) u32

const gr_gdiobjects = u32(0)

fn C.SetPixel(hdc voidptr, x int, y int, color u32) u32

fn quiet_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	return C.DefWindowProcW(hwnd, message, wparam, lparam)
}

// canvas_editor monta um editor sobre uma captura de tamanho conhecido, num cliente de tamanho dado e com as duas superfícies que a janela usa, como o open_editor faria.
fn canvas_editor(image_width int, image_height int, width int, height int) !Editor {
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, image_width, image_height)!
	C.ReleaseDC(unsafe { nil }, screen)
	mut editor := Editor{
		source: source
		canvas_width: width
		canvas_height: height - toolbar_height
		scene: Scene{
			crop: Rect{
				width: image_width
				height: image_height
			}
		}
		selected: -1
	}
	editor.apply()!
	editor.background = new_surface(source.dc, width, height)!
	editor.buffer = new_surface(source.dc, width, height)!
	return editor
}

// release_surfaces devolve tudo que o editor de teste criou, para uma rodada da suíte não deixar dezenas de bitmaps do tamanho da janela para trás.
fn (mut e Editor) release_surfaces() {
	e.source.release()
	e.current.release()
	e.background.release()
	e.buffer.release()
}

// A janela não pode encolher abaixo do que a barra precisa: na largura mínima os três blocos da direita ainda cabem. O que o Windows recebe é o tamanho de fora, com a moldura somada ao cliente, e a moldura vem do estilo — com a borda grossa ela é maior que com a borda fina, e quem responder o mínimo da borda fina deixaria a janela encolher abaixo do que a barra exige.
fn test_a_janela_tem_um_minimo_que_cabe_a_barra() {
	assert editor_style & ws_thickframe != 0
	assert editor_style & ws_maximizebox != 0
	width, height := editor_min_size(editor_style)
	assert width > min_client_width
	assert height > toolbar_height + min_canvas_height
	// Uma moldura de janela com título não passa de cem pixels em cada sentido.
	assert width - min_client_width < 100
	assert height - toolbar_height - min_canvas_height < 100
	thin_width, thin_height := editor_min_size(ws_caption | ws_sysmenu)
	assert thin_width < width
	assert thin_height < height
	assert picker_rect(min_client_width) != none
}

// O mínimo vai no campo que o Windows lê, ptMinTrackSize, e os outros continuam como estavam: escrito no campo errado, ele não limitaria nada, e a janela encolheria até a barra sumir.
fn test_o_minimo_vai_no_campo_que_o_windows_le() {
	mut info := C.MINMAXINFO{}
	limit_editor_size(isize(voidptr(&info)))
	width, height := editor_min_size(editor_style)
	_, work := monitor_at(cursor_position())
	assert info.ptMinTrackSize.x == min(width, work.width)
	assert info.ptMinTrackSize.y == min(height, work.height)
	assert info.ptMaxTrackSize.x == 0
	assert info.ptMaxSize.x == 0
}

// O tamanho de abertura mantém o mínimo da barra quando cabe e usa toda a área útil quando precisa reduzir a imagem.
fn test_o_tamanho_de_abertura_respeita_o_minimo() {
	monitor := Rect{
		width: 1920
		height: 1080
	}
	narrow_width, narrow_height := editor_open_size(1600, 150, monitor)
	assert narrow_width == 1600
	assert narrow_height == min_canvas_height
	small_width, small_height := editor_open_size(300, 200, monitor)
	assert small_width == min_client_width
	assert small_height == min_canvas_height
	big_width, big_height := editor_open_size(3840, 2160, monitor)
	outer_width, outer_height := editor_min_size(editor_style)
	assert big_width + outer_width - min_client_width <= monitor.width
	assert big_height + outer_height - min_canvas_height <= monitor.height
	assert big_width >= min_client_width
}

fn test_abertura_em_cem_por_cento_quando_cabe_na_area_util() {
	work := Rect{-1920, 30, 1920, 1010}
	width, height := editor_open_size(1800, 900, work)
	assert width == 1800
	assert height == 900
	assert fit_within(1800, 900, width, height) == 1.0
	outer_width, outer_height := editor_min_size(editor_style)
	place := centered_in(work, width + outer_width - min_client_width, height + outer_height - min_canvas_height)
	assert place.x >= work.x
	assert place.y >= work.y
	assert place.x + place.width <= work.x + work.width
	assert place.y + place.height <= work.y + work.height
}

fn test_imagem_grande_usa_o_maximo_disponivel() {
	work := Rect{0, 0, 1920, 1040}
	width, height := editor_open_size(3840, 2160, work)
	outer_width, outer_height := editor_min_size(editor_style)
	limit_width := work.width - (outer_width - min_client_width)
	limit_height := work.height - (outer_height - min_canvas_height)
	assert width == limit_width || height == limit_height
	assert fit_within(3840, 2160, width, height) > 0.4
	// Mesmo um monitor menor que o mínimo habitual deve conter a janela inteira.
	small_width, small_height := editor_open_size(1600, 1200, Rect{0, 0, 1024, 720})
	assert small_width + outer_width - min_client_width <= 1024
	assert small_height + outer_height - min_canvas_height <= 720
}

fn test_arrastar_ponta_respeita_escala_e_historico() ! {
	token := start_gdiplus()!
	defer { stop_gdiplus(token) }
	mut editor := canvas_editor(800, 600, 400, toolbar_height + 300)!
	defer { editor.release_surfaces() }
	shape := Shape{tool: .arrow, area: Rect{100, 100, 200, 100}, thickness: 3}
	editor.add_shape(shape)
	editor.origin_x = 150
	editor.origin_y = toolbar_height + 100
	editor.cursor_x = 175
	editor.cursor_y = toolbar_height + 140
	editor.start_grab(.line_end, false)
	editor.finish_grab()
	moved := editor.scene.shapes[0]
	x1, y1, x2, y2 := line_ends(moved.area, moved.origin)
	assert [x1, y1, x2, y2] == [100, 100, 350, 280]
	editor.undo()
	assert editor.scene.shapes[0] == shape
	editor.redo()
	assert editor.scene.shapes[0] == moved
}

// Redimensionar refaz o espaço da imagem e as duas superfícies no tamanho do cliente, recoloca a imagem no meio dele e solta as superfícies antigas. Sem as novas, a composição sairia recortada pelo bitmap antigo; sem soltar as velhas, arrastar a borda vazaria dois DCs e dois bitmaps do tamanho da janela por movimento do mouse.
fn test_redimensionar_refaz_o_espaco_e_as_superficies() ! {
	mut editor := canvas_editor(400, 200, 600, toolbar_height + 300)!
	defer {
		editor.release_surfaces()
	}
	assert editor.view == Rect{
		x: 100
		y: toolbar_height + 50
		width: 400
		height: 200
	}
	editor.background_ready = true
	objects := C.GetGuiResources(C.GetCurrentProcess(), gr_gdiobjects)
	assert objects > 0

	assert editor.resize_canvas(1000, toolbar_height + 800)
	assert editor.canvas_width == 1000
	assert editor.canvas_height == 800
	assert editor.background.width == 1000
	assert editor.background.height == toolbar_height + 800
	assert editor.buffer.width == 1000
	assert editor.buffer.height == toolbar_height + 800
	assert !editor.background_ready
	assert editor.view == Rect{
		x: 300
		y: toolbar_height + 300
		width: 400
		height: 200
	}
	// Duas superfícies novas nasceram e duas velhas saíram: a conta de objetos do GDI do processo volta ao que era. Sem soltar as velhas, arrastar a borda vazaria dois DCs e dois bitmaps por movimento do mouse.
	assert C.GetGuiResources(C.GetCurrentProcess(), gr_gdiobjects) == objects
}

// Minimizar chega com o cliente zerado, e o mesmo tamanho de novo — que é o que a janela manda ao ser mostrada — não refaz nada e nem toca no gesto em curso: um Win+M no meio de um arrasto guardaria a marcação sem que nada tivesse mudado de tamanho.
fn test_o_cliente_zerado_e_o_mesmo_tamanho_nao_refazem_nada() ! {
	mut editor := canvas_editor(400, 200, 600, toolbar_height + 300)!
	defer {
		editor.release_surfaces()
	}
	before := editor.background
	assert !editor.resize_canvas(0, 0)
	assert !editor.resize_canvas(600, toolbar_height)
	assert !editor.resize_canvas(600, toolbar_height + 300)
	assert editor.canvas_width == 600
	assert editor.canvas_height == 300
	assert editor.background.dc == before.dc

	editor.dragging = true
	editor_resized(unsafe { nil }, mut editor, 0, 0)
	assert editor.dragging
	assert editor.scene.shapes.len == 0
	editor.dragging = false
}

// Redimensionar no meio de um arrasto encerra o arrasto onde ele estava, como quando outra janela toma o mouse: o traço em curso guarda pixels da janela, e a vista mudando debaixo dele o deixaria escorregado em relação à imagem.
fn test_redimensionar_no_meio_de_um_gesto_encerra_o_gesto() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	mut editor := canvas_editor(400, 200, 600, toolbar_height + 300)!
	defer {
		editor.release_surfaces()
	}
	editor.tool = .rectangle
	editor.dragging = true
	editor.sliding = true
	editor.origin_x = 150
	editor.origin_y = toolbar_height + 20
	editor.cursor_x = 300
	editor.cursor_y = toolbar_height + 120

	editor_resized(unsafe { nil }, mut editor, 1000, toolbar_height + 800)
	assert !editor.dragging
	assert !editor.sliding
	assert editor.scene.shapes.len == 1
	assert editor.canvas_width == 1000
}

// Com a imagem sendo arrastada pelo botão direito, redimensionar encerra o arrasto e devolve o mouse. O encerramento é o mesmo de quando outra janela toma o mouse, e lá ele já estava perdido; aqui ele ainda é da janela, e sem devolvê-lo o editor receberia todo clique da área de trabalho, em coordenadas do cliente dele.
fn test_redimensionar_devolve_o_mouse() ! {
	name := 'VShotTesteTamanho'.to_wide()
	instance := C.GetModuleHandleW(unsafe { nil })
	class := C.WNDCLASSW{
		lpfnWndProc: voidptr(quiet_proc)
		hInstance: instance
		lpszClassName: voidptr(name)
	}
	C.RegisterClassW(&class)
	hwnd := C.CreateWindowExW(ws_ex_toolwindow | ws_ex_noactivate, name, name, ws_popup,
		0, 0, 200, 200, unsafe { nil }, unsafe { nil }, instance, unsafe { nil })
	assert hwnd != unsafe { nil }
	defer {
		C.DestroyWindow(hwnd)
	}
	C.ShowWindow(hwnd, sw_shownoactivate)
	mut editor := canvas_editor(400, 200, 600, toolbar_height + 300)!
	defer {
		editor.release_surfaces()
	}
	editor.panning = true
	C.SetCapture(hwnd)
	assert C.GetCapture() == hwnd

	editor_resized(hwnd, mut editor, 1000, toolbar_height + 800)
	assert !editor.panning
	assert C.GetCapture() != hwnd
	// O arrasto da imagem não desenha nada: ele só move a vista.
	assert editor.scene.shapes.len == 0
	assert editor.canvas_width == 1000
}

// A imagem só é refeita quando ela ou a vista mudam: um botão aceso refaz a barra, e a redução da imagem inteira fica como estava. Quando a vista muda, ela é refeita.
fn test_a_barra_se_refaz_sem_reduzir_a_imagem_de_novo() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	mut editor := canvas_editor(300, 200, 900, 600)!
	defer {
		editor.release_surfaces()
	}
	editor.compose_background()
	assert editor.canvas_ready
	spot_x := editor.view.x + 10
	spot_y := editor.view.y + 10
	// Uma marca na composição: se a imagem fosse reduzida de novo, ela sumiria.
	C.SetPixel(editor.background.dc, spot_x, spot_y, 0x00123456)
	editor.status = 'outra mensagem'
	editor.compose_background()
	assert C.GetPixel(editor.background.dc, spot_x, spot_y) == 0x00123456
	editor.layout()
	assert !editor.canvas_ready
	editor.compose_background()
	assert C.GetPixel(editor.background.dc, spot_x, spot_y) != 0x00123456
}

// Quando só a barra vai para a tela, a prévia e os painéis não são desenhados, porque não apareceriam: o que há abaixo da barra no quadro em preparo fica intacto. Na janela inteira eles vêm.
fn test_repintar_so_a_barra_nao_desenha_o_que_fica_abaixo_dela() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	mut editor := canvas_editor(300, 200, 900, 600)!
	defer {
		editor.release_surfaces()
	}
	editor.tool = .rectangle
	target := new_surface(editor.source.dc, 900, 600)!
	defer {
		target.release()
	}
	panel := editor.options_panel()?
	spot_x := panel.x + panel.width / 2
	spot_y := panel.y + panel.height / 2
	C.SetPixel(editor.buffer.dc, spot_x, spot_y, 0x00123456)
	paint_editor(target.dc, mut editor, C.RECT{
		right: 100
		bottom: toolbar_height
	})
	assert C.GetPixel(editor.buffer.dc, spot_x, spot_y) == 0x00123456
	paint_editor(target.dc, mut editor, C.RECT{
		right: 900
		bottom: 600
	})
	assert C.GetPixel(editor.buffer.dc, spot_x, spot_y) != 0x00123456
}
