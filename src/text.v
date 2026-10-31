module main

fn C.DrawTextW(hdc voidptr, text voidptr, count int, area &C.RECT, format u32) int

// A ferramenta de texto: a digitação em curso, a medida do que foi escrito e o desenho da
// marcação. A digitação acontece na própria janela, e não num controle `EDIT` sobreposto:
// assim o que se vê enquanto se escreve é exatamente o que vai ficar — a fonte, a cor, o
// tamanho e o balão. Um controle nativo traria seleção de trecho e navegação por teclado
// de graça, mas desenharia com a aparência dele, e o texto saltaria ao ser confirmado.
//
// As teclas mortas chegam já compostas: quem resolve os acentos é o `TranslateMessage` do
// laço de mensagens, antes de a mensagem de caractere existir.

// DT_WORDBREAK quebra a linha na largura da caixa; DT_NOPREFIX não come o `&` como se
// fosse marca de atalho; DT_NOCLIP deixa o que não coube aparecer, em vez de sumir;
// DT_CALCRECT mede sem desenhar.
const dt_wordbreak = u32(0x0010)
const dt_noprefix = u32(0x0800)
const dt_noclip = u32(0x0100)
const dt_calcrect = u32(0x0400)

// A altura da fonte sai da espessura, pela mesma razão que o raio do balão numerado: o
// controle do painel é um só, e o que ele governa em cada ferramenta é o tamanho dela. De
// um a doze viram quatro a quarenta e oito pixels, que cobre de legenda a título.
const text_scale = 4
// A espessura com que o texto começa, que dá uma fonte de vinte pixels.
const text_thickness = 5
// Largura mínima da caixa, em alturas de fonte: é o que um clique sem arrasto ganha.
const text_min_columns = 10
const text_label_color = u32(0x00ffffff)
// O ponteiro de texto do Windows, a barra em forma de I. O ponto ativo dele é o meio da
// barra, e é ali que a primeira linha de um clique nasce centrada.
const idc_ibeam = voidptr(32513)
// Peso da fonte. O texto sobre uma captura disputa atenção com o conteúdo dela, e o
// semibold se sustenta sobre fundo claro e escuro.
const text_weight = 600

// text_height devolve o corpo da fonte para a espessura dada.
fn text_height(thickness f32) int {
	return max(int(thickness * text_scale), 1)
}

// text_padding é a folga entre o texto e a borda do balão.
fn text_padding(height int) int {
	return max(height / 3, 2)
}

// text_font cria a fonte do corpo pedido. Quem chama devolve.
fn text_font(height int) voidptr {
	return C.CreateFontW(-height, 0, 0, 0, text_weight, 0, 0, 0, default_charset, 0, 0,
		antialiased_quality, 0, 'Segoe UI'.to_wide())
}

// measure_text devolve a altura que o texto ocupa quebrado na largura dada.
fn measure_text(hdc voidptr, text string, width int, height int) int {
	font := text_font(height)
	old_font := C.SelectObject(hdc, font)
	mut box := C.RECT{
		right: max(width, 1)
	}
	C.DrawTextW(hdc, text.to_wide(), -1, &box, dt_wordbreak | dt_noprefix | dt_calcrect)
	C.SelectObject(hdc, old_font)
	C.DeleteObject(font)
	return box.bottom
}

// draw_text desenha a marcação de texto: o balão, quando o estilo pede, e as palavras
// dentro dele.
fn draw_text(hdc voidptr, mark Shape, area Rect, thickness f32) {
	height := text_height(thickness)
	pad := text_padding(height)
	if mark.style.filled {
		fill_rounded(hdc, area, mark.color, mark_corner(mark, thickness))
	}
	font := text_font(height)
	old_font := C.SelectObject(hdc, font)
	C.SetBkMode(hdc, transparent_bk)
	C.SetTextColor(hdc, if mark.style.filled { text_label_color } else { mark.color })
	mut box := C.RECT{
		left: area.x + pad
		top: area.y + pad
		right: area.x + area.width - pad
		bottom: area.y + area.height
	}
	C.DrawTextW(hdc, mark.text.to_wide(), -1, &box, dt_wordbreak | dt_noprefix | dt_noclip)
	C.SelectObject(hdc, old_font)
	C.DeleteObject(font)
}

// Folga entre a borda do botão de estilo e a miniatura do texto.
const text_sample_inset = 5

// draw_text_sample desenha a miniatura dos dois botões de estilo do texto: o "T" dentro do
// balão e o "T" sozinho. Ela não passa pelo `draw_mark` como as outras porque o tamanho da
// letra do texto vem da espessura, e a espessura das outras miniaturas daria uma letra de
// seis pixels. Aqui a letra é medida pelo próprio botão.
fn draw_text_sample(hdc voidptr, button Rect, filled bool, color u32) {
	area := Rect{
		x: button.x + text_sample_inset
		y: button.y + text_sample_inset
		width: button.width - 2 * text_sample_inset
		height: button.height - 2 * text_sample_inset
	}
	if filled {
		fill_rounded(hdc, area, color, corner_radius)
	}
	font := text_font(area.height)
	old_font := C.SelectObject(hdc, font)
	old_align := C.SetTextAlign(hdc, ta_center)
	C.SetBkMode(hdc, transparent_bk)
	// Num balão a letra é vazada, na cor do painel; solta, ela é a própria cor do ícone.
	C.SetTextColor(hdc, if filled { options_color } else { color })
	// O `y` do TextOut é o topo da célula da fonte, que é mais alta que a letra: subir um
	// oitavo do corpo põe a letra no meio do quadro.
	C.TextOutW(hdc, area.x + area.width / 2, area.y - area.height / 8, 'T'.to_wide(), 1)
	C.SetTextAlign(hdc, old_align)
	C.SelectObject(hdc, old_font)
	C.DeleteObject(font)
}

// typed_shape é a marcação que a digitação em curso vai virar. A barra vertical no fim é o
// cursor: em vez de medir onde a última linha termina para desenhar um traço ali, ele é um
// caractere do próprio texto, e a quebra de linha o leva junto.
fn (e Editor) typed_shape() Shape {
	return Shape{
		tool: .text
		area: e.typed_area
		color: e.color
		thickness: e.thickness
		style: e.style
		text: e.typed + '|'
	}
}

// text_box devolve a caixa da digitação com a altura que o texto pede. A largura vem do
// arrasto e não muda: é ela que decide onde as linhas quebram.
fn (e Editor) text_box(text string) Rect {
	return text_fit(e.current.dc, e.typed_area, text, e.thickness)
}

// text_fit devolve a caixa com a altura que o texto pede no corpo da espessura dada. A largura fica, porque é ela que decide onde as linhas quebram. É a mesma conta na digitação e ao trocar a espessura de um texto já feito.
fn text_fit(hdc voidptr, area Rect, text string, thickness int) Rect {
	height := text_height(f32(thickness))
	pad := text_padding(height)
	return Rect{
		...area
		height: measure_text(hdc, text, area.width - 2 * pad, height) + 2 * pad
	}
}

// start_text abre a digitação numa caixa nova. Um arrasto mais estreito que uma linha não
// é uma caixa, é um clique: ele ganha uma largura de partida, senão não haveria onde
// escrever, e a caixa sobe metade da primeira linha — o texto nasce à direita do ponteiro
// e centrado nele, e não abaixo. Um arrasto estreito de propósito é respeitado, e um
// arrasto de verdade fica onde foi feito.
fn (mut e Editor) start_text(area Rect) {
	height := text_height(f32(e.thickness))
	click := area.width < height
	// A caixa fica dentro do recorte, como a lente da lupa: o que passasse da borda sumiria na prévia e no resultado, e perto da borda direita as linhas quebrariam fora da imagem.
	crop := e.scene.crop
	width := min(if click { height * text_min_columns } else { area.width }, crop.width)
	e.typing = true
	e.typed = ''
	e.high_surrogate = 0
	e.typed_at = -1
	e.typed_area = Rect{
		...area
		x:     clamp(area.x, crop.x, crop.x + crop.width - width)
		width: width
	}
	e.typed_area = e.text_box('|')
	if click {
		// O topo mais baixo em que a caixa ainda cabe, mas nunca acima do recorte: num recorte mais baixo que uma linha, a primeira linha começa rente ao topo dele.
		bottom := max(crop.y, crop.y + crop.height - e.typed_area.height)
		e.typed_area = Rect{
			...e.typed_area
			y: clamp(area.y - e.typed_area.height / 2, crop.y, bottom)
		}
	}
	e.selected = -1
}

// edit_text reabre uma marcação de texto já feita. Ela sai da cena enquanto está sendo
// reescrita, para não aparecer duas vezes; desistir a devolve pelo mesmo caminho que
// desfazer usa.
fn (mut e Editor) edit_text(index int) string {
	shape := e.scene.shapes[index]
	future := e.future.clone()
	e.record()
	e.scene.shapes.delete(index)
	e.apply() or {
		e.rollback()
		return 'Falha ao reabrir o texto: ${err}'
	}
	e.rewrite_future = future
	e.typing = true
	e.typed = shape.text
	e.high_surrogate = 0
	e.typed_at = index
	e.typed_area = shape.area
	// A digitação desenha com a aparência do texto, e o padrão das próximas marcações fica guardado para voltar quando ela terminar.
	e.before_rewrite = Shape{
		color: e.color
		thickness: e.thickness
		style: e.style
	}
	e.color = shape.color
	e.thickness = shape.thickness
	e.style = shape.style
	e.selected = -1
	e.typed_area = e.text_box(e.typed + '|')
	return 'Reescrevendo o texto'
}

// type_unit recebe uma unidade UTF-16 do WM_CHAR. Um caractere fora do plano básico — um emoji — chega em duas, as metades de um par substituto, e cada metade sozinha virava um "�": a alta espera a baixa, e as duas juntas viram o caractere. Uma metade solta, sem a outra, é descartada.
fn (mut e Editor) type_unit(unit rune) {
	if unit >= 0xd800 && unit <= 0xdbff {
		e.high_surrogate = unit
		return
	}
	high := e.high_surrogate
	e.high_surrogate = 0
	if unit >= 0xdc00 && unit <= 0xdfff {
		if high != 0 {
			e.type_letter(rune(0x10000 + ((u32(high) - 0xd800) << 10) + (u32(unit) - 0xdc00)))
		}
		return
	}
	e.type_letter(unit)
}

// type_letter acrescenta ao texto em digitação o que veio do teclado, e devolve se a caixa
// mudou de tamanho.
fn (mut e Editor) type_letter(letter rune) {
	match letter {
		`\b` { e.typed = drop_last(e.typed) }
		`\r` { e.typed += '\n' }
		else { e.typed += letter.str() }
	}
	e.typed_area = e.text_box(e.typed + '|')
}

// drop_last tira a última letra, contando letras e não bytes: um "ã" ocupa dois bytes, e
// apagar meio caractere deixaria o texto inválido.
fn drop_last(text string) string {
	letters := text.runes()
	return if letters.len == 0 { '' } else { letters#[..-1].string() }
}

// finish_text fecha a digitação e guarda o que foi escrito. Texto em branco não vira
// marcação — e numa reescrita, apagar tudo apaga a marcação.
fn (mut e Editor) finish_text() string {
	// Só o fim é cortado, que é o que o Enter final e os espaços deixam. As linhas em branco e os espaços do começo são parte do texto, e a prévia os mostrava: cortá-los fazia o texto saltar ao confirmar.
	text := e.typed.trim_right(' \t\n')
	index := e.typed_at
	shape := Shape{
		tool: .text
		area: e.text_box(text)
		color: e.color
		thickness: e.thickness
		style: e.style
		text: text
	}
	e.typing = false
	e.typed = ''
	e.typed_at = -1
	if index >= 0 {
		e.restore_defaults()
	}
	if text == '' {
		return if index >= 0 { 'Texto apagado' } else { e.hint() }
	}
	// Numa reescrita o estado anterior já foi guardado ao reabrir a marcação.
	if index < 0 {
		e.record()
	}
	e.selected = if index >= 0 && index <= e.scene.shapes.len {
		e.scene.shapes.insert(index, shape)
		index
	} else {
		e.scene.shapes << shape
		e.scene.shapes.len - 1
	}
	e.apply() or {
		// Numa reescrita a imagem na tela é a da cena sem o texto, montada ao reabri-lo, e a cena com o texto de antes ficou no histórico: o texto novo sai, a cena volta a ser a da imagem, e desfazer traz o de antes. O rollback devolvia o texto antigo à cena sem devolvê-lo à imagem.
		if index >= 0 {
			e.scene.shapes.delete(e.selected)
		} else {
			e.rollback()
		}
		e.selected = -1
		return 'Falha ao aplicar: ${err}'
	}
	return 'Texto escrito'
}

// restore_defaults devolve o padrão das próximas marcações ao que era antes de o texto ser reaberto: reescrever um texto em balão não é escolher o balão, a cor e o corpo dele para o próximo retângulo.
fn (mut e Editor) restore_defaults() {
	e.color = e.before_rewrite.color
	e.thickness = e.before_rewrite.thickness
	e.style = e.before_rewrite.style
}

// cancel_text abandona a digitação. Numa reescrita a marcação volta como estava.
fn (mut e Editor) cancel_text() string {
	rewriting := e.typed_at >= 0
	e.typing = false
	e.typed = ''
	e.typed_at = -1
	if rewriting {
		e.restore_defaults()
		shown := e.scene.clone()
		e.rollback()
		// Como no desfazer: a cena que não pôde ser montada volta ao histórico, e a da imagem na tela, sem o texto, continua valendo; desfazer tenta devolvê-lo de novo.
		e.apply() or {
			e.past << e.scene
			e.scene = shown
			return 'Falha ao devolver o texto: ${err}'
		}
		// Reabrir e desistir não foi edição nenhuma: o refazer volta como estava.
		e.future = e.rewrite_future
	}
	return e.hint()
}
