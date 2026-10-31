module main

import math

// O zoom é da vista: ele não muda a cena, mas muda todo o caminho entre a imagem e a
// janela. Os testes olham esse caminho — o ponto que fica parado sob a roda, os limites do
// deslocamento, e a ida e volta das conversões com a imagem ampliada e deslocada.

// zoom_editor monta um editor sobre uma captura de 400 por 200 numa área de 600 por 300,
// onde ela cabe sem redução: em 2× ela passa das duas medidas e pode andar para os quatro
// lados.
fn zoom_editor() !Editor {
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, 400, 200)!
	C.ReleaseDC(unsafe { nil }, screen)
	mut editor := Editor{
		source: source
		tool: .rectangle
		color: annotation_color
		thickness: annotation_width
		canvas_width: 600
		canvas_height: 300
		scene: Scene{
			crop: Rect{
				width: 400
				height: 200
			}
		}
		selected: -1
	}
	editor.apply()!
	return editor
}

// Uma imagem menor que o espaço fica centrada; uma maior anda até a borda, e não além.
fn test_o_deslocamento_tem_limites() {
	assert clamp_pan(50, 300, 600) == 0
	assert clamp_pan(50, 800, 600) == 50
	assert clamp_pan(500, 800, 600) == 100
	assert clamp_pan(-500, 800, 600) == -100
}

// O zoom não passa de caber na janela para baixo, nem da ampliação máxima para cima.
fn test_o_zoom_tem_limites() ! {
	mut editor := zoom_editor()!
	editor.zoom_by(-1)
	assert editor.zoom == 1.0
	for _ in 0 .. 40 {
		editor.zoom_by(1)
	}
	assert math.abs(editor.scale - max_display_scale) < 0.001
}

// O ponto da imagem sob a roda fica parado: é o que leva ao detalhe em vez de ao centro.
fn test_a_roda_mantem_o_ponto_sob_o_ponteiro() ! {
	mut editor := zoom_editor()!
	anchor_x := editor.view.x + 300
	anchor_y := editor.view.y + 150
	before := editor.to_image(Rect{
		x: anchor_x
		y: anchor_y
	})
	editor.zoom_at(2.0, anchor_x, anchor_y)
	assert editor.scale == 2.0
	after := editor.to_image(Rect{
		x: anchor_x
		y: anchor_y
	})
	assert math.abs(after.x - before.x) <= 1
	assert math.abs(after.y - before.y) <= 1
}

// Tamanho real é um pixel da imagem para um da janela, e a imagem inteira volta ao começo.
fn test_tamanho_real_e_imagem_inteira() ! {
	mut editor := zoom_editor()!
	editor.zoom_by(1)
	editor.zoom_by(1)
	editor.pan_by(-80, 0)
	editor.zoom_actual()
	assert editor.scale == 1.0
	editor.zoom_fit()
	assert editor.zoom == 1.0
	assert editor.pan_x == 0 && editor.pan_y == 0
}

// Com a imagem ampliada e deslocada, ir da captura à janela e voltar devolve o mesmo ponto.
fn test_a_conversao_vale_ampliada_e_deslocada() ! {
	mut editor := zoom_editor()!
	editor.zoom_at(2.0, editor.view.x + 100, editor.view.y + 50)
	editor.pan_by(37, 0)
	spot := Rect{
		x: 150
		y: 70
		width: 40
		height: 20
	}
	back := editor.to_source(editor.to_image(editor.to_client(spot)))
	assert back == spot
	client := editor.to_client(spot)
	point := editor.to_source_point(client.x, client.y)
	assert point.x == spot.x && point.y == spot.y
}

// Arrastar só anda quando há para onde: uma imagem que cabe não sai do centro.
fn test_arrastar_so_anda_quando_ha_para_onde() ! {
	mut editor := zoom_editor()!
	assert !editor.pan_by(40, 40)
	editor.zoom_at(2.0, 300, 200)
	x := editor.view.x
	assert editor.pan_by(-30, 0)
	assert editor.view.x == x - 30
	// Arrastada além do limite, ela para com a borda encostada na borda da área.
	editor.pan_by(-1000, 0)
	assert editor.view.x + editor.view.width == editor.canvas_width
}

// Aproximar a marcação escolhida a põe no meio, ocupando quase toda a área visível.
fn test_aproximar_a_marcacao_escolhida() ! {
	mut editor := zoom_editor()!
	editor.scene.shapes << Shape{
		tool: .rectangle
		area: Rect{
			x: 150
			y: 60
			width: 200
			height: 80
		}
	}
	editor.selected = 0
	editor.zoom_selection()
	box := editor.to_client(editor.scene.shapes[0].area)
	middle_x, middle_y := editor.canvas_middle()
	assert math.abs(box.x + box.width / 2 - middle_x) <= 2
	assert math.abs(box.y + box.height / 2 - middle_y) <= 2
	// Uma marcação mais achatada que a área visível é presa pela largura.
	assert math.abs(f64(box.width) - f64(editor.canvas_width) * focus_fill) <= 2
}

// Sem marcação escolhida, aproximar dela não muda nada.
fn test_sem_escolha_nao_ha_o_que_aproximar() ! {
	mut editor := zoom_editor()!
	assert editor.zoom_selection() == 'Escolha uma marcação para aproximar dela'
	assert editor.zoom == 1.0
}

// O zoom sobrevive às edições: aplicar a cena de novo não o desfaz.
fn test_o_zoom_sobrevive_as_edicoes() ! {
	mut editor := zoom_editor()!
	editor.zoom_at(2.0, 300, 200)
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
	assert editor.scale == 2.0
	editor.undo()
	assert editor.scale == 2.0
}

// As teclas com Ctrl: mais, menos, zero, um e dois; as demais não são do zoom.
fn test_as_teclas_do_zoom() ! {
	mut editor := zoom_editor()!
	assert editor.zoom_key(vk_oem_plus) != none
	assert editor.zoom > 1.0
	assert editor.zoom_key(0x30) != none
	assert editor.zoom == 1.0
	assert editor.zoom_key(0x31) != none
	assert editor.zoom_key(u32(0x41)) == none
}

// Cada bloco da barra abre o painel dele, e o painel do zoom tem os dois botões.
fn test_os_blocos_abrem_os_paineis() {
	size := size_rect(min_client_width) or { panic('a janela mínima tem os blocos') }
	zoom := zoom_rect(min_client_width) or { panic('a janela mínima tem os blocos') }
	assert zoom.x == size.x + status_size_width
	assert popover_at(min_client_width, size.x + 5, 20)? == Popover.resize
	assert popover_at(min_client_width, zoom.x + 5, 20)? == Popover.zoom
	assert popover_at(min_client_width, 5, 20) == none

	mut editor := Editor{
		canvas_width: min_client_width
		canvas_height: 600
		tool: .rectangle
		selected: -1
		popover: .zoom
	}
	panel := editor.zoom_panel() or { panic('o painel deveria abrir') }
	assert panel.x + panel.width <= editor.canvas_width - options_margin
	assert editor.resize_panel() == none
	assert editor.options_panel() == none
	minus := zoom_button_rect(panel, -1)
	plus := zoom_button_rect(panel, 1)
	assert editor.zoom_button_at(minus.x + 5, minus.y + 5)? == -1
	assert editor.zoom_button_at(plus.x + 5, plus.y + 5)? == 1
	assert editor.zoom_button_at(panel.x + panel.width / 2, minus.y + 5) == none
}

// O giro da roda vem com sinal na palavra alta: para longe de quem usa é positivo.
fn test_o_giro_da_roda_tem_sinal() {
	assert wheel_delta(usize(120) << 16) == 120
	assert wheel_delta(usize(0xff88) << 16) == -120
	assert wheel_delta((usize(240) << 16) | 0x0008) == 240
}

// A mesma conta na geometria da janela real, onde a imagem aparece reduzida: 1280 por 800
// numa área de 1250 por 636, cinco passos de roda com o ponteiro no mesmo lugar. No primeiro
// passo a imagem mal passa da área e o deslocamento é preso na borda, então o ponto escapa;
// nos seguintes ele tem de voltar, e não ficar onde escapou. Foi o que a janela real
// mostrou antes de o ponto mirado ser guardado: o erro do primeiro passo virava o alvo dos
// seguintes, e o canto do retângulo terminava a cento e dez pixels do ponteiro.
fn test_a_roda_mantem_o_ponto_com_a_imagem_reduzida() ! {
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, 1280, 800)!
	C.ReleaseDC(unsafe { nil }, screen)
	mut editor := Editor{
		source: source
		canvas_width: 1250
		canvas_height: 636
		scene: Scene{
			crop: Rect{
				width: 1280
				height: 800
			}
		}
		selected: -1
	}
	editor.apply()!
	anchor_x := 401
	anchor_y := 301
	start := editor.to_image(Rect{
		x: anchor_x
		y: anchor_y
	})
	editor.zoom_at(editor.zoom * zoom_step, anchor_x, anchor_y)
	first := editor.to_image(Rect{
		x: anchor_x
		y: anchor_y
	})
	// A borda prende o primeiro passo.
	assert first.x != start.x
	for _ in 2 .. 6 {
		editor.zoom_at(editor.zoom * zoom_step, anchor_x, anchor_y)
	}
	now := editor.to_image(Rect{
		x: anchor_x
		y: anchor_y
	})
	assert math.abs(now.x - start.x) <= 1, 'x ${start.x} virou ${now.x}'
	assert math.abs(now.y - start.y) <= 1, 'y ${start.y} virou ${now.y}'
}

// Depois de arrastar a imagem, a roda mira o que está sob o ponteiro agora, e não o ponto
// guardado de antes do arrasto.
fn test_arrastar_esquece_o_ponto_mirado() ! {
	mut editor := zoom_editor()!
	editor.zoom_at(2.0, 300, 200)
	editor.pan_by(-50, 0)
	before := editor.to_image(Rect{
		x: 300
		y: 200
	})
	editor.zoom_at(editor.zoom * zoom_step, 300, 200)
	after := editor.to_image(Rect{
		x: 300
		y: 200
	})
	assert math.abs(after.x - before.x) <= 1
	assert math.abs(after.y - before.y) <= 1
}

// O redimensionamento da janela respeita o que o usuário escolheu: quem estava com a imagem inteira à vista continua com ela no espaço novo, e quem tinha escolhido uma escala — o tamanho real — fica com a mesma escala, e não com a mesma proporção do encaixe, para a porcentagem na barra não mudar sozinha.
fn test_o_encaixe_e_a_escala_escolhida_sobrevivem_ao_redimensionamento() ! {
	mut editor := zoom_editor()!
	defer {
		editor.source.release()
		editor.current.release()
		editor.background.release()
		editor.buffer.release()
	}
	assert editor.zoom == 1.0
	assert editor.resize_canvas(300, toolbar_height + 200)
	assert editor.zoom == 1.0
	assert math.abs(editor.scale - 0.75) < 0.001
	assert math.abs(editor.scale - editor.fit_scale()) < 0.001

	editor.zoom_actual()
	assert math.abs(editor.scale - 1.0) < 0.001
	assert editor.resize_canvas(200, toolbar_height + 150)
	assert math.abs(editor.fit_scale() - 0.5) < 0.001
	assert math.abs(editor.scale - 1.0) < 0.001
	assert editor.canvas_width == 200
}

// Crescendo o espaço, uma escala escolhida que fique abaixo do encaixe novo não sobrevive, e nem tem como: o editor não mostra a imagem menor do que cabendo inteira. É o que acontece ao maximizar com a imagem afastada, e o que o zoom já fazia a cada recorte.
fn test_a_escala_abaixo_do_encaixe_volta_ao_encaixe() ! {
	mut editor := zoom_editor()!
	defer {
		editor.source.release()
		editor.current.release()
		editor.background.release()
		editor.buffer.release()
	}
	assert editor.resize_canvas(300, toolbar_height + 200)
	editor.zoom_by(1)
	assert editor.zoom > 1.0
	assert math.abs(editor.scale - 0.9375) < 0.001

	assert editor.resize_canvas(900, toolbar_height + 600)
	assert math.abs(editor.fit_scale() - 1.0) < 0.001
	assert editor.zoom == 1.0
	assert math.abs(editor.scale - 1.0) < 0.001
}
