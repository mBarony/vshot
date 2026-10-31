module main

// Redimensionar muda o tamanho do resultado sem mexer na geometria guardada: as marcações
// continuam em coordenadas da captura, e o fator entra no caminho até a janela. Os testes
// daqui olham esse caminho nas duas direções, o histórico, e os pixels que saem.

// sized_editor monta um editor sobre uma captura branca de 200 por 100, sem janela.
fn sized_editor() !Editor {
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, 200, 100)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(source.dc, Rect{
		width: 200
		height: 100
	}, 0x00ffffff)
	mut editor := Editor{
		source: source
		tool: .rectangle
		color: annotation_color
		thickness: annotation_width
		canvas_width: 900
		canvas_height: 700
		scene: Scene{
			crop: Rect{
				width: 200
				height: 100
			}
		}
		selected: -1
	}
	editor.apply()!
	return editor
}

// Os índices dos fatores, para os testes lerem como a barra lê.
const half = 2
const unit_factor = 3
const double = 4

// Uma cena nova está em tamanho natural, e a cópia do histórico leva o fator junto.
fn test_a_cena_comeca_em_tamanho_natural() {
	assert Scene{}.factor == 1.0
	scene := Scene{
		factor: 0.5
	}
	assert scene.clone().factor == 0.5
	assert resize_labels.len == resize_factors.len
	assert resize_factors[unit_factor] == 1.0
}

// Escolher um fator muda o tamanho da imagem de trabalho, e desfazer volta.
fn test_redimensionar_se_desfaz() ! {
	mut editor := sized_editor()!
	assert editor.apply_resize(half) == 'Imagem em 50%: 100x50px'
	assert editor.current.width == 100
	assert editor.current.height == 50
	assert editor.past.len == 1
	editor.undo()
	assert editor.scene.factor == 1.0
	assert editor.current.width == 200
	editor.redo()
	assert editor.current.width == 100
}

// Escolher o fator em que a imagem já está não é edição.
fn test_o_mesmo_fator_nao_entra_no_historico() ! {
	mut editor := sized_editor()!
	editor.apply_resize(unit_factor)
	assert editor.past.len == 0
	editor.apply_resize(double)
	editor.apply_resize(double)
	assert editor.past.len == 1
}

// Uma edição feita depois de redimensionar, desfeita, não leva o tamanho junto. É o que
// quebraria se a cópia do histórico esquecesse o fator.
fn test_desfazer_outra_coisa_mantem_o_tamanho() ! {
	mut editor := sized_editor()!
	editor.apply_resize(half)
	editor.record()
	editor.scene.shapes << Shape{
		tool: .rectangle
		area: Rect{
			x: 10
			y: 10
			width: 20
			height: 20
		}
	}
	editor.apply()!
	editor.undo()
	assert editor.scene.factor == 0.5
	assert editor.current.width == 100
}

// O fator entra no caminho da captura até a janela, e a volta desfaz a ida.
fn test_o_fator_entra_nas_duas_pontas_da_conversao() ! {
	for index in [half, double] {
		mut editor := sized_editor()!
		editor.apply_resize(index)
		spot := Rect{
			x: 40
			y: 30
			width: 20
			height: 10
		}
		client := editor.to_client(spot)
		back := editor.to_source(editor.to_image(client))
		assert back == spot, resize_labels[index]
		point := editor.to_source_point(client.x, client.y)
		assert point.x == spot.x && point.y == spot.y, resize_labels[index]
	}
}

// Um retângulo desenhado sobre a imagem ampliada cai no lugar certo da captura.
fn test_desenhar_na_imagem_ampliada_guarda_na_captura() ! {
	mut editor := sized_editor()!
	editor.apply_resize(double)
	target := Rect{
		x: 20
		y: 30
		width: 40
		height: 20
	}
	client := editor.to_client(target)
	editor.origin_x = client.x
	editor.origin_y = client.y
	editor.cursor_x = client.x + client.width
	editor.cursor_y = client.y + client.height
	editor.finish_drag()
	assert editor.scene.shapes.last().area == target
}

// Com moldura, o tamanho vale para a imagem pronta: a moldura cresce junto.
fn test_a_moldura_redimensiona_junto() ! {
	mut editor := sized_editor()!
	editor.choose(.backdrop)
	margin := editor.margin()
	editor.apply_resize(half)
	assert editor.current.width == scaled_side(200 + 2 * margin, 0.5)
	assert editor.current.height == scaled_side(100 + 2 * margin, 0.5)
}

// A imagem ampliada guarda as cores no lugar: o que era esquerda continua à esquerda.
fn test_ampliar_guarda_as_cores_no_lugar() ! {
	screen := C.GetDC(unsafe { nil })
	image := new_surface(screen, 40, 20)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(image.dc, Rect{
		width: 20
		height: 20
	}, 0x000000ff)
	paint_rect(image.dc, Rect{
		x: 20
		width: 20
		height: 20
	}, 0x00ff0000)
	bigger := scaled_to(image, 2.0)!
	defer {
		bigger.release()
	}
	assert bigger.width == 80 && bigger.height == 40
	assert C.GetPixel(bigger.dc, 5, 20) == 0x000000ff
	assert C.GetPixel(bigger.dc, 75, 20) == 0x00ff0000
}

// No fator um não há cópia: a própria imagem volta.
fn test_fator_um_nao_copia() ! {
	screen := C.GetDC(unsafe { nil })
	image := new_surface(screen, 10, 10)!
	C.ReleaseDC(unsafe { nil }, screen)
	same := scaled_to(image, 1.0)!
	defer {
		same.release()
	}
	assert same.dc == image.dc
}

// O painel só existe aberto, fica inteiro dentro do editor, e cada botão responde pelo
// fator dele — o vão entre dois botões não escolhe nada.
fn test_o_painel_e_seus_botoes() {
	mut editor := Editor{
		canvas_width: min_client_width
		canvas_height: 600
		selected: -1
	}
	assert editor.resize_panel() == none
	editor.popover = .resize
	panel := editor.resize_panel() or { panic('o painel deveria abrir') }
	assert panel.x >= options_margin
	assert panel.x + panel.width <= editor.canvas_width - options_margin
	for index in 0 .. resize_factors.len {
		button := resize_button_rect(panel, index)
		assert button.x + button.width <= panel.x + panel.width - resize_padding + 1
		assert editor.resize_choice_at(button.x + button.width / 2, button.y + button.height / 2)? == index
	}
	first := resize_button_rect(panel, 0)
	assert editor.resize_choice_at(first.x + first.width + resize_gap / 2, first.y + 5) == none
}

// O bloco do tamanho fica logo à direita do bloco da cor, e some com ele.
fn test_o_bloco_do_tamanho_segue_o_da_cor() {
	colour := picker_rect(min_client_width) or { panic('a janela mínima tem os blocos') }
	size := size_rect(min_client_width) or { panic('a janela mínima tem os blocos') }
	assert size.x == colour.x + status_color_width
	assert size_rect(toolbar_tools_width() + status_block_width - 1) == none
}

// Com o painel de redimensionar aberto, o de opções cede o canto.
fn test_o_painel_de_opcoes_cede_o_canto() {
	mut editor := Editor{
		canvas_width: min_client_width
		canvas_height: 600
		tool: .rectangle
		selected: -1
	}
	assert editor.options_panel() != none
	editor.popover = .resize
	assert editor.options_panel() == none
}
