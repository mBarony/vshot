module main

import math

fn test_tags_lists_every_element() {
	found := tags('<svg a="1">\n  <path d="M0 0"/>\n</svg>')
	assert found.len == 3
	assert tag_name(found[0]) == 'svg'
	assert tag_name(found[1]) == 'path'
	// O fechamento não tem nome de forma, e é por isso que ele não vira desenho nenhum.
	assert tag_name(found[2]) == ''
}

fn test_attribute_does_not_match_a_longer_name() {
	tag := 'path d="M0 0" stroke-width="1.3" fill-opacity="0.2"'
	assert attribute(tag, 'stroke-width')? == '1.3'
	assert attribute(tag, 'stroke') == none
	assert attribute(tag, 'fill') == none
	assert attribute(tag, 'fill-opacity')? == '0.2'
}

fn test_first_tag_finds_the_root() {
	root := first_tag('<?xml?>\n<svg stroke-width="1.5">\n<path/>\n</svg>', 'svg')?
	assert attribute(root, 'stroke-width')? == '1.5'
}

fn test_scanner_reads_numbers_glued_by_the_sign() {
	mut scanner := PathScanner{
		data: '1.6-1.4 2e2,3'
	}
	assert scanner.number() == 1.6
	assert scanner.number() == -1.4
	assert scanner.number() == 200
	assert scanner.number() == 3
	assert scanner.done()
}

fn test_scanner_reads_glued_arc_flags() {
	mut scanner := PathScanner{
		data: '0 1 5'
	}
	assert scanner.flag() == false
	assert scanner.flag() == true
	assert scanner.number() == 5
}

fn test_relative_point_walks_from_the_cursor() {
	mut scanner := PathScanner{
		data: '3 4 3 4'
	}
	cursor := Pointf{
		x: 10
		y: 20
	}
	assert scanner.point(cursor, true) == Pointf{13, 24}
	assert scanner.point(cursor, false) == Pointf{3, 4}
}

fn test_command_letters_are_the_ones_the_icons_use() {
	for letter in 'MmLlHhVvCcAaZz' {
		assert is_command(letter)
	}
	for letter in 'SsQqTtRrXy1.-' {
		assert !is_command(letter)
	}
}

// Um quarto de volta: as pontas caem sobre os dois extremos pedidos e o percurso inteiro
// fica sobre o círculo. Dos dois centros possíveis, os dois indicadores em falso escolhem
// aquele que deixa o arco curto e no sentido decrescente — o de (10, 10).
fn test_arc_starts_and_ends_where_it_was_told() {
	curves := arc_beziers(Pointf{10, 0}, Pointf{0, 10}, 10, 10, 0, false, false)
	assert curves.len == 1
	assert near(curves[0][0], Pointf{10, 0})
	assert near(curves[0][3], Pointf{0, 10})
	assert on_circle(curves, Pointf{10, 10}, 10)
}

// A mesma passagem pelo caminho longo dá três quartos de volta, que não cabem num bezier
// só: o arco sai fatiado, e cada fatia continua rente ao círculo.
fn test_the_long_way_around_is_sliced() {
	curves := arc_beziers(Pointf{10, 0}, Pointf{0, 10}, 10, 10, 0, true, true)
	assert curves.len == 3
	assert near(curves[0][0], Pointf{10, 0})
	assert near(curves[2][3], Pointf{0, 10})
	assert on_circle(curves, Pointf{10, 10}, 10)
}

// Raios pequenos demais para ligar os dois pontos são esticados até darem, e o arco vira
// a meia-volta que passa pelos dois.
fn test_short_radii_are_stretched_instead_of_giving_up() {
	curves := arc_beziers(Pointf{0, 0}, Pointf{20, 0}, 1, 1, 0, false, true)
	assert curves.len == 2
	assert near(curves[0][0], Pointf{0, 0})
	assert near(curves[1][3], Pointf{20, 0})
	assert on_circle(curves, Pointf{10, 0}, 10)
	// O indicador de sentido manda pelo lado de cima, que no SVG é o do y menor.
	assert bezier_at(curves[0], 0.5).y < 0
}

fn test_an_arc_without_radius_draws_nothing() {
	assert arc_beziers(Pointf{0, 0}, Pointf{5, 5}, 0, 3, 0, false, true).len == 0
}

// on_circle percorre as curvas e confere que elas não se afastam do círculo. Um bezier
// não é um arco, mas com fatias de até um quarto de volta a diferença fica na terceira
// casa — bem abaixo do pixel em que o ícone é desenhado.
fn on_circle(curves [][]Pointf, center Pointf, radius f64) bool {
	for curve in curves {
		for step in 0 .. 11 {
			point := bezier_at(curve, f64(step) / 10)
			reach := math.sqrt((point.x - center.x) * (point.x - center.x) +
				(point.y - center.y) * (point.y - center.y))
			if math.abs(reach - radius) > 0.01 {
				return false
			}
		}
	}
	return true
}

fn near(a Pointf, b Pointf) bool {
	return math.abs(a.x - b.x) < 0.01 && math.abs(a.y - b.y) < 0.01
}

// bezier_at devolve o ponto da curva na fração pedida do percurso.
fn bezier_at(curve []Pointf, t f64) Pointf {
	rest := 1 - t
	mut x := 0.0
	mut y := 0.0
	weights := [rest * rest * rest, 3 * rest * rest * t, 3 * rest * t * t, t * t * t]
	for index, weight in weights {
		x += weight * curve[index].x
		y += weight * curve[index].y
	}
	return Pointf{x, y}
}
