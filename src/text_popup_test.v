module main

fn C.IsWindow(hwnd voidptr) bool

fn C.GetForegroundWindow() voidptr

fn C.SendMessageW(hwnd voidptr, message u32, wparam usize, lparam isize) isize

// A faixa fica no centro da área de trabalho do monitor, encostada na borda de cima, também num segundo monitor à direita do primeiro; com a barra de tarefas no alto, ela encosta embaixo da barra, e não por cima dela.
fn test_a_faixa_encosta_no_topo_central() {
	assert text_popup_rect(Rect{
		width:  1920
		height: 1040
	}) == Rect{
		x:      (1920 - text_popup_width) / 2
		y:      0
		width:  text_popup_width
		height: text_popup_height
	}
	second := text_popup_rect(Rect{
		x:      1920
		width:  2560
		height: 1400
	})
	assert second.x == 1920 + (2560 - text_popup_width) / 2
	assert second.y == 0
	below_taskbar := text_popup_rect(Rect{
		y:      48
		width:  1920
		height: 1032
	})
	assert below_taskbar.y == 48
}

// O botão fica na ponta direita, e a amostra do texto à esquerda dele, sem encostar; os dois cabem na altura da faixa.
fn test_o_botao_fica_a_direita_da_amostra() {
	button := text_button_rect()
	preview := text_preview_rect()
	assert button.x + button.width == text_popup_width - text_popup_padding
	assert preview.x == text_popup_padding
	assert preview.x + preview.width < button.x
	assert button.y >= 0 && button.y + button.height <= text_popup_height
	assert preview.y + preview.height <= text_popup_height
}

// Mostrar a faixa não tira o foco de ninguém, e o clique nela também não; uma faixa nova fecha a anterior, e fechar a tira da tela.
fn test_a_faixa_nao_toma_o_foco() {
	mut popup := TextPopup{}
	before := C.GetForegroundWindow()
	show_text_popup(mut popup, unsafe { nil }, 'primeira\nsegunda')
	first := popup.hwnd
	assert first != unsafe { nil }
	assert C.IsWindow(first)
	// O que decide o foco é o estilo e a resposta ao clique, e não quem está em primeiro plano: rodando em segundo plano, o Windows já impede qualquer janela de tomar o foco, e a comparação abaixo passaria sem eles. -20 é o GWL_EXSTYLE.
	assert u32(C.GetWindowLongPtrW(first, -20)) & ws_ex_noactivate != 0
	assert C.SendMessageW(first, wm_mouseactivate, 0, 0) == isize(ma_noactivate)
	assert C.GetForegroundWindow() == before
	show_text_popup(mut popup, unsafe { nil }, 'outra\nfaixa')
	assert !C.IsWindow(first)
	assert C.IsWindow(popup.hwnd)
	close_text_popup(mut popup)
	assert popup.hwnd == unsafe { nil }
}
