module main

// As duas pontas do arrasto entram na área: do canto de cima ao pixel sob o ponteiro no canto de baixo sai a tela inteira, e o arrasto para trás dá o mesmo tipo de retângulo.
fn test_area_inclui_o_pixel_sob_o_ponteiro() {
	full := Selection{
		width: 1920
		height: 1080
		cursor_x: 1919
		cursor_y: 1079
	}
	assert full.area() == Rect{
		x: 0
		y: 0
		width: 1920
		height: 1080
	}
	back := Selection{
		origin_x: 10
		origin_y: 10
		cursor_x: 5
		cursor_y: 5
	}
	assert back.area() == Rect{
		x: 5
		y: 5
		width: 6
		height: 6
	}
}
