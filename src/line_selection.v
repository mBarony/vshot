module main

// line_handles devolve apenas as duas extremidades, sem caixa ou alças laterais.
fn line_handles(mark Shape, area Rect) []Rect {
	from_x, from_y, to_x, to_y := line_ends(area, mark.origin)
	return [point_handle(from_x, from_y), point_handle(to_x, to_y)]
}

// line_part_at prioriza as pontas; o restante do traço serve para mover a forma inteira.
fn line_part_at(mark Shape, area Rect, x int, y int) Grab {
	boxes := line_handles(mark, area)
	for index, box in boxes {
		if contains(grow(box, handle_reach), x, y) {
			return if index == 0 { Grab.line_start } else { Grab.line_end }
		}
	}
	from_x, from_y, to_x, to_y := line_ends(area, mark.origin)
	return if near_segment(from_x, from_y, to_x, to_y, x, y, line_reach) {
		Grab.body
	} else {
		Grab.none
	}
}

// moved_endpoint move só a ponta pega, preservando a outra e o sentido da seta mesmo ao atravessá-la.
fn (s Shape) moved_endpoint(grab Grab, dx int, dy int) Shape {
	x1, y1, x2, y2 := line_ends(s.area, s.origin)
	from := Point{
		x: x1 + if grab == .line_start { dx } else { 0 }
		y: y1 + if grab == .line_start { dy } else { 0 }
	}
	to := Point{
		x: x2 + if grab == .line_end { dx } else { 0 }
		y: y2 + if grab == .line_end { dy } else { 0 }
	}
	origin := if to.x >= from.x {
		if to.y >= from.y { Corner.top_left } else { Corner.bottom_left }
	} else {
		if to.y >= from.y { Corner.top_right } else { Corner.bottom_right }
	}
	return Shape{
		...s
		area: bounds([from, to])
		origin: origin
	}
}
