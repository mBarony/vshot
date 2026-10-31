module main

// O OCR sobre uma superfície com texto escrito pelo GDI: a leitura acha as palavras, e cada linha da tela vira uma linha do texto — é delas que o popup pergunta se as quebras ficam.

// written_surface escreve as linhas em preto sobre branco, numa letra grande o bastante para a leitura não depender da sorte.
fn written_surface(lines []string) !Frozen {
	width := 900
	height := 80 * lines.len + 40
	screen := C.GetDC(unsafe { nil })
	surface := new_surface(screen, width, height)!
	C.ReleaseDC(unsafe { nil }, screen)
	paint_rect(surface.dc, Rect{
		width:  width
		height: height
	}, u32(0x00ffffff))
	font := C.CreateFontW(-48, 0, 0, 0, 400, 0, 0, 0, default_charset, 0, 0, antialiased_quality,
		0, 'Segoe UI'.to_wide())
	old_font := C.SelectObject(surface.dc, font)
	C.SetBkMode(surface.dc, transparent_bk)
	C.SetTextColor(surface.dc, u32(0))
	for index, line in lines {
		C.TextOutW(surface.dc, 30, 20 + 80 * index, line.to_wide(), utf16_length(line))
	}
	C.SelectObject(surface.dc, old_font)
	C.DeleteObject(font)
	return surface
}

// O texto escrito na área é lido, e cada linha da tela vira uma linha do texto.
fn test_le_o_texto_da_area_linha_por_linha() ! {
	surface := written_surface(['Captura de tela', 'Texto reconhecido'])!
	defer {
		surface.release()
	}
	text := read_text(surface, Rect{
		width:  surface.width
		height: surface.height
	})!
	lines := text.split_into_lines()
	assert lines.len == 2, text
	assert lines[0].contains('Captura'), text
	assert lines[1].contains('reconhecido'), text
}
