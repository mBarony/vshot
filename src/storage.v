module main

import os
// Nenhuma função do módulo é chamada pelo V: o import liga o stbi e traz o cabeçalho em que a stbi_write_png_to_func é declarada.
import stbi as _
import time

// O nome de fábrica da pasta das capturas, criada ao lado do executável. A configuração
// pode trocar o nome ou pôr a pasta em qualquer lugar.
const output_dir = 'capturas'

fn C.stbi_write_png_to_func(func voidptr, context voidptr, width int, height int, channels int, data voidptr, stride int) int

// save grava a captura como PNG na pasta pedida, criando-a se preciso, e devolve o caminho
// do arquivo.
// O arquivo é aberto pelo os, que no Windows usa a API larga, e o stbi só monta o PNG e o entrega a write_png_chunk. O stbi_write_png abriria o arquivo ele mesmo, com o fopen estreito, que lê o caminho na página de código do sistema e falha com acento — numa pasta chamada Área, por exemplo. Por dentro ele monta o PNG em memória do mesmo jeito, então o consumo não muda.
fn save(shot Screenshot, dir string) !string {
	ensure_dir(dir)!
	path := free_path(dir)
	mut sink := PngSink{
		file: os.create(path)!
	}
	ok := C.stbi_write_png_to_func(voidptr(write_png_chunk), voidptr(&sink), shot.width, shot.height, 4, shot.pixels, shot.width * 4)
	sink.file.close()
	// Com o disco cheio, o pendrive tirado ou a pasta de rede fora do ar, a gravação sai curta — muitas vezes só no fechamento, que não avisa —, e o balão dizia "Captura salva" sobre um arquivo truncado. O tamanho do arquivo é o que mostra se o PNG chegou inteiro.
	if ok == 0 || os.file_size(path) != sink.bytes {
		os.rm(path) or {}
		return error(if ok == 0 { 'falha ao montar o PNG' } else { 'falha ao gravar o PNG' })
	}
	return path
}

// ensure_dir cria a pasta e as de cima que faltam, subindo pelo caminho até achar uma que existe. O os.mkdir_all remonta o caminho pela raiz: num caminho de rede, \\servidor\compartilhamento\nova, ele tentava criar \servidor no disco atual em vez de usar o compartilhamento.
fn ensure_dir(path string) ! {
	dir := path.trim_right('\\/')
	if os.is_dir(dir) {
		return
	}
	// Subiu até a raiz sem achar nada: um disco que não existe, ou uma pasta de rede fora do ar.
	if dir == '' {
		return error('o começo do caminho não existe')
	}
	parent := os.dir(dir)
	if parent != dir && parent != '' {
		ensure_dir(parent)!
	}
	os.mkdir(dir)!
}

// PngSink é o destino do stbi: o arquivo, e quantos bytes do PNG montado foram mandados para ele.
struct PngSink {
mut:
	file  os.File
	bytes u64
}

// write_png_chunk recebe do stbi o PNG montado, grava no arquivo que save abriu e conta os bytes.
fn write_png_chunk(context voidptr, data voidptr, size int) {
	mut sink := unsafe { &PngSink(context) }
	sink.bytes += u64(size)
	unsafe { sink.file.write_ptr(data, size) }
}

// free_path devolve um caminho ainda não ocupado: o carimbo de tempo tem resolução de
// segundo, e duas capturas no mesmo segundo apagariam a primeira.
fn free_path(dir string) string {
	stamp := time.now().custom_format('YYYY-MM-DD_HH-mm-ss')
	mut path := os.join_path(dir, 'captura_${stamp}.png')
	for i := 1; os.exists(path); i++ {
		path = os.join_path(dir, 'captura_${stamp}_${i}.png')
	}
	return path
}
