module main

// Todos os sentidos preservam a extremidade oposta, inclusive cruzando os dois eixos.
fn test_mover_extremidade_preserva_a_outra_ponta() {
	for tool in diagonal_tools {
		for origin in [Corner.top_left, .top_right, .bottom_right, .bottom_left] {
			shape := Shape{tool: tool, area: Rect{100, 100, 200, 100}, origin: origin}
			x1, y1, x2, y2 := line_ends(shape.area, origin)
			start := shape.moved_endpoint(.line_start, 350, -250)
			sx, sy, ex, ey := line_ends(start.area, start.origin)
			assert [sx, sy, ex, ey] == [x1 + 350, y1 - 250, x2, y2]
			end := shape.moved_endpoint(.line_end, -350, 250)
			ax, ay, bx, by := line_ends(end.area, end.origin)
			assert [ax, ay, bx, by] == [x1, y1, x2 - 350, y2 + 250]
		}
	}
}

// Uma linha horizontal ou vertical pode girar livremente ao arrastar uma ponta.
fn test_extremidades_de_linhas_retificadas_giram() {
	for area in [Rect{100, 100, 200, 0}, Rect{100, 100, 0, 200}] {
		shape := Shape{tool: .arrow, area: area}
		moved := shape.moved_endpoint(.line_end, 50, 80)
		x1, y1, x2, y2 := line_ends(moved.area, moved.origin)
		assert [x1, y1] == [100, 100]
		assert [x2, y2] == [100 + area.width + 50, 100 + area.height + 80]
	}
}

fn test_so_as_extremidades_tem_alcas_com_zoom_e_recorte() {
	for tool in diagonal_tools {
		for scale in [0.5, 1.0, 2.0] {
			shape := Shape{tool: tool, area: Rect{210, 220, 200, 100}, origin: .bottom_left}
			editor := Editor{
				view: Rect{100, 44, 400, 300}
				scale: scale
				scene: Scene{crop: Rect{10, 20, 800, 600}, shapes: [shape]}
				selected: 0
			}
			area := editor.to_client(shape.area)
			assert editor.grab_at(area.x, area.y + area.height) == .line_start
			assert editor.grab_at(area.x + area.width, area.y) == .line_end
			assert editor.grab_at(area.x, area.y) == .none
			assert editor.grab_at(area.x + area.width / 2, area.y) == .none
			assert editor.grab_at(area.x + area.width / 2, area.y + area.height / 2) == .body
		}
	}
}

fn test_selecao_da_linha_desenha_apenas_as_pontas() ! {
	token := start_gdiplus()!
	defer { stop_gdiplus(token) }
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, 400, 300)!
	C.ReleaseDC(unsafe { nil }, screen)
	defer { surface.release() }
	C.PatBlt(surface.dc, 0, 0, 400, 300, blackness)
	shape := Shape{tool: .arrow, area: Rect{50, 50, 200, 100}}
	editor := Editor{scale: 1.0}
	draw_selected(surface.dc, &editor, shape)
	assert C.GetPixel(surface.dc, 50, 50) == handle_fill
	assert C.GetPixel(surface.dc, 250, 150) == handle_fill
	assert C.GetPixel(surface.dc, 150, 50) == 0
	assert C.GetPixel(surface.dc, 150, 48) == 0
}
