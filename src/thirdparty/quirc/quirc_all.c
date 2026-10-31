/* As fontes do quirc numa unidade só, para entrarem na compilação do V junto com o
 * programa, pelo #include de qr.v: o V só compila o C que ele mesmo gera e o que esse C
 * inclui. Os arquivos ao lado são os de lib/ da versão indicada em LEIA-ME.txt, sem
 * alteração. */
#include "quirc.c"
#include "decode.c"
#include "identify.c"
#include "version_db.c"
