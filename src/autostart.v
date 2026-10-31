module main

import os

#flag windows -ladvapi32

fn C.RegCreateKeyExW(key voidptr, sub_key &u16, reserved u32, class &u16, options u32, access u32, security voidptr, result &voidptr, disposition &u32) int

fn C.RegSetValueExW(key voidptr, name &u16, reserved u32, kind u32, data voidptr, size u32) int

fn C.RegDeleteValueW(key voidptr, name &u16) int

fn C.RegCloseKey(key voidptr) int

// Iniciar com o Windows é uma linha na chave Run do usuário: o Windows abre, no login, cada
// programa que estiver ali. Nada de serviço nem de tarefa agendada, e nada que peça
// permissão de administrador.
const hkey_current_user = voidptr(usize(0x80000001))
const key_set_value = u32(0x0002)
const reg_sz = u32(1)
const run_key = 'Software\\Microsoft\\Windows\\CurrentVersion\\Run'

// apply_autostart põe ou tira a aplicação da chave Run, conforme a configuração. Chamar de
// novo com o mesmo valor não muda nada, e é por isso que ela roda a cada leitura do arquivo.
fn apply_autostart(enabled bool) ! {
	mut key := voidptr(unsafe { nil })
	// Criar abre a chave que existe e cria a que falta, num perfil novo ou limpo por um otimizador. Só abrir falhava nesses perfis: com nao, um balão de erro a cada leitura do arquivo; com sim, a entrada nunca era gravada.
	if C.RegCreateKeyExW(hkey_current_user, run_key.to_wide(), 0, unsafe { nil }, 0, key_set_value,
		unsafe { nil }, &key, unsafe { nil }) != 0 {
		return error('não foi possível abrir a chave de inicialização do Windows')
	}
	defer {
		C.RegCloseKey(key)
	}
	if !enabled {
		// Não estar lá já é o que se queria: o erro de valor inexistente não conta.
		C.RegDeleteValueW(key, app_name.to_wide())
		return
	}
	// Entre aspas, para um caminho com espaço não virar um programa e seus argumentos.
	command := '"${os.executable()}"'
	size := u32((utf16_length(command) + 1) * 2)
	if C.RegSetValueExW(key, app_name.to_wide(), 0, reg_sz, command.to_wide(), size) != 0 {
		return error('não foi possível gravar a chave de inicialização do Windows')
	}
}
