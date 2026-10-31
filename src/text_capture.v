module main

// A captura de texto: a tela congela, o usuário arrasta um retângulo, e o que está escrito nele vai para a área de transferência — o conteúdo de um QR code, quando há um, ou o texto que o OCR do Windows reconhece. O texto é copiado na hora, com as quebras de linha da tela; quando há mais de uma linha, a faixa de text_popup.v mostra o que foi copiado e oferece tirá-las, porque colado num campo de busca ou numa mensagem elas quase sempre atrapalham.

// Quantos caracteres do texto o balão mostra: o balão guarda 255 unidades, e a folga cobre a reticência e os emojis, que ocupam duas.
const text_preview = 120

// capture_text congela a tela, deixa escolher uma área e copia o que está escrito nela.
fn capture_text(hwnd voidptr, mut app App) {
	if app.busy {
		return
	}
	app.busy = true
	defer {
		app.busy = false
	}
	frozen := app.freeze(virtual_screen()) or {
		tray_notify(hwnd, app_name, 'Falha ao capturar a tela: ${err}')
		return
	}
	defer {
		frozen.release()
	}
	// Sem área escolhida o usuário desistiu, e desistir não merece aviso nenhum.
	area := select_region(frozen, C.GetModuleHandleW(unsafe { nil })) or { return }
	found := recognize(frozen, area) or {
		tray_notify(hwnd, app_name, 'Falha ao reconhecer o texto: ${err}')
		return
	}
	deliver_text(hwnd, found, mut app.text_popup)
}

// recognize lê a área: primeiro um QR code, cujo conteúdo é exato e vale mais que qualquer leitura de letras, e, sem QR code, o texto pelo OCR. Devolve o texto sem espaços nas pontas, vazio quando não há nada escrito.
fn recognize(frozen Frozen, area Rect) !string {
	if code := read_qr(frozen, area) {
		return code.trim_space()
	}
	return read_text(frozen, area)!.trim_space()
}

// deliver_text copia o que foi reconhecido. Com mais de uma linha, a faixa mostra o que foi copiado e oferece tirar as quebras; numa linha só não há o que oferecer, e o balão da bandeja basta.
fn deliver_text(hwnd voidptr, found string, mut popup TextPopup) {
	if found == '' {
		tray_notify(hwnd, app_name, 'Nenhum texto nem QR code na área escolhida')
		return
	}
	copy_text(hwnd, found) or {
		tray_notify(hwnd, app_name, err.msg())
		return
	}
	if found.contains('\n') {
		show_text_popup(mut popup, hwnd, found)
		return
	}
	tray_notify(hwnd, 'Texto copiado', shortened(found))
}

// joined_lines junta as linhas numa só, separadas por um espaço. Os espaços nas pontas de cada linha saem, e as linhas em branco, que separavam parágrafos, também: quem pediu o texto sem quebras quer uma linha só.
fn joined_lines(text string) string {
	return text.split_into_lines().map(it.trim_space()).filter(it != '').join(' ')
}

// shortened corta o texto para o balão, que não comporta uma página inteira. O corte é por caractere, e não por byte, para não partir uma letra acentuada ao meio.
fn shortened(text string) string {
	letters := text.runes()
	if letters.len <= text_preview {
		return text
	}
	return letters[..text_preview].string() + '…'
}
