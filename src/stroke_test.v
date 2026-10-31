module main

fn sample_stroke() []Point {
	return [Point{10, 10}, Point{30, 50}, Point{50, 30}, Point{70, 70}]
}

// A caixa do traço é a que envolve todos os pontos, e é por ela que a seleção e as alças
// valem para ele como valem para as outras marcações.
fn test_caixa_envolve_todos_os_pontos() {
	area := bounds(sample_stroke())
	assert area.x == 10 && area.y == 10
	assert area.width == 60 && area.height == 60
	// Um ponto só tem caixa sem lado, e isso é uma marcação legítima.
	single := bounds([Point{40, 40}])
	assert single == Rect{
		x: 40
		y: 40
	}
	assert bounds([]) == Rect{}
}

// Mover e redimensionar levam o traço junto: os pontos são reescalados da caixa velha para
// a nova.
fn test_traco_acompanha_a_caixa() {
	mark := Shape{
		tool: .freehand
		area: bounds(sample_stroke())
		color: annotation_color
		thickness: 3
		points: sample_stroke()
	}
	// Movida cem para a direita e cinquenta para baixo, sem mudar de tamanho.
	moved := mark.fitted(Rect{
		x: 110
		y: 60
		width: 60
		height: 60
	})
	assert moved.points[0] == Point{110, 60}
	assert moved.points[3] == Point{170, 120}

	// Com o dobro do tamanho, o caminho dobra junto e continua começando no canto.
	bigger := mark.fitted(Rect{
		x: 10
		y: 10
		width: 120
		height: 120
	})
	assert bigger.points[0] == Point{10, 10}
	assert bigger.points[3] == Point{130, 130}
	assert bigger.points[1] == Point{50, 90}

	// E a marcação original não foi tocada.
	assert mark.points[3] == Point{70, 70}
}

// Uma caixa sem lado não tem proporção: o ponto acompanha a origem em vez de dividir por
// zero.
fn test_caixa_sem_lado_nao_divide_por_zero() {
	flat := Rect{
		x: 0
		y: 0
		width: 100
		height: 0
	}
	moved := remap(Point{50, 0}, flat, Rect{
		x: 10
		y: 20
		width: 200
		height: 0
	})
	assert moved == Point{110, 20}
}

// O traço livre entra na cena mesmo quando o arrasto não saiu do lugar: um ponto é uma
// marcação. As outras ferramentas continuam precisando de área.
fn test_traco_de_um_ponto_e_valido() {
	assert usable(Rect{ x: 5, y: 5 }, .freehand)
	assert !usable(Rect{ x: 5, y: 5 }, .rectangle)
	assert !usable(Rect{ x: 5, y: 5 }, .line)
}

// Acertar um traço livre é chegar perto do caminho dele, e não cair na caixa — que num
// rabisco é quase toda vazia.
fn test_acerto_do_traco_e_pelo_caminho() {
	mark := Shape{
		tool: .freehand
		area: bounds(sample_stroke())
		color: annotation_color
		thickness: 3
		points: sample_stroke()
	}
	editor := Editor{
		view: Rect{
			width: 500
			height: 500
		}
		scale: 1.0
		scene: Scene{
			shapes: [mark]
		}
	}
	// Sobre o primeiro trecho, entre (10,10) e (30,50).
	assert editor.hits(mark, 20, 30)
	// No canto superior direito da caixa, longe de qualquer trecho.
	assert !editor.hits(mark, 68, 12)
	assert editor.shape_at(20, 30) == 0
	assert editor.shape_at(68, 12) == -1
}

// O marca-texto começa amarelo e largo, e as outras ferramentas começam vermelhas e finas.
// Entrar nele e sair dele leva os dois padrões junto.
fn test_marca_texto_troca_os_padroes_ao_entrar_e_sair() {
	mut editor := Editor{
		tool: .rectangle
	}
	assert editor.color == annotation_color
	assert editor.thickness == annotation_width

	editor.choose(.highlighter)
	assert editor.color == highlight_color
	assert editor.thickness == highlight_thickness

	// Trocar de espessura dentro da mesma família continua valendo.
	editor.thickness = 30
	editor.choose(.highlighter)
	assert editor.thickness == 30

	editor.choose(.line)
	assert editor.color == annotation_color
	assert editor.thickness == annotation_width
}

// O numerador e o borrar começam os dois no 6, mas no numerador o número é o raio, e no borrar é o bloco: passar de um para o outro volta ao padrão do outro, como entre as demais famílias. As ferramentas sem padrão próprio continuam uma família só.
fn test_numerador_e_borrar_sao_familias_diferentes() {
	mut editor := Editor{
		tool: .counter
	}
	editor.thickness = 10
	editor.choose(.blur)
	assert editor.thickness == blur_thickness
	editor.choose(.rectangle)
	editor.thickness = 8
	editor.choose(.arrow)
	assert editor.thickness == 8
}

fn test_so_o_marca_texto_e_translucido() {
	assert stroke_alpha(.highlighter) == highlight_alpha
	assert stroke_alpha(.freehand) == 255
	assert highlight_alpha > 0 && highlight_alpha < 255
}

// Toda ferramenta começa com uma espessura que o controle alcança: fora de 1 a 12, o botão ficaria fora da faixa e a roda afinaria o traço em vez de engrossar.
fn test_espessura_de_partida_cabe_no_controle() {
	for tool in toolbar_tools {
		thickness := default_thickness(tool)
		assert thickness >= min_thickness && thickness <= max_thickness, '${tool}: ${thickness}'
	}
}

// Com uma ferramenta de desenho na mão, as alças e o corpo da marcação selecionada pegam,
// como com a ferramenta de seleção: arrastar o corpo move a marcação.
fn test_alca_e_corpo_pegam_com_ferramenta_de_desenho() {
	editor := Editor{
		view: Rect{
			width: 500
			height: 500
		}
		scale: 1.0
		scene: Scene{
			shapes: [
				Shape{
					tool: .rectangle
					area: Rect{
						x: 100
						y: 100
						width: 200
						height: 100
					}
					color: annotation_color
					thickness: 3
				},
			]
		}
		selected: 0
		tool: .rectangle
	}
	assert editor.grab_at(200, 150) == .body, 'o corpo pega com ferramenta de desenho'
	assert editor.grab_at(300, 200) == .bottom_right
	assert editor.grab_at(200, 100) == .top
	assert editor.grab_at(450, 450) == .none
}

// O numerador tem as três formas da referência — círculo, ponta fina e ponta grossa —, e
// exatamente uma fica acesa, venha de onde vier; o círculo é o padrão, e trocar a forma não
// mexe no resto do estilo.
fn test_o_numerador_tem_tres_formas() {
	assert style_slots(.counter) == style_slots_counter
	assert style_slots_counter.len == 3
	assert style_is_active(Style{}, style_slots_counter.first())
	for index in style_slots_counter {
		style := style_pressed(Style{
			rounded: true
			filled: true
			tip: .thick
		}, index)
		assert style.rounded && style.filled
		for other in style_slots_counter {
			assert style_is_active(style, other) == (other == index), 'botão ${index}, aceso ${other}'
		}
	}
}

// O balão novo sai com a forma escolhida no painel: sem isto, a escolha só mudaria a
// miniatura do botão.
fn test_o_balao_novo_leva_a_forma_do_painel() {
	editor := Editor{
		view: Rect{
			width: 500
			height: 500
		}
		scale: 1.0
		scene: Scene{
			crop: Rect{
				width: 500
				height: 500
			}
		}
		tool: .counter
		thickness: counter_thickness
		style: Style{
			tip: .thick
		}
		origin_x: 100
		origin_y: 100
		cursor_x: 100
		cursor_y: 100
	}
	assert editor.counter_shape().style.tip == .thick
}

// Cada forma sobre fundo branco, com a ponta embaixo à direita: o círculo não passa do
// disco, a ponta grossa enche o canto inteiro, e a fina só a faixa estreita em volta da
// direção dela. Virada para baixo, a ponta fina sai de baixo do disco, e não do canto.
fn test_as_tres_formas_e_a_direcao_da_ponta() ! {
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
	white := u32(0x00ffffff)
	// Raio de 24 com a espessura 6, centrado em (50, 50). (69, 69) fica na diagonal, a 27
	// pixels do centro: fora do disco e dentro das duas pontas. (73, 62) fica fora do disco
	// e longe da direção da ponta fina, mas dentro do canto da grossa.
	area := Rect{
		x: 26
		y: 26
		width: 48
		height: 48
	}
	for tip in [Tip.none, .thin, .thick] {
		paint_rect(surface.dc, Rect{
			width: 100
			height: 100
		}, white)
		draw_counter(surface.dc, Shape{
			tool: .counter
			area: area
			points: [Point{50, 50}, Point{80, 80}]
			color: 0x000000ff
			style: Style{
				tip: tip
			}
		}, area, 6, 1)
		assert (C.GetPixel(surface.dc, 69, 69) != white) == (tip != .none), '${tip} na diagonal'
		assert (C.GetPixel(surface.dc, 73, 62) != white) == (tip == .thick), '${tip} no canto'
	}
	// A mesma ponta fina, virada para baixo: sai de baixo do disco, e a diagonal fica limpa.
	paint_rect(surface.dc, Rect{
		width: 100
		height: 100
	}, white)
	draw_counter(surface.dc, Shape{
		tool: .counter
		area: area
		points: [Point{50, 50}, Point{50, 90}]
		color: 0x000000ff
		style: Style{
			tip: .thin
		}
	}, area, 6, 1)
	assert C.GetPixel(surface.dc, 50, 80) != white
	assert C.GetPixel(surface.dc, 69, 69) == white
}

// Com um balão de ponta escolhido, a alça além da ponta a gira para qualquer ângulo, sem
// mover o balão; no círculo não há alça de ponta.
fn test_a_alca_gira_a_ponta_do_balao() {
	radius := int(counter_radius(f32(counter_thickness)))
	mark := Shape{
		tool: .counter
		area: Rect{
			x: 200 - radius
			y: 200 - radius
			width: 2 * radius
			height: 2 * radius
		}
		color: annotation_color
		thickness: counter_thickness
		style: Style{
			tip: .thin
		}
		points: [Point{200, 200}, Point{300, 200}]
	}
	mut editor := Editor{
		view: Rect{
			width: 500
			height: 500
		}
		scale: 1.0
		scene: Scene{
			crop: Rect{
				width: 500
				height: 500
			}
			shapes: [mark]
		}
		selected: 0
		tool: .select
	}
	// Apontada para a direita, a alça fica à direita do disco, além da ponta.
	handle := tip_handle(mark)
	assert handle.y == 200 && handle.x > 200 + radius * 3 / 2
	grab, lens := editor.part_at(handle.x, handle.y)
	assert grab == .tip && !lens

	// Arrastada para baixo do balão, a ponta passa a apontar para baixo; o balão fica.
	editor.grabbed = mark
	editor.grab = .tip
	editor.origin_x = handle.x
	editor.origin_y = handle.y
	editor.cursor_x = 200
	editor.cursor_y = handle.y + 100
	aimed := editor.grabbed_shape()
	assert aimed.area == mark.area
	assert aimed.points[0] == mark.points[0]
	assert aimed.points[1] == Point{200, 300}

	// No círculo, o mesmo lugar não pega alça de ponta nenhuma.
	editor.scene.shapes[0] = Shape{
		...mark
		style: Style{}
	}
	round_grab, _ := editor.part_at(handle.x, handle.y)
	assert round_grab != .tip
}

// O balão não tem alças de caixa, porque o tamanho dele vem da espessura: um canto da caixa, fora do disco, não pega nada, e o disco pega o corpo.
fn test_o_balao_nao_tem_alcas_de_caixa() {
	radius := int(counter_radius(f32(counter_thickness)))
	mark := Shape{
		tool: .counter
		area: Rect{
			x: 200 - radius
			y: 200 - radius
			width: 2 * radius
			height: 2 * radius
		}
		color: annotation_color
		thickness: counter_thickness
		points: [Point{200, 200}, Point{200 + radius, 200 + radius}]
	}
	editor := Editor{
		view: Rect{
			width: 500
			height: 500
		}
		scale: 1.0
		scene: Scene{
			crop: Rect{
				width: 500
				height: 500
			}
			shapes: [mark]
		}
		selected: 0
		tool: .select
	}
	corner, _ := editor.part_at(200 + radius, 200 + radius)
	assert corner == .none
	body, _ := editor.part_at(200 + radius - 2, 200)
	assert body == .body
}

// Mudar a espessura de um balão escolhido refaz a caixa para o raio novo, em volta do mesmo centro, e a ponta continua virada para onde estava.
fn test_espessura_do_balao_refaz_a_caixa() ! {
	radius := int(counter_radius(f32(counter_thickness)))
	// A captura por baixo deixa o apply montar a imagem de trabalho: sem ela o apply falha, e a espessura volta atrás.
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, 500, 500)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		source.release()
	}
	mut editor := Editor{
		source: source
		canvas_width: 800
		canvas_height: 600
		scene: Scene{
			crop: Rect{
				width: 500
				height: 500
			}
			shapes: [
				Shape{
					tool: .counter
					area: counter_box(Point{200, 200}, counter_thickness)
					color: annotation_color
					thickness: counter_thickness
					style: Style{
						tip: .thin
					}
					points: [Point{200, 200}, Point{300, 200}]
				},
			]
		}
		selected: 0
		tool: .select
	}
	assert editor.scene.shapes[0].area.width == 2 * radius
	editor.set_thickness(10)!
	mark := editor.scene.shapes[0]
	assert mark.area == counter_box(Point{200, 200}, 10)
	assert mark.points[1] == Point{300, 200}
}

// O balão é posto por clique: o centro é onde o arrasto começou, a caixa é a do disco, e a
// ponta aponta embaixo à direita — ou, se o arrasto saiu do disco, para onde ele terminou.
fn test_o_arrasto_aponta_a_ponta_do_balao() {
	mut editor := Editor{
		view: Rect{
			width: 500
			height: 500
		}
		scale: 1.0
		tool: .counter
		thickness: counter_thickness
		color: annotation_color
		origin_x: 200
		origin_y: 200
		cursor_x: 200
		cursor_y: 200
	}
	radius := int(counter_radius(f32(counter_thickness)))

	// Clique seco: a caixa é a do disco, e a ponta aponta embaixo à direita.
	plain := editor.counter_shape()
	assert plain.points[0] == Point{200, 200}
	assert plain.points[1] == Point{200 + radius, 200 + radius}
	assert plain.area == Rect{
		x: 200 - radius
		y: 200 - radius
		width: 2 * radius
		height: 2 * radius
	}

	// Arrasto curto, ainda dentro do disco: não aponta nada.
	editor.cursor_x = 200 + radius - 2
	assert editor.counter_shape().points[1] == Point{200 + radius, 200 + radius}

	// Arrasto que sai do disco: a ponta aponta para onde ele terminou, e a caixa continua a
	// do disco.
	editor.cursor_x = 300
	editor.cursor_y = 260
	aimed := editor.counter_shape()
	assert aimed.points[1] == Point{300, 260}
	assert aimed.area == plain.area
}

// O número sai da contagem na cena, e não de um contador guardado: apagar um do meio
// renumera os seguintes sozinho.
fn test_numero_sai_da_contagem_na_cena() {
	badge := Shape{
		tool: .counter
		color: annotation_color
		thickness: counter_thickness
		points: [Point{10, 10}]
	}
	mut editor := Editor{
		scene: Scene{
			shapes: [
				badge,
				Shape{
					tool: .rectangle
					color: annotation_color
					thickness: 3
				},
				badge,
			]
		}
	}
	// Dois balões na cena, então o próximo é o terceiro. O retângulo no meio não conta.
	assert editor.next_number() == 3
	editor.scene.shapes.delete(0)
	assert editor.next_number() == 2
}

// Acertar um balão é cair dentro do disco. O ponteiro faz parte da caixa mas não do alvo.
fn test_acerto_do_balao_e_o_disco() {
	radius := int(counter_radius(f32(counter_thickness)))
	mark := Shape{
		tool: .counter
		area: Rect{
			x: 200 - radius
			y: 200 - radius
			width: 100 + radius
			height: 60 + radius
		}
		color: annotation_color
		thickness: counter_thickness
		points: [Point{200, 200}, Point{300, 260}]
	}
	editor := Editor{
		view: Rect{
			width: 500
			height: 500
		}
		scale: 1.0
		scene: Scene{
			shapes: [mark]
		}
	}
	assert editor.hits(mark, 200, 200)
	assert editor.hits(mark, 200 + radius - 2, 200)
	assert !editor.hits(mark, 200 + radius + 4, 200)
	// A ponta do ponteiro está dentro da caixa e fora do alvo.
	assert !editor.hits(mark, 298, 258)
}
