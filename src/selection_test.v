module main

// editor_with monta um editor sem janela nem imagem, só com o suficiente para as contas de
// coordenada: onde a imagem aparece, por quanto ela foi reduzida e o que há na cena.
fn editor_with(shapes []Shape, scale f64) Editor {
	return Editor{
		view: Rect{
			x: 100
			y: 44
			width: 400
			height: 300
		}
		scale: scale
		scene: Scene{
			crop: Rect{
				x: 10
				y: 20
				width: 800
				height: 600
			}
			shapes: shapes
		}
		selected: 0
	}
}

fn sample_shape() Shape {
	return Shape{
		tool: .rectangle
		area: Rect{
			x: 210
			y: 220
			width: 200
			height: 100
		}
		color: annotation_color
		thickness: annotation_width
	}
}

fn test_to_client_desconta_o_recorte_e_a_reducao() {
	editor := editor_with([sample_shape()], 0.5)
	area := editor.to_client(sample_shape().area)
	// (210 - 10) * 0,5 + 100 e (220 - 20) * 0,5 + 44.
	assert area.x == 200
	assert area.y == 144
	assert area.width == 100
	assert area.height == 50
}

fn test_alca_fica_centrada_no_canto() {
	area := Rect{
		x: 200
		y: 100
		width: 100
		height: 50
	}
	corner := handle_rect(area, .bottom_right)
	assert corner.x == 300 - handle_size / 2
	assert corner.y == 150 - handle_size / 2
	side := handle_rect(area, .top)
	assert side.x == 250 - handle_size / 2
	assert side.y == 100 - handle_size / 2
}

fn test_clique_pega_alca_corpo_ou_nada() {
	editor := editor_with([sample_shape()], 0.5)
	// A marcação ocupa de (200, 144) a (300, 194) na janela.
	assert editor.grab_at(300, 194) == .bottom_right
	assert editor.grab_at(250, 144) == .top
	assert editor.grab_at(250, 170) == .body
	assert editor.grab_at(400, 300) == .none
}

fn test_marcacao_mais_acima_ganha_o_clique() {
	mut under := sample_shape()
	mut over := Shape{
		tool: .rectangle
		area: Rect{
			x: 260
			y: 240
			width: 100
			height: 40
		}
		color: annotation_color
		thickness: annotation_width
	}
	editor := editor_with([under, over], 0.5)
	// As duas se sobrepõem em (270, 160) na janela; vence a última da lista, que foi a
	// desenhada por cima.
	assert editor.shape_at(270, 160) == 1
	assert editor.shape_at(210, 150) == 0
	assert editor.shape_at(50, 50) == -1
}

fn test_arrastar_o_corpo_so_desloca() {
	moved := resized(sample_shape().area, .body, 30, -40)
	assert moved.x == 240
	assert moved.y == 180
	assert moved.width == 200
	assert moved.height == 100
}

fn test_cada_alca_move_o_lado_que_lhe_cabe() {
	area := sample_shape().area
	right := resized(area, .right, 50, 999)
	assert right.x == 210
	assert right.y == 220
	assert right.width == 250
	// A alça do meio da direita não mexe na altura, por mais que o mouse suba ou desça.
	assert right.height == 100

	top_left := resized(area, .top_left, 10, 20)
	assert top_left.x == 220
	assert top_left.y == 240
	assert top_left.width == 190
	assert top_left.height == 80
}

fn test_atravessar_o_lado_oposto_nao_inverte_a_marcacao() {
	// A alça da esquerda arrastada 300 para a direita passa da borda direita, que está a 200.
	flipped := resized(sample_shape().area, .left, 300, 0)
	assert flipped.x == 410
	assert flipped.width == 100
	assert flipped.height == 100
}

fn test_ponteiro_indica_o_sentido_da_alca() {
	assert cursor_for(.top_left) == cursor_for(.bottom_right)
	assert cursor_for(.top) == cursor_for(.bottom)
	assert cursor_for(.body) == idc_sizeall
	assert cursor_for(.none) == idc_arrow
}

// blank_image devolve uma superfície do tamanho pedido. O conteúdo não importa aqui: o
// que se confere é a marcação que volta à cena, não os pixels.
fn blank_image(size int) !Frozen {
	screen_dc := C.GetDC(unsafe { nil })
	defer {
		C.ReleaseDC(unsafe { nil }, screen_dc)
	}
	return new_surface(screen_dc, size, size)!
}

// O mesmo vale para o arrasto: mover a marcação muda a geometria e nada mais. Este usa
// uma imagem de verdade porque `finish_grab` remonta a imagem de trabalho, e sem ela a
// remontagem falharia e a cena voltaria ao estado anterior sem nunca testar nada.
fn test_mover_preserva_o_estilo() {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	source := blank_image(60)!
	defer {
		source.release()
	}
	mark := Shape{
		tool: .rectangle
		area: Rect{
			x: 10
			y: 10
			width: 20
			height: 20
		}
		color: annotation_color
		thickness: 7
		style: Style{
			rounded: true
			filled: true
		}
	}
	mut editor := Editor{
		source: source
		canvas_width: 60
		canvas_height: 60
		scene: Scene{
			crop: Rect{
				width: source.width
				height: source.height
			}
			shapes: [mark]
		}
		selected: 0
		tool: .select
	}
	defer {
		editor.current.release()
	}
	editor.apply()!
	assert editor.scale == 1.0

	// Como no start_grab: a cena é guardada antes de a marcação sair dela.
	editor.record()
	editor.grabbed = mark
	editor.scene.shapes.delete(0)
	editor.grab = .body
	editor.cursor_x = 5
	assert editor.finish_grab() == 'Marcação movida'

	moved := editor.scene.shapes[0]
	assert moved.area.x == 15
	assert moved.thickness == 7
	assert moved.style.rounded && moved.style.filled
	assert moved.color == annotation_color
}

// Com zoom, uma linha, seta ou régua passa de mil pixels na janela: o acerto não pode estourar a conta nem perder precisão no traço longo.
fn test_acerto_no_traco_longo() {
	assert near_segment(0, 100, 1941, 100, 1500, 103, 6)
	assert near_segment(0, 100, 15360, 100, 12000, 105, 6)
	assert near_segment(0, 0, 12000, 9000, 8000, 6000, 6)
	assert !near_segment(0, 100, 15360, 100, 12000, 107, 6)
}
