module main

// WINVER precisa chegar a 0x0605 antes do windows.h, senão a declaração de
// SetProcessDpiAwarenessContext fica de fora do cabeçalho.
#flag windows -DWINVER=0x0605 -D_WIN32_WINNT=0x0605

#flag windows -luser32 -lgdi32 -lmsimg32

#include <windows.h>

fn C.SetProcessDpiAwarenessContext(value voidptr) bool

fn C.GetSystemMetrics(index int) int

fn C.GetDC(hwnd voidptr) voidptr

fn C.ReleaseDC(hwnd voidptr, hdc voidptr) int

fn C.CreateCompatibleDC(hdc voidptr) voidptr

fn C.CreateCompatibleBitmap(hdc voidptr, width int, height int) voidptr

fn C.SelectObject(hdc voidptr, object voidptr) voidptr

fn C.BitBlt(dst voidptr, x int, y int, width int, height int, src voidptr, src_x int, src_y int, rop u32) bool

fn C.GetDIBits(hdc voidptr, bitmap voidptr, start u32, lines u32, bits voidptr, info voidptr, usage u32) int

fn C.DeleteObject(object voidptr) bool

fn C.DeleteDC(hdc voidptr) bool

const srccopy = u32(0x00cc0020)
// CAPTUREBLT inclui as janelas em camadas (menus, sobreposições transparentes) na cópia.
const captureblt = u32(0x40000000)
const dib_rgb_colors = u32(0)
const bi_rgb = u32(0)

// Tamanho em bytes de BITMAPINFOHEADER, que é o valor que o campo biSize precisa carregar.
// Não é o sizeof da struct abaixo, que reserva espaço extra de propósito.
const bitmap_info_header_size = u32(40)

// BitmapInfoHeader espelha BITMAPINFOHEADER campo a campo e acrescenta a folga de uma
// RGBQUAD no fim, para que o endereço possa ser passado onde o GDI espera um BITMAPINFO.
struct BitmapInfoHeader {
mut:
	bi_size             u32
	bi_width            int
	bi_height           int
	bi_planes           u16
	bi_bit_count        u16
	bi_compression      u32
	bi_size_image       u32
	bi_x_pels_per_meter int
	bi_y_pels_per_meter int
	bi_clr_used         u32
	bi_clr_important    u32
	color_table         [4]u32
}

// Rect é uma área em pixels, relativa ao canto superior esquerdo da tela virtual.
struct Rect {
	x      int
	y      int
	width  int
	height int
}

// Screenshot é uma imagem RGBA sem compressão, em pixels físicos da tela. O buffer vem
// do alocador do sistema, fora do coletor de lixo do V, e quem cria precisa devolvê-lo
// com release(). São 8 MB numa tela 1920x1080, e numa aplicação que fica residente esse
// peso não pode esperar o coletor decidir mexer.
struct Screenshot {
	width  int
	height int
	pixels &u8
}

// release devolve o buffer de pixels ao sistema.
fn (s Screenshot) release() {
	unsafe { C.free(s.pixels) }
}

// Frozen é a tela copiada para um bitmap do GDI. A cópia existe para que o conteúdo não
// mude enquanto o usuário escolhe a área, e para que a própria janela de seleção não
// apareça no resultado.
struct Frozen {
	dc       voidptr
	bitmap   voidptr
	previous voidptr
	left     int
	top      int
	width    int
	height   int
}

// enable_dpi_awareness declara o processo ciente de DPI por monitor. Sem isto o Windows
// entrega uma cópia reduzida e reescalada em telas com zoom acima de 100%: numa tela
// 1920x1080 a 150%, a captura sairia com 1280x720. Precisa ser chamada uma única vez, na
// entrada do programa e antes de qualquer janela, porque o Windows recusa a mudança
// depois que a primeira janela do processo existe.
fn enable_dpi_awareness() {
	// -4 é o valor de DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2.
	C.SetProcessDpiAwarenessContext(voidptr(-4))
}

// freeze_area copia para a memória uma área da tela virtual: ela inteira, com todos os monitores, ou um monitor só. Quem chama precisa liberar o resultado com release().
fn freeze_area(area Rect) !Frozen {
	left := area.x
	top := area.y
	width := area.width
	height := area.height
	if width <= 0 || height <= 0 {
		return error('não foi possível obter as dimensões da tela')
	}

	screen_dc := C.GetDC(unsafe { nil })
	if screen_dc == unsafe { nil } {
		return error('GetDC falhou')
	}
	defer {
		C.ReleaseDC(unsafe { nil }, screen_dc)
	}

	frozen := new_surface(screen_dc, width, height)!
	if !C.BitBlt(frozen.dc, 0, 0, width, height, screen_dc, left, top, srccopy | captureblt) {
		frozen.release()
		return error('BitBlt falhou')
	}
	return Frozen{
		...frozen
		left: left
		top: top
	}
}

// new_surface cria um bitmap em memória do tamanho pedido, já selecionado no seu próprio
// DC e pronto para receber ou fornecer pixels.
fn new_surface(model voidptr, width int, height int) !Frozen {
	dc := C.CreateCompatibleDC(model)
	if dc == unsafe { nil } {
		return error('CreateCompatibleDC falhou')
	}
	bitmap := C.CreateCompatibleBitmap(model, width, height)
	if bitmap == unsafe { nil } {
		C.DeleteDC(dc)
		return error('CreateCompatibleBitmap falhou')
	}
	return Frozen{
		dc: dc
		bitmap: bitmap
		previous: C.SelectObject(dc, bitmap)
		width: width
		height: height
	}
}

// release devolve ao Windows o DC e o bitmap. Sem isto cada captura vaza memória de vídeo.
// Aceita uma superfície que nunca chegou a existir, para quem libera não ter de checar.
fn (f Frozen) release() {
	if f.dc == unsafe { nil } {
		return
	}
	C.SelectObject(f.dc, f.previous)
	C.DeleteObject(f.bitmap)
	C.DeleteDC(f.dc)
}

// region recorta um pedaço da cópia congelada e devolve os pixels em RGBA. Quem chama
// libera o resultado com release().
fn (f Frozen) region(area Rect) !Screenshot {
	pixels := if f.covers(area) {
		// A imagem inteira é lida direto do congelado. Passar pelo recorte alocaria outro
		// bitmap de 8 MB e o copiaria só para reproduzir o que já está ali, e este é
		// justamente o caminho da captura de tela cheia.
		f.read_whole()!
	} else {
		bitmap := f.crop(area)!
		defer {
			C.DeleteObject(bitmap)
		}
		read_pixels(f.dc, bitmap, area.width, area.height)!
	}
	return Screenshot{
		width: area.width
		height: area.height
		pixels: pixels
	}
}

// covers diz se a área pedida é a imagem congelada inteira.
fn (f Frozen) covers(area Rect) bool {
	return area.x == 0 && area.y == 0 && area.width == f.width && area.height == f.height
}

// read_whole lê o próprio bitmap congelado, que precisa sair do DC durante a leitura.
fn (f Frozen) read_whole() !&u8 {
	C.SelectObject(f.dc, f.previous)
	defer {
		C.SelectObject(f.dc, f.bitmap)
	}
	return read_pixels(f.dc, f.bitmap, f.width, f.height)!
}

// cut devolve uma cópia contendo apenas a área pedida, como uma imagem independente. A
// original não é tocada, e quem chama libera o resultado com release().
fn (f Frozen) cut(area Rect) !Frozen {
	piece := new_surface(f.dc, area.width, area.height)!
	if !C.BitBlt(piece.dc, 0, 0, area.width, area.height, f.dc, area.x, area.y, srccopy) {
		piece.release()
		return error('BitBlt do recorte falhou')
	}
	return piece
}

// crop recorta um pedaço da cópia congelada e devolve o bitmap solto, já fora de qualquer
// DC. Quem chama vira dono dele: ou o libera, ou o entrega a quem assuma essa
// responsabilidade, como a área de transferência.
fn (f Frozen) crop(area Rect) !voidptr {
	piece := new_surface(f.dc, area.width, area.height)!
	blitted := C.BitBlt(piece.dc, 0, 0, area.width, area.height, f.dc, area.x, area.y, srccopy)
	// O GetDIBits e a área de transferência exigem que o bitmap não esteja selecionado.
	C.SelectObject(piece.dc, piece.previous)
	C.DeleteDC(piece.dc)
	if !blitted {
		C.DeleteObject(piece.bitmap)
		return error('BitBlt do recorte falhou')
	}
	return piece.bitmap
}

// read_pixels lê o bitmap do GDI para um buffer RGBA de cima para baixo, o formato que o
// PNG usa. O buffer é do alocador do sistema e quem chama precisa liberá-lo.
fn read_pixels(hdc voidptr, bitmap voidptr, width int, height int) !&u8 {
	mut header := BitmapInfoHeader{
		bi_size: bitmap_info_header_size
		bi_width: width
		// Altura negativa pede as linhas de cima para baixo. Sem isso a imagem sai de
		// cabeça para baixo, porque o formato DIB é, por padrão, de baixo para cima.
		bi_height: -height
		bi_planes: 1
		bi_bit_count: 32
		bi_compression: bi_rgb
	}
	size := usize(width) * usize(height) * 4
	pixels := unsafe { &u8(C.malloc(size)) }
	if pixels == unsafe { nil } {
		return error('sem memória para ${size} bytes de pixels')
	}
	lines := C.GetDIBits(hdc, bitmap, 0, u32(height), pixels, voidptr(&header), dib_rgb_colors)
	if lines != height {
		unsafe { C.free(pixels) }
		return error('GetDIBits copiou ${lines} de ${height} linhas')
	}
	bgra_to_rgba(pixels, width * height)
	return pixels
}

// bgra_to_rgba converte no próprio buffer: o GDI entrega BGRA e o PNG espera RGBA. O
// quarto byte vem indefinido do BitBlt, então é fixado em opaco.
//
// A troca é feita de 32 bits por vez, e não byte a byte, porque são dois milhões de
// pixels a cada captura de tela cheia. A aritmética assume little-endian, que é o que o
// x86-64 desta aplicação sempre é: lido como u32, o pixel BGRA vira 0xAARRGGBB.
fn bgra_to_rgba(pixels &u8, count int) {
	unsafe {
		mut words := &u32(pixels)
		for i := 0; i < count; i++ {
			pixel := words[i]
			words[i] = (pixel & 0x0000ff00) | ((pixel & 0x00ff0000) >> 16) | ((pixel & 0x000000ff) << 16) | 0xff000000
		}
	}
}
