module main

// O zoom da vista: o último bloco da direita da barra mostra quanto a imagem está ampliada
// na janela, e clicar nele abre um painel com − e + e os atalhos. Ele é da vista, e não da
// imagem: não entra no histórico nem no resultado, e sobrevive às edições.
//
// A escala de exibição passa a ser a que faz a imagem caber na janela vezes o zoom. Com
// zoom, a imagem fica maior que a área visível, e o deslocamento dela — arrastado com o
// botão direito — diz que pedaço aparece.

fn C.IntersectClipRect(hdc voidptr, left int, top int, right int, bottom int) int

fn C.SaveDC(hdc voidptr) int

fn C.RestoreDC(hdc voidptr, saved int) bool

fn C.ExtSelectClipRgn(hdc voidptr, region voidptr, mode int) int

// RGN_AND intersecta o recorte novo com o que já havia, em vez de trocá-lo.
const rgn_and = 1
const wm_mousewheel = u32(0x020a)
const vk_oem_plus = u32(0xbb)
const vk_oem_minus = u32(0xbd)
const vk_add = u32(0x6b)
const vk_subtract = u32(0x6d)

// Quanto cada passo de zoom multiplica.
const zoom_step = 1.25
// A maior ampliação na janela, em relação ao pixel da imagem de trabalho.
const max_display_scale = 8.0
// Quanto da área visível a marcação escolhida ocupa quando se aproxima dela.
const focus_fill = 0.8

// Popover é o painel que pende da barra: o de um bloco da direita, ou a ajuda da régua, que
// pende do botão dela. Só um fica aberto por vez.
enum Popover {
	none
	resize
	zoom
	ruler_help
}

// fit_scale é a escala que faz a imagem de trabalho inteira caber na janela.
fn (e Editor) fit_scale() f64 {
	return fit_within(e.current.width, e.current.height, e.canvas_width, e.canvas_height)
}

// clamp_pan prende o deslocamento. Uma imagem menor que o espaço fica centrada; uma maior
// anda até a borda dela encostar na borda do espaço, e não além.
fn clamp_pan(pan int, side int, room int) int {
	if side <= room {
		return 0
	}
	reach := (side - room) / 2
	return clamp(pan, -reach, reach)
}

// clamp_zoom prende o zoom entre caber na janela e a ampliação máxima.
fn (e Editor) clamp_zoom(zoom f64) f64 {
	fit := e.fit_scale()
	top := if fit > 0 { max_display_scale / fit } else { 1.0 }
	return if zoom < 1.0 {
		1.0
	} else if zoom > top { top } else { zoom }
}

// zoom_after_resize devolve o zoom depois de o espaço da imagem mudar de tamanho. O zoom é relativo ao encaixe: quem estava com a imagem inteira à vista continua com ela, e quem tinha escolhido uma escala — o tamanho real, por exemplo — fica com a mesma escala, para a porcentagem que a barra mostra não mudar sozinha ao redimensionar a janela.
//
// Há dois casos em que a escala escolhida não sobrevive, e não há como ela sobreviver: quando ela fica abaixo do encaixe novo, porque o editor não mostra a imagem menor do que cabendo inteira, e quando a imagem cabe em tamanho real, porque aí escolher o tamanho real é estar no encaixe, e os dois estados são o mesmo.
fn zoom_after_resize(zoom f64, scale f64, fit f64) f64 {
	if zoom == 1.0 || fit <= 0 {
		return 1.0
	}
	return scale / fit
}

// place ajusta o deslocamento para o ponto (ix, iy) da imagem de trabalho cair no ponto
// (qx, qy) da janela, na escala em vigor. É a conta que o zoom pela roda e o aproximar da
// marcação dividem.
fn (mut e Editor) place(ix f64, iy f64, qx int, qy int) {
	width := int(f64(e.current.width) * e.scale)
	height := int(f64(e.current.height) * e.scale)
	e.pan_x = round(f64(qx) - ix * e.scale) - (e.canvas_width - width) / 2
	e.pan_y = round(f64(qy) - iy * e.scale) - toolbar_height - (e.canvas_height - height) / 2
	e.layout()
}

// zoom_at muda o zoom mantendo parado o ponto da imagem que está sob (ax, ay).
//
// Perto da borda o deslocamento é preso — a imagem não mostra o que há além dela — e o
// ponto escapa do ponteiro naquele passo. Se o passo seguinte mirasse o ponto que ficou sob
// o ponteiro, o erro viraria o novo alvo e se acumularia. Por isso, enquanto o ponteiro não
// sai do lugar e ninguém mais mexe na vista, os passos seguidos miram o ponto do primeiro,
// que volta para baixo do ponteiro assim que a imagem tem folga para isso.
fn (mut e Editor) zoom_at(zoom f64, ax int, ay int) string {
	if ax != e.zoom_anchor.x || ay != e.zoom_anchor.y || e.view != e.zoom_view {
		e.zoom_focus_x = f64(ax - e.view.x) / e.scale
		e.zoom_focus_y = f64(ay - e.view.y) / e.scale
	}
	e.zoom = e.clamp_zoom(zoom)
	e.layout()
	e.place(e.zoom_focus_x, e.zoom_focus_y, ax, ay)
	e.zoom_anchor = Point{ax, ay}
	e.zoom_view = e.view
	return 'Zoom ${int(e.scale * 100 + 0.5)}%'
}

// canvas_middle é o meio da área visível, de onde o zoom pelo teclado parte.
fn (e Editor) canvas_middle() (int, int) {
	return e.canvas_width / 2, toolbar_height + e.canvas_height / 2
}

// zoom_by aproxima ou afasta um passo, a partir do meio da área visível.
fn (mut e Editor) zoom_by(steps int) string {
	x, y := e.canvas_middle()
	factor := if steps > 0 { zoom_step } else { 1.0 / zoom_step }
	return e.zoom_at(e.zoom * factor, x, y)
}

// zoom_fit volta a imagem inteira para dentro da janela.
fn (mut e Editor) zoom_fit() string {
	e.zoom = 1.0
	e.pan_x = 0
	e.pan_y = 0
	e.layout()
	return 'Zoom ${int(e.scale * 100 + 0.5)}%: a imagem inteira'
}

// zoom_actual mostra a imagem em pixels reais, um da imagem para um da janela.
fn (mut e Editor) zoom_actual() string {
	x, y := e.canvas_middle()
	fit := e.fit_scale()
	return e.zoom_at(if fit > 0 { 1.0 / fit } else { 1.0 }, x, y)
}

// zoom_selection aproxima a marcação escolhida até ela ocupar quase toda a área visível.
fn (mut e Editor) zoom_selection() string {
	if e.selected < 0 || e.selected >= e.scene.shapes.len {
		return 'Escolha uma marcação para aproximar dela'
	}
	// Aproximar da moldura é ver a imagem inteira, que é o que ela veste: a área zerada dela levava o zoom ao máximo, no canto de dentro da moldura.
	if e.scene.shapes[e.selected].tool == .backdrop {
		return e.zoom_fit()
	}
	box := e.to_client(e.scene.shapes[e.selected].area)
	ix := f64(box.x - e.view.x) / e.scale
	iy := f64(box.y - e.view.y) / e.scale
	iw := f64_max(f64(box.width) / e.scale, 1.0)
	ih := f64_max(f64(box.height) / e.scale, 1.0)
	wanted := f64_min(f64(e.canvas_width) * focus_fill / iw, f64(e.canvas_height) * focus_fill / ih)
	fit := e.fit_scale()
	e.zoom = e.clamp_zoom(if fit > 0 { wanted / fit } else { 1.0 })
	e.layout()
	x, y := e.canvas_middle()
	e.place(ix + iw / 2, iy + ih / 2, x, y)
	return 'Zoom ${int(e.scale * 100 + 0.5)}%: a marcação escolhida'
}

// pan_by arrasta a imagem, e diz se ela de fato andou.
fn (mut e Editor) pan_by(dx int, dy int) bool {
	before_x := e.view.x
	before_y := e.view.y
	e.pan_x += dx
	e.pan_y += dy
	e.layout()
	return e.view.x != before_x || e.view.y != before_y
}

// zoom_rect devolve o bloco do zoom na barra, ou none quando os blocos da direita não
// cabem.
fn zoom_rect(width int) ?Rect {
	size := size_rect(width)?
	return Rect{
		x: size.x + status_size_width
		y: 0
		width: status_zoom_width - 10
		height: toolbar_height
	}
}

// zoom_key traduz as teclas do zoom, que valem com o Ctrl apertado, e devolve none para as
// outras, que seguem o caminho de sempre.
fn (mut e Editor) zoom_key(key u32) ?string {
	return match key {
		vk_oem_plus, vk_add { e.zoom_by(1) }
		vk_oem_minus, vk_subtract { e.zoom_by(-1) }
		0x30 { e.zoom_fit() }
		0x31 { e.zoom_actual() }
		0x32 { e.zoom_selection() }
		else { none }
	}
}
