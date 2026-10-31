module main

fn C.SetPixel(hdc voidptr, x int, y int, color u32) u32

// pixel_at devolve os quatro canais de um pixel do buffer bruto.
fn pixel_at(pixels &u8, index int) []u8 {
	unsafe {
		return [pixels[index * 4], pixels[index * 4 + 1], pixels[index * 4 + 2],
			pixels[index * 4 + 3]]
	}
}

// Numa máquina sem tela renderizada a captura sai toda preta, e uma imagem preta
// esconderia tanto uma troca de canais quanto uma inversão vertical. Este teste desenha
// cores conhecidas num bitmap próprio e confere o que sai de read_pixels.
fn test_read_pixels_devolve_rgba_de_cima_para_baixo() {
	screen_dc := C.GetDC(unsafe { nil })
	assert screen_dc != unsafe { nil }
	defer {
		C.ReleaseDC(unsafe { nil }, screen_dc)
	}

	dc := C.CreateCompatibleDC(screen_dc)
	assert dc != unsafe { nil }
	defer {
		C.DeleteDC(dc)
	}

	bitmap := C.CreateCompatibleBitmap(screen_dc, 2, 2)
	assert bitmap != unsafe { nil }
	defer {
		C.DeleteObject(bitmap)
	}

	// COLORREF é 0x00bbggrr, ou seja, o vermelho puro vira 0x000000ff.
	previous := C.SelectObject(dc, bitmap)
	C.SetPixel(dc, 0, 0, 0x000000ff) // vermelho, canto superior esquerdo
	C.SetPixel(dc, 1, 0, 0x0000ff00) // verde, canto superior direito
	C.SetPixel(dc, 0, 1, 0x00ff0000) // azul, canto inferior esquerdo
	C.SetPixel(dc, 1, 1, 0x00ffffff) // branco, canto inferior direito
	C.SelectObject(dc, previous)

	pixels := read_pixels(dc, bitmap, 2, 2)!
	defer {
		unsafe { C.free(pixels) }
	}

	// Se os canais estivessem trocados, o vermelho apareceria como azul aqui.
	assert pixel_at(pixels, 0) == [u8(255), 0, 0, 255], 'superior esquerdo deveria ser vermelho'
	assert pixel_at(pixels, 1) == [u8(0), 255, 0, 255], 'superior direito deveria ser verde'
	// Se a imagem viesse de baixo para cima, este seria o vermelho e não o azul.
	assert pixel_at(pixels, 2) == [u8(0), 0, 255, 255], 'inferior esquerdo deveria ser azul'
	assert pixel_at(pixels, 3) == [u8(255), 255, 255, 255], 'inferior direito deveria ser branco'
}
