module main

import os

// Uma pasta com acento no caminho recebe o PNG inteiro: a gravação passa pela API larga do Windows, e não pelo fopen estreito, que lê o caminho na página de código do sistema.
fn test_salva_em_pasta_com_acento() ! {
	base := os.join_path(os.temp_dir(), 'vshot-teste-acento')
	defer {
		os.rmdir_all(base) or {}
	}
	pixels := [u8(255), 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 255, 255]
	shot := Screenshot{
		width: 2
		height: 2
		pixels: unsafe { &u8(pixels.data) }
	}
	path := save(shot, os.join_path(base, 'João', 'Área'))!
	assert os.exists(path)
	bytes := os.read_bytes(path)!
	assert bytes[..8] == [u8(0x89), 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
}

// Um compartilhamento de rede fora do ar é um erro, e não uma pasta nova no disco atual: era em \servidor, na raiz do disco, que o os.mkdir_all tentava criar o caminho.
fn test_a_pasta_de_rede_fora_do_ar_e_um_erro() {
	if _ := ensure_dir('\\\\localhost\\vshot-nao-existe\\a\\b') {
		assert false
	}
	assert !os.exists('\\localhost')
}

// A pasta nasce com as de cima, com ou sem a barra no fim, e criá-la de novo não é erro. Um arquivo no caminho é: a falha chega a quem salva, em vez de o PNG ir parar noutro lugar.
fn test_a_pasta_nasce_com_as_de_cima() ! {
	base := os.join_path(os.temp_dir(), 'vshot-teste-pasta')
	defer {
		os.rmdir_all(base) or {}
	}
	deep := os.join_path(base, 'a', 'b')
	ensure_dir(deep + os.path_separator)!
	assert os.is_dir(deep)
	ensure_dir(deep)!
	blocked := os.join_path(base, 'arquivo')
	os.write_file(blocked, '')!
	if _ := ensure_dir(os.join_path(blocked, 'c')) {
		assert false
	}
}
