module main

import os

// A configuração: um arquivo de texto ao lado do executável, com uma opção por linha. Ele
// nasce com os valores de sempre e um comentário explicando cada opção, e é relido sozinho
// quando alguém o salva. Uma linha inválida não derruba nada: quem lê diz qual é a linha, e
// a configuração anterior continua valendo.

const config_file = 'vshot.ini'
const mod_alt = u32(0x0001)
const mod_win = u32(0x0008)

// Hotkey é uma combinação de teclas: os modificadores, na convenção do RegisterHotKey, e a
// tecla virtual.
struct Hotkey {
	modifiers u32
	key       u32
}

// Wheel é a combinação da roda do mouse que aproxima e afasta. As outras mudam o tamanho da
// ferramenta.
enum Wheel {
	plain
	ctrl
	shift
}

struct Config {
mut:
	screen    Hotkey
	region    Hotkey
	editor    Hotkey
	ocr       Hotkey
	copy      Hotkey
	save      Hotkey
	undo      Hotkey
	redo      Hotkey
	// A tecla de cada ferramenta, na ordem da barra.
	tools     []u32
	zoom      Wheel
	folder    string
	autostart bool
	// Se a captura para o editor pega todos os monitores, ou só o monitor em que o ponteiro está.
	all_monitors bool
	// Se as marcações encaixam umas nas outras ao mover, redimensionar e criar.
	snap_edges bool = true
}

// default_config é a configuração de fábrica, que é também o conteúdo do arquivo novo.
fn default_config() Config {
	return Config{
		screen: Hotkey{mod_control | mod_shift, 0x32}
		region: Hotkey{mod_control | mod_shift, 0x33}
		editor: Hotkey{mod_control | mod_shift, 0x34}
		ocr: Hotkey{mod_control | mod_shift, 0x35}
		copy: Hotkey{mod_control, 0x43}
		save: Hotkey{mod_control, 0x53}
		undo: Hotkey{mod_control, 0x5a}
		redo: Hotkey{mod_control, 0x59}
		tools: toolbar_tools.map(u32(tool_shortcut(it)[0]))
		zoom: .plain
		folder: output_dir
	}
}

// tool_setting é o nome da opção da tecla de cada ferramenta.
fn tool_setting(tool Tool) string {
	return tool_info[int(tool)].setting
}

// key_code traduz o nome de uma tecla: uma letra, um algarismo, F1 a F24, ou algumas pelo
// nome.
fn key_code(name string) ?u32 {
	upper := name.trim_space().to_upper()
	if upper.len == 1 && (upper[0].is_letter() || upper[0].is_digit()) {
		return u32(upper[0])
	}
	if code := function_key(upper) {
		return code
	}
	return match upper {
		'PRINTSCREEN', 'PRTSC' { u32(0x2c) }
		'PAUSE' { u32(0x13) }
		'INSERT' { u32(0x2d) }
		else { none }
	}
}

// function_key traduz F1 a F24, e só eles: F0, F25 e F01 não são teclas.
fn function_key(upper string) ?u32 {
	if upper.len < 2 || upper[0] != `F` || upper[1..].int().str() != upper[1..] {
		return none
	}
	number := upper[1..].int()
	if number < 1 || number > 24 {
		return none
	}
	return u32(0x70 + number - 1)
}

// key_name é o inverso de key_code, para a barra e o balão dizerem a tecla em vigor.
fn key_name(code u32) string {
	if (code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5a) {
		return [u8(code)].bytestr()
	}
	if code >= 0x70 && code <= 0x87 {
		return 'F${code - 0x70 + 1}'
	}
	return match code {
		0x2c { 'PrintScreen' }
		0x13 { 'Pause' }
		0x2d { 'Insert' }
		else { '?' }
	}
}

// parse_hotkey lê uma combinação como "Ctrl+Shift+2": modificadores e uma tecla só.
fn parse_hotkey(text string) !Hotkey {
	mut modifiers := u32(0)
	mut key := u32(0)
	for part in text.split('+') {
		modifier := match part.trim_space().to_lower() {
			'ctrl', 'control' { mod_control }
			'shift' { mod_shift }
			'alt' { mod_alt }
			'win' { mod_win }
			else { u32(0) }
		}
		if modifier != 0 {
			modifiers |= modifier
			continue
		}
		if key != 0 {
			return error('"${text}" tem mais de uma tecla')
		}
		key = key_code(part) or { return error('tecla desconhecida "${part.trim_space()}"') }
	}
	if key == 0 {
		return error('falta a tecla em "${text}"')
	}
	return Hotkey{modifiers, key}
}

// str escreve a combinação do jeito que o arquivo e a barra mostram.
fn (h Hotkey) str() string {
	mut parts := []string{}
	for modifier, name in {
		mod_control: 'Ctrl'
		mod_shift:   'Shift'
		mod_alt:     'Alt'
		mod_win:     'Win'
	} {
		if h.modifiers & modifier != 0 {
			parts << name
		}
	}
	parts << key_name(h.key)
	return parts.join('+')
}

// wheel_names são os valores da opção do zoom, na ordem de Wheel.
const wheel_names = ['roda', 'ctrl+roda', 'shift+roda']

// parse_config lê o texto do arquivo por cima da configuração de fábrica: uma opção que
// falta fica com o valor de sempre. Linhas vazias e o que vem depois de ";" não contam. A
// marca de UTF-8 que o Bloco de Notas pode pôr no começo também não: sem tirá-la, a
// primeira linha deixava de ser comentário e o arquivo inteiro era recusado.
fn parse_config(text string) !Config {
	mut config := default_config()
	for index, raw in text.trim_string_left('﻿').split_into_lines() {
		line := raw.all_before(';').trim_space()
		if line == '' {
			continue
		}
		if !line.contains('=') {
			return error('linha ${index + 1}: falta o "="')
		}
		config.set(line.all_before('=').trim_space().to_lower(), line.all_after('=').trim_space()) or {
			return error('linha ${index + 1}: ${err}')
		}
	}
	config.check_tools()!
	config.check_hotkeys()!
	return config
}

// check_hotkeys recusa o mesmo atalho em duas opções. Entre os de captura só um seria registrado no Windows, e um atalho do editor igual a um de captura nunca chegaria ao editor, porque o Windows o entrega à captura antes. A mensagem diz as duas opções: num vshot.ini de uma versão anterior, sem captura_texto, o atalho de fábrica dela pode repetir um que o usuário escolheu, e o arquivo não mostraria de onde vem o outro.
fn (c Config) check_hotkeys() ! {
	names := ['captura_tela', 'captura_area', 'captura_editor', 'captura_texto', 'copiar', 'salvar',
		'desfazer', 'refazer']
	keys := [c.screen, c.region, c.editor, c.ocr, c.copy, c.save, c.undo, c.redo]
	for index, key in keys {
		other := keys.index(key)
		if other != index {
			return error('${key} está em ${names[other]} e em ${names[index]}')
		}
	}
}

// set aplica uma opção.
fn (mut c Config) set(name string, value string) ! {
	match name {
		'captura_tela', 'captura_area', 'captura_editor', 'captura_texto' {
			c.set_hotkey(name, parse_hotkey(value)!)
		}
		'copiar', 'salvar', 'desfazer', 'refazer' {
			c.set_hotkey(name, editor_hotkey(value)!)
		}
		'zoom' {
			index := wheel_names.index(value.to_lower().replace(' ', ''))
			if index < 0 {
				return error('o zoom é ${wheel_names.join(', ')}')
			}
			c.zoom = unsafe { Wheel(index) }
		}
		'pasta' {
			if value == '' {
				return error('a pasta não pode ficar vazia')
			}
			c.folder = value
		}
		'iniciar_com_windows' {
			c.autostart = parse_yes(value)!
		}
		'capturar_todos_monitores' {
			c.all_monitors = parse_yes(value)!
		}
		'alinhar_bordas' {
			c.snap_edges = parse_yes(value)!
		}
		else {
			c.set_tool(name, value)!
		}
	}
}

// set_hotkey guarda a combinação da opção.
fn (mut c Config) set_hotkey(name string, key Hotkey) {
	match name {
		'captura_tela' { c.screen = key }
		'captura_area' { c.region = key }
		'captura_editor' { c.editor = key }
		'captura_texto' { c.ocr = key }
		'copiar' { c.copy = key }
		'salvar' { c.save = key }
		'desfazer' { c.undo = key }
		else { c.redo = key }
	}
}

// editor_hotkey lê um atalho do editor. A tabela de aceleradores do editor não guarda o Win, e sem Ctrl nem Alt o atalho engoliria uma tecla da digitação ou a de uma ferramenta.
fn editor_hotkey(value string) !Hotkey {
	key := parse_hotkey(value)!
	if key.modifiers & mod_win != 0 {
		return error('o Win não vale nos atalhos do editor')
	}
	if key.modifiers & (mod_control | mod_alt) == 0 {
		return error('o atalho do editor precisa de Ctrl ou Alt')
	}
	return key
}

// set_tool guarda a tecla de uma ferramenta, que é uma tecla sozinha, sem modificador.
fn (mut c Config) set_tool(name string, value string) ! {
	index := toolbar_tools.map(tool_setting(it)).index(name)
	if index < 0 {
		return error('opção desconhecida "${name}"')
	}
	code := key_code(value) or { return error('tecla desconhecida "${value}"') }
	// F10 e PrintScreen não chegam ao editor como tecla apertada, e 1 e 2 são da régua: a ferramenta ficaria sem tecla.
	if code in [u32(0x79), 0x2c, 0x31, 0x32] {
		return error('a tecla ${key_name(code)} não serve para ferramenta')
	}
	c.tools[index] = code
}

// check_tools recusa a mesma tecla em duas ferramentas: só uma delas poderia ser escolhida.
fn (c Config) check_tools() ! {
	for index, key in c.tools {
		other := c.tools.index(key)
		if other != index {
			return error('a tecla ${key_name(key)} está em ${tool_setting(toolbar_tools[other])} e em ${tool_setting(toolbar_tools[index])}')
		}
	}
}

// parse_yes lê sim ou não.
fn parse_yes(value string) !bool {
	answer := value.to_lower()
	if answer in ['sim', 's', 'yes', 'true', '1'] {
		return true
	}
	if answer in ['nao', 'não', 'n', 'no', 'false', '0'] {
		return false
	}
	return error('use sim ou nao, e não "${value}"')
}

// yes_no escreve sim ou nao, do jeito que parse_yes lê.
fn yes_no(value bool) string {
	return if value { 'sim' } else { 'nao' }
}

// output_path é a pasta das capturas: o nome configurado ao lado do executável, ou o
// caminho inteiro, se ele for absoluto.
fn (c Config) output_path() string {
	if os.is_abs_path(c.folder) {
		return c.folder
	}
	return os.join_path(os.dir(os.executable()), c.folder)
}

// text escreve a configuração do jeito que o arquivo guarda, com um comentário por grupo.
fn (c Config) text() string {
	mut lines := ['; VShot — configurações. Salve o arquivo e a aplicação o relê sozinha.',
		'; Um erro numa linha aparece no balão da bandeja, e as configurações anteriores',
		'; continuam valendo até ele ser corrigido.', '',
		'; Atalhos globais de captura: Ctrl, Shift, Alt e Win, mais uma tecla — uma letra, um',
		'; algarismo, F1 a F24 ou PrintScreen.', 'captura_tela = ${c.screen}',
		'captura_area = ${c.region}', 'captura_editor = ${c.editor}', 'captura_texto = ${c.ocr}', '',
		'; Capturar todos os monitores na captura para o editor: sim, ou nao para só o monitor em que está o ponteiro.',
		'capturar_todos_monitores = ${yes_no(c.all_monitors)}', '',
		'; Ações do editor: Ctrl ou Alt, com ou sem Shift, mais uma tecla — aqui o Win não vale.',
		'copiar = ${c.copy}', 'salvar = ${c.save}', 'desfazer = ${c.undo}',
		'refazer = ${c.redo}', '', '; A tecla que escolhe cada ferramenta no editor, sem modificador.']
	for index, tool in toolbar_tools {
		lines << '${tool_setting(tool)} = ${key_name(c.tools[index])}'
	}
	lines << ['', '; Qual roda aproxima e afasta: roda, ctrl+roda ou shift+roda. As outras duas',
		'; mudam o tamanho da ferramenta.', 'zoom = ${wheel_names[int(c.zoom)]}', '',
		'; A pasta das capturas: um nome, criado ao lado do executável, ou um caminho inteiro.',
		'pasta = ${c.folder}', '', '; Abrir a aplicação junto com o Windows: sim ou nao.',
		'iniciar_com_windows = ${yes_no(c.autostart)}', '',
		'; Alinhar as marcações umas às outras ao mover, redimensionar e criar: sim ou nao. O botão da barra do editor muda esta linha.',
		'alinhar_bordas = ${yes_no(c.snap_edges)}']
	return lines.join('\r\n') + '\r\n'
}

// text_with_snap devolve o texto do arquivo com a opção do alinhamento no valor pedido. Só a linha dela muda, porque o resto é de quem escreveu o arquivo; num arquivo de uma versão anterior, sem ela, a linha entra no fim.
fn text_with_snap(text string, on bool) string {
	line := 'alinhar_bordas = ${yes_no(on)}'
	mut lines := text.split_into_lines()
	index := lines.map(it.all_before(';').all_before('=').trim_space().to_lower()).index('alinhar_bordas')
	if index < 0 {
		lines << line
	} else {
		lines[index] = line
	}
	return lines.join('\r\n') + '\r\n'
}

// config_path é onde o arquivo mora: ao lado do executável.
fn config_path() string {
	return os.join_path(os.dir(os.executable()), config_file)
}

// load_config lê o arquivo, criando-o com a configuração de fábrica quando ele não existe.
fn load_config(path string) !Config {
	if !os.exists(path) {
		defaults := default_config()
		os.write_file(path, defaults.text())!
		return defaults
	}
	return parse_config(os.read_file(path)!)
}
