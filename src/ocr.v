module main

// O OCR do Windows, pela API do Windows Runtime, chamada em C em ocr_read.c. O MinGW não traz o cabeçalho do OCR, e as poucas interfaces que a leitura usa estão declaradas à mão em ocr_winrt.h, como as do GDI+ em gdipflat.h.

#flag windows -lruntimeobject

#include "ocr_read.c"

fn C.vshot_read_text(pixels &u8, width int, height int, failure &int) &u16

// A falha própria da leitura, fora dos códigos do Windows: nenhum idioma de OCR instalado.
const ocr_no_language = u32(0xa0000001)

// read_text devolve o texto da área, uma linha da tela por linha do texto.
fn read_text(frozen Frozen, area Rect) !string {
	shot := frozen.region(area)!
	defer {
		shot.release()
	}
	// A região vem em RGBA, o formato do PNG, e o OCR recebe BGRA: a troca do vermelho com o azul é a mesma nos dois sentidos.
	bgra_to_rgba(shot.pixels, shot.width * shot.height)
	mut failure := 0
	text := C.vshot_read_text(shot.pixels, shot.width, shot.height, &failure)
	if text == unsafe { nil } {
		return error(ocr_failure(u32(failure)))
	}
	defer {
		unsafe { C.free(text) }
	}
	return unsafe { string_from_wide(text) }
}

// ocr_failure explica a falha da leitura para o balão da bandeja.
fn ocr_failure(code u32) string {
	if code == ocr_no_language {
		return 'o Windows não tem nenhum idioma de OCR instalado'
	}
	return 'erro 0x${code:08x} do OCR do Windows'
}
