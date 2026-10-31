module main

// A configuração é texto escrito à mão, e o que importa é a leitura: o que ela aceita, o
// que ela recusa dizendo onde, e que o arquivo que a aplicação escreve volta igual.

// As combinações se leem em qualquer caixa e com espaços, e se escrevem de volta do jeito
// que a barra mostra.
fn test_as_combinacoes_de_teclas() ! {
	screen := parse_hotkey('ctrl + shift + 2')!
	assert screen == Hotkey{mod_control | mod_shift, 0x32}
	assert screen.str() == 'Ctrl+Shift+2'
	assert parse_hotkey('Alt+PrintScreen')!.str() == 'Alt+PrintScreen'
	assert parse_hotkey('F12')! == Hotkey{0, 0x7b}
	assert parse_hotkey('Win+Shift+s')!.str() == 'Shift+Win+S'
	if _ := parse_hotkey('Ctrl+Shift') {
		assert false, 'uma combinação sem tecla não vale'
	}
	if _ := parse_hotkey('Ctrl+A+B') {
		assert false, 'duas teclas não valem'
	}
	if _ := parse_hotkey('Ctrl+Enter') {
		assert false, 'tecla que a configuração não conhece'
	}
}

// Os nomes das teclas vão e voltam.
fn test_os_nomes_das_teclas() {
	for name in ['A', 'Z', '0', '9', 'F1', 'F24', 'PrintScreen', 'Pause', 'Insert'] {
		code := key_code(name) or { panic(name) }
		assert key_name(code) == name
	}
	assert key_code('F25') == none
	assert key_code('F01') == none
}

// O arquivo que a aplicação escreve na primeira vez é lido de volta como a configuração de
// fábrica, e a de fábrica é a de sempre: os atalhos, as teclas da referência e a pasta.
fn test_o_arquivo_de_fabrica_volta_igual() ! {
	defaults := default_config()
	assert defaults.screen.str() == 'Ctrl+Shift+2'
	assert defaults.ocr.str() == 'Ctrl+Shift+5'
	assert defaults.save.str() == 'Ctrl+S'
	assert defaults.tools[toolbar_tools.index(Tool.rectangle)] == u32(`R`)
	assert defaults.zoom == .plain
	assert defaults.folder == 'capturas'
	assert !defaults.autostart
	assert !defaults.all_monitors
	assert parse_config(defaults.text())! == defaults
}

// Cada opção muda o que diz; as que faltam ficam com o valor de fábrica; comentários e
// linhas vazias não contam.
fn test_as_opcoes_mudam_o_que_dizem() ! {
	config := parse_config('; um comentário\n\ncaptura_area = Ctrl+Alt+R ; outro\nretangulo = Q\nzoom = Ctrl + Roda\npasta = C:\\Imagens\\VShot\niniciar_com_windows = sim\ncapturar_todos_monitores = sim\n')!
	assert config.region == Hotkey{mod_control | mod_alt, u32(`R`)}
	assert config.screen == default_config().screen
	assert config.tools[toolbar_tools.index(Tool.rectangle)] == u32(`Q`)
	assert config.zoom == .ctrl
	assert config.folder == 'C:\\Imagens\\VShot'
	assert config.output_path() == 'C:\\Imagens\\VShot'
	assert config.autostart
	assert config.all_monitors
}

// O alinhamento começa ligado, o arquivo o desliga, e o botão muda só a linha dele: num arquivo de uma versão anterior, sem a linha, ela entra no fim.
fn test_a_opcao_do_alinhamento() ! {
	assert default_config().snap_edges
	assert !parse_config('alinhar_bordas = nao')!.snap_edges
	text := '; meu comentário\r\nzoom = ctrl+roda\r\nalinhar_bordas = sim ; à mão\r\n'
	assert text_with_snap(text, false) == '; meu comentário\r\nzoom = ctrl+roda\r\nalinhar_bordas = nao\r\n'
	old := text_with_snap('zoom = ctrl+roda\r\n', false)
	assert old == 'zoom = ctrl+roda\r\nalinhar_bordas = nao\r\n'
	config := parse_config(old)!
	assert !config.snap_edges
	assert config.zoom == .ctrl
}

// O arquivo salvo pelo Bloco de Notas com a marca de UTF-8 no começo é lido igual.
fn test_a_marca_de_utf8_nao_atrapalha() ! {
	defaults := default_config()
	assert parse_config('﻿' + defaults.text())! == defaults
}

// Um erro diz a linha e o motivo, para ser achado no Bloco de Notas.
fn test_os_erros_dizem_a_linha() {
	cases := {
		'captura_tela = Ctrl+Shift+2\nzoom = alt+roda': 'linha 2: o zoom'
		'seta = Ctrl+A':                                'linha 1: tecla desconhecida'
		'cor = vermelha':                               'linha 1: opção desconhecida "cor"'
		'pasta':                                        'linha 1: falta o "="'
		'iniciar_com_windows = talvez':                 'linha 1: use sim ou nao'
		'capturar_todos_monitores = todos':             'linha 1: use sim ou nao'
		'seta = R':                                     'a tecla R está em seta e em retangulo'
		'copiar = Win+C':                               'linha 1: o Win não vale nos atalhos do editor'
		'salvar = S':                                   'linha 1: o atalho do editor precisa de Ctrl ou Alt'
		'salvar = Shift+S':                             'precisa de Ctrl ou Alt'
		'seta = F10':                                   'linha 1: a tecla F10 não serve para ferramenta'
		'lupa = PrintScreen':                           'linha 1: a tecla PrintScreen não serve'
		'seta = 1':                                     'linha 1: a tecla 1 não serve'
		// Num vshot.ini de antes do captura_texto, o de fábrica dele repete o que o usuário pôs noutra opção.
		'captura_editor = Ctrl+Shift+5':                'Ctrl+Shift+5 está em captura_editor e em captura_texto'
		'copiar = Ctrl+Shift+2':                        'Ctrl+Shift+2 está em captura_tela e em copiar'
	}
	for text, expected in cases {
		parse_config(text) or {
			assert err.msg().contains(expected), '${text}: ${err.msg()}'
			continue
		}
		assert false, '${text} deveria ter sido recusado'
	}
}
