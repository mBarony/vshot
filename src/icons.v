module main

// Os ícones da barra são os arquivos de `assets/icons`: desenhos de linha de 24 por 24,
// feitos à mão, que vão embutidos no executável para a aplicação continuar sendo um
// arquivo só. Eles são lidos uma vez na abertura do editor e viram caminhos do GDI+, que
// aceitam qualquer cor e qualquer tamanho na hora de desenhar.

// Lado do ícone dentro do botão da barra, que é também o lado do `viewBox` dos arquivos:
// eles saem desenhados sem redução.
const icon_size = 24

// Os desenhos que a barra usa, pelo nome do arquivo. Sobram arquivos sem dono na pasta —
// de botões que saíram da barra ou que ainda não entraram —, e eles não custam nada
// enquanto não entram nesta lista.
const icon_svg = {
	'arrow':         $embed_file('assets/icons/arrow.svg')
	'circle-handle': $embed_file('assets/icons/circle-handle.svg')
	'copy':          $embed_file('assets/icons/copy.svg')
	'counter':       $embed_file('assets/icons/counter.svg')
	'cursor':        $embed_file('assets/icons/cursor.svg')
	'droplet':       $embed_file('assets/icons/droplet.svg')
	'ellipse':       $embed_file('assets/icons/ellipse.svg')
	'frame':         $embed_file('assets/icons/frame.svg')
	'highlighter':   $embed_file('assets/icons/highlighter.svg')
	'line':          $embed_file('assets/icons/line.svg')
	'measure':       $embed_file('assets/icons/measure.svg')
	'pencil':        $embed_file('assets/icons/pencil.svg')
	'rect':          $embed_file('assets/icons/rect.svg')
	'save':          $embed_file('assets/icons/save.svg')
	'snap':          $embed_file('assets/icons/snap.svg')
	'text':          $embed_file('assets/icons/text.svg')
}

// tool_icon devolve o desenho da ferramenta.
fn tool_icon(tool Tool) string {
	return tool_info[int(tool)].icon
}

// action_icon devolve o desenho da ação.
fn action_icon(action Action) string {
	return match action {
		.copy { 'copy' }
		.save { 'save' }
	}
}

// IconSet são os desenhos da barra já convertidos em caminhos do GDI+.
struct IconSet {
	art map[string]IconArt
}

// load_icons lê todos os desenhos da lista. Precisa do GDI+ ligado.
fn load_icons() IconSet {
	mut art := map[string]IconArt{}
	for name in icon_svg.keys() {
		mut file := icon_svg[name] or { continue }
		art[name] = parse_svg(file.to_string())
	}
	return IconSet{
		art: art
	}
}

// release devolve ao GDI+ os caminhos dos ícones.
fn (set IconSet) release() {
	for _, art in set.art {
		art.release()
	}
}

// draw_icon põe o desenho no quadrado que começa em (x, y), na cor pedida.
fn draw_icon(hdc voidptr, name string, x int, y int, set IconSet, color u32) {
	art := set.art[name] or { return }
	draw_art(hdc, art, x, y, color)
}
