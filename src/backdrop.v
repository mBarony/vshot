module main

fn C.CreateRoundRectRgn(left int, top int, right int, bottom int, width int, height int) voidptr

// A moldura é a única coisa do editor que não é desenhada sobre a imagem: ela põe a imagem
// inteira dentro de outra, maior. Por isso o resultado muda de tamanho, e todas as contas
// que levam um ponto da captura até a janela passam a somar a folga que ela acrescenta.
//
// Ela é guardada na cena como as marcações, e não num campo à parte: assim desfazer,
// refazer, o painel de opções e a tecla Delete valem para ela sem nada novo. O que a
// distingue é que há no máximo uma, ela não é criada por arrasto, e ela é aplicada depois
// de todas as outras — porque não é uma marcação sobre a imagem, é a imagem dentro de
// outra.

// A folga em pixels sai da espessura do painel: um a doze viram dez a cento e vinte.
const backdrop_step = 10
// A espessura com que a moldura começa, que dá uma folga de sessenta pixels.
const backdrop_thickness = 6
// Um azul de fundo, que é a cor com que a referência abre.
const backdrop_color = u32(0x00c86e28)
// A sombra é feita de camadas concêntricas, cada uma quase transparente: somadas, elas dão
// o degradê que uma sombra suave tem. Desenhar uma sombra de verdade exigiria borrar um
// bitmap com alfa, que o GDI não guarda.
const shadow_layers = 12
const shadow_alpha = u8(16)
const shadow_drop = 4

// backdrop_of devolve a moldura da cena, se houver uma.
fn backdrop_of(scene Scene) ?Shape {
	for shape in scene.shapes {
		if shape.tool == .backdrop {
			return shape
		}
	}
	return none
}

// backdrop_margin é a folga que a moldura acrescenta de cada lado.
fn backdrop_margin(thickness int) int {
	return thickness * backdrop_step
}

// scene_margin é quanto a imagem de trabalho cresceu por causa da moldura. Sem moldura é
// zero, e aí todas as conversões de coordenada seguem valendo como valiam.
fn scene_margin(scene Scene) int {
	shape := backdrop_of(scene) or { return 0 }
	return backdrop_margin(shape.thickness)
}

// backdrop_radius é o arredondamento do canto da imagem dentro da moldura.
fn backdrop_radius(margin int) int {
	return max(margin / 3, 4)
}

// wrap_backdrop devolve a imagem dentro da moldura. A original não é tocada: quem chama
// decide o que fazer com ela.
fn wrap_backdrop(inner Frozen, mark Shape) !Frozen {
	margin := backdrop_margin(mark.thickness)
	framed := new_surface(inner.dc, inner.width + 2 * margin, inner.height + 2 * margin)!
	paint_rect(framed.dc, Rect{
		width: framed.width
		height: framed.height
	}, mark.color)
	seat := Rect{
		x: margin
		y: margin
		width: inner.width
		height: inner.height
	}
	// O canto é preso a um terço do lado menor, como nas marcações: numa captura baixa, o raio da folga larga fazia das pontas da imagem semicírculos, e comia bem mais que a quina.
	radius := if mark.style.rounded {
		min(backdrop_radius(margin), min(inner.width, inner.height) / 3)
	} else {
		0
	}
	if mark.style.shadow {
		// As camadas cabem na folga, com dois pixels de sobra: na largura 1 as doze passavam da borda, e a sombra terminava numa faixa cinza cortada em vez de sumir na cor da moldura.
		draw_backdrop_shadow(framed.dc, seat, radius, min(shadow_layers, margin - shadow_drop - 2))
	}
	if !place_inner(framed, inner, seat, radius) {
		framed.release()
		return error('BitBlt da moldura falhou')
	}
	return framed
}

// place_inner assenta a imagem no meio da moldura, recortada no canto arredondado quando o
// estilo pede.
fn place_inner(framed Frozen, inner Frozen, seat Rect, radius int) bool {
	if radius > 0 {
		region := C.CreateRoundRectRgn(seat.x, seat.y, seat.x + seat.width + 1, seat.y +
			seat.height + 1, radius * 2, radius * 2)
		C.SelectClipRgn(framed.dc, region)
		defer {
			C.SelectClipRgn(framed.dc, unsafe { nil })
			C.DeleteObject(region)
		}
		return C.BitBlt(framed.dc, seat.x, seat.y, inner.width, inner.height, inner.dc,
			0, 0, srccopy)
	}
	return C.BitBlt(framed.dc, seat.x, seat.y, inner.width, inner.height, inner.dc, 0,
		0, srccopy)
}

// draw_backdrop_shadow desenha a sombra sob a imagem: camadas concêntricas quase
// transparentes, da mais larga para a mais estreita. Somadas, elas escurecem mais perto da
// imagem e desaparecem para fora, que é o que uma sombra faz.
// Só as faixas em volta do miolo são pintadas, com um contexto e um pincel para todas: o miolo a imagem cobre logo depois, e misturar doze camadas do tamanho dela, cada uma com contexto e pincel próprios, custava centenas de milissegundos por edição numa captura grande.
// `layers` é quantas camadas cabem na folga.
fn draw_backdrop_shadow(hdc voidptr, seat Rect, radius int, layers int) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	mut brush := voidptr(unsafe { nil })
	if C.GdipCreateSolidFill(to_argb_alpha(0x00000000, shadow_alpha), &brush) != 0 {
		return
	}
	defer {
		C.GdipDeleteBrush(brush)
	}
	for strip in shadow_strips(seat, radius) {
		C.GdipSetClipRectI(graphics, strip.x, strip.y, strip.width, strip.height, combine_mode_replace)
		for layer := layers; layer > 0; layer-- {
			path := corner_path(shadow_layer(seat, layer), radius + layer) or { continue }
			C.GdipFillPath(graphics, brush, path)
			C.GdipDeletePath(path)
		}
	}
}

// shadow_layer devolve a caixa de uma camada da sombra: a imagem alargada de cada lado e descida um pouco.
fn shadow_layer(seat Rect, layer int) Rect {
	return Rect{
		x: seat.x - layer
		y: seat.y - layer + shadow_drop
		width: seat.width + 2 * layer
		height: seat.height + 2 * layer
	}
}

// shadow_strips devolve as faixas em volta do miolo que a imagem cobre, que é onde a sombra aparece: em cima, embaixo e dos dois lados, sem se sobrepor. O miolo é a imagem encolhida do raio do canto, que ela cobre por inteiro mesmo arredondada. Numa imagem menor que dois cantos não há miolo, e a faixa é a sombra toda.
fn shadow_strips(seat Rect, radius int) []Rect {
	pad := shadow_layers + 2
	outer := Rect{
		x: seat.x - pad
		y: seat.y - pad
		width: seat.width + 2 * pad
		height: seat.height + 2 * pad + shadow_drop
	}
	top := seat.y + radius
	bottom := seat.y + seat.height - radius
	left := seat.x + radius
	right := seat.x + seat.width - radius
	if right <= left || bottom <= top {
		return [outer]
	}
	return [
		Rect{
			...outer
			height: top - outer.y
		},
		Rect{
			...outer
			y: bottom
			height: outer.y + outer.height - bottom
		},
		Rect{
			x: outer.x
			y: top
			width: left - outer.x
			height: bottom - top
		},
		Rect{
			x: right
			y: top
			width: outer.x + outer.width - right
			height: bottom - top
		},
	]
}

// use_backdrop escolhe a moldura que já existe, ou põe uma nova. Ela não nasce de um
// arrasto: escolher a ferramenta já é o gesto, e o painel governa o resto.
fn (mut e Editor) use_backdrop() string {
	for index, shape in e.scene.shapes {
		if shape.tool == .backdrop {
			e.selected = index
			return 'Moldura'
		}
	}
	e.record()
	e.scene.shapes << Shape{
		tool: .backdrop
		color: backdrop_color
		thickness: backdrop_thickness
		style: Style{
			rounded: true
			shadow: true
		}
	}
	e.selected = e.scene.shapes.len - 1
	e.apply() or {
		e.rollback()
		e.selected = -1
		return 'Falha ao pôr a moldura: ${err}'
	}
	return 'Moldura posta'
}

// draw_shadow_sample desenha a miniatura dos dois botões de sombra: um quadro com a mancha
// atrás dele e um quadro sozinho.
fn draw_shadow_sample(hdc voidptr, area Rect, shadow bool, color u32) {
	block := Rect{
		x: area.x
		y: area.y
		width: area.width - 3
		height: area.height - 3
	}
	if shadow {
		fill_round_rect(hdc, Rect{
			x: block.x + 3
			y: block.y + 3
			width: block.width
			height: block.height
		}, 2, color, 110)
	}
	paint_rect(hdc, block, color)
}
