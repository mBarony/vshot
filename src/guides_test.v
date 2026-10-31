module main

// As guias de alinhamento: o encaixe só ao alcance, uma guia por posição que coincide, o encaixe ao mover, esticar e criar, e o tracejado na tela.

// guide_box monta uma caixa em uma linha, para os casos caberem na leitura.
fn guide_box(x int, y int, width int, height int) Rect {
	return Rect{
		x:      x
		y:      y
		width:  width
		height: height
	}
}

// A outra caixa dos testes: esquerda 100, centro 140 e direita 180; topo 300, meio 320 e base 340.
const other_box = Rect{
	x:      100
	y:      300
	width:  80
	height: 40
}

// Perto de um alinhamento — pela esquerda, pelo centro ou pela direita —, a caixa movida encaixa nele; longe de todos, ela fica onde o mouse a pôs.
fn test_perto_do_alinhamento_a_caixa_encaixa() {
	assert snapped(guide_box(103, 50, 50, 30), [other_box], 5).x == 100, 'esquerda'
	assert snapped(guide_box(113, 50, 50, 30), [other_box], 5).x == 115, 'centro'
	assert snapped(guide_box(128, 50, 50, 30), [other_box], 5).x == 130, 'direita'
	assert snapped(guide_box(150, 50, 50, 30), [other_box], 5).x == 150, 'longe'
	assert snapped(guide_box(400, 297, 50, 30), [other_box], 5).y == 300, 'topo'
	assert snapped(guide_box(400, 303, 50, 30), [other_box], 5).y == 305, 'meio'
	assert snapped(guide_box(400, 312, 50, 30), [other_box], 5).y == 310, 'base'
}

// Entre dois alinhamentos ao alcance vence o mais perto, e cada eixo encaixa por conta própria.
fn test_vence_o_alinhamento_mais_perto() {
	// Os nomes fogem de `near` e `far`, que o windows.h define como macros vazias.
	closest := guide_box(106, 0, 50, 30)
	remote := guide_box(0, 0, 50, 30)
	moved := snapped(guide_box(104, 302, 50, 30), [closest, other_box, remote], 5)
	assert moved.x == 106
	assert moved.y == 300
}

// Cada posição que coincide com a de mesmo tipo da outra caixa tem uma guia, que atravessa as duas caixas; sem coincidência não há guia.
fn test_cada_posicao_que_coincide_tem_uma_guia() {
	left := guides(guide_box(100, 50, 50, 30), [other_box])
	assert left.len == 1
	assert left[0].standing && left[0].at == 100 && left[0].from == 50 && left[0].to == 340
	centered := guides(guide_box(115, 305, 50, 30), [other_box])
	assert centered.len == 2
	assert centered[0].standing && centered[0].at == 140 && centered[0].from == 300 && centered[0].to == 340
	assert !centered[1].standing && centered[1].at == 320 && centered[1].from == 100 && centered[1].to == 180
	assert guides(guide_box(150, 50, 50, 30), [other_box]).len == 0
}

// guided_editor monta um editor com uma marcação na cena e outra pega pelo corpo, na escala 1: a janela e a captura têm as mesmas coordenadas.
fn guided_editor(grab Grab, cursor_x int) Editor {
	return Editor{
		scale:    1.0
		scene:    Scene{
			crop:   guide_box(0, 0, 500, 500)
			shapes: [Shape{
				tool: .rectangle
				area: other_box
			}]
		}
		grabbed:  Shape{
			tool: .rectangle
			area: guide_box(200, 50, 50, 30)
		}
		grab:     grab
		cursor_x: cursor_x
		selected: 0
	}
}

// Mover encaixa a caixa inteira; esticar pela alça encaixa só o lado pego, e o outro fica parado.
fn test_mover_e_esticar_encaixam() {
	assert guided_editor(.body, -97).grabbed_shape().area == guide_box(100, 50, 50, 30)
	// A borda esquerda esticada para 103 fica a três pixels da esquerda da outra caixa, e vai para 100; a direita fica em 250.
	assert guided_editor(.left, -97).grabbed_shape().area == guide_box(100, 50, 150, 30)
	// A moldura não é figura: a caixa dela é a imagem inteira, e alinhar com ela não conta.
	mut framed := guided_editor(.body, -97)
	framed.scene.shapes = [Shape{
		tool: .backdrop
		area: other_box
	}]
	assert framed.grabbed_shape().area.x == 103
}

// O lado em movimento encaixa no lado de mesmo tipo, e nunca encosta no parado nem passa dele.
fn test_o_lado_nao_passa_do_parado() {
	columns := [edges(100, 80)]
	assert snapped_side(0, 177, columns, 5) == 180, 'fim com fim'
	assert snapped_side(300, 103, columns, 5) == 100, 'começo com começo'
	assert snapped_side(300, 177, columns, 5) == 177, 'começo não encaixa no fim'
	assert snapped_side(102, 100, [edges(103, 80)], 5) == 100, 'passaria do parado'
	assert snapped_side(100, 103, [edges(90, 10)], 5) == 103, 'encostaria no parado'
	assert snapped_side(103, 103, columns, 5) == 103, 'sem largura continua sem largura'
}

// Esticar além do lado oposto vira a caixa, e o lado pego continua encaixando, agora como o outro tipo.
fn test_esticar_alem_do_oposto_encaixa() {
	mut editor := guided_editor(.left, 28)
	editor.grabbed = Shape{
		tool: .rectangle
		area: guide_box(150, 50, 20, 30)
	}
	// A esquerda de 150 passa da direita, em 170, e chega a 178: virou o fim da caixa, e encaixa no fim da outra, em 180.
	assert editor.grabbed_shape().area == guide_box(170, 50, 10, 30)
}

// As pontas da linha encaixam uma de cada vez, com a outra parada.
fn test_a_ponta_da_linha_encaixa() {
	mut editor := guided_editor(.line_end, -21)
	editor.grabbed = Shape{
		tool: .line
		area: guide_box(10, 10, 193, 100)
	}
	// A ponta de 203 chega a 182, a dois pixels da direita da outra caixa, e encaixa em 180; a outra fica em 10.
	assert editor.grabbed_shape().area == guide_box(10, 10, 170, 100)
}

// A caixa nova encaixa pelos lados, e o recorte e o clique parado não encaixam.
fn test_criar_encaixa() {
	mut editor := guided_editor(.none, 178)
	editor.view = guide_box(0, 0, 500, 500)
	editor.tool = .rectangle
	editor.origin_x = 103
	editor.origin_y = 50
	editor.cursor_y = 90
	assert editor.drag_area() == guide_box(100, 50, 80, 40)
	assert editor.snapped_area() == guide_box(100, 50, 80, 40)
	editor.tool = .select
	assert editor.drag_area() == guide_box(103, 50, 75, 40)
	editor.tool = .rectangle
	editor.cursor_x = 104
	editor.cursor_y = 51
	assert editor.drag_area() == guide_box(103, 50, 1, 1)
}

// O balão novo encaixa pelo disco, mesmo no clique que o cria.
fn test_o_balao_novo_encaixa() {
	mut editor := guided_editor(.none, 0)
	editor.view = guide_box(0, 0, 500, 500)
	editor.thickness = 6
	box := counter_box(Point{143, 50}, 6)
	editor.origin_x = 143
	editor.origin_y = 50
	editor.cursor_x = 143
	editor.cursor_y = 50
	assert editor.counter_shape().area == guide_box(box.x - 3, box.y, box.width, box.height)
}

// Com o alinhamento desligado nada encaixa e nenhuma guia aparece, ao mover, esticar ou criar.
fn test_desligado_nao_encaixa() {
	mut moved := guided_editor(.body, -97)
	moved.toggle_snap()
	assert moved.status == 'Alinhamento desligado'
	assert moved.grabbed_shape().area == guide_box(103, 50, 50, 30)
	assert moved.guide_targets().len == 0
	mut stretch := guided_editor(.left, -97)
	stretch.toggle_snap()
	assert stretch.grabbed_shape().area == guide_box(103, 50, 147, 30)
	mut drawn := guided_editor(.none, 178)
	drawn.view = guide_box(0, 0, 500, 500)
	drawn.tool = .rectangle
	drawn.origin_x = 103
	drawn.origin_y = 50
	drawn.cursor_y = 90
	drawn.toggle_snap()
	assert drawn.drag_area() == guide_box(103, 50, 75, 40)
	drawn.toggle_snap()
	assert drawn.status == 'Alinhamento ligado'
	assert drawn.drag_area() == guide_box(100, 50, 80, 40)
}

// guide_pixels conta quantos pixels da coluna têm a cor da guia.
fn guide_pixels(hdc voidptr, x int, from int, to int) int {
	mut painted := 0
	for y in from .. to {
		if C.GetPixel(hdc, x, y) == guide_color {
			painted++
		}
	}
	return painted
}

// Na tela, a prévia do arrasto que cria sai no lugar encaixado e com a guia; desligado, sai onde o mouse a pôs, e sem guia.
fn test_a_previa_de_criar_mostra_o_encaixe() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 400, 400)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	mut editor := guided_editor(.none, 178)
	editor.view = guide_box(0, 0, 500, 500)
	editor.tool = .rectangle
	editor.thickness = 1
	editor.color = u32(0x00000000)
	editor.origin_x = 103
	editor.origin_y = 50
	editor.cursor_y = 90
	paint_rect(surface.dc, guide_box(0, 0, 400, 400), u32(0x00ffffff))
	draw_dragged(surface.dc, &editor)
	// Entre a base da prévia, em 90, e o topo da outra caixa, em 300, a coluna 100 só tem a guia.
	assert guide_pixels(surface.dc, 100, 95, 295) > 60
	assert guide_pixels(surface.dc, 103, 95, 295) == 0
	assert C.GetPixel(surface.dc, 150, 50) != u32(0x00ffffff), 'o topo da prévia'
	editor.toggle_snap()
	paint_rect(surface.dc, guide_box(0, 0, 400, 400), u32(0x00ffffff))
	draw_dragged(surface.dc, &editor)
	assert guide_pixels(surface.dc, 100, 95, 295) == 0
	assert C.GetPixel(surface.dc, 100, 70) == u32(0x00ffffff), 'a prévia não encaixou'
	assert C.GetPixel(surface.dc, 103, 70) != u32(0x00ffffff), 'a prévia fica onde o mouse a pôs'
}

// Esticando, a guia aparece como no mover.
fn test_esticar_mostra_a_guia() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 400, 400)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	mut editor := guided_editor(.left, -97)
	editor.grabbed = Shape{
		...editor.grabbed
		thickness: 1
	}
	paint_rect(surface.dc, guide_box(0, 0, 400, 400), u32(0x00ffffff))
	draw_grabbed(surface.dc, &editor)
	assert guide_pixels(surface.dc, 100, 95, 295) > 60
}

// Um clique parado sobre a marcação não a encaixa: a soltura a devolve como estava, e a prévia mostra o mesmo, em vez de um salto que voltaria ao soltar.
fn test_clique_parado_nao_encaixa() {
	mut editor := guided_editor(.body, 0)
	// A quatro pixels da esquerda da outra caixa, ao alcance do encaixe.
	editor.grabbed = Shape{
		tool: .rectangle
		area: guide_box(104, 50, 50, 30)
	}
	assert editor.grabbed_shape().area == guide_box(104, 50, 50, 30)
}

// Na tela a guia é tracejada: parte da coluna tem a cor da guia, e parte deixa ver o que está por baixo.
fn test_a_guia_sai_tracejada() ! {
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 400, 400)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	paint_rect(surface.dc, guide_box(0, 0, 400, 400), u32(0x00ffffff))
	editor := guided_editor(.body, 0)
	draw_guides(surface.dc, editor, guide_box(100, 50, 50, 30))
	mut painted := 0
	for y in 60 .. 330 {
		if C.GetPixel(surface.dc, 100, y) == guide_color {
			painted++
		}
	}
	assert painted > 60, 'a guia deveria aparecer'
	assert painted < 230, 'a guia deveria ter vãos'
	assert C.GetPixel(surface.dc, 101, 200) == u32(0x00ffffff), 'a guia tem um pixel de largura'
}

// As marcações que o recorte deixou de fora não se veem, e não servem de alvo; a que encosta nele serve, mesmo sem altura, como uma linha deitada.
fn test_o_que_o_recorte_esconde_nao_e_alvo() {
	mut editor := guided_editor(.body, 0)
	editor.scene.crop = guide_box(200, 0, 300, 500)
	assert editor.guide_targets().len == 0
	editor.scene.shapes << Shape{
		tool: .line
		area: guide_box(250, 100, 100, 0)
	}
	assert editor.guide_targets() == [guide_box(250, 100, 100, 0)]
}

// A guia não passa da imagem: o trecho que cai fora do recorte, até a parte escondida da outra marcação, não aparece.
fn test_a_guia_nao_passa_do_recorte() ! {
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 400, 400)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	paint_rect(surface.dc, guide_box(0, 0, 400, 400), u32(0x00ffffff))
	mut editor := guided_editor(.body, 0)
	// O recorte corta a outra caixa, que vai da linha 300 à 340, na linha 320.
	editor.scene.crop = guide_box(0, 0, 500, 320)
	draw_guides(surface.dc, editor, guide_box(100, 50, 50, 30))
	mut inside := 0
	mut outside := 0
	for y in 60 .. 340 {
		if C.GetPixel(surface.dc, 100, y) != guide_color {
			continue
		}
		if y < 320 {
			inside++
		} else {
			outside++
		}
	}
	assert inside > 0, 'a guia deveria aparecer dentro do recorte'
	assert outside == 0, 'a guia não deveria passar do recorte'
}
