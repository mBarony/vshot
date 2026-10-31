module main

import math

// O conta-gotas tem duas metades: escrever a cor em oito formatos, que é conta pura, e ler
// a cor certa da captura, que é o que se confere aqui sobre superfícies pintadas. Copiar
// para a área de transferência não é testado: um teste que rodasse a cada compilação
// trocaria o que o usuário tem copiado.

// O amarelo do exemplo da referência, #FFC200, em COLORREF, que é 0x00bbggrr.
const amber = u32(0x0000c2ff)

// Os oito formatos, na ordem da referência, escritos como cada plataforma os lê.
fn test_os_oito_formatos() {
	assert color_text(amber, 0) == '#FFC200'
	assert color_text(amber, 1) == 'FFC200'
	assert color_text(amber, 2) == 'rgba(255, 194, 0, 1)'
	assert color_text(amber, 3) == '(1.00, 0.76, 0.00)'
	assert color_text(amber, 4) == '0xFFFFC200'
	assert color_text(amber, 5) == 'UIColor(red: 1.00, green: 0.76, blue: 0.00, alpha: 1.00)'
	assert color_text(amber, 6) == 'Color.FromArgb(255, 255, 194, 0)'
	assert color_format_names.len == 8
}

// Os canais saem da ordem certa: o COLORREF guarda o azul no byte alto, e uma troca aqui
// passaria despercebida num cinza.
fn test_os_canais_saem_na_ordem_certa() {
	assert color_text(0x000000ff, 0) == '#FF0000'
	assert color_text(0x0000ff00, 0) == '#00FF00'
	assert color_text(0x00ff0000, 0) == '#0000FF'
	assert color_text(0x00010203, 0) == '#030201'
}

// O vermelho puro tem OKLCH conhecido — é o exemplo da própria especificação do CSS:
// oklch(62.8% 0.2577 29.23). Branco é claridade um sem croma, e preto é zero.
fn test_oklch_bate_com_a_especificacao() {
	lightness, chroma, hue := oklch(255, 0, 0)
	assert math.abs(lightness - 0.628) < 0.001
	assert math.abs(chroma - 0.2577) < 0.001
	assert math.abs(hue - 29.23) < 0.05
	assert color_text(0x000000ff, 7) == 'oklch(0.628 0.258 29.2)'
	assert color_text(0x00ffffff, 7) == 'oklch(1.000 0.000 0.0)'
	assert color_text(0x00000000, 7) == 'oklch(0.000 0.000 0.0)'
}

// Trocar de formato passa pelos oito e volta ao primeiro.
fn test_o_formato_da_a_volta() {
	mut editor := Editor{}
	for _ in 0 .. color_format_names.len - 1 {
		editor.next_format()
	}
	assert editor.color_format == color_format_names.len - 1
	editor.next_format()
	assert editor.color_format == 0
}

// O conta-gotas só lê onde a imagem está à vista. Com a imagem ampliada passando por baixo da barra e do painel de opções, o ponto sobre eles cai num pixel da imagem, mas a cor lida não seria a que se vê.
fn test_conta_gotas_nao_le_o_que_esta_coberto() ! {
	mut editor := picker_editor()!
	defer {
		editor.current.release()
		editor.source.release()
	}
	editor.tool = .rectangle
	editor.view = Rect{
		width: 900
		height: 700
	}
	editor.scale = 4.5
	assert editor.sample_at(60, 300) != none
	assert editor.sample_at(20, 10) == none
	panel := editor.options_panel() or { panic('o painel deveria existir') }
	assert editor.sample_at(panel.x + 5, panel.y + 5) == none
	assert editor.darkest_near(panel.x + 5, panel.y + 5) == none
}

// A ajuda da régua fica por cima da imagem, e o conta-gotas não lê o que está debaixo dela: a cor lida não seria a que se vê.
fn test_conta_gotas_nao_le_sob_a_ajuda_da_regua() ! {
	mut editor := picker_editor()!
	defer {
		editor.current.release()
		editor.source.release()
	}
	editor.tool = .ruler
	editor.popover = .ruler_help
	editor.view = Rect{
		width: 900
		height: 700
	}
	editor.scale = 4.5
	help := editor.ruler_help_rect() or { panic('a ajuda deveria estar aberta') }
	assert editor.sample_at(help.x + 5, help.y + 5) == none
	assert editor.sample_at(help.x + 5, help.y + help.height + 5) != none
}

// Sem nada acompanhando o ponteiro, o movimento que só troca a cor sob ele redesenha só o bloco da cor: redesenhar a janela inteira custava duas cópias do tamanho dela a cada movimento sobre uma foto. Um arrasto, ou a composição por refazer, ainda pedem a janela inteira.
fn test_so_a_cor_mudou_redesenha_so_o_bloco() {
	mut editor := Editor{
		canvas_width:     min_client_width
		canvas_height:    700
		background_ready: true
	}
	block := picker_rect(editor.canvas_width) or { panic('a janela mínima tem o bloco da cor') }
	colour := editor.dirty_area(true) or { panic('a cor mudou, e o bloco dela é redesenhado') }
	assert colour == block
	assert editor.dirty_area(false) == none
	editor.dragging = true
	whole := editor.dirty_area(false) or { panic('o arrasto redesenha a janela inteira') }
	assert whole.width == editor.canvas_width
	assert whole.height == toolbar_height + editor.canvas_height
}

// picker_editor monta um editor sobre uma captura branca com um quadrado vermelho e um
// único pixel preto.
fn picker_editor() !Editor {
	screen := C.GetDC(unsafe { nil })
	source := new_surface(screen, 200, 100)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(source.dc, Rect{
		width: 200
		height: 100
	}, 0x00ffffff)
	paint_rect(source.dc, Rect{
		x: 50
		y: 20
		width: 20
		height: 20
	}, 0x000000ff)
	C.SetPixel(source.dc, 150, 60, 0x00000000)
	mut editor := Editor{
		source: source
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

fn C.SetPixel(hdc voidptr, x int, y int, color u32) u32

// A cor lida é a da captura sob o ponteiro, e fora da imagem não há leitura.
fn test_le_a_cor_sob_o_ponteiro() ! {
	mut editor := picker_editor()!
	assert editor.sample_at(editor.view.x + 60, editor.view.y + 30)? == 0x000000ff
	assert editor.sample_at(editor.view.x + 10, editor.view.y + 10)? == 0x00ffffff
	assert editor.sample_at(editor.view.x - 5, editor.view.y + 10) == none
}

// A cor só é dita mudada quando muda: andar sobre a mesma cor não pede redesenho.
fn test_so_redesenha_quando_a_cor_muda() ! {
	mut editor := picker_editor()!
	assert editor.sample_cursor(editor.view.x + 60, editor.view.y + 30)
	assert editor.sampled == 0x000000ff
	assert !editor.sample_cursor(editor.view.x + 61, editor.view.y + 31)
	// Fora da imagem a última cor continua valendo.
	assert !editor.sample_cursor(editor.view.x - 5, editor.view.y)
	assert editor.sampled == 0x000000ff
}

// Perto de um pixel preto, a cor mais escura é ele, mesmo com o ponteiro sobre o branco; a
// dez pixels de distância ele ainda conta, a trinta não.
fn test_a_mais_escura_em_volta_acha_a_letra() ! {
	mut editor := picker_editor()!
	close_by := editor.to_client(Rect{
		x: 154
		y: 60
	})
	assert editor.darkest_near(close_by.x, close_by.y)? == 0x00000000
	away := editor.to_client(Rect{
		x: 180
		y: 60
	})
	assert editor.darkest_near(away.x, away.y)? == 0x00ffffff
}

// O bloco da cor fica onde os blocos da direita começam, e some com eles numa janela
// estreita demais.
fn test_o_bloco_some_com_os_outros() {
	wide := picker_rect(min_client_width) or { panic('a janela mínima tem os blocos') }
	assert wide.x == min_client_width - status_block_width
	assert wide.x >= toolbar_tools_width()
	assert picker_rect(toolbar_tools_width() + status_block_width - 1) == none
}
