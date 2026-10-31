module main

import math

// A leitura do texto do SVG: os elementos, os atributos e os comandos do `d`. Fica à parte
// do desenho porque é a metade que não sabe nada de GDI+ — e é a que dá para testar sem
// abrir janela nenhuma.

// tags devolve o texto de cada elemento do documento, sem os sinais de menor e maior.
fn tags(text string) []string {
	mut found := []string{}
	mut rest := text
	for {
		open := rest.index('<') or { break }
		rest = rest[open + 1..]
		close := rest.index('>') or { break }
		found << rest[..close]
		rest = rest[close + 1..]
	}
	return found
}

// tag_name devolve o nome do elemento, que é o que vem antes do primeiro espaço.
fn tag_name(tag string) string {
	for index, letter in tag {
		if letter == ` ` || letter == `\t` || letter == `\n` || letter == `/` {
			return tag[..index]
		}
	}
	return tag
}

// first_tag devolve o primeiro elemento com o nome pedido.
fn first_tag(text string, name string) ?string {
	for tag in tags(text) {
		if tag_name(tag) == name {
			return tag
		}
	}
	return none
}

// attribute devolve o valor do atributo. A busca inclui o espaço antes do nome e o sinal de
// igual depois, senão `stroke` acharia `stroke-width` e `fill` acharia `fill-opacity`.
fn attribute(tag string, name string) ?string {
	key := ' ${name}="'
	start := tag.index(key) or { return none }
	rest := tag[start + key.len..]
	end := rest.index('"') or { return none }
	return rest[..end]
}

// Pointf é um ponto com casas decimais, que é como o SVG fala.
struct Pointf {
	x f64
	y f64
}

// PathScanner percorre o atributo `d` devolvendo comandos e números. Os separadores do SVG
// são frouxos: vírgula, espaço, ou nada quando o sinal já separa.
struct PathScanner {
	data string
mut:
	pos int
}

fn (mut s PathScanner) skip() {
	for s.pos < s.data.len && s.data[s.pos] in [` `, `\t`, `\n`, `\r`, `,`] {
		s.pos++
	}
}

fn (s PathScanner) done() bool {
	return s.pos >= s.data.len
}

// is_command diz se o byte é uma das letras de comando que este leitor entende.
fn is_command(letter u8) bool {
	return letter in [`M`, `m`, `L`, `l`, `H`, `h`, `V`, `v`, `C`, `c`, `A`, `a`, `Z`, `z`]
}

// accept avança um byte quando ele é um dos dois pedidos, e diz se avançou.
fn (mut s PathScanner) accept(a u8, b u8) bool {
	if s.pos < s.data.len && (s.data[s.pos] == a || s.data[s.pos] == b) {
		s.pos++
		return true
	}
	return false
}

// digits avança sobre os algarismos, e também sobre os pontos quando `dot` é verdadeiro.
fn (mut s PathScanner) digits(dot bool) {
	for s.pos < s.data.len && (s.data[s.pos].is_digit() || (dot && s.data[s.pos] == `.`)) {
		s.pos++
	}
}

// number lê o próximo número, com sinal, casas decimais e expoente. O sinal do expoente só vale depois do `e`: sem ele, um sinal começa o número seguinte, como em "1.6-1.4".
fn (mut s PathScanner) number() f64 {
	s.skip()
	start := s.pos
	s.accept(`-`, `+`)
	s.digits(true)
	if s.accept(`e`, `E`) {
		s.accept(`-`, `+`)
		s.digits(false)
	}
	if s.pos == start {
		// Nada que pareça número: anda um byte para não girar em falso.
		s.pos++
		return 0
	}
	return s.data[start..s.pos].f64()
}

// flag lê um dos dois indicadores do arco, que valem zero ou um e podem vir colados.
fn (mut s PathScanner) flag() bool {
	s.skip()
	if s.done() {
		return false
	}
	letter := s.data[s.pos]
	s.pos++
	return letter == `1`
}

// arc_sweep devolve quanto o arco gira, com o sinal que o indicador de sentido pede: positivo no sentido crescente, negativo no decrescente. Um giro nulo fica nulo.
fn arc_sweep(start f64, finish f64, sweep bool) f64 {
	turn := finish - start
	if sweep && turn < 0 {
		return turn + 2 * math.pi
	}
	if !sweep && turn > 0 {
		return turn - 2 * math.pi
	}
	return turn
}

// arc_beziers converte o arco do SVG numa sequência de curvas de bezier, que é o que o
// GDI+ sabe acrescentar a um caminho. O SVG descreve o arco pelo ponto de chegada; o GDI+
// quer o centro, então a conta é a conversão padrão de uma forma para a outra.
fn arc_beziers(from Pointf, to Pointf, radius_x f64, radius_y f64, rotation f64, large bool, sweep bool) [][]Pointf {
	if radius_x == 0 || radius_y == 0 {
		return [][]Pointf{}
	}
	angle := rotation * math.pi / 180
	cosine := math.cos(angle)
	sine := math.sin(angle)
	half_x := (from.x - to.x) / 2
	half_y := (from.y - to.y) / 2
	turned_x := cosine * half_x + sine * half_y
	turned_y := -sine * half_x + cosine * half_y

	// Raios pequenos demais para ligar os dois pontos são esticados até darem, que é o que
	// a especificação manda fazer em vez de desistir.
	mut rx := math.abs(radius_x)
	mut ry := math.abs(radius_y)
	excess := turned_x * turned_x / (rx * rx) + turned_y * turned_y / (ry * ry)
	if excess > 1 {
		rx *= math.sqrt(excess)
		ry *= math.sqrt(excess)
	}

	numerator := math.max(0.0, rx * rx * ry * ry - rx * rx * turned_y * turned_y - ry * ry * turned_x * turned_x)
	denominator := rx * rx * turned_y * turned_y + ry * ry * turned_x * turned_x
	mut reach := if denominator == 0 { 0.0 } else { math.sqrt(numerator / denominator) }
	if large == sweep {
		reach = -reach
	}
	turned_center_x := reach * rx * turned_y / ry
	turned_center_y := -reach * ry * turned_x / rx
	center := Pointf{
		x: cosine * turned_center_x - sine * turned_center_y + (from.x + to.x) / 2
		y: sine * turned_center_x + cosine * turned_center_y + (from.y + to.y) / 2
	}

	start := math.atan2((turned_y - turned_center_y) / ry, (turned_x - turned_center_x) / rx)
	finish := math.atan2((-turned_y - turned_center_y) / ry, (-turned_x - turned_center_x) / rx)
	sweep_angle := arc_sweep(start, finish, sweep)

	// Um bezier não acompanha bem mais de um quarto de volta, então o arco é fatiado.
	steps := int(math.ceil(math.abs(sweep_angle) / (math.pi / 2)))
	step := sweep_angle / f64(steps)
	// O comprimento das alavancas que fazem o bezier passar rente ao arco.
	lever := 4.0 / 3.0 * math.tan(step / 4)
	mut curves := [][]Pointf{}
	for index in 0 .. steps {
		begin := start + f64(index) * step
		end := begin + step
		curves << [
			on_ellipse(center, rx, ry, cosine, sine, begin),
			ellipse_control(center, rx, ry, cosine, sine, begin, lever),
			ellipse_control(center, rx, ry, cosine, sine, end, -lever),
			on_ellipse(center, rx, ry, cosine, sine, end),
		]
	}
	return curves
}

// on_ellipse devolve o ponto da elipse no ângulo dado, já girado.
fn on_ellipse(center Pointf, rx f64, ry f64, cosine f64, sine f64, angle f64) Pointf {
	x := rx * math.cos(angle)
	y := ry * math.sin(angle)
	return Pointf{
		x: center.x + cosine * x - sine * y
		y: center.y + sine * x + cosine * y
	}
}

// ellipse_control devolve o ponto de controle do bezier, que sai do ponto da elipse na
// direção da tangente.
fn ellipse_control(center Pointf, rx f64, ry f64, cosine f64, sine f64, angle f64, lever f64) Pointf {
	point := on_ellipse(center, rx, ry, cosine, sine, angle)
	tangent_x := -rx * math.sin(angle)
	tangent_y := ry * math.cos(angle)
	return Pointf{
		x: point.x + lever * (cosine * tangent_x - sine * tangent_y)
		y: point.y + lever * (sine * tangent_x + cosine * tangent_y)
	}
}

// point lê um par de números, somado ao cursor quando o comando é relativo.
fn (mut s PathScanner) point(cursor Pointf, relative bool) Pointf {
	x := s.number()
	y := s.number()
	return Pointf{
		x: if relative { cursor.x + x } else { x }
		y: if relative { cursor.y + y } else { y }
	}
}
