module main

// Juntar as linhas tira as quebras — as do Windows e as soltas —, os espaços que sobravam nas pontas de cada linha e as linhas em branco entre os parágrafos.
fn test_juntar_as_linhas() {
	assert joined_lines('primeira linha\r\nsegunda\nterceira') == 'primeira linha segunda terceira'
	assert joined_lines('  recuada  \r\n\r\n  depois do branco ') == 'recuada depois do branco'
	assert joined_lines('uma só') == 'uma só'
}

// O texto longo é cortado para o popup e o balão sem partir um caractere acentuado ao meio; o curto passa inteiro.
fn test_texto_longo_e_cortado_inteiro() {
	cut := shortened('ã'.repeat(text_preview + 10))
	assert cut.runes().len == text_preview + 1
	assert cut.ends_with('…')
	assert shortened('curto') == 'curto'
}

// A reticência do corte cabe no balão da bandeja, que guarda 255 unidades: cortado depois disso, o Windows truncava o texto e a reticência nunca aparecia.
fn test_o_corte_cabe_no_balao() {
	shown := shortened('ã'.repeat(1000))
	assert utf16_length(shown) <= 255
	assert shown.ends_with('…')
}
