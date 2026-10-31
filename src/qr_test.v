module main

// O QR code dos testes, com o texto "VShot QR 2026": versão 1, 21 por 21 módulos, correção M, gerado pelo segno. Cada linha é uma linha de módulos, e 1 é módulo escuro.
const qr_rows = [
	'111111100010101111111',
	'100000101101001000001',
	'101110101101101011101',
	'101110101110101011101',
	'101110100010101011101',
	'100000100100101000001',
	'111111101010101111111',
	'000000001100100000000',
	'100000101000111001110',
	'011110010110101110111',
	'110111110000101001010',
	'101010010010000101101',
	'111100110010110111001',
	'000000001001000100010',
	'111111100000100000110',
	'100000100110001011111',
	'101110100000111100011',
	'101110100001000011000',
	'101110100101110110011',
	'100000100000100001100',
	'111111101100111001010',
]

// blank_surface monta uma superfície branca do tamanho pedido.
fn blank_surface(width int, height int) !Frozen {
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, width, height)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(surface.dc, Rect{
		width:  width
		height: height
	}, u32(0x00ffffff))
	return surface
}

// qr_surface pinta o código numa superfície branca, com cada módulo em `size` pixels e a margem de quatro módulos que a norma pede em volta.
fn qr_surface(size int) !Frozen {
	side := (qr_rows.len + 8) * size
	surface := blank_surface(side, side)!
	for y, row in qr_rows {
		for x in 0 .. row.len {
			if row[x] == `1` {
				paint_rect(surface.dc, Rect{
					x:      (x + 4) * size
					y:      (y + 4) * size
					width:  size
					height: size
				}, u32(0))
			}
		}
	}
	return surface
}

// O QR code na área é lido, e o que sai é o texto que foi codificado nele.
fn test_le_o_qr_code_da_area() ! {
	surface := qr_surface(8)!
	defer {
		surface.release()
	}
	assert read_qr(surface, Rect{
		width:  surface.width
		height: surface.height
	}) or { '' } == 'VShot QR 2026'
}

// O conteúdo em ISO-8859-1, que é o padrão do modo byte, sai com os acentos certos, e o em UTF-8 também.
fn test_qr_em_latin1_e_em_utf8() {
	assert qr_text([u8(0x53), 0xe3, 0x6f]) == 'São'
	assert qr_text('São'.bytes()) == 'São'
	assert qr_text('VShot'.bytes()) == 'VShot'
}

// Numa área sem QR code não há o que ler, e a vez passa ao OCR.
fn test_sem_qr_code_nao_le_nada() ! {
	surface := blank_surface(120, 80)!
	defer {
		surface.release()
	}
	assert read_qr(surface, Rect{
		width:  120
		height: 80
	}) == none
}
