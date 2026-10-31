module main

// A lupa tem duas pontas, e só uma delas é a caixa da marcação. Os testes daqui olham onde
// a segunda cai, que é o que o resto do editor não sabe sozinho.

// white_canvas monta uma superfície branca do tamanho pedido. Cada arquivo de teste é
// compilado com o módulo e sem os outros testes, então este ajudante mora aqui e não é
// compartilhado.
fn white_canvas(width int, height int) !Frozen {
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, width, height)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(surface.dc, Rect{
		width: width
		height: height
	}, 0x00ffffff)
	return surface
}

// rgb reparte um COLORREF, que é 0x00bbggrr, nos três canais.
fn rgb(color u32) (int, int, int) {
	return int(color & 0xff), int((color >> 8) & 0xff), int((color >> 16) & 0xff)
}

// A lente sai na diagonal de onde o arrasto partiu, e nunca por cima da origem.
fn test_a_lente_sai_do_lado_de_onde_o_arrasto_veio() {
	area := Rect{
		x: 100
		y: 100
		width: 40
		height: 20
	}
	// Arrasto para a direita e para baixo: a lente vai para cima e para a esquerda.
	lens := magnifier_lens(area, .top_left)
	assert lens.x + lens.width < area.x
	assert lens.y + lens.height < area.y

	other := magnifier_lens(area, .bottom_right)
	assert other.x > area.x + area.width
	assert other.y > area.y + area.height

	sideways := magnifier_lens(area, .top_right)
	assert sideways.x > area.x + area.width
	assert sideways.y + sideways.height < area.y
}

// A lente é a origem ampliada, e guarda a proporção dela: uma origem larga dá uma lente
// larga, e não um quadrado.
fn test_a_lente_amplia_guardando_a_proporcao() {
	area := Rect{
		x: 50
		y: 60
		width: 40
		height: 20
	}
	lens := magnifier_lens(area, .top_left)
	assert lens.width == area.width * magnifier_zoom
	assert lens.height == area.height * magnifier_zoom
	assert lens.width * area.height == lens.height * area.width
}

// Entre as duas pontas sobra o vão que deixa a linha aparecer.
fn test_sobra_vao_entre_a_origem_e_a_lente() {
	area := Rect{
		x: 200
		y: 200
		width: 30
		height: 30
	}
	lens := magnifier_lens(area, .bottom_right)
	assert lens.x - (area.x + area.width) == magnifier_gap
	assert lens.y - (area.y + area.height) == magnifier_gap
}

// Clicar na lente escolhe a marcação: a caixa dela é só a origem, mas quem clica mira no
// que vê, e o que se vê maior é a lente.
fn test_a_lente_tambem_pega_o_clique() {
	area := Rect{
		x: 100
		y: 100
		width: 40
		height: 20
	}
	lens := magnifier_lens(area, .top_left)
	assert magnifier_hits(area, lens, 120, 110)
	assert magnifier_hits(area, lens, lens.x + lens.width / 2, lens.y + lens.height / 2)
	// O vão entre as duas não pega, e nem o lado oposto ao da lente.
	assert !magnifier_hits(area, lens, area.x - magnifier_gap / 2, area.y - magnifier_gap / 2)
	assert !magnifier_hits(area, lens, area.x + area.width + 50, area.y)
}

// lens_editor monta um editor sem janela com uma lupa escolhida: a origem de 40 por 20 em
// (400, 400), e a lente de 120 por 60 em (100, 100), longe dela.
fn lens_editor() Editor {
	return Editor{
		view: Rect{
			width: 1000
			height: 1000
		}
		scale: 1.0
		scene: Scene{
			crop: Rect{
				width: 1000
				height: 1000
			}
			shapes: [
				Shape{
					tool: .magnifier
					area: Rect{
						x: 400
						y: 400
						width: 40
						height: 20
					}
					points: lens_points(Rect{
						x: 100
						y: 100
						width: 120
						height: 60
					})
					thickness: 2
				},
			]
		}
		selected: 0
		tool: .select
	}
}

// Durante o arrasto, a lente vai à janela pela mesma conta das alças dela. Numa origem pequena e numa vista reduzida, a conta pela razão entre a origem na captura e a origem na janela, cuja largura é truncada, punha a lente longe das alças.
fn test_lente_da_previa_fica_dentro_das_alcas() {
	mut editor := lens_editor()
	editor.scale = 0.37
	mark := Shape{
		tool: .magnifier
		area: Rect{
			x: 400
			y: 400
			width: 10
			height: 10
		}
		points: lens_points(Rect{
			x: 100
			y: 100
			width: 30
			height: 30
		})
	}
	framed := editor.to_client(lens_of(mark))
	shown := editor.magnifier_in_window(mark)
	assert target_lens(shown, shown.area) == framed
	// A conta antiga, pela origem na janela, se afasta das alças.
	assert target_lens(mark, editor.to_client(mark.area)) != framed
}

// Perto da borda, a lente que não cabe na diagonal do arrasto vai para o outro lado da origem naquele eixo; longe dela, fica onde magnifier_lens a põe; e num recorte pequeno fica presa dentro dele.
fn test_lente_nasce_dentro_do_recorte() {
	// Nomes como near, far e small são macros nos cabeçalhos do Windows, e o C gerado não compila com eles.
	whole := Rect{
		width: 1000
		height: 1000
	}
	by_edge := Rect{
		x: 10
		y: 10
		width: 50
		height: 30
	}
	assert lens_within(by_edge, .top_left, whole) == Rect{
		x: 70
		y: 50
		width: 150
		height: 90
	}
	inland := Rect{
		x: 400
		y: 400
		width: 40
		height: 20
	}
	assert lens_within(inland, .top_left, whole) == magnifier_lens(inland, .top_left)
	tiny := Rect{
		width: 100
		height: 100
	}
	held := lens_within(Rect{ x: 40, y: 40, width: 20, height: 20 }, .top_left, tiny)
	assert held.x >= 0 && held.x + held.width <= 100
	assert held.y >= 0 && held.y + held.height <= 100
}

// Cada ponta da lupa tem as suas alças e o seu corpo, e o clique diz qual das duas pegou.
fn test_cada_ponta_da_lupa_tem_o_seu_controle() {
	editor := lens_editor()
	corner, on_lens := editor.part_at(440, 420)
	assert corner == .bottom_right && !on_lens
	body, in_lens := editor.part_at(410, 405)
	assert body == .body && !in_lens
	lens_corner, at_lens := editor.part_at(100, 100)
	assert lens_corner == .top_left && at_lens
	lens_body, inside_lens := editor.part_at(160, 130)
	assert lens_body == .body && inside_lens
	nothing, _ := editor.part_at(300, 300)
	assert nothing == .none
}

// Mexer numa ponta não mexe na outra: a lente anda e cresce com a origem parada, e a
// origem anda com a lente parada. Crescer a lente é o que aumenta a ampliação.
fn test_mexer_numa_ponta_nao_mexe_na_outra() {
	mut editor := lens_editor()
	mark := editor.scene.shapes[0]
	editor.grabbed = mark
	editor.origin_x = 160
	editor.origin_y = 130
	editor.cursor_x = 190
	editor.cursor_y = 150

	editor.grab = .body
	editor.grab_lens = true
	moved := editor.grabbed_shape()
	assert moved.area == mark.area
	assert lens_of(moved) == Rect{
		x: 130
		y: 120
		width: 120
		height: 60
	}

	editor.grab = .bottom_right
	grown := editor.grabbed_shape()
	assert grown.area == mark.area
	assert lens_of(grown) == Rect{
		x: 100
		y: 100
		width: 150
		height: 80
	}

	editor.grab = .body
	editor.grab_lens = false
	source := editor.grabbed_shape()
	assert source.area == Rect{
		x: 430
		y: 420
		width: 40
		height: 20
	}
	assert lens_of(source) == lens_of(mark)
}

// A linha de ligação vai de borda a borda: no miolo da origem não sobra toco de reta, e no
// vão entre as duas pontas ela aparece.
fn test_a_linha_nao_sobra_dentro_da_origem() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	surface := white_canvas(200, 200)!
	defer {
		surface.release()
	}
	area := Rect{
		x: 100
		y: 100
		width: 20
		height: 20
	}
	// Sem lente guardada, ela sai em cima e à esquerda: de (30, 30) a (90, 90). A linha vai
	// do meio da origem, (110, 110), ao meio da lente, (60, 60).
	draw_magnifier(surface.dc, Shape{
		tool: .magnifier
		color: 0x000000ff
		thickness: 2
	}, area, 2)
	assert C.GetPixel(surface.dc, 110, 110) == 0x00ffffff, 'o miolo da origem continua limpo'
	assert C.GetPixel(surface.dc, 105, 105) == 0x00ffffff
	red, green, _ := rgb(C.GetPixel(surface.dc, 95, 95))
	assert red > 150 && green < 150, 'no vão a linha aparece'
}

// Os dois botões do painel são a forma das duas pontas, e um exclui o outro.
fn test_a_lupa_escolhe_entre_quadro_e_elipse() {
	assert style_slots(.magnifier) == style_slots_lens
	square := style_pressed(Style{}, style_slots_lens[0])
	round := style_pressed(Style{}, style_slots_lens[1])
	assert !square.rounded
	assert round.rounded
	assert style_is_active(square, style_slots_lens[0])
	assert !style_is_active(square, style_slots_lens[1])
	assert style_is_active(round, style_slots_lens[1])
	assert style_name(style_slots_lens[0]) == 'Lupa retangular'
	assert style_name(style_slots_lens[1]) == 'Lupa redonda'
	// Trocar a forma da lupa não mexe no que as outras ferramentas guardam.
	rich := Style{
		filled: true
		dashed: true
		erase: true
	}
	changed := style_pressed(rich, style_slots_lens[1])
	assert changed.filled && changed.dashed && changed.erase
}

// Escolher a lupa a deixa redonda, e sair dela devolve o canto reto às outras — sem mexer
// no preenchimento nem no resto do estilo.
fn test_a_lupa_comeca_redonda() {
	mut editor := Editor{
		selected: -1
		tool: .rectangle
		style: Style{
			filled: true
			dashed: true
		}
	}
	editor.choose(.magnifier)
	assert editor.style.rounded
	assert editor.style.filled && editor.style.dashed
	editor.choose(.rectangle)
	assert !editor.style.rounded
	assert editor.style.filled && editor.style.dashed
}

// Ampliar mostra o que estava na origem, e não o que estava onde a lente caiu.
fn test_a_lente_mostra_o_que_estava_na_origem() ! {
	surface := white_canvas(200, 200)!
	defer {
		surface.release()
	}
	// Um quadrado vermelho de dez por dez no meio, que é o que vai ser ampliado.
	paint_rect(surface.dc, Rect{
		x: 100
		y: 100
		width: 10
		height: 10
	}, 0x000000ff)
	area := Rect{
		x: 100
		y: 100
		width: 10
		height: 10
	}
	draw_magnifier(surface.dc, Shape{
		tool: .magnifier
		color: annotation_color
		thickness: 2
	}, area, 2)

	lens := magnifier_lens(area, .top_left)
	// O miolo da lente tem de ter virado vermelho, que era a cor da origem inteira.
	red, green, blue := rgb(C.GetPixel(surface.dc, lens.x + lens.width / 2, lens.y +
		lens.height / 2))
	assert red > 200 && green < 60 && blue < 60
	// E fora da lente e da origem, a superfície continua branca.
	assert C.GetPixel(surface.dc, 190, 190) == 0x00ffffff
}
