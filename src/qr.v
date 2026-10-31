module main

// A leitura de QR code, pelo quirc: um decodificador pequeno em C, de licença ISC, embutido em thirdparty/quirc. Ele trabalha sobre uma imagem em tons de cinza, acha os três quadrados de canto de cada código e decodifica o que encontrou.

import encoding.utf8

#include "thirdparty/quirc/quirc_all.c"

// No quirc.h as três são `struct` sem typedef, e por isso sem o @[typedef].
struct C.quirc {}

struct C.quirc_code {}

struct C.quirc_data {
	payload     [8896]u8
	payload_len int
}

fn C.quirc_new() &C.quirc

fn C.quirc_destroy(decoder &C.quirc)

fn C.quirc_resize(decoder &C.quirc, width int, height int) int

fn C.quirc_begin(decoder &C.quirc, width &int, height &int) &u8

fn C.quirc_end(decoder &C.quirc)

fn C.quirc_count(decoder &C.quirc) int

fn C.quirc_extract(decoder &C.quirc, index int, code &C.quirc_code)

fn C.quirc_decode(code &C.quirc_code, data &C.quirc_data) int

fn C.quirc_flip(code &C.quirc_code)

// read_qr devolve o conteúdo do primeiro QR code legível na área, ou none quando não há nenhum.
fn read_qr(frozen Frozen, area Rect) ?string {
	shot := frozen.region(area) or { return none }
	defer {
		shot.release()
	}
	decoder := C.quirc_new()
	if decoder == unsafe { nil } {
		return none
	}
	defer {
		C.quirc_destroy(decoder)
	}
	if C.quirc_resize(decoder, shot.width, shot.height) < 0 {
		return none
	}
	fill_gray(C.quirc_begin(decoder, unsafe { nil }, unsafe { nil }), shot)
	C.quirc_end(decoder)
	for index in 0 .. C.quirc_count(decoder) {
		if text := decode_qr(decoder, index) {
			return text
		}
	}
	return none
}

// decode_qr decodifica um dos códigos achados. Um código espelhado — visto por trás de um vidro, ou refletido — só sai virado, e por isso é tentado de novo assim, como o próprio quirc recomenda.
fn decode_qr(decoder &C.quirc, index int) ?string {
	mut code := C.quirc_code{}
	mut data := C.quirc_data{}
	C.quirc_extract(decoder, index, &code)
	if C.quirc_decode(&code, &data) != 0 {
		C.quirc_flip(&code)
		if C.quirc_decode(&code, &data) != 0 {
			return none
		}
	}
	return qr_text(unsafe { (&u8(&data.payload[0])).vbytes(data.payload_len) })
}

// qr_text lê o conteúdo do código como texto. O modo byte do QR code é, pela norma, ISO-8859-1, e é assim que muitos geradores gravam um texto que cabe nele; outros gravam UTF-8. Bytes que formam UTF-8 válido valem como UTF-8, e os demais são lidos como ISO-8859-1, em que cada byte é o ponto de código de mesmo valor: sem isso, o "ã" de "São" virava "�".
fn qr_text(payload []u8) string {
	text := payload.bytestr()
	if utf8.validate_str(text) {
		return text
	}
	return payload.map(rune(it)).string()
}

// fill_gray escreve a imagem RGBA em tons de cinza no buffer do quirc, com o peso de cada canal na luminância: o verde pesa mais que o vermelho, e o azul quase nada.
fn fill_gray(target &u8, shot Screenshot) {
	unsafe {
		mut gray := target
		for index in 0 .. shot.width * shot.height {
			pixel := shot.pixels + index * 4
			gray[index] = u8((u32(pixel[0]) * 77 + u32(pixel[1]) * 150 + u32(pixel[2]) * 29) >> 8)
		}
	}
}
