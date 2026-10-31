module main

fn C.GetPixel(hdc voidptr, x int, y int) u32

// A ferramenta de borrar, que é a primeira que mexe no conteúdo da imagem em vez de
// desenhar por cima. Ela tem dois modos, e nenhum deles precisa de cor: borrar reduz a
// área a blocos chapados, e apagar a cobre com a média das cores que havia ali.
//
// O borrão sai de duas passadas do próprio GDI: a área encolhe com interpolação, que faz a
// média dos pixels, e volta ao tamanho sem interpolação, que repete cada pixel num bloco.
// Uma convolução escrita à mão daria um desfoque suave, mas seria um laço sobre os pixels
// a cada quadro da prévia — e a referência mostra justamente o mosaico, não o desfoque.

// STRETCH_COLORONCOLOR devolve o pixel mais próximo, sem misturar: é o que transforma a
// miniatura em blocos.
const stretch_coloroncolor = 3

// O lado do bloco em pixels, a partir da espessura. Um a doze viram dois a vinte e quatro.
const blur_grain = 2
// A espessura com que a ferramenta começa, que dá blocos de doze pixels.
const blur_thickness = 6

// blur_block devolve o lado do bloco do mosaico.
fn blur_block(thickness f32) int {
	return max(int(thickness * blur_grain), 2)
}

// draw_blur aplica o modo pedido sobre a área. Ela lê da mesma superfície em que escreve,
// que é o que a diferencia das outras marcações.
fn draw_blur(hdc voidptr, mark Shape, area Rect) {
	if area.width < 1 || area.height < 1 {
		return
	}
	if mark.style.erase {
		erase_area(hdc, area)
		return
	}
	// Os blocos são contados pela caixa da marcação, que está em pixels da captura na prévia e no resultado: com a imagem reduzida, a prévia tem o mesmo número de blocos do resultado, e não o grão mais fino que a espessura reduzida dela, truncada e com piso, dava.
	block := blur_block(f32(mark.thickness))
	shrink(hdc, area, max(mark.area.width / block, 1), max(mark.area.height / block, 1))
}

// shrink encolhe a área para o tamanho dado e a devolve ao lugar. A ida faz a média das
// cores; a volta repete cada pixel, e é ela que produz os blocos.
fn shrink(hdc voidptr, area Rect, width int, height int) {
	tiny := new_surface(hdc, width, height) or { return }
	defer {
		tiny.release()
	}
	C.SetStretchBltMode(tiny.dc, stretch_halftone)
	C.SetBrushOrgEx(tiny.dc, 0, 0, unsafe { nil })
	C.StretchBlt(tiny.dc, 0, 0, width, height, hdc, area.x, area.y, area.width, area.height,
		srccopy)
	C.SetStretchBltMode(hdc, stretch_coloroncolor)
	C.StretchBlt(hdc, area.x, area.y, area.width, area.height, tiny.dc, 0, 0, width, height,
		srccopy)
}

// erase_area cobre a área com a média das cores que havia nela. Apagar com uma cor
// escolhida deixaria um retângulo que salta à vista; com a média, o que sai é um bloco que
// se acomoda no que está em volta — e não há cor para escolher, que é o que a referência
// mostra no painel desta ferramenta.
fn erase_area(hdc voidptr, area Rect) {
	tiny := new_surface(hdc, 1, 1) or { return }
	defer {
		tiny.release()
	}
	C.SetStretchBltMode(tiny.dc, stretch_halftone)
	C.SetBrushOrgEx(tiny.dc, 0, 0, unsafe { nil })
	C.StretchBlt(tiny.dc, 0, 0, 1, 1, hdc, area.x, area.y, area.width, area.height, srccopy)
	paint_rect(hdc, area, C.GetPixel(tiny.dc, 0, 0))
}

// draw_blur_sample desenha a miniatura dos dois botões de estilo: um quadro repartido em
// blocos e um quadro chapado. A referência põe aqui os nomes escritos — "Blur", "Blur
// Text", "Erase", "Erase Text" —, mas botões com palavra exigiriam largura por botão em
// todo o painel, e são quatro modos dos quais só dois estão aqui.
fn draw_blur_sample(hdc voidptr, area Rect, erase bool, color u32) {
	if erase {
		paint_rect(hdc, area, color)
		return
	}
	// Quatro blocos em xadrez, que é a menor figura que se lê como mosaico.
	across := area.width / 2
	down := area.height / 2
	paint_rect(hdc, Rect{
		x: area.x
		y: area.y
		width: across
		height: down
	}, color)
	paint_rect(hdc, Rect{
		x: area.x + across
		y: area.y + down
		width: area.width - across
		height: area.height - down
	}, color)
}

// paint_rect preenche o retângulo com uma cor chapada.
fn paint_rect(hdc voidptr, area Rect, color u32) {
	brush := C.CreateSolidBrush(color)
	mut box := C.RECT{
		left: area.x
		top: area.y
		right: area.x + area.width
		bottom: area.y + area.height
	}
	C.FillRect(hdc, &box, brush)
	C.DeleteObject(brush)
}
