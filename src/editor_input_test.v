module main

// O ponteiro do mouse é a resposta do editor à pergunta "o que acontece se eu clicar aqui". Os testes daqui olham essa escolha e quem responde por ela: dentro da janela é o editor; na moldura — a borda que redimensiona, o título —, é o Windows.

fn C.SetCursorPos(x int, y int) bool

// still_proc é uma janela que não faz nada: ela existe só para ter um cliente onde o ponteiro possa estar.
fn still_proc(hwnd voidptr, message u32, wparam usize, lparam isize) isize {
	return C.DefWindowProcW(hwnd, message, wparam, lparam)
}

// cursor_editor monta um editor com a imagem no meio da janela e um retângulo desenhado nela.
fn cursor_editor(tool Tool, selected int) Editor {
	return Editor{
		canvas_width: 900
		canvas_height: 600
		view: Rect{
			x: 150
			y: toolbar_height + 50
			width: 600
			height: 400
		}
		scale: 1.0
		tool: tool
		selected: selected
		scene: Scene{
			crop: Rect{
				width: 600
				height: 400
			}
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 100
						y: 100
						width: 200
						height: 150
					}
					thickness: 2
				},
			]
		}
	}
}

// Fora da área de cliente o editor não responde, e a borda fica com as setas de redimensionar que o Windows põe nela. Respondendo por ela, o editor punha o ponteiro do lugar onde o mouse esteve por último — quem viesse da barra encontrava a seta na borda, no lugar da seta dupla. Os códigos são os do Windows: 10 é a borda esquerda, 17 a quina de baixo à direita, 12 a borda de cima e 2 o título.
fn test_fora_do_cliente_o_ponteiro_e_do_windows() {
	editor := cursor_editor(.select, -1)
	// O mouse fica num lugar em que o editor teria resposta — o alto da tela, onde ficaria a barra —, senão não daria para distinguir quem não respondeu por ser moldura de quem não respondeu por não ter ponteiro próprio ali.
	before := cursor_position()
	defer {
		C.SetCursorPos(before.x, before.y)
	}
	C.SetCursorPos(300, 20)
	assert !editor_cursor(unsafe { nil }, &editor, 0, isize(10))
	assert !editor_cursor(unsafe { nil }, &editor, 0, isize(17))
	assert !editor_cursor(unsafe { nil }, &editor, 0, isize(12))
	assert !editor_cursor(unsafe { nil }, &editor, 0, isize(2))
}

// Dentro da área de cliente o editor responde, e responde pelo lugar em que o mouse está agora: o Windows pergunta qual ponteiro usar antes de avisar que o mouse andou, então a última posição que chegou por mensagem está sempre um movimento atrasada. Aqui a posição guardada aponta para a imagem, onde o ponteiro seria o da classe da janela e o editor não responderia, e o mouse de verdade está sobre a barra, onde ele responde a seta.
fn test_o_ponteiro_sai_de_onde_o_mouse_esta_agora() {
	name := 'VShotTestePonteiro'.to_wide()
	instance := C.GetModuleHandleW(unsafe { nil })
	class := C.WNDCLASSW{
		lpfnWndProc: voidptr(still_proc)
		hInstance: instance
		lpszClassName: voidptr(name)
	}
	C.RegisterClassW(&class)
	hwnd := C.CreateWindowExW(ws_ex_toolwindow | ws_ex_noactivate, name, name, ws_popup,
		0, 0, 900, 700, unsafe { nil }, unsafe { nil }, instance, unsafe { nil })
	assert hwnd != unsafe { nil }
	defer {
		C.DestroyWindow(hwnd)
	}
	C.ShowWindow(hwnd, sw_shownoactivate)
	before := cursor_position()
	defer {
		C.SetCursorPos(before.x, before.y)
	}
	mut editor := cursor_editor(.select, -1)
	editor.cursor_x = 600
	editor.cursor_y = toolbar_height + 330
	assert cursor_at(&editor, editor.cursor_x, editor.cursor_y) == none

	C.SetCursorPos(300, 20)
	assert editor_cursor(hwnd, &editor, usize(hwnd), isize(ht_client))
}

// Cada lugar tem o ponteiro do que o clique ali faz: a seta na barra, onde se clica em botão; a cruz na imagem vazia com Selecionar, onde o arrasto recorta; a seta sobre uma marcação, que o clique escolhe; a seta fora da imagem, onde não há o que fazer; e a alça da marcação selecionada diz em que sentido ela estica.
fn test_o_ponteiro_diz_o_que_o_lugar_faz() {
	editor := cursor_editor(.select, -1)
	assert cursor_at(&editor, 300, 10)? == idc_arrow
	// A imagem ocupa, na janela, de 150,94 a 750,494, e o retângulo da cena, de 250,194 a 450,344.
	assert cursor_at(&editor, 600, toolbar_height + 330) == none
	assert cursor_at(&editor, 20, toolbar_height + 300)? == idc_arrow
	assert cursor_at(&editor, 350, toolbar_height + 150)? == idc_arrow

	// Com a marcação escolhida, os mesmos pontos da borda dela viram alças, e cada uma diz em que sentido estica.
	chosen := cursor_editor(.select, 0)
	assert cursor_at(&chosen, 250, toolbar_height + 150)? == cursor_for(.top_left)
	assert cursor_at(&chosen, 350, toolbar_height + 150)? == cursor_for(.top)

	drawing := cursor_editor(.rectangle, -1)
	assert cursor_at(&drawing, 600, toolbar_height + 330) == none
	// Com uma ferramenta de desenho na mão a barra continua com a seta, e não com a cruz: ali se clica em botão, e não se desenha.
	assert cursor_at(&drawing, 300, 10)? == idc_arrow

	writing := cursor_editor(.text, -1)
	assert cursor_at(&writing, 600, toolbar_height + 330)? == idc_ibeam
}
