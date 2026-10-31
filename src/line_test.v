module main

// O traço atravessa a caixa partindo do canto de onde o arrasto saiu. São quatro cantos, e
// não duas diagonais, porque a ponta da seta fica onde o arrasto terminou.
fn test_pontas_saem_da_caixa_e_do_canto_de_origem() {
	area := Rect{
		x: 10
		y: 20
		width: 100
		height: 50
	}
	x1, y1, x2, y2 := line_ends(area, .top_left)
	assert [x1, y1, x2, y2] == [10, 20, 110, 70]
	sx1, sy1, sx2, sy2 := line_ends(area, .bottom_left)
	assert [sx1, sy1, sx2, sy2] == [10, 70, 110, 20], 'saindo do pé, ela sobe'
	// A mesma diagonal na direção contrária troca as pontas de lugar.
	rx1, ry1, rx2, ry2 := line_ends(area, .bottom_right)
	assert [rx1, ry1, rx2, ry2] == [110, 70, 10, 20]
	tx1, ty1, tx2, ty2 := line_ends(area, .top_right)
	assert [tx1, ty1, tx2, ty2] == [110, 20, 10, 70]
}

// Com Shift a ponta é presa a 0°, 45° ou 90°, pelo ângulo mais próximo.
fn test_shift_prende_a_linha_nos_angulos_redondos() {
	quase_reta_x, quase_reta_y := snap_to_angle(0, 0, 100, 5)
	assert [quase_reta_x, quase_reta_y] == [100, 0]

	quase_vertical_x, quase_vertical_y := snap_to_angle(0, 0, 5, 100)
	assert [quase_vertical_x, quase_vertical_y] == [0, 100]

	// Perto de 45° vira 45° exato, com o comprimento tirado da média dos dois lados.
	diagonal_x, diagonal_y := snap_to_angle(0, 0, 100, 90)
	assert [diagonal_x, diagonal_y] == [95, 95]

	// E vale para os quatro quadrantes.
	sobe_x, sobe_y := snap_to_angle(200, 200, 120, 100)
	assert [sobe_x, sobe_y] == [110, 110]
}

// O Shift vale para cada ferramenta do jeito dela: a seta e a régua se prendem aos ângulos
// como a linha, o retângulo e a elipse viram quadrado e círculo, e o resto segue o ponteiro.
fn test_shift_em_cada_ferramenta() {
	for tool in [Tool.line, .arrow, .ruler] {
		x, y := shift_snap(tool, 0, 0, 100, 5)
		assert [x, y] == [100, 0], '${tool}'
		diagonal_x, diagonal_y := shift_snap(tool, 0, 0, 100, 90)
		assert [diagonal_x, diagonal_y] == [95, 95], '${tool} a 45°'
	}
	for tool in [Tool.rectangle, .oval] {
		x, y := shift_snap(tool, 10, 10, 110, 40)
		assert [x, y] == [110, 110], '${tool}'
		// Para cima e para a esquerda também, com o lado do maior dos dois.
		up_x, up_y := shift_snap(tool, 100, 100, 70, 20)
		assert [up_x, up_y] == [20, 20], '${tool} para cima'
		// Um arrasto só na horizontal ainda dá um quadrado, e não uma caixa sem altura.
		flat_x, flat_y := shift_snap(tool, 0, 0, 50, 0)
		assert [flat_x, flat_y] == [50, 50], '${tool} deitado'
	}
	x, y := shift_snap(.blur, 0, 0, 100, 5)
	assert [x, y] == [100, 5]
}

// Com Shift, a linha deitada ou em pé tem a caixa sem altura ou sem largura, e a prévia tem
// de aparecer mesmo assim. Ela sumia a 0° e a 90°, e só aparecia a 45°.
fn test_a_previa_da_linha_reta_aparece() {
	flat := Rect{
		x: 10
		y: 10
		width: 80
	}
	standing := Rect{
		x: 10
		y: 10
		height: 80
	}
	for tool in [Tool.line, .arrow, .ruler] {
		assert previewable(flat, tool), '${tool} deitada'
		assert previewable(standing, tool), '${tool} em pé'
		assert !previewable(Rect{
			x: 10
			y: 10
		}, tool), '${tool} sem sair do lugar'
	}
	// Uma caixa continua precisando dos dois lados.
	assert !previewable(flat, .rectangle)
	assert previewable(Rect{
		x: 10
		y: 10
		width: 5
		height: 5
	}, .rectangle)
}

// Sem Shift a ponta é a do cursor, sem correção nenhuma.
fn test_sem_shift_a_ponta_e_a_do_cursor() {
	mut editor := Editor{
		tool: .line
		origin_x: 10
		origin_y: 10
		cursor_x: 100
		cursor_y: 12
	}
	x, y := editor.drag_cursor()
	assert [x, y] == [100, 12]
	assert editor.drag_corner() == .top_left

	editor.cursor_y = 4
	assert editor.drag_corner() == .bottom_left, 'a ponta acima da origem faz o traço subir'
	editor.cursor_x = 2
	assert editor.drag_corner() == .bottom_right, 'e à esquerda, ele volta'
}

// Quase toda a caixa de uma linha é vazia. Acertá-la é chegar perto do traço.
fn test_acerto_da_linha_e_por_distancia() {
	assert near_segment(0, 0, 100, 0, 50, 3, 6)
	assert !near_segment(0, 0, 100, 0, 50, 10, 6)

	// Fora das pontas a distância é até a ponta, e não até a reta infinita.
	assert near_segment(0, 0, 100, 0, 103, 0, 6)
	assert !near_segment(0, 0, 100, 0, 110, 0, 6)

	// Na diagonal, o meio da caixa é o traço e o canto dela não é.
	assert near_segment(0, 0, 100, 100, 50, 50, 6)
	assert !near_segment(0, 0, 100, 100, 100, 0, 6)

	// Um arrasto que não saiu do lugar continua tendo um ponto para acertar.
	assert near_segment(40, 40, 40, 40, 42, 42, 6)
	assert !near_segment(40, 40, 40, 40, 60, 60, 6)
}

// Cada ferramenta oferece os estilos que fazem sentido nela.
fn test_a_linha_escolhe_entre_continuo_e_pontilhado() {
	assert style_slots(.line) == [4, 5]
	assert style_name(5) == 'Traço pontilhado'
	assert style_pressed(Style{}, 5).dashed
	assert !style_pressed(Style{ dashed: true }, 4).dashed
	// Trocar o traço não mexe nos campos das outras ferramentas.
	full := Style{
		rounded: true
		filled: true
	}
	dashed := style_pressed(full, 5)
	assert dashed.rounded && dashed.filled && dashed.dashed
	assert style_is_active(dashed, 5) && !style_is_active(dashed, 4)
}

// O mesmo vale para o corpo da marcação já selecionada: clicar dentro da caixa de uma
// linha, mas longe do traço, não pode começar um arrasto dela. Isto já esteve errado.
fn test_corpo_da_linha_selecionada_tambem_e_por_distancia() {
	editor := Editor{
		view: Rect{
			width: 1000
			height: 1000
		}
		scale: 1.0
		scene: Scene{
			shapes: [
				Shape{
					tool: .line
					area: Rect{
						x: 100
						y: 100
						width: 400
						height: 200
					}
					color: annotation_color
					thickness: 3
					origin: .top_left
				},
			]
		}
		selected: 0
	}
	// Sobre o traço, no meio da diagonal.
	assert editor.grab_at(300, 200) == .body
	// Dentro da caixa e longe do traço.
	assert editor.grab_at(450, 130) == .none
	// E as alças continuam valendo, que são o que dá para pegar nos cantos.
	assert editor.grab_at(100, 100) == .line_start
	assert editor.grab_at(500, 300) == .line_end
	assert editor.grab_at(500, 100) == .none
	assert editor.grab_at(300, 100) == .none
}

// A seta usa os quatro cantos, e não só a diagonal: a mesma caixa arrastada em sentidos
// opostos põe a ponta em lugares opostos.
fn test_seta_aponta_para_onde_o_arrasto_terminou() {
	area := Rect{
		x: 0
		y: 0
		width: 100
		height: 100
	}
	_, _, tip_x, tip_y := line_ends(area, .top_left)
	assert [tip_x, tip_y] == [100, 100]
	_, _, back_x, back_y := line_ends(area, .bottom_right)
	assert [back_x, back_y] == [0, 0], 'a mesma diagonal ao contrário aponta ao contrário'
}

// A ponta sai de um vetor unitário e do perpendicular dele: as duas asas ficam simétricas
// em relação ao traço, e recuadas dele pelo comprimento da ponta.
fn test_asas_da_ponta_sao_simetricas() {
	base_x, base_y, wing_x, wing_y, other_x, other_y := arrow_head(0, 0, 100, 0, 4.0)
	// Numa seta horizontal, a base recua no eixo x e as asas se afastam no y.
	assert round(base_x) == 100 - int(4.0 * head_reach)
	assert round(base_y) == 0
	assert round(wing_y) == int(4.0 * head_spread)
	assert round(other_y) == -int(4.0 * head_spread)
	assert round(wing_x) == round(other_x)
}

// Esticar a linha ou a seta pela alça da ponta além da outra ponta leva a ponta junto, em vez de inverter o traço: o canto de partida troca de lado no eixo atravessado. Parar exatamente no lado oposto não troca nada, e o traço livre espelha o caminho dentro da caixa nova.
fn test_atravessar_o_lado_oposto_leva_a_ponta_junto() {
	arrow := Shape{
		tool: .arrow
		area: Rect{
			width: 100
			height: 100
		}
		origin: .top_left
	}
	across, down := crossed(arrow.area, .bottom_right, -150, -150)
	assert across && down
	back := arrow.fitted(resized(arrow.area, .bottom_right, -150, -150)).flipped(across, down)
	assert back.origin == .bottom_right
	side_x, side_y := crossed(arrow.area, .bottom_right, -150, 0)
	assert side_x && !side_y
	sideways := arrow.fitted(resized(arrow.area, .bottom_right, -150, 0)).flipped(side_x, side_y)
	assert sideways.origin == .top_right
	edge_x, _ := crossed(arrow.area, .bottom_right, -100, 0)
	assert !edge_x

	stroke := Shape{
		tool: .freehand
		area: Rect{
			width: 100
			height: 100
		}
		points: [Point{0, 0}, Point{100, 50}]
	}
	over, _ := crossed(stroke.area, .left, 150, 0)
	mirror := stroke.fitted(resized(stroke.area, .left, 150, 0)).flipped(over, false)
	assert mirror.points == [Point{150, 0}, Point{100, 50}]
}

// Numa seta mais curta que a ponta, a ponta encolhe na mesma proporção e a base dela não passa da cauda.
fn test_ponta_da_seta_curta_nao_passa_da_cauda() {
	base_x, _, _, wing_y, _, _ := arrow_head(0, 0, 10, 0, 12.0)
	assert base_x >= 0
	assert round(wing_y) == round((10 - base_x) * head_spread / head_reach)
}

// A seta cheia fina, na diagonal, tem haste desde a cauda: com os vértices arredondados para inteiro, os dois cantos da cauda caíam no mesmo pixel, e a haste virava uma cunha que começava num ponto.
fn test_seta_cheia_fina_tem_haste_desde_a_cauda() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 100, 100)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	paint_rect(surface.dc, Rect{
		width: 100
		height: 100
	}, u32(0x00ffffff))
	draw_arrow(surface.dc, 10, 10, 90, 90, Style{ head: .block }, u32(0x000000ff), 1.0)
	pixel := C.GetPixel(surface.dc, 12, 12)
	assert (pixel >> 8) & 0xff < 150, 'a haste deveria cobrir o pixel logo depois da cauda'
}

// As asas da seta vão com as frações: arredondadas para inteiro, cada uma andava até meio pixel, por tantos diferentes, e o V pequeno da prévia saía com um braço mais longo e ângulos desiguais. Nesta seta as asas exatas terminam em (56,007; 30,557) e (57,493; 26,843), e a seta tem de sair igual à haste mais essas duas asas.
fn test_as_asas_da_seta_vao_com_as_fracoes() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	arrow := new_surface(screen, 80, 50)!
	exact := new_surface(screen, 80, 50)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		arrow.release()
		exact.release()
	}
	red := u32(0x000000ff)
	for surface in [arrow, exact] {
		paint_rect(surface.dc, Rect{
			width: 80
			height: 50
		}, u32(0x00ffffff))
	}
	draw_arrow(arrow.dc, 10, 10, 60, 30, Style{ head: .simple }, red, 1.0)
	_, _, wing_x, wing_y, other_x, other_y := arrow_head(10, 10, 60, 30, 1.0)
	draw_line(exact.dc, 10, 10, 60, 30, Style{}, red, 1.0)
	draw_line(exact.dc, 60, 30, wing_x, wing_y, Style{}, red, 1.0)
	draw_line(exact.dc, 60, 30, other_x, other_y, Style{}, red, 1.0)
	for y in 0 .. 50 {
		for x in 0 .. 80 {
			assert C.GetPixel(arrow.dc, x, y) == C.GetPixel(exact.dc, x, y)
		}
	}
}

// Um arrasto que não saiu do lugar não tem direção, e a ponta desaba sobre o próprio ponto
// em vez de dividir por zero.
fn test_seta_sem_comprimento_nao_explode() {
	base_x, base_y, wing_x, wing_y, _, _ := arrow_head(50, 50, 50, 50, 4.0)
	assert [round(base_x), round(base_y), round(wing_x), round(wing_y)] == [50, 50, 50, 50]
}

fn test_a_seta_escolhe_entre_quatro_pontas() {
	assert style_slots(.arrow) == [6, 7, 8, 9]
	assert style_name(6) == 'Ponta cheia'
	assert style_name(9) == 'Ponta dupla'
	assert style_pressed(Style{}, 9).head == .double
	// Trocar a ponta não mexe nos campos das outras ferramentas.
	full := Style{
		rounded: true
		filled: true
		dashed: true
	}
	tapered := style_pressed(full, 7)
	assert tapered.head == .tapered
	assert tapered.rounded && tapered.filled && tapered.dashed
	assert style_is_active(tapered, 7) && !style_is_active(tapered, 6)
}

// Somar meio e truncar arredonda para o lado errado nos negativos, e o polígono da seta
// passa por ali quando o arrasto começa perto da borda de cima.
fn test_arredondamento_vale_dos_dois_lados_do_zero() {
	assert round(7.5) == 8
	assert round(7.4) == 7
	assert round(-7.5) == -8
	assert round(-7.4) == -7
	assert round(0.0) == 0
}

// Uma linha horizontal ou vertical tem um dos lados da caixa zerado. Descartá-la por isso
// já aconteceu, e é justamente o traço que o Shift produz.
fn test_traco_reto_nao_e_descartado() {
	horizontal := Rect{
		x: 10
		y: 10
		width: 200
		height: 0
	}
	vertical := Rect{
		x: 10
		y: 10
		width: 0
		height: 200
	}
	assert usable(horizontal, .line)
	assert usable(vertical, .arrow)
	// O retângulo e a elipse continuam precisando dos dois lados: sem um deles não sobra
	// forma nenhuma.
	assert !usable(horizontal, .rectangle)
	assert !usable(vertical, .oval)
	// E um arrasto que não saiu do lugar não vale para ninguém.
	assert !usable(Rect{ x: 10, y: 10 }, .line)
}
