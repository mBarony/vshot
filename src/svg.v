module main

// O subconjunto de SVG que os ícones usam: `rect`, `circle` e `path`, com os comandos
// M, L, H, V, C, A e Z nas formas absoluta e relativa. Não é um leitor de SVG de verdade,
// e não pretende ser — é o suficiente para os arquivos de `assets/icons`, que são desenhos
// de linha de 24 por 24 sem transformações, gradientes nem grupos.
//
// O desenho sai em caminhos do GDI+, montados uma vez na abertura do editor. Rasterizar os
// ícones num arquivo à parte seria menos código, mas traria um artefato gerado ao
// repositório e um passo de build dependente de um navegador.

// SvgFigure é uma forma do desenho, já convertida em caminho do GDI+.
struct SvgFigure {
	path         voidptr
	filled       bool
	fill_alpha   u8
	stroked      bool
	stroke_width f32
}

// IconArt é um ícone inteiro, pronto para ser desenhado quantas vezes for preciso.
struct IconArt {
	figures []SvgFigure
}

// FillModeWinding, que é a regra de preenchimento padrão do SVG.
const fill_mode_winding = 1
// LineJoinRound e LineCapRound, para casar com o stroke-linejoin dos arquivos.
const line_join_round = 2

// parse_svg lê o desenho e devolve os caminhos dele. Precisa do GDI+ ligado.
fn parse_svg(text string) IconArt {
	root := first_tag(text, 'svg') or { return IconArt{} }
	base_width := attribute(root, 'stroke-width') or { '1' }
	mut figures := []SvgFigure{}
	for tag in tags(text) {
		path := shape_path(tag) or { continue }
		width := attribute(tag, 'stroke-width') or { base_width }
		figures << SvgFigure{
			path: path
			filled: paints(tag, 'fill')
			fill_alpha: u8(255 * (attribute(tag, 'fill-opacity') or { '1' }).f64())
			stroked: paints(tag, 'stroke')
			stroke_width: f32(width.f64())
		}
	}
	return IconArt{
		figures: figures
	}
}

// release devolve ao GDI+ os caminhos do ícone.
fn (art IconArt) release() {
	for figure in art.figures {
		C.GdipDeletePath(figure.path)
	}
}

// paints diz se o atributo de pintura tem cor. Os arquivos usam `currentColor` para pintar
// e `none` para não pintar, e o que não é dito no elemento vem da raiz — onde `fill` é
// sempre `none` e `stroke` é sempre `currentColor`.
fn paints(tag string, name string) bool {
	value := attribute(tag, name) or { return name == 'stroke' }
	return value != 'none'
}

// shape_path monta o caminho da forma, ou none se o elemento não for uma delas.
fn shape_path(tag string) ?voidptr {
	name := tag_name(tag)
	if name !in ['rect', 'circle', 'path'] {
		return none
	}
	mut path := voidptr(unsafe { nil })
	if C.GdipCreatePath(fill_mode_winding, &path) != 0 {
		return none
	}
	match name {
		'rect' { add_rect(path, tag) }
		'circle' { add_circle(path, tag) }
		else { add_path_data(path, attribute(tag, 'd') or { '' }) }
	}
	return path
}

// add_rect acrescenta o retângulo, com os cantos arredondados que `rx` pedir.
fn add_rect(path voidptr, tag string) {
	x := number(tag, 'x')
	y := number(tag, 'y')
	width := number(tag, 'width')
	height := number(tag, 'height')
	radius := number(tag, 'rx')
	if radius <= 0 {
		C.GdipAddPathLine(path, f32(x), f32(y), f32(x + width), f32(y))
		C.GdipAddPathLine(path, f32(x + width), f32(y), f32(x + width), f32(y + height))
		C.GdipAddPathLine(path, f32(x + width), f32(y + height), f32(x), f32(y + height))
		C.GdipClosePathFigure(path)
		return
	}
	side := f32(radius * 2)
	C.GdipAddPathArc(path, f32(x), f32(y), side, side, 180, 90)
	C.GdipAddPathArc(path, f32(x + width) - side, f32(y), side, side, 270, 90)
	C.GdipAddPathArc(path, f32(x + width) - side, f32(y + height) - side, side, side, 0,
		90)
	C.GdipAddPathArc(path, f32(x), f32(y + height) - side, side, side, 90, 90)
	C.GdipClosePathFigure(path)
}

// add_circle acrescenta o círculo, que o GDI+ desenha como elipse inscrita numa caixa.
fn add_circle(path voidptr, tag string) {
	radius := number(tag, 'r')
	C.GdipAddPathEllipse(path, f32(number(tag, 'cx') - radius), f32(number(tag, 'cy') - radius),
		f32(radius * 2), f32(radius * 2))
}

// number lê um atributo numérico, ou zero se ele não estiver lá.
fn number(tag string, name string) f64 {
	return (attribute(tag, name) or { '0' }).f64()
}

// draw_art desenha o ícone com o canto superior esquerdo em (x, y), na cor pedida.
fn draw_art(hdc voidptr, art IconArt, x int, y int, color u32) {
	mut graphics := voidptr(unsafe { nil })
	if C.GdipCreateFromHDC(hdc, &graphics) != 0 {
		return
	}
	defer {
		C.GdipDeleteGraphics(graphics)
	}
	C.GdipSetSmoothingMode(graphics, smoothing_antialias)
	// O desenho vem em coordenadas do próprio ícone; quem o põe no lugar é a translação.
	C.GdipTranslateWorldTransform(graphics, f32(x), f32(y), 0)
	for figure in art.figures {
		draw_figure(graphics, figure, color)
	}
	C.GdipResetWorldTransform(graphics)
}

// draw_figure pinta o miolo e depois o contorno, nessa ordem, para o traço não ficar por
// baixo do preenchimento.
fn draw_figure(graphics voidptr, figure SvgFigure, color u32) {
	if figure.filled {
		mut brush := voidptr(unsafe { nil })
		if C.GdipCreateSolidFill(to_argb_alpha(color, figure.fill_alpha), &brush) == 0 {
			C.GdipFillPath(graphics, brush, figure.path)
			C.GdipDeleteBrush(brush)
		}
	}
	if !figure.stroked {
		return
	}
	mut pen := voidptr(unsafe { nil })
	if C.GdipCreatePen1(to_argb(color), figure.stroke_width, unit_pixel, &pen) != 0 {
		return
	}
	C.GdipSetPenStartCap(pen, line_cap_round)
	C.GdipSetPenEndCap(pen, line_cap_round)
	C.GdipSetPenLineJoin(pen, line_join_round)
	C.GdipDrawPath(graphics, pen, figure.path)
	C.GdipDeletePen(pen)
}

// add_path_data percorre o atributo `d` e acrescenta ao caminho o que ele descreve. Um
// comando sem letra repete o anterior, e depois de um `moveto` a repetição vira `lineto` —
// as duas regras do SVG que mais aparecem nestes arquivos.
fn add_path_data(path voidptr, data string) {
	mut scanner := PathScanner{
		data: data
	}
	mut command := u8(0)
	mut cursor := Pointf{}
	mut opening := Pointf{}
	for {
		scanner.skip()
		if scanner.done() {
			break
		}
		if is_command(scanner.data[scanner.pos]) {
			command = scanner.data[scanner.pos]
			scanner.pos++
		}
		if command == 0 {
			break
		}
		relative := command >= `a`
		match command | 0x20 {
			`m` {
				cursor = scanner.point(cursor, relative)
				C.GdipStartPathFigure(path)
				opening = cursor
				command = if relative { `l` } else { `L` }
			}
			`z` {
				C.GdipClosePathFigure(path)
				cursor = opening
			}
			else {
				cursor = add_segment(path, mut scanner, command | 0x20, relative, cursor)
			}
		}
	}
}

// add_segment acrescenta ao caminho o trecho de um comando de desenho — reta, horizontal, vertical, curva ou arco, que é o que sobra das letras que is_command aceita — e devolve onde a pena ficou.
fn add_segment(path voidptr, mut scanner PathScanner, letter u8, relative bool, cursor Pointf) Pointf {
	match letter {
		`l` {
			return line_to(path, cursor, scanner.point(cursor, relative))
		}
		`h` {
			x := scanner.number()
			return line_to(path, cursor, Pointf{
				x: if relative { cursor.x + x } else { x }
				y: cursor.y
			})
		}
		`v` {
			y := scanner.number()
			return line_to(path, cursor, Pointf{
				x: cursor.x
				y: if relative { cursor.y + y } else { y }
			})
		}
		`c` {
			first := scanner.point(cursor, relative)
			second := scanner.point(cursor, relative)
			last := scanner.point(cursor, relative)
			bezier_to(path, cursor, first, second, last)
			return last
		}
		else {
			radius_x := scanner.number()
			radius_y := scanner.number()
			rotation := scanner.number()
			large := scanner.flag()
			sweep := scanner.flag()
			target := scanner.point(cursor, relative)
			for curve in arc_beziers(cursor, target, radius_x, radius_y, rotation, large, sweep) {
				bezier_to(path, curve[0], curve[1], curve[2], curve[3])
			}
			return target
		}
	}
}

// line_to acrescenta o segmento e devolve a ponta dele, que vira o cursor.
fn line_to(path voidptr, from Pointf, to Pointf) Pointf {
	C.GdipAddPathLine(path, f32(from.x), f32(from.y), f32(to.x), f32(to.y))
	return to
}

// bezier_to acrescenta a curva de quatro pontos.
fn bezier_to(path voidptr, from Pointf, first Pointf, second Pointf, to Pointf) {
	C.GdipAddPathBezier(path, f32(from.x), f32(from.y), f32(first.x), f32(first.y),
		f32(second.x), f32(second.y), f32(to.x), f32(to.y))
}
