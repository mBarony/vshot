module main

// A barra tem dois grupos na mesma fila: as ações à esquerda e as ferramentas depois do
// traço. Os testes daqui olham a fronteira entre os dois, que é onde um erro de conta
// faria um clique cair no grupo errado sem nada parecer estranho na tela.

fn test_the_actions_come_first_and_the_tools_after_the_gap() {
	assert action_button_left(0) == toolbar_margin
	last := action_button_left(toolbar_actions.len - 1) + tool_button_size
	assert last == toolbar_margin + row_width(toolbar_actions.len)
	assert toolbar_tools_left() - last == 2 * toolbar_group_gap
	assert tool_button_left(0) == toolbar_tools_left()
}

// O traço fica no meio do vão, sem encostar em botão nenhum dos dois lados.
fn test_the_separator_sits_between_the_groups() {
	separator := toolbar_margin + row_width(toolbar_actions.len) + toolbar_group_gap
	assert action_at(separator, tool_button_top) == none
	assert tool_at(separator, tool_button_top) == none
	assert separator > action_button_left(toolbar_actions.len - 1) + tool_button_size
	assert separator < tool_button_left(0)
}

// Nenhum ponto da barra pode responder pelos dois grupos, e o centro de cada botão tem de
// devolver justamente o dele.
fn test_no_point_belongs_to_both_groups() {
	for x in 0 .. toolbar_tools_width() + 40 {
		if action_at(x, tool_button_top) != none {
			assert tool_at(x, tool_button_top) == none
		}
	}
	half := tool_button_size / 2
	for index, action in toolbar_actions {
		assert action_at(action_button_left(index) + half, tool_button_top + half)? == action
	}
	for index, tool in toolbar_tools {
		assert tool_at(tool_button_left(index) + half, tool_button_top + half)? == tool
	}
}

// Acima e abaixo da fila de botões não há botão nenhum, mesmo na coluna de um deles.
fn test_the_row_has_a_top_and_a_bottom() {
	middle := action_button_left(0) + tool_button_size / 2
	assert action_at(middle, tool_button_top - 1) == none
	assert action_at(middle, tool_button_top + tool_button_size) == none
	assert action_at(middle, tool_button_top) != none
}

// A barra inteira — ações, ferramentas, mensagem e os três blocos da direita — tem de
// caber na janela mais estreita que o editor aceita.
fn test_the_whole_bar_fits_the_narrowest_window() {
	assert toolbar_tools_width() + status_message_room + status_block_width <= min_client_width
}

// A barra abre com copiar e salvar, nessa ordem, e as ferramentas começam pela que seleciona
// e recorta; o recorte não tem botão próprio.
fn test_a_barra_segue_a_ordem_pedida() {
	assert toolbar_actions == [Action.copy, .save]
	assert toolbar_tools == [Tool.select, .arrow, .text, .ruler, .rectangle, .backdrop, .freehand,
		.magnifier, .blur, .highlighter, .counter, .oval, .line]
}

// O ponteiro sobre uma ação ou uma ferramenta faz a barra dizer o nome e a tecla dela; fora dos botões, volta o estado da edição, que não foi apagado no caminho.
fn test_hovering_an_action_names_it_without_losing_the_status() {
	mut editor := Editor{
		status: 'Retângulo (R)'
	}
	half := tool_button_size / 2
	assert editor.toolbar_message() == 'Retângulo (R)'

	assert editor.track_hover(action_button_left(1) + half, tool_button_top + half)
	assert editor.toolbar_message() == 'Salvar e fechar  (Ctrl+S)'
	// Andar dentro do mesmo botão não é mudança, e não custa um redesenho.
	assert !editor.track_hover(action_button_left(1) + half + 1, tool_button_top + half)

	assert editor.track_hover(tool_button_left(0) + half, tool_button_top + half)
	assert editor.toolbar_message() == 'Selecionar; arraste na imagem para recortar  (V)'
	assert editor.track_hover(tool_button_left(0) + half, toolbar_height + 50)
	assert editor.toolbar_message() == 'Retângulo (R)'
}

// O botão do alinhamento fica depois das ferramentas, sem dividir ponto com elas. O ponteiro sobre ele faz a barra dizer o estado, e o clique troca o estado sem trocar a ferramenta.
fn test_o_botao_do_alinhamento() {
	half := tool_button_size / 2
	spot_x := snap_button_left() + half
	spot_y := tool_button_top + half
	assert tool_at(spot_x, spot_y) == none
	assert !on_snap_button(tool_button_left(toolbar_tools.len - 1) + half, spot_y)
	assert !on_snap_button(spot_x, toolbar_height + 5)
	assert 'snap' in icon_svg
	mut editor := Editor{
		tool: .rectangle
		status: 'Retângulo (R)'
	}
	assert editor.track_hover(spot_x, spot_y)
	assert editor.toolbar_message() == 'Alinhar às bordas: ligado'
	assert !editor.track_hover(spot_x + 1, spot_y)
	dispatch_editor(unsafe { nil }, mut editor, wm_lbuttondblclk, 0, isize(spot_x | (spot_y << 16)))
	assert !editor.config.snap_edges
	assert editor.tool == .rectangle
	assert editor.toolbar_message() == 'Alinhar às bordas: desligado'
	dispatch_editor(unsafe { nil }, mut editor, wm_mouseleave, 0, 0)
	assert !editor.hovered_snap
	assert editor.toolbar_message() == 'Alinhamento desligado'
}

// Na tela o botão fica aceso com o alinhamento ligado e apagado com ele desligado, com o desenho dele nos dois casos.
fn test_o_botao_do_alinhamento_na_tela() ! {
	token := start_gdiplus()!
	defer {
		stop_gdiplus(token)
	}
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, toolbar_tools_width(), toolbar_height)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	mut editor := Editor{
		icons: load_icons()
	}
	defer {
		editor.icons.release()
	}
	whole := Rect{
		width: surface.width
		height: toolbar_height
	}
	face_x := snap_button_left() + 3
	face_y := tool_button_top + tool_button_size / 2
	// A coluna do traço do desenho, em x = 4 do quadrado de 24, que começa 5 pixels depois da borda do botão.
	mark_x := snap_button_left() + (tool_button_size - icon_size) / 2 + 4
	paint_rect(surface.dc, whole, toolbar_color)
	draw_snap_button(surface.dc, &editor)
	assert C.GetPixel(surface.dc, face_x, face_y) == toolbar_active_color
	assert C.GetPixel(surface.dc, mark_x, face_y) != toolbar_active_color
	editor.toggle_snap()
	paint_rect(surface.dc, whole, toolbar_color)
	draw_snap_button(surface.dc, &editor)
	assert C.GetPixel(surface.dc, face_x, face_y) == toolbar_color
	assert C.GetPixel(surface.dc, mark_x, face_y) != toolbar_color
}

// O editor abre com a seleção na mão, sem painel de opções, e a barra diz a ferramenta e a tecla dela, que vem da configuração.
fn test_o_editor_abre_com_a_selecao() {
	mut config := default_config()
	config.tools[toolbar_tools.index(Tool.select)] = u32(`S`)
	editor := editor_start(Frozen{}, unsafe { nil }, config, 800, 600)
	assert editor.tool == .select
	assert editor.options_panel() == none
	assert editor.toolbar_message() == 'Selecionar; arraste na imagem para recortar (S)'
}

// O resultado de um comando toma o lugar do nome do botão sob o ponteiro: uma falha ao salvar não fica escondida atrás de "Salvar e fechar". Andar dentro do botão não traz o nome de volta; sair dele e voltar traz.
fn test_resultado_do_comando_passa_na_frente_do_nome() {
	mut editor := Editor{}
	half := tool_button_size / 2
	assert editor.track_hover(action_button_left(1) + half, tool_button_top + half)
	editor.status = 'Falha ao salvar: x'
	editor.hover_muted = true
	assert editor.toolbar_message() == 'Falha ao salvar: x'
	assert !editor.track_hover(action_button_left(1) + half + 1, tool_button_top + half)
	assert editor.toolbar_message() == 'Falha ao salvar: x'
	assert editor.track_hover(tool_button_left(0) + half, tool_button_top + half)
	assert editor.track_hover(action_button_left(1) + half, tool_button_top + half)
	assert editor.toolbar_message() == 'Salvar e fechar  (Ctrl+S)'
}

// Quando o ponteiro sai da janela com um botão aceso, o botão apaga e a barra volta à mensagem que estava lá.
fn test_ponteiro_que_sai_da_janela_apaga_o_botao() {
	mut editor := Editor{
		status: 'Retângulo (R)'
	}
	half := tool_button_size / 2
	assert editor.track_hover(action_button_left(1) + half, tool_button_top + half)
	editor.background_ready = true
	dispatch_editor(unsafe { nil }, mut editor, wm_mouseleave, 0, 0)
	assert editor.hovered == -1
	assert !editor.background_ready
	assert editor.toolbar_message() == 'Retângulo (R)'
}

// Com CS_DBLCLKS, o segundo clique de um par rápido chega como duplo clique. Sobre a barra ele é só mais um clique, e escolhe a ferramenta em vez de se perder.
// A tabela das ferramentas é lida pela ordem do enum: ela tem uma linha por ferramenta, e a barra as mostra nessa mesma ordem. Fora dela, o rótulo, a tecla, o desenho e a opção de uma ferramenta seriam os de outra.
fn test_a_tabela_das_ferramentas_segue_o_enum() {
	assert tool_info.len == toolbar_tools.len
	for index, tool in toolbar_tools {
		assert int(tool) == index
	}
	assert tool_name(.line) == 'Linha'
	assert tool_shortcut(.select) == 'V'
	assert tool_icon(.ruler) == 'measure'
	assert tool_setting(.freehand) == 'traco_livre'
}

fn test_o_rotulo_da_cor_cabe_no_bloco() ! {
	// O rótulo mais largo, "Tab copia Android", começa 28 pixels depois do início do bloco da cor e tem de acabar antes do traço que o separa do bloco do tamanho: com o bloco de 150 pixels, ele passava do traço e cobria o começo de "Tamanho".
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 400, 40)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	font := C.CreateFontW(-15, 0, 0, 0, 400, 0, 0, 0, default_charset, 0, 0, antialiased_quality,
		0, 'Segoe UI'.to_wide())
	defer {
		C.DeleteObject(font)
	}
	old_font := C.SelectObject(surface.dc, font)
	defer {
		C.SelectObject(surface.dc, old_font)
	}
	block := picker_rect(min_client_width) or { panic('a janela mínima tem o bloco da cor') }
	for name in color_format_names {
		mut measured := C.RECT{}
		C.DrawTextW(surface.dc, 'Tab copia ${name}'.to_wide(), -1, &measured, dt_calcrect | dt_noprefix)
		assert 28 + measured.right <= block.width, name
	}
}

fn test_duplo_clique_na_barra_e_um_clique() {
	mut editor := Editor{
		tool: .rectangle
		config: default_config()
	}
	half := tool_button_size / 2
	arrow := toolbar_tools.index(Tool.arrow)
	spot := isize((tool_button_left(arrow) + half) | ((tool_button_top + half) << 16))
	dispatch_editor(unsafe { nil }, mut editor, wm_lbuttondblclk, 0, spot)
	assert editor.tool == .arrow
}

// Cada ação tem nome, atalho e desenho próprios: sem isso duas delas ficariam
// indistinguíveis numa barra que só mostra ícones.
fn test_every_action_is_told_apart() {
	mut names := []string{}
	mut icons := []string{}
	mut commands := []u32{}
	for action in toolbar_actions {
		assert action_name(action) !in names
		assert action_icon(action) !in icons
		assert action_command(action) !in commands
		assert action_icon(action) in icon_svg
		names << action_name(action)
		icons << action_icon(action)
		commands << action_command(action)
	}
}

// O mesmo para as ferramentas, que agora tiram o desenho da mesma lista.
fn test_every_tool_has_its_own_drawing() {
	mut icons := []string{}
	for tool in toolbar_tools {
		assert tool_icon(tool) !in icons
		assert tool_icon(tool) in icon_svg
		icons << tool_icon(tool)
	}
}

// Uma mensagem mais comprida que o vão é cortada antes do primeiro bloco da direita, e não
// passa por baixo dele. O teste desenha a barra com uma mensagem enorme e confere que a
// faixa entre o fim do vão e o traço dos blocos continua da cor da barra.
fn test_a_mensagem_comprida_nao_invade_os_blocos() ! {
	width := min_client_width
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, width, toolbar_height)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer {
		surface.release()
	}
	paint_rect(surface.dc, Rect{
		width: width
		height: toolbar_height
	}, toolbar_color)
	font := C.CreateFontW(-15, 0, 0, 0, 400, 0, 0, 0, default_charset, 0, 0, antialiased_quality,
		0, 'Segoe UI'.to_wide())
	defer {
		C.DeleteObject(font)
	}
	editor := Editor{
		font: font
		status: 'Copiado UIColor(red: 1.00, green: 0.76, blue: 0.00, alpha: 1.00) e mais um tanto de texto'
	}
	draw_toolbar_status(surface.dc, width, &editor)
	left := width - status_block_width
	for x in left - status_message_gap + 1 .. left - 10 {
		for y in 0 .. toolbar_height {
			assert C.GetPixel(surface.dc, x, y) == toolbar_color, 'pixel ${x},${y}'
		}
	}
}

// Qualquer botão aceso pede o aviso de saída da janela. A ferramenta ficava de fora: da fila dela à barra de título são poucos pixels, e o botão seguia aceso, com a barra dizendo o nome dele, depois de o ponteiro sair.
fn test_o_botao_aceso_pede_o_aviso_de_saida() {
	assert !Editor{}.has_hover()
	assert Editor{
		hovered: 0
	}.has_hover()
	assert Editor{
		hovered_tool: 3
	}.has_hover()
	assert Editor{
		hovered_snap: true
	}.has_hover()
}
