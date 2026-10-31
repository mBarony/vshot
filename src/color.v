module main

#flag windows -lcomdlg32

#include <commdlg.h>

fn C.ChooseColorW(choice voidptr) bool

// @[typedef] porque CHOOSECOLORW é um typedef no commdlg.h: sem isso o V escreve
// `struct CHOOSECOLORW`, que não existe.
@[typedef]
struct C.CHOOSECOLORW {
mut:
	lStructSize    u32
	hwndOwner      voidptr
	hInstance      voidptr
	rgbResult      u32
	lpCustColors   &u32 = unsafe { nil }
	Flags          u32
	lCustData      isize
	lpfnHook       voidptr
	lpTemplateName &u16 = unsafe { nil }
}

// CC_RGBINIT abre o diálogo já na cor que se passa, e CC_FULLOPEN mostra o seletor
// contínuo aberto em vez de escondido atrás de um botão.
const cc_rgbinit = u32(0x00000001)
const cc_fullopen = u32(0x00000002)

// O diálogo do Windows guarda dezesseis cores "personalizadas". Preencher as primeiras com
// as cores de marcação mais usadas as deixa a um clique, sem inventar uma paleta própria
// flutuando por cima do editor.
const quick_colors = [
	u32(0x000000ff), // vermelho
	u32(0x000080ff), // laranja
	u32(0x0000d7ff), // amarelo
	u32(0x0000c000), // verde
	u32(0x00c08000), // azul
	u32(0x00e01080), // roxo
	u32(0x00000000), // preto
	u32(0x00ffffff), // branco
]
const custom_color_slots = 16

// A grade de cores: quatro colunas por duas linhas, e o botão do seletor embaixo.
const palette_columns = 4
const palette_cell = 28
const palette_gap = 6
const palette_padding = 12
const palette_drop = 6
const custom_height = 26
const custom_gap = 8
const palette_width = 2 * palette_padding + palette_columns * palette_cell + (palette_columns - 1) * palette_gap
const palette_height = 2 * palette_padding + 2 * palette_cell + palette_gap + custom_gap + custom_height

const palette_color = u32(0x00262626)
const palette_ring_color = u32(0x00ffffff)

// palette_rect devolve onde a paleta está, ou none quando ela não está aberta. Ela pende
// do disco de cor, e não da borda do painel, para ficar claro de onde saiu.
fn (e Editor) palette_rect() ?Rect {
	if !e.palette_open {
		return none
	}
	panel := e.options_panel()?
	if !has_swatch(e.options_tool()) {
		return none
	}
	swatch := swatch_rect(panel)
	return Rect{
		x: clamp(swatch.x + swatch.width / 2 - palette_width / 2, options_margin, e.canvas_width - palette_width - options_margin)
		y: panel.y + panel.height + palette_drop
		width: palette_width
		height: palette_height
	}
}

// settle_palette fecha a paleta que ficou sem lugar. Ela pende do painel de opções, e quando um clique ou uma tecla o levam embora — Selecionar sem nada escolhido, uma ferramenta sem cor, um arrasto, o painel do tamanho ou o do zoom —, ela fecha junto: aberta sem painel, ela voltava sozinha quando o painel voltasse.
fn (mut e Editor) settle_palette() {
	if e.palette_rect() == none {
		e.palette_open = false
	}
}

// palette_cell_rect devolve o quadrado da cor de índice `index` na grade.
fn palette_cell_rect(palette Rect, index int) Rect {
	return Rect{
		x: palette.x + palette_padding + (index % palette_columns) * (palette_cell + palette_gap)
		y: palette.y + palette_padding + (index / palette_columns) * (palette_cell + palette_gap)
		width: palette_cell
		height: palette_cell
	}
}

// palette_custom_rect devolve o botão que abre o seletor do Windows.
fn palette_custom_rect(palette Rect) Rect {
	return Rect{
		x: palette.x + palette_padding
		y: palette.y + palette_padding + 2 * palette_cell + palette_gap + custom_gap
		width: palette.width - 2 * palette_padding
		height: custom_height
	}
}

// palette_color_at devolve a cor sob o ponto, ou none se ele caiu fora da grade.
fn (e Editor) palette_color_at(x int, y int) ?u32 {
	palette := e.palette_rect()?
	for index, color in quick_colors {
		if contains(palette_cell_rect(palette, index), x, y) {
			return color
		}
	}
	return none
}

// apply_color aplica a cor à marcação selecionada, e guarda-a para as próximas. Com uma
// marcação selecionada a troca entra no histórico; sem nenhuma, só o padrão muda.
// A cor que a marcação já tem não é troca: guardá-la no histórico deixaria um desfazer que não desfaz nada, e apagaria o refazer.
fn (mut e Editor) apply_color(color u32) string {
	previous := e.color
	if e.sets_default() {
		e.color = color
	}
	if e.selected < 0 || e.selected >= e.scene.shapes.len {
		return 'Cor trocada'
	}
	if e.scene.shapes[e.selected].color == color {
		return 'Cor trocada'
	}
	e.record()
	e.scene.shapes[e.selected] = Shape{
		...e.scene.shapes[e.selected]
		color: color
	}
	// Sem a imagem nova, o padrão volta junto com a cena, como na espessura: senão as próximas marcações sairiam com a cor que a barra acabou de dizer que falhou.
	e.apply() or {
		e.rollback()
		e.color = previous
		return 'Falha ao trocar a cor: ${err}'
	}
	return 'Cor trocada'
}

// draw_palette desenha a grade de cores e o botão do seletor.
fn draw_palette(hdc voidptr, e &Editor, palette Rect) {
	draw_panel(hdc, palette, palette_color)

	current := e.current_color()
	for index, color in quick_colors {
		box := palette_cell_rect(palette, index)
		if color == current {
			// A cor em vigor ganha um anel, que é o que a distingue sem mudar o tamanho
			// dela e desalinhar a grade.
			fill_rounded(hdc, grow(box, 2), palette_ring_color, button_radius + 2)
		}
		fill_rounded(hdc, box, color, button_radius)
	}
	draw_custom_button(hdc, e, palette_custom_rect(palette))
}

// draw_custom_button desenha o botão que abre o seletor do Windows.
fn draw_custom_button(hdc voidptr, e &Editor, box Rect) {
	fill_button(hdc, box, button_face_color)
	old_font := C.SelectObject(hdc, e.font)
	C.SetBkMode(hdc, transparent_bk)
	C.SetTextColor(hdc, toolbar_text_color)
	centered_text(hdc, box, 'Personalizada')
	C.SelectObject(hdc, old_font)
}

// ask_color abre o seletor de cores do Windows e devolve a cor escolhida, ou none se o
// usuário desistir.
fn ask_color(owner voidptr, current u32) ?u32 {
	// O vetor precisa sobreviver à chamada e ter os dezesseis lugares: o diálogo escreve
	// nele quando o usuário monta uma cor nova.
	mut custom := []u32{len: custom_color_slots, init: 0x00ffffff}
	for index, color in quick_colors {
		custom[index] = color
	}
	mut choice := C.CHOOSECOLORW{
		lStructSize: u32(sizeof(C.CHOOSECOLORW))
		hwndOwner: owner
		rgbResult: current
		lpCustColors: &u32(custom.data)
		Flags: cc_rgbinit | cc_fullopen
	}
	if !C.ChooseColorW(&choice) {
		return none
	}
	return choice.rgbResult
}
