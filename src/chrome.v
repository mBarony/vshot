module main

// O acabamento das caixas e dos botões do editor: as caixas flutuantes — o painel de opções, a paleta, os painéis do tamanho e do zoom, a ajuda da régua — com quinas arredondadas, borda fina e uma sombra difusa embaixo, e os botões arredondados. Tudo pelo GDI+, suavizado: pelo GDI as quinas sairiam serrilhadas.

// Raio das quinas das caixas e dos botões.
const chrome_radius = 8
const button_radius = 6
// A borda das caixas, um tom acima do fundo delas: marca o contorno sem pesar.
const panel_border_color = u32(0x00474747)
// O fundo dos botões em repouso nos painéis, e o do botão da barra sob o ponteiro.
const button_face_color = u32(0x003c3c3c)
// A sombra das caixas e da imagem: quantas camadas, cada uma um pixel maior que a anterior, quanto ela desce, e quanto cada camada escurece — somadas perto da borda, dão um cinza suave, e somem na ponta.
const panel_shadow_spread = 8
const panel_shadow_drop = 3
const panel_shadow_alpha = u8(9)

// draw_panel desenha uma caixa flutuante: a sombra difusa, a borda fina e o fundo, as duas arredondadas. A borda é um fundo de tom mais claro, e o fundo de verdade vem por cima, um pixel para dentro: uma linha de um pixel suavizada sobre coordenadas inteiras sairia borrada em dois.
fn draw_panel(hdc voidptr, panel Rect, color u32) {
	fill_shadow(hdc, panel, chrome_radius)
	fill_round_rect(hdc, panel, chrome_radius, panel_border_color, 255)
	fill_round_rect(hdc, grow(panel, -1), chrome_radius - 1, color, 255)
}

// fill_button pinta o fundo arredondado de um botão.
fn fill_button(hdc voidptr, area Rect, color u32) {
	fill_round_rect(hdc, area, button_radius, color, 255)
}

// fill_shadow desenha a sombra difusa de uma caixa: camadas de preto quase transparente, cada uma um pixel maior que a anterior e descidas um pouco, que somadas escurecem perto da caixa e somem longe dela. O miolo fica fora do recorte, porque a caixa o cobre logo depois: sem isso cada camada misturaria a área inteira, e sob a imagem ampliada seriam oito misturas do tamanho da janela a cada composição.
fn fill_shadow(hdc voidptr, area Rect, radius int) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	C.GdipSetClipRectI(graphics, area.x, area.y, area.width, area.height, combine_mode_exclude)
	mut brush := voidptr(unsafe { nil })
	if C.GdipCreateSolidFill(to_argb_alpha(0, panel_shadow_alpha), &brush) != 0 {
		return
	}
	defer {
		C.GdipDeleteBrush(brush)
	}
	for layer in 1 .. panel_shadow_spread + 1 {
		box := grow(area, layer)
		path := corner_path(Rect{
			...box
			y: box.y + panel_shadow_drop
		}, radius + layer) or { continue }
		C.GdipFillPath(graphics, brush, path)
		C.GdipDeletePath(path)
	}
}
