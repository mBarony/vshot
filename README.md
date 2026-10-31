# VShot

Aplicação residente na área de notificação do Windows 11. Fica parada consumindo quase nada e captura a tela sob demanda, salvando um PNG na pasta `capturas/`, criada ao lado do executável.

| Atalho de fábrica | O que faz |
|---|---|
| `Ctrl+Shift+2` | Captura a tela inteira e salva na hora |
| `Ctrl+Shift+3` | Congela a tela e deixa você arrastar um retângulo; só a área escolhida é salva |
| `Ctrl+Shift+4` | Captura o monitor em que o ponteiro está — ou todos, se a configuração pedir — e abre no editor, para recortar e marcar antes de salvar ou copiar |
| `Ctrl+Shift+5` | Congela a tela e deixa você arrastar um retângulo; o texto que está nele, ou o conteúdo de um QR code, vai para a área de transferência |

Não tem janela principal: o ícone na bandeja é toda a interface. Clique com o botão direito para escolher qualquer um dos quatro modos, abrir as configurações ou sair; clique duplo captura a tela inteira.

## Configuração

Tudo que é tecla ou escolha fica em `vshot.ini`, ao lado do executável. Ele nasce na primeira execução com os valores de fábrica e um comentário explicando cada opção, e o item **Configurações…** do menu da bandeja o abre no Bloco de Notas. Salve o arquivo e a aplicação o relê sozinha em até dois segundos: os atalhos novos passam a valer e o balão da bandeja confirma.

| Opção | O que decide | De fábrica |
|---|---|---|
| `captura_tela`, `captura_area`, `captura_editor`, `captura_texto` | Os atalhos globais dos quatro modos de captura | `Ctrl+Shift+2`, `3`, `4` e `5` |
| `copiar`, `salvar`, `desfazer`, `refazer` | Os atalhos das ações no editor | `Ctrl+C`, `Ctrl+S`, `Ctrl+Z`, `Ctrl+Y` |
| `selecionar`, `seta`, `texto`, `regua`, `retangulo`, `moldura`, `traco_livre`, `lupa`, `borrar`, `marca_texto`, `numerador`, `elipse`, `linha` | A tecla que escolhe cada ferramenta no editor | As da referência: `V`, `A`, `T`, `U`, `R`, `K`, `D`, `M`, `B`, `H`, `C`, `O`, `L` |
| `zoom` | Qual roda aproxima: `roda`, `ctrl+roda` ou `shift+roda`; as outras duas mudam o tamanho da ferramenta | `roda` |
| `pasta` | Onde as capturas são gravadas: um nome, criado ao lado do executável, ou um caminho inteiro | `capturas` |
| `capturar_todos_monitores` | Se a captura para o editor pega todos os monitores (`sim`) ou só o monitor em que o ponteiro está (`nao`) | `nao` |
| `iniciar_com_windows` | Abrir a aplicação no login do Windows: `sim` ou `nao` | `nao` |
| `alinhar_bordas` | Alinhar as marcações umas às outras ao mover, redimensionar e criar: `sim` ou `nao`. O botão da barra do editor muda esta linha | `sim` |

Os atalhos de captura combinam `Ctrl`, `Shift`, `Alt` e `Win` com uma tecla — uma letra, um algarismo, `F1` a `F24` ou `PrintScreen`. Os do editor precisam de `Ctrl` ou `Alt`, e neles o `Win` não vale: a tabela de atalhos do editor não o guarda, e sem modificador o atalho engoliria uma tecla da digitação ou a de uma ferramenta. As teclas das ferramentas vão sem modificador, e a mesma tecla não pode estar em duas; `F10` e `PrintScreen` também não servem, porque não chegam ao editor como tecla apertada, nem `1` e `2`, que são da régua. Um erro no arquivo — uma tecla que não existe, uma opção desconhecida, um atalho que outro programa já usa — aparece no balão com o número da linha, e as configurações anteriores continuam valendo inteiras até ele ser corrigido. Iniciar com o Windows é uma linha na chave `Run` do usuário no registro, posta e tirada conforme a opção, sem nada que peça administrador.

Ficam fixos os atalhos do zoom (`Ctrl +`, `Ctrl −`, `Ctrl 0`, `Ctrl 1`, `Ctrl 2`), o `Tab` do conta-gotas, o `Esc`, o `Delete` e as teclas da régua (`1`, `2` e as setas).

## Texto e QR code

O `Ctrl+Shift+5` congela a tela como o `Ctrl+Shift+3`: arraste um retângulo sobre o que quer copiar. Se houver um QR code na área, o conteúdo dele vai para a área de transferência; se não, vai o texto que o OCR do próprio Windows reconhece, nos idiomas instalados no Windows. O texto é copiado na hora, com as quebras de linha da tela. Quando ele tem mais de uma linha, uma faixa discreta, de quinas arredondadas, aparece encostada no topo da tela, no centro, sem tirar o foco de onde você estava: à esquerda, o começo do que foi copiado; à direita, o botão **Remover quebras de linha**, que copia o texto de novo numa linha só. A faixa some sozinha em alguns segundos, mas não enquanto o ponteiro está sobre ela. Com uma linha só, ou com um QR code, quem confirma a cópia é o balão da bandeja, que também avisa quando não havia nada escrito na área. A leitura do QR code usa o [quirc](https://github.com/dlbeer/quirc), embutido em `src/thirdparty/quirc`, de licença ISC.

O OCR lê no idioma do Windows quando há reconhecimento instalado para ele, e senão no primeiro idioma de reconhecimento que houver — num Windows em português com só o reconhecimento do inglês, as palavras saem, mas os acentos erram ("Não" vira "Näo"). Para acertá-los, rode o `instalar-ocr-portugues.bat`, que fica ao lado do executável: ele pede permissão de administrador, baixa o reconhecimento óptico de caracteres do português pelo Windows Update e diz quando terminou. O mesmo recurso também se instala pelas opções de idioma do Windows.

## O editor

Abre com a captura em 100% quando ela cabe, centrado na área útil do monitor em que o ponteiro está, com a ferramenta **Selecionar** na mão. Se não couber, reduz apenas o necessário para ocupar o maior tamanho disponível, descontando a barra de tarefas, o título, as bordas e a barra de ferramentas. A janela é redimensionável e maximizável: arraste a borda ou clique em maximizar e o espaço da imagem cresce junto, com a imagem reencaixada nele. O tamanho mínimo da barra é respeitado até o limite da área útil do monitor. Tudo fica na barra de cima. À esquerda, copiar e salvar; depois do traço que as separa, as ferramentas; no meio, a mensagem do que acabou de acontecer; e à direita a cor amostrada, o tamanho da imagem e o zoom.

As ferramentas são treze, nesta ordem: **Selecionar e recortar**, **Seta**, **Texto**, **Régua**, **Retângulo**, **Moldura**, **Traço livre**, **Lupa**, **Borrar**, **Marca-texto**, **Numerador**, **Elipse** e **Linha**. O plano de cada uma está em `PLANO-EDITOR.md`.

**Recortar** — com o primeiro botão das ferramentas, arraste sobre uma parte vazia da imagem e ela é recortada assim que você solta o botão. Um clique que tremeu não recorta: o arrasto precisa passar de oito pixels nos dois sentidos. O que sobra passa a ser a imagem de trabalho, exibida no tamanho real quando couber, e pode ser recortada de novo. As marcações já feitas acompanham o recorte, e desfazer devolve a captura inteira.

**Retângulo**, **Elipse**, **Linha** e **Seta** — arraste para desenhar sobre a imagem, para destacar algo. A elipse é a inscrita no retângulo do arrasto; a linha e a seta vão de onde o arrasto começou até onde ele terminou, e a ponta da seta fica onde ele terminou. Com `Shift` apertado a linha e a seta se prendem ao ângulo mais próximo entre 0°, 45° e 90°, e o retângulo e a elipse viram quadrado e círculo, com o lado do maior dos dois lados do arrasto.

**Traço livre** — arraste e o traço acompanha o mouse. Um clique sem arrastar deixa um ponto, que é uma marcação como outra qualquer.

**Numerador** — cada clique põe um balão com o próximo número. O balão tem as três formas da referência, escolhidas no painel: o círculo, que é o padrão, a ponta fina e a ponta grossa, em gota. A ponta nasce embaixo à direita; arrastar a partir do balão ao criá-lo a aponta para onde o arrasto foi, e com o balão selecionado uma alça além da ponta a gira para qualquer ângulo. Apagar um do meio renumera os seguintes sozinho.

**Texto** — arraste para dizer onde o texto vai caber e escreva. O que aparece enquanto se digita já é o resultado: mesma fonte, mesma cor, mesmo balão. `Enter` quebra a linha, `Ctrl+Enter` termina, `Esc` desiste, e um clique fora da caixa também termina. A largura vem do arrasto e decide onde as linhas quebram; a altura acompanha o que foi escrito. Com a ferramenta na mão, o ponteiro sobre a imagem é o cursor de texto do Windows, a barra em forma de I. Um clique sem arrastar abre uma caixa de partida à direita desse cursor, com a primeira linha centrada no meio dele; as linhas seguintes crescem para baixo. Perto da borda da imagem, a caixa se ajusta para caber nela. Acentuação funciona: as teclas mortas chegam já compostas. Com a ferramenta **Selecionar** na mão, um duplo clique sobre um texto o reabre para reescrever — apagar tudo apaga a marcação.

**Marca-texto** — o mesmo traço, largo e translúcido, para destacar sem esconder. Escolhê-lo já troca a cor para amarelo e a espessura para doze, o máximo do controle; sair dele devolve o vermelho e o traço fino. A prévia durante o arrasto tem exatamente a cor, a espessura, o canto e o preenchimento do resultado, inclusive quando a imagem está reduzida e a espessura é fracionária.

**Borrar** — arraste sobre o que não deve ser lido. Ela tem dois modos: **borrar em blocos**, que reduz a área a um mosaico, e **apagar com a média**, que a cobre com uma cor só, tirada da média do que havia ali. O controle do painel governa o tamanho do bloco. É a única ferramenta sem disco de cor: as duas tiram a cor da própria imagem.

**Lupa** — arraste sobre o que é pequeno demais para ser lido e ele aparece três vezes maior ao lado, ligado à origem por uma linha. A lente sai na diagonal de onde o arrasto partiu: quem arrasta para a direita e para baixo a coloca em cima e à esquerda, no espaço que acabou de deixar livre. Perto da borda, onde ela não caberia nessa diagonal, vai para o outro lado da origem naquele eixo, e num recorte pequeno demais para ela fica presa à borda dele — fora da imagem ela não apareceria no resultado, nem as alças dela poderiam ser pegas. As duas pontas podem ser redondas ou retangulares. Clicar em qualquer uma das duas escolhe a marcação, e cada uma ganha as suas alças: a origem decide o que a lente mostra, e a lente decide onde isso aparece e com que tamanho. Mover ou esticar uma não mexe na outra, e esticar a lente aumenta a ampliação. A linha que as liga vai de borda a borda.

**Moldura** — põe a imagem inteira dentro de outra, maior, para a captura ganhar respiro antes de virar post ou slide. Não se arrasta: escolher a ferramenta já põe a moldura, e o painel governa o resto — a cor pelo disco, a largura pelo controle, e os quatro botões escolhem o canto da imagem, arredondado ou reto, e se ela projeta sombra. O painel é dela enquanto ela está escolhida; depois de um `Esc` ou de um desfazer ele some, para não mexer em valores que moldura nenhuma usa. Escolher a ferramenta de novo devolve a moldura que já existe, e o painel com ela, em vez de empilhar uma segunda; `Delete` com ela escolhida a tira. O resultado salvo é a imagem com a moldura, e as marcações já feitas continuam onde estavam.

**Régua** — arraste para medir: o traço ganha as duas pontas marcadas e uma etiqueta com o comprimento em pixels da captura, que acompanha o arrasto enquanto ele acontece. Com `Shift` ela se prende a 0°, 45° e 90°, como a linha. Ela também mede sozinha, pelo teclado, como a referência: escolher a régua abre uma caixa com o aviso *Use o teclado — Segure 1, 2 ou uma seta para medir. Clique para adicionar; solte a tecla para cancelar.*. Segurando `1`, a régua acha onde começa e onde termina, na vertical, a faixa de cor sob o ponteiro; segurando `2`, na horizontal; segurando uma seta, mede do ponteiro até a borda da faixa naquela direção. Enquanto a tecla está apertada a medida acompanha o mouse. Clique com o botão esquerdo para adicioná-la à imagem como uma régua selecionada e ajustável; soltar a tecla sem clicar cancela a prévia. É o jeito de medir a largura de um botão ou a altura de uma barra sem mirar nas bordas dele. A caixa some na primeira medida, no primeiro clique sobre a imagem ou com `Esc`.

**Conta-gotas** — o primeiro bloco da direita da barra mostra a cor do pixel sob o ponteiro, e `Tab` a copia como texto. `Shift+Tab` copia a cor mais escura nos vinte pixels em volta do ponteiro: sobre texto, é a cor da letra e não a do fundo, sem precisar mirar num traço de um pixel. Clicar no bloco troca o formato, entre os oito da referência — `#FFC200`, `FFC200`, `rgba()` do CSS, RGB em frações de um, Android `0xFFFFC200`, `UIColor`, C# `Color.FromArgb()` e OKLCH. A cor é lida na captura em tamanho real, e não no que a janela mostra reduzido: a redução mistura pixels vizinhos, e a cor que ela daria não existe na captura.

**Redimensionar** — o bloco do meio da barra mostra o tamanho do resultado, e clicar nele abre um painel com 25%, 33%, 50%, 1×, 2× e 4×, sempre em relação à captura. A moldura e as marcações redimensionam junto, e salvar e copiar levam a imagem no tamanho escolhido. Diferente da referência, que avisa que não dá para voltar, aqui `Ctrl+Z` desfaz o redimensionamento como qualquer outra edição.

**Zoom** — o último bloco da direita da barra mostra quanto a imagem está ampliada na janela, e clicar nele abre um painel com − e + e os atalhos. A roda do mouse, sem tecla nenhuma apertada, aproxima e afasta mantendo parado o que está sob o ponteiro, então ela leva direto ao detalhe — com `Ctrl` ou `Shift` ela muda o tamanho da ferramenta, como descrito no painel de opções; com a imagem maior que a janela, o botão direito arrastado a desloca. `Ctrl +` e `Ctrl −` aproximam e afastam a partir do meio, `Ctrl 0` volta à imagem inteira, `Ctrl 1` mostra em tamanho real, um pixel da imagem para um da tela, e `Ctrl 2` aproxima a marcação escolhida até ela ocupar quase toda a área visível. O zoom é só da vista: não entra no histórico nem no que é salvo, e continua valendo enquanto se desenha, se desfaz ou se redimensiona. Ele vai de caber na janela até oito vezes o pixel da imagem, e dá para desenhar, escolher e medir com a imagem ampliada.

**A cor** sai da paleta que pende do disco: oito cores num toque e um botão **Personalizada** para o seletor do Windows, que abre já na cor em vigor e com as mesmas oito à mão. Um clique fora da paleta a fecha sem escolher nada, e o `Esc` fecha ela antes de desmarcar ou fechar a janela.

**A marcação recém-desenhada já vem selecionada.** Assim que você solta o botão, ela ganha as alças e o painel passa a governá-la: trocar cor, espessura ou estilo ali muda o que acabou de ser feito, e a escolha continua valendo para as próximas. As alças e o corpo dela pegam mesmo com a ferramenta de desenho ainda na mão: arrastar uma alça ajusta o tamanho, e arrastar o corpo move a marcação, sem trocar de ferramenta. Um arrasto que comece fora dela desenha uma marcação nova, que passa a ser a selecionada; para desenhar por cima da selecionada, o `Esc` a desmarca antes. Um clique sem arrastar sobre uma marcação qualquer a escolhe, com qualquer ferramenta na mão — menos o numerador e o texto, que criam justamente com um clique e por isso continuam pondo o balão ou o texto, inclusive dentro de um retângulo.

**Selecionar** — é o mesmo botão do recorte: sobre uma marcação o clique a escolhe, e sobre a imagem vazia o arrasto recorta, com o ponteiro em cruz para dizer isso. Clique sobre uma marcação para escolhê-la. Linhas, setas e réguas ganham somente duas alças, uma em cada extremidade: arrastar uma ponta mantém a outra parada e permite girar o traço, inclusive quando ele é horizontal ou vertical. As demais formas com caixa mantêm suas alças de redimensionamento. Arraste o corpo para mover a marcação inteira. Ao mover, ao redimensionar e ao criar, uma linha fina e tracejada aparece quando a marcação fica alinhada com outra — pela esquerda, pelo centro ou pela direita, por cima, pelo meio ou por baixo —, e a poucos pixels do alinhamento ela encaixa nele, porque com a imagem reduzida cada pixel do mouse vale mais de um da captura e o alinhamento exato não sairia na mão. `Delete` apaga a marcação escolhida e `Esc` apenas a desmarca — só o `Esc` seguinte, sem nada selecionado, fecha o editor. Enquanto uma marcação está sendo arrastada, o teclado e a roda esperam o botão ser solto, e enquanto se desenha o teclado também espera.

**Alinhar às bordas** — o botão depois das ferramentas liga e desliga o encaixe e as guias, e fica aceso enquanto está ligado. Ao redimensionar, só o lado ou a ponta que você pegou encaixa, e o outro fica parado. Ao criar, os dois lados do arrasto encaixam, e o balão do numerador encaixa pelo disco, já no clique. Com `Shift` o arrasto de criar não encaixa, porque ali a ponta já está presa ao ângulo ou ao quadrado. O traço livre e o marca-texto seguem o mouse, e o recorte não encaixa. A escolha vale para as próximas capturas, e fica guardada no `vshot.ini` quando o editor fecha.

**O painel de opções** aparece no canto superior direito, logo abaixo da barra, sempre que houver uma marcação selecionada ou uma ferramenta que desenhe. Ele traz o disco de cor, que abre a paleta, um controle deslizante de espessura, de um a doze pixels — que também anda com `Ctrl` ou `Shift` e a roda do mouse, um passo por dente, e muda o tamanho de qualquer ferramenta: o traço, a letra do texto, o balão do numerador, o bloco do borrão; sem nada que tenha tamanho, a roda volta a ser zoom —, e os botões de estilo da ferramenta: para o retângulo são cinco — cantos arredondados ou retos, e o preenchimento: só o contorno, translúcido, que destaca a área deixando a imagem aparecer, ou opaco, que a cobre por inteiro na cor da marcação —, para a elipse são os três do preenchimento, porque elipse não tem canto, para a linha são os dois do traço, contínuo ou pontilhado, para a seta são as quatro pontas — cheia, afunilada, simples e dupla —, para o texto são dois, o balão preenchido e a palavra solta, para borrar são dois, o mosaico e a média, para a lupa são dois, a forma redonda e a retangular, para a moldura são quatro, o canto da imagem e a sombra, para o numerador são as três formas do balão — círculo, ponta fina e ponta grossa —, e para o traço livre e o marca-texto não há nenhum, então o painel encolhe até o controle. Com uma marcação selecionada a troca vale para ela e entra no histórico; sem nenhuma, vale para as próximas.

**As ações abrem a barra**, antes das ferramentas: copiar e salvar. Como são só ícones, parar o ponteiro sobre um deles acende o botão e faz a barra dizer o nome e o atalho; quando o ponteiro sai, volta a mensagem que estava lá. Sobre uma ferramenta acontece o mesmo, com um fundo mais discreto que o da ferramenta na mão.

**Copiar** (`Ctrl+C`) põe a imagem editada na área de transferência e **Salvar** (`Ctrl+S`) a grava em `capturas/`. Os dois encerram o editor e confirmam pelo balão da bandeja.

**Desfazer** (`Ctrl+Z`), **Refazer** (`Ctrl+Y`) e **Fechar** (`Esc`, que sai sem salvar nada) ficam só no teclado. Desfazer e refazer andam pelo histórico uma edição por vez.

## Seleção de área

No `Ctrl+Shift+3` o que está fora do retângulo aparece escurecido e o que está dentro fica no brilho original, com uma borda branca. `Esc`, `Alt+F4` ou o botão direito cancelam, e um clique seco sem arrastar também.

## Compilar

```
windres -I src/assets src/assets/vshot.rc -O coff -o build/vshot-res.o
v -prod -cc gcc -subsystem windows -ldflags "$PWD/build/vshot-res.o" -o build/vshot.exe src
```

O primeiro comando compila o ícone da aplicação num objeto que o segundo entrega ao ligador junto com o código, e é assim que ele vai parar dentro do executável. O `windres` acompanha o gcc do MinGW. Sem o primeiro passo e sem o `-ldflags`, o executável sai do mesmo jeito, só que com o ícone genérico do Windows no Explorer, na bandeja e na janela do editor.

O caminho do objeto tem de ser absoluto — o `$PWD` funciona igual no PowerShell e no bash. O V liga o executável a partir da pasta dele, e não da do projeto, e um caminho relativo não é encontrado. Pelo mesmo motivo o objeto vai no `-ldflags`, e não no `-cflags`: este é repassado também à compilação dos módulos que o V guarda em cache, onde o objeto só atrapalha.

As outras três flags importam:

`-cc gcc` porque o tcc embutido no V não compila este programa. Sem a flag o V avisa e cai para o gcc sozinho, o que funciona mas polui a saída.

`-subsystem windows` porque sem ela o executável fica marcado como aplicativo de console e o Windows abre uma janela de console ao iniciá-lo pelo Explorer. O V já gera o ponto de entrada gráfico por conta própria — ele trata como gráfico todo programa que linka `gdi32` —, mas o padrão `auto` não repassa `-mwindows` ao linkador, então os dois lados discordam. A flag alinha os dois.

`-prod` reduz o executável de 1,1 MB para 416 KB.

Vale definir `V_C_ERROR_BUG_REPORT_DISABLED=1` no ambiente: quando a compilação C falha, o V envia por conta própria um trecho do código-fonte em volta do erro para `https://bugs.vlang.io/bug-report`.

## Usar

Execute `build/vshot.exe`. Ele não abre nada — vai para a bandeja e fica esperando os atalhos.

Cada captura vira `capturas/captura_AAAA-MM-DD_HH-MM-SS.png`, numa pasta criada ao lado do executável — durante o desenvolvimento, portanto, dentro de `build/`. A opção `pasta` da configuração troca o nome ou põe a pasta em qualquer lugar. Se duas caírem no mesmo segundo, a segunda ganha o sufixo `_1`, `_2` e assim por diante, em vez de apagar a primeira.

Os atalhos globais são exclusivos do sistema: se outro programa já registrou um deles, ou se a aplicação já estiver rodando, a segunda instância avisa numa caixa de diálogo e encerra em vez de ficar viva sem funcionar.

## Consumo

Os números de cada versão estão em `CONSUMO.md`, com uma linha por funcionalidade entregue, e o roteiro de medição em `scripts/medir-consumo.ps1`.

## Testar

```
v -subsystem console -cc gcc test src
```

O `-subsystem console` não é opcional aqui. Sem ele o binário de teste também é compilado como aplicativo gráfico, pelo mesmo motivo que o executável final, e aí os `assert` não têm para onde escrever: a falha aparece como um `FAIL` mudo, sem dizer qual asserção quebrou nem com quais valores.

Um teste desenha cores conhecidas num bitmap próprio e confere o que sai da leitura de pixels. Ele existe porque numa máquina sem tela renderizada a captura sai toda preta, e uma imagem preta esconderia tanto uma troca de canais de cor quanto uma inversão vertical da imagem.

Outro confere que a marcação sai com a borda suavizada: uma caneta de dois pixels centrada na borda cobre meio pixel de cada lado, e esse meio pixel tem de sair como mistura entre o traço e o fundo. Com o GDI ele saía de uma cor só, e é essa diferença que o teste fixa.

Outro cobre o painel de opções: que ele encolhe para a elipse e volta ao tamanho cheio quando a marcação selecionada é um retângulo, que o disco de cor é o primeiro item e o controle começa depois dele, que o painel fica no canto superior direito independentemente de onde esteja a marcação, que aparece também sem seleção quando a ferramenta desenha, que some durante o arrasto, que o botão do controle percorre a faixa inteira sem sair dela, que o canto e o preenchimento são independentes, que o preenchimento tem três escolhas e só uma fica acesa, que `Ctrl` ou `Shift` com a roda mudam o tamanho preso à faixa do controle — sem seleção sem histórico, com seleção uma entrada por passo e nenhuma no limite — e que a mensagem da roda diz quais teclas estavam apertadas, que no pixel do meio da marcação só o contorno deixa o fundo, o translúcido o mistura e o opaco o cobre — no retângulo e na elipse —, e que trocar um campo da marcação preserva todos os outros — este último por causa de um defeito que existiu: mudar a espessura devolvia o retângulo aos cantos retos e sem preenchimento.

Outro cobre os monitores: que a janela centra no monitor também quando ele começa em coordenada negativa, à esquerda ou acima do principal; que a captura para o editor congela o monitor do ponteiro, ou a tela virtual com a opção; e, com uma janela de cor conhecida posta longe da origem, que a área congelada é a pedida, e não o canto da tela. A máquina dos testes tem um monitor só, então a escolha entre um monitor e todos é conferida pelo tamanho, e não por dois monitores de verdade. Outro confere que o editor abre com a seleção na mão, sem painel de opções, e com a barra dizendo a tecla que a configuração deu a ela.

Outro cobre o ponteiro do mouse, que é a resposta do editor à pergunta "o que acontece se eu clicar aqui": que fora da área de cliente o editor não responde, deixando a borda com as setas de redimensionar do Windows; que ele responde pelo lugar em que o mouse está no instante da pergunta, e não pelo último que chegou por mensagem, que vem sempre um movimento atrasado; e que cada lugar tem o ponteiro do que o clique ali faz — a seta na barra e nos painéis, inclusive com uma ferramenta de desenho na mão, a cruz na imagem vazia, a seta sobre uma marcação e sobre o fundo, o ponteiro de texto com a ferramenta de texto, e a alça da marcação escolhida dizendo em que sentido ela estica.

Outro cobre a janela redimensionável: que o menor tamanho que ela responde ao Windows cabe a barra inteira, vem do estilo da janela e é escrito no campo que o Windows lê — no campo errado, a janela encolheria até a barra sumir —, que o tamanho de abertura respeita esse mesmo mínimo nos dois sentidos, que redimensionar refaz as duas superfícies no tamanho do cliente e recoloca a imagem no meio dele, que as superfícies antigas saem — a conta de objetos do GDI do processo volta ao que era, que é como um vazamento apareceria —, que o cliente zerado da janela minimizada e o mesmo tamanho de novo não refazem nada nem tocam no gesto em curso, e que um arrasto em curso termina antes de a vista mudar debaixo dele, com o mouse devolvido à área de trabalho. O teste do zoom acrescenta que o encaixe e a escala escolhida sobrevivem ao redimensionamento: no encaixe, a imagem inteira continua inteira no espaço novo; com o tamanho real escolhido, um pixel da imagem continua um pixel da janela.

Outro cobre a configuração, que é texto escrito à mão: que as combinações de teclas se leem em qualquer caixa e com espaços e se escrevem de volta do jeito que a barra mostra, que uma combinação sem tecla, com duas teclas ou com uma tecla desconhecida é recusada, que os nomes das teclas vão e voltam, que o arquivo de fábrica é lido de volta igual — inclusive com a marca de UTF-8 que o Bloco de Notas pode pôr no começo —, que cada opção muda o que diz — inclusive a de capturar todos os monitores, que de fábrica é não — e as que faltam ficam com o valor de fábrica, e que cada erro diz a linha e o motivo, inclusive a mesma tecla em duas ferramentas.

Outro cobre o redimensionamento: que redimensionar muda o tamanho da imagem de trabalho e se desfaz, que escolher o fator em vigor não entra no histórico, que desfazer outra edição feita depois não leva o tamanho junto, que ir da captura à janela e voltar devolve o mesmo ponto em 50% e em 2×, que um retângulo desenhado sobre a imagem ampliada é guardado no lugar certo da captura, que a moldura redimensiona junto, que a imagem ampliada guarda as cores no lugar, e que o painel e os botões dele ficam onde devem.

Outro cobre o zoom, que muda todo o caminho entre a imagem e a janela sem mudar a cena: que ele não passa de caber na janela para baixo nem da ampliação máxima para cima, que o ponto sob a roda fica parado, que tamanho real é um pixel para um e a imagem inteira zera o deslocamento, que ir da captura à janela e voltar devolve o mesmo ponto com a imagem ampliada e deslocada, que o deslocamento para com a borda da imagem encostada na da área, que aproximar a marcação escolhida a põe no meio, que desenhar e desfazer não desfazem o zoom, que a roda decodifica o sinal do giro, e que cada bloco da barra abre o painel dele. Um deles refaz a geometria da janela real — uma captura 1280x800 numa área de 1250x636, cinco giros no mesmo ponto — porque foi nela que o ponto escapou do ponteiro, e o teste com a imagem pequena não pegava.

Outro cobre o conta-gotas: os oito formatos com o amarelo do exemplo da referência, os canais na ordem certa — o COLORREF guarda o azul no byte alto, e uma troca passaria despercebida num cinza —, o OKLCH do vermelho puro contra o valor da própria especificação do CSS, a cor lida sob o ponteiro e não fora da imagem, e a cor mais escura achada a dez pixels do ponteiro e ignorada a trinta. Copiar para a área de transferência fica de fora de propósito: um teste que rodasse a cada compilação trocaria o que o usuário tem copiado. Um teste da barra desenha uma mensagem enorme e confere, pixel a pixel, que ela para antes do bloco da cor.

Outro cobre a régua sobre superfícies pintadas: que o comprimento é o do traço e não o da caixa, que um clique no meio de uma faixa acha as duas bordas e na própria borda mede a faixa inteira, que a faixa para na borda da imagem, que um tom vizinho dentro da folga conta como a mesma cor e um de fora corta, e que com moldura a régua medida sozinha nasce no lugar certo da captura — que é justamente onde a folga da moldura poderia deslocá-la. Cobre também as teclas: que `2` mede a largura e `1` a altura da mesma faixa, que enquanto a tecla está apertada a medida é só prévia, que somente um clique a adiciona ao histórico e que soltar a tecla cancela, que cada seta mede do ponteiro até a borda certa, que fora da imagem não há prévia nem régua, que as teclas só medem com a régua na mão, e que escolher a régua abre a ajuda dentro do editor e a primeira medida a fecha.

Outro cobre a moldura, que é a única coisa que muda o tamanho do resultado: que escolher a ferramenta põe uma só e escolher de novo não empilha outra, que a imagem cresce a folga de cada lado, que a original fica no meio e a cor em volta, que o canto arredondado come a quina da imagem e o meio de cada lado não, que a sombra escurece logo abaixo da imagem e deixa o resto limpo, e que ir da captura à janela e voltar devolve o mesmo ponto depois de a folga entrar.

Outro cobre a lupa, que tem duas pontas e só uma delas é a caixa da marcação: que a lente sai na diagonal de onde o arrasto veio e nunca por cima da origem, que perto da borda ela passa para o outro lado e fica dentro do recorte, que ela guarda a proporção da origem em vez de virar quadrado, que sobra o vão que deixa a linha aparecer, que clicar na lente escolhe a marcação, que o miolo da lente mostra o que estava na origem — e não o que estava onde ela caiu —, que cada ponta tem as suas alças e o seu corpo e o clique diz qual das duas pegou, que mexer numa ponta não mexe na outra, e que a linha de ligação não deixa toco de reta no miolo da origem.

Outro desenha cores conhecidas numa superfície e confere os pixels que saem do borrão: que um quadrado preto num quarto do bloco vira um bloco inteiro de cinza claro e o bloco vizinho continua branco, e que apagar cobre a área com uma cor só, com os canais na média do que havia. Se as duas passadas de redução saíssem trocadas, ou se a volta interpolasse, o resultado continuaria sendo um retângulo do tamanho certo — a geometria não denunciaria nada.

Outro conduz a digitação do começo ao fim sobre uma superfície de desenho, sem janela: que o escrito vira marcação selecionada e entra no histórico, que a caixa cresce para baixo mas não para os lados, que um clique seco ganha largura de partida e um arrasto estreito de propósito é respeitado, que desistir não deixa nada para trás, que reabrir uma marcação a devolve no mesmo lugar da pilha, e que apagar conta letras e não bytes — um "ã" ocupa dois bytes, e apagar meio caractere deixaria o texto inválido.

Outro cobre a fronteira entre os dois grupos da barra: que os botões seguem a ordem pedida, que as ações vêm primeiro e as ferramentas começam depois do vão, que o traço cai no meio desse vão sem encostar em nenhum botão, que ponto nenhum da fila responde pelos dois grupos, que o centro de cada botão devolve justamente o dele, e que a barra inteira cabe na janela mais estreita que o editor aceita.

Outro cobre a leitura do SVG sem abrir janela nenhuma: que os atributos são achados pelo nome inteiro, para `stroke` não casar com `stroke-width`; que os números do caminho são separados pelo próprio sinal, como em `1.6-1.4`; e que o arco do SVG, que é descrito pelo ponto de chegada, vira curvas que começam e terminam onde foi pedido e não se afastam do círculo em nenhum ponto do percurso — inclusive quando ele dá três quartos de volta e precisa ser fatiado, e quando os raios são pequenos demais e têm de ser esticados.

Outro cobre a seleção: confere a conversão entre as coordenadas da captura e as da janela, onde fica cada alça, o que um clique pega em cada ponto, qual marcação vence quando duas se sobrepõem, que arrastar uma alça para além do lado oposto não deixa a marcação com largura negativa, e que mover preserva cor, espessura e estilo.

Outro cobre a geometria da linha e da seta: as pontas que saem da caixa e do canto de origem, o ângulo em que `Shift` as prende — o mesmo para a régua —, o quadrado em que ele prende o retângulo e a elipse, inclusive num arrasto só na horizontal, as asas simétricas da ponta, e que acertá-las é chegar perto do traço — inclusive quando já estão selecionadas, que é onde isso esteve errado. Cobre também que um traço perfeitamente reto não é descartado por ter um dos lados da caixa zerado, e que arredondar funciona dos dois lados do zero.

Outro confere que o marca-texto deixa o fundo passar e que o traço livre no mesmo lugar cobre, e que entrar no marca-texto e sair dele leva a cor e a espessura junto.

Outro cobre o numerador: que a ponta aponta para onde o arrasto foi só quando ele sai de dentro do disco, que a caixa é sempre a do disco, que o número sai da contagem na cena e cai sozinho ao apagar um do meio, e que acertar o balão é cair no disco e não no ponteiro. Cobre também as três formas: que só um botão fica aceso e o círculo é o padrão, que no pixel a ponta grossa enche o canto e a fina só a faixa estreita em volta da direção, que a ponta virada para baixo sai de baixo do disco, e que a alça além da ponta pega antes das outras e a gira sem mover o balão — e que o círculo não tem essa alça.

Outro cobre a paleta: que ela pende do disco de cor, que cabe inteira dentro do editor mesmo encostada na borda, que as oito cores ocupam quatro colunas por duas fileiras com o botão do seletor embaixo, e que o vão entre os quadrados não escolhe cor nenhuma.

Outro confere que a marcação nasce selecionada, que a segunda toma o lugar da primeira, e que o painel passa a mostrar o que ela tem em vez do padrão da ferramenta. Outro, que com uma ferramenta de desenho na mão a alça e o corpo da marcação selecionada pegam, que arrastar o corpo a move e entra no histórico, que apertar e soltar sem mexer não entra, e que sobre uma marcação não selecionada o arrasto desenha em vez de pegar. Outro, que com a elipse na mão um clique de mão trêmula dentro de um retângulo o escolhe sem desenhar nem entrar no histórico, que um arrasto a partir do mesmo ponto desenha uma elipse por cima, e que o numerador põe o balão dentro do retângulo em vez de escolhê-lo.

Outro confere que recortar move a janela da cena: a imagem de trabalho encolhe, o canto do recorte vem do lugar certo da captura, e um traço livre feito antes sobrevive na posição correta. Outro conduz o botão que seleciona e recorta: o clique sobre uma marcação a escolhe sem começar arrasto, o clique trêmulo sobre a imagem vazia não recorta, e o arrasto de verdade recorta no lugar certo e se desfaz.

Outro cobre o traço livre: a caixa que envolve os pontos, o reescalonamento deles quando a caixa muda de lugar ou de tamanho, a caixa sem lado que não pode dividir por zero, o traço de um ponto só, e o acerto pelo caminho e não pela caixa.

Outro confere que a elipse é a inscrita na caixa do arrasto: o meio de cada lado é tocado pelo traço e o canto da caixa continua sendo o fundo, que é o que a distingue do retângulo.

O último cobre a cena: monta uma imagem em que cada pixel carrega a própria coordenada, aplica janelas e marcações, e confere pixel a pixel que estreitar a janela desloca a origem certo, que voltar atrás devolve exatamente a imagem anterior e que uma marcação feita antes sobrevive na posição correta.

## Estrutura

O código-fonte fica em `src/`, o executável em `build/`, e `tmp/` guarda as capturas do CleanShot que servem de referência ao editor. `build/` e `tmp/` ficam fora do controle de versão.

| Pasta | O que tem |
|---|---|
| `src/` | Todo o código, os testes ao lado do que testam, os ícones da barra em `src/assets/icons/`, e o ícone da aplicação em `src/assets/vshot.ico`, com o `vshot.rc` que o embute |
| `build/` | O executável e, ao lado dele, as capturas que a aplicação grava |
| `scripts/` | O roteiro de medição de consumo |
| `tmp/` | As capturas do CleanShot usadas como referência |

| Arquivo em `src/` | Responsabilidade |
|---|---|
| `main.v` | Janela oculta, atalhos globais e laço de mensagens |
| `editor.v` | Montagem da janela do editor e as ações que a encerram |
| `editor_input.v` | As mensagens da janela do editor: o que o mouse e o teclado fazem, e o tamanho novo quando ela é redimensionada |
| `editor_view.v` | Apresentação da imagem na janela: escala, posição, desenho e o espaço refeito quando a janela muda de tamanho |
| `scene.v` | O que está visível, o que foi desenhado, desfazer e refazer |
| `options.v` | O painel de opções que acompanha a ferramenta ou a marcação |
| `gdiplus.v` | A camada de desenho suavizada e o que ela empresta ao editor |
| `toolbar.v` | Layout, desenho e estado da barra de ferramentas |
| `chrome.v` | O acabamento das caixas flutuantes e dos botões: quinas arredondadas, borda fina e sombra |
| `icons.v` | Qual desenho cada ferramenta usa na barra |
| `svg.v` | Conversão do desenho em caminhos do GDI+ |
| `svg_read.v` | Leitura do texto do SVG: elementos, atributos e comandos de caminho |
| `region.v` | Seleção de área sobre a tela congelada |
| `selection.v` | Escolha de uma marcação e as alças que a manipulam |
| `line_selection.v` | Edição de linhas, setas e réguas pelas extremidades |
| `guides.v` | As guias de alinhamento e o encaixe ao mover, redimensionar ou criar uma marcação |
| `text_capture.v` | A captura de texto: a área, a leitura e a cópia do que foi lido |
| `text_popup.v` | A faixa do texto copiado, com o botão que tira as quebras de linha |
| `qr.v` | A leitura de QR code, pelo quirc embutido em `thirdparty/quirc` |
| `ocr.v` | O OCR do Windows, chamado pela API do Windows Runtime |
| `color.v` | Escolha da cor da marcação pelo seletor do Windows |
| `annotation.v` | Qual primitiva cada ferramenta usa, e o marcador do arrasto |
| `text.v` | A digitação, a medida do texto e o desenho do balão |
| `blur.v` | O mosaico e o apagamento, que leem a imagem em vez de só escrever nela |
| `magnifier.v` | A lente, onde ela cai e o que ela mostra |
| `backdrop.v` | A moldura em volta da imagem, com folga, canto e sombra |
| `ruler.v` | A régua: o traço com as pontas marcadas, o rótulo e a leitura da faixa de cor |
| `ruler_probe.v` | A medida pelo teclado e a caixa que ensina a usá-la |
| `picker.v` | O conta-gotas: a cor sob o ponteiro, os oito formatos e a cópia |
| `resize.v` | O fator de tamanho do resultado e o painel que o escolhe |
| `zoom.v` | A ampliação e o deslocamento da vista, e os atalhos que os mudam |
| `zoom_panel.v` | O painel que pende do bloco do zoom |
| `tray.v` | Ícone na bandeja, menu de contexto e balões |
| `capture.v` | Congelamento e recorte da tela pelo GDI |
| `monitor.v` | A tela virtual, o monitor em que o ponteiro está e o que a captura para o editor congela |
| `clipboard.v` | Entrega da imagem e do texto à área de transferência |
| `storage.v` | Onde e como gravar o PNG |
| `config.v` | O arquivo de configuração: a leitura, os erros e o texto de fábrica |
| `autostart.v` | A entrada na chave de inicialização do Windows |

## Decisões

**Congelar antes de mostrar.** Nem a seleção nem o editor desenham sobre a tela ao vivo: a tela é copiada primeiro e as janelas exibem essa cópia. Isso resolve dois problemas de uma vez — o conteúdo não muda enquanto o usuário decide, e as próprias janelas da aplicação não aparecem no resultado.

**A edição acontece na hora, e o que está na tela é o que será salvo.** A marcação é aplicada à imagem de trabalho no instante em que o arrasto termina, e não há um segundo caminho de desenho que possa divergir do que aparece.

**O recorte é uma janela, não uma destruição.** A cena guarda que pedaço da captura está visível e o que foi desenhado sobre ele, e a geometria de cada marcação fica em coordenadas da captura original. Recortar move a janela: nada é perdido, nenhuma marcação precisa ser reescrita, e desfazer devolve a captura inteira com tudo no lugar.

**As marcações são desenhadas pelo GDI+.** O GDI não suaviza borda, não tem transparência por objeto e só aceita espessura inteira. Enquanto só existia retângulo isso quase não aparecia, mas seta, elipse, linha e traço livre sairiam todas escadeadas, e marca-texto e sombra não sairiam de jeito nenhum. O `gdiplus.dll` acompanha o Windows e tem uma API C plana, declarada à mão em `gdipflat.h` porque o cabeçalho que vem com o compilador é só para C++.

**O GDI+ vive enquanto o editor vive.** Ele sobe uma thread e cerca de 2 MB, e é ligado na abertura do editor e desligado no fechamento em vez de na partida da aplicação. Parada na bandeja, que é onde ela passa quase todo o tempo, a aplicação não carrega nada disso. Em troca, nada que dependa dele pode ser desenhado fora do editor — inclusive nos testes, que ligam e desligam por conta própria.

**O tamanho é um fator guardado na cena, aplicado por último.** Redimensionar não reescreve a geometria de nada: as marcações continuam em coordenadas da captura, e o fator é aplicado sobre a imagem pronta, depois das marcações e da moldura. Quem muda é o caminho entre a captura e a janela, que passa a multiplicar pelo fator — é o mesmo lugar em que a folga da moldura já entrava. Por ser um campo da cena, ele entra no histórico, e é por isso que dá para desfazer.

**Há duas escalas, e cada uma tem seu lugar.** A redução com que a janela mostra a imagem de trabalho continua sendo o que o bloco do zoom mostra e o que o conta-gotas usa para achar o pixel, porque os dois olham a imagem de trabalho. Tudo que parte da captura — a espessura das prévias, as alças, o raio do balão numerado, o arrasto que move uma marcação — usa o fator vezes essa redução, porque uma linha de três pixels na captura mede seis na imagem em 2×.

**O zoom é da vista, e não da cena.** Ele multiplica a redução que faz a imagem caber na janela, e o deslocamento diz que pedaço aparece; os dois são campos do editor, e não da cena. Por isso não entram no histórico nem no resultado, e aplicar a cena de novo depois de uma edição não os desfaz. Como todo o caminho entre a captura e a janela já passava por essa redução e pela posição da imagem, o zoom não criou conversão nova: ele só mudou os dois números que as conversões já usavam.

**Com zoom, só o pedaço visível é copiado.** Ampliar a imagem inteira a cada quadro custaria uma superfície oito vezes maior que a janela. A composição copia só o trecho da imagem de trabalho que cai na área visível, cortado em pixels inteiros da origem, e sem interpolação quando amplia — para o pixel aparecer como bloco, que é para o que se amplia. As alças e as prévias são recortadas à área abaixo da barra, para uma marcação que passe da borda não ser desenhada por cima dos botões.

**A roda lembra o ponto que mirou.** Perto da borda o deslocamento é preso, porque a imagem não mostra o que há além dela, e naquele passo o ponto escapa do ponteiro. Se o passo seguinte mirasse o que ficou sob o ponteiro, o erro viraria o novo alvo e se acumularia: cinco giros sobre o canto de um retângulo o deixavam a mais de cem pixels do ponteiro. Enquanto o ponteiro não sai do lugar e nada mais mexe na vista, os giros seguidos miram o ponto do primeiro, que volta para baixo do ponteiro assim que a imagem tem folga.

**O arrasto prende o mouse.** Com a imagem ampliada, uma marcação chega facilmente à borda da janela, e o botão solto do lado de fora não chegava ao editor: ele ficava arrastando até o próximo clique. Agora o editor captura o mouse enquanto um botão arrasta — o esquerdo desenhando ou movendo, o direito deslocando — e o solta junto com o botão, onde quer que ele esteja.

**Os painéis são desenhados depois do recorte.** O painel de opções, a paleta e os dois painéis da barra vêm numa passada própria, depois das alças e das prévias. Antes eles eram parte da mesma passada, que termina cedo enquanto se digita um texto, e o painel sumia durante a digitação.

**A cópia da cena para o histórico passou a levar tudo que a cena tiver.** Ela copiava campo a campo, e um campo novo que ficasse de fora voltaria ao padrão a cada desfazer: com o fator, redimensionar, desenhar um retângulo e desfazer o retângulo devolveria a imagem ao tamanho natural. Agora a cópia espalha a cena inteira e só troca a lista de marcações, e um teste faz exatamente essa sequência.

**O bloco da cor é desenhado por cima da barra, e não dentro dela.** A barra faz parte da composição fixa, que só é refeita quando algo muda de verdade, porque refazê-la repete a redução da imagem inteira. O bloco da cor muda a cada pixel que o ponteiro atravessa, então ele vem por cima, na mesma passada da prévia do arrasto — e passar o mouse pela imagem custa só uma cópia da janela pronta.

**O `Tab` é do conta-gotas.** O plano deixava em aberto uma disputa: o `Tab` percorrendo as marcações, como em editores de desenho, ou copiando a cor, como na referência. Ficou com a referência, que é quem mostra o atalho escrito na barra.

**A mensagem da barra é cortada antes dos blocos.** Ela ocupa o vão entre a última ferramenta e o bloco da cor, e uma mensagem maior que o vão era escrita por baixo dele. Ninguém tinha visto porque as mensagens eram curtas; uma cor copiada como `UIColor(...)` não é. Agora o que não cabe vira reticências.

**A régua mede pelo teclado e só guarda a medida com um clique.** Segurar a tecla deixa a prévia acompanhar o mouse; o clique esquerdo a transforma numa régua selecionada, com alças nas duas pontas e desfazer. Soltar a tecla ou perder o foco cancela a prévia sem alterar a imagem nem o histórico.

**A régua mede sozinha lendo a faixa de cor, e não detectando bordas.** A medida anda pela linha — ou pela coluna — do ponteiro para os dois lados até achar um pixel diferente demais do primeiro, com uma folga de doze em cada canal. É o que uma interface de cor chapada pede, e é onde a ferramenta faz sentido; numa fotografia, onde nenhum pixel é igual ao vizinho, a faixa sai curta e a medida manual continua lá. A leitura é feita na imagem de trabalho, com as marcações anteriores já desenhadas: mede-se o que se vê.

**A moldura é uma marcação na cena, e não um campo à parte.** Ela não é desenhada sobre a imagem — é a imagem inteira dentro de outra —, mas é guardada na lista de marcações como as demais. Assim desfazer, refazer, o painel de opções e o `Delete` valem para ela sem nenhuma máquina nova. O que a distingue são três regras: há no máximo uma, ela não nasce de um arrasto, e ela é aplicada depois de todas as outras, e não na vez dela na lista.

**A folga da moldura entra em todas as conversões de coordenada.** Como a imagem de trabalho passa a ser maior que o recorte, a origem dela deixa de coincidir com a origem do recorte, e um ponto da captura passa a cair mais adiante na janela. As quatro funções que levam um ponto de um lado para o outro somam ou descontam essa folga; sem moldura ela vale zero e as contas ficam exatamente como eram. É o único lugar em que a moldura toca o resto do editor.

**A sombra são camadas concêntricas quase transparentes.** Uma sombra de verdade seria um bitmap com alfa borrado, e o GDI não guarda alfa entre operações. Doze retângulos arredondados, cada um um pixel maior que o anterior e com opacidade de dezesseis em duzentos e cinquenta e cinco, somam-se num degradê que escurece perto da imagem e some para fora — que é o que uma sombra faz.

**A lupa copia a origem antes de desenhar qualquer traço.** A linha que liga as duas pontas parte do meio da região de origem, então desenhá-la antes da cópia a faria aparecer ampliada dentro da lente — foi exatamente o que aconteceu na primeira versão. A ordem é: copiar a origem, traçar a linha, ampliar dentro da lente, e só então contornar as duas, para a linha sair de trás delas em vez de atravessá-las.

**A lente é guardada na marcação, e não calculada a partir da origem.** Enquanto ela era sempre a origem ampliada três vezes na diagonal do arrasto, não havia o que controlar nela. Agora os dois cantos dela ficam guardados no campo de pontos que a marcação já tinha para o traço livre, em coordenadas da captura, e são desenhados pela mesma conta que leva a origem até a tela. A seleção passou a dizer, além do que foi pego, se foi na lente; o resto da máquina — alças, arrasto, histórico — continuou sendo o de uma caixa só, aplicado ora a uma ponta, ora à outra.

**A linha de ligação é recortada fora das duas pontas.** Ela é traçada do meio de uma ao meio da outra, que é a conta mais simples para a direção certa, e o miolo das duas é tirado do recorte antes do traço. Na lente o toco de dentro ficava coberto pela ampliação, mas na origem nada o cobria, e sobrava uma pequena reta no item menor.

**A lente amplia sem interpolar.** Ampliar é para ver o pixel; a média deixaria o resultado embaçado, que é o oposto do que a ferramenta serve. É a mesma decisão do mosaico de borrar, invertida: lá a média é a ida e a repetição é a volta.

**O borrão é o próprio GDI encolhendo e devolvendo a imagem.** A área encolhe com interpolação, que faz a média dos pixels, e volta ao tamanho sem interpolação, que repete cada pixel num bloco. Duas chamadas, nenhum laço sobre pixels. Uma convolução escrita à mão daria um desfoque suave em vez do mosaico, mas seria um laço sobre a área a cada quadro da prévia — e a referência mostra justamente o mosaico. Apagar é a mesma ideia levada ao extremo: a área encolhe até um pixel só, e esse pixel vira a cor que cobre tudo.

**Apagar não pergunta a cor.** Com uma cor escolhida, a área apagada viraria um retângulo que salta à vista; com a média do que havia ali, ela se acomoda no que está em volta. É por isso que o painel de borrar não tem disco de cor — como na referência —, e o painel encolhe para ocupar só o que usa.

**O texto é digitado na própria janela, e não num campo do Windows sobreposto.** Um controle `EDIT` nativo traria seleção de trecho, navegação por teclado e área de transferência de graça, e é o caminho que o plano sugeria. Mas ele desenharia com a aparência dele — outra fonte, outro fundo, sem balão —, e o texto saltaria de aparência ao ser confirmado. Digitando na janela, o que se vê enquanto se escreve é exatamente o que fica. O preço é o que ficou de fora: não há seleção de trecho, nem cursor que ande pelo texto, nem colar. O acento, que era a maior dúvida, não custou nada: o `TranslateMessage` do laço de mensagens compõe a tecla morta antes de a mensagem de caractere existir.

**O cursor da digitação é um caractere do texto.** Em vez de medir onde a última linha termina para desenhar um traço ali, o que é desenhado é o texto com uma barra vertical no fim. A quebra de linha leva o cursor junto sem nenhuma conta, e ele nunca fica fora do lugar. Em troca, a caixa muda de largura de leve ao ser confirmada.

**As ações moram na mesma barra que as ferramentas.** Elas ficavam numa faixa própria embaixo da janela, com botões nativos do Windows e rótulo escrito. Passaram para a esquerda da barra de cima, como ícones, separadas das ferramentas por um traço: são o que se faz com a imagem, e as ferramentas são o que se faz com o desenho. A janela ficou 44 pixels mais baixa e a imagem ganhou esse espaço; em compensação a barra ficou mais larga, e a largura mínima da janela subiu de 1150 para 1250 — um teste confere que ações, ferramentas, mensagem e blocos de estado cabem nessa soma, para a largura não ficar para trás quando a barra crescer de novo.

**A barra tem só o que se usa pelo mouse.** Depois ela foi reordenada e enxugada: copiar e salvar abrem a fila, que é o fim natural de uma captura, e desfazer, refazer e fechar saíram dela, porque vivem no teclado (`Ctrl+Z`, `Ctrl+Y`, `Esc`) e na barra só ocupavam lugar. Com eles saiu também o estado de botão apagado, que só existia para os dois do histórico.

**Selecionar e recortar dividem um botão.** O que decide entre os dois é onde o clique cai: numa marcação, ele a escolhe, e na marcação já escolhida a move ou estica; na imagem vazia, que antes só desmarcava, o arrasto recorta. Nenhum gesto que existia mudou de sentido. O risco da junção é um clique distraído virar recorte, e por isso o arrasto só recorta quando passa de oito pixels nos dois sentidos — e continua se desfazendo com `Ctrl+Z`.

**Um botão sem rótulo precisa dizer o nome em algum lugar.** O ponteiro sobre uma ação ou uma ferramenta acende o botão e põe o nome e o atalho na barra, no lugar da mensagem de estado. É a mesma linha, e não uma tarja flutuante: uma tarja seria mais uma superfície com posição, tempo e desenho próprios para dizer duas palavras. A mensagem de estado não é sobrescrita — ela continua guardada e volta assim que o ponteiro sai.

**O ícone da aplicação é um recurso do executável.** É o mesmo desenho do RustShot, a versão em Rust desta aplicação: uma câmera branca sobre um quadrado laranja, num `.ico` com sete tamanhos, de 16 a 256 pixels. Ele entra no executável como recurso, e não embutido como dados, porque é o recurso que o Explorer lê para mostrar o arquivo. A bandeja e a janela do editor o carregam do próprio executável, pedindo o tamanho que o Windows usa para cada lugar, e o Windows escolhe a imagem certa para a escala da tela. Os testes são compilados sem o recurso, e aí vale o ícone genérico.

**A configuração é um arquivo de texto, relido sozinho.** Uma janela de configurações seria mais confortável, mas seria vários controles desenhados à mão como os do editor — campos que capturam a tecla apertada, lista, caixa de marcar — para editar vinte e poucas linhas. O arquivo cabe no Bloco de Notas, explica cada opção nos próprios comentários, e é relido quando a data dele muda, que a aplicação consulta a cada dois segundos. Um erro não derruba nada: a leitura para, diz a linha, e a configuração anterior fica valendo — inclusive os atalhos globais, que são soltos e registrados de novo, e voltam aos anteriores se o novo estiver ocupado.

**Os ícones são SVG desenhados na hora, e não uma imagem pronta.** Cada botão da barra tem um arquivo em `src/assets/icons/`, com 24 por 24 e traço de 1,5. Eles vão embutidos no executável e, na abertura do editor, viram caminhos do GDI+ — que já é quem desenha as marcações, e sabe arco, bezier e polígono. A alternativa era rasterizar os arquivos num PNG antes de compilar, o que é menos código, mas põe no repositório um arquivo gerado que ninguém edita e um passo de build que depende de uma ferramenta de fora. Desenhando direto, o arquivo é a única versão que existe: mudar um ícone é mudar o SVG e recompilar.

**A cor do ícone é dada na hora de desenhar.** Com a tira de PNG a cor vinha pré-multiplicada nos pixels, então a barra guardava duas cópias inteiras da tira: uma na cor apagada e outra na cor da ferramenta ativa. Um caminho do GDI+ não tem cor — quem tem é a caneta —, então uma cópia serve para as duas, e serviria para qualquer terceira cor sem custo nenhum.

**O leitor de SVG entende só o que os arquivos usam.** `rect`, `circle` e `path`, com os comandos `M`, `L`, `H`, `V`, `C`, `A` e `Z` nas duas formas. Não há grupos, transformações, gradientes nem `style`. Ler SVG por inteiro seria uma biblioteca; ler estes catorze arquivos são duzentas linhas, e o que falta quebra na compilação do próprio ícone, não em produção.

**O painel fica parado no canto.** Ele não persegue a marcação selecionada. Seguir o objeto parecia mais direto, mas então o painel pulava de lugar a cada clique e cobria justamente o que estava sendo editado; parado no alto à direita ele está sempre no mesmo lugar e nunca por cima do trabalho, que é o que a referência faz.

**A paleta é a única superfície do editor com estado.** Todo o resto — barra, painel, alças — é calculado na hora de desenhar a partir da cena e da ferramenta. A paleta precisa lembrar se está aberta, e é um campo só; em troca, ela é a única coisa que exige fechar quando se clica em outro lugar.

**As oito cores rápidas são também as do seletor do Windows.** As mesmas oito que a paleta mostra são carregadas nos lugares "personalizados" do `ChooseColor`, então escolher entre elas e escolher uma qualquer são o mesmo gesto em dois níveis, sem duas listas para manter.

**O marca-texto é translúcido, e não multiplicativo.** O plano previa mistura multiplicativa, que escurece o que está embaixo e deixa texto preto continuar preto. O que está aqui é transparência simples. Sobre fundo claro, que é onde se destaca texto, as duas são praticamente iguais; sobre fundo escuro a transparência cobre em vez de tingir. Fazer multiplicação de verdade exigiria ler de volta os pixels sob o traço a cada quadro da prévia, e é essa parte que custa — não o desenho final.

**A ponta do balão é um polígono somado ao disco.** A ponta grossa da referência é um disco em que um dos quartos virou canto vivo. Em vez de montar esse contorno como caminho — três arcos e duas retas —, o balão desenha, antes do disco, o quadrado que vai do centro até o canto, girado para a direção da ponta: os dois lados dele que ficam sobre os raios somem dentro do disco, e os outros dois fecham o canto. A ponta fina é um triângulo estreito com a base por dentro do disco. As duas usam o mesmo preenchimento de polígono.

**A direção da ponta é um ponto, e não um ângulo.** Ela é guardada como o segundo ponto que o balão carrega — o mesmo campo que o ponteiro comprido usava antes de a referência mostrar a ponta curta e girável, que o substituiu. Guardada assim, mover o balão leva a direção junto pela mesma conta que leva o centro, e a alça que gira a ponta só precisa trocar esse ponto.

**O número não é guardado.** Ele sai da contagem de balões que vêm antes na cena, calculada na hora de desenhar. Guardar o número em cada balão obrigaria a reescrever todos os seguintes ao apagar um do meio, e a desfazer isso ao desfazer; assim renumerar não é código nenhum.

**O traço livre guarda o caminho, e a caixa vem dele.** É a única marcação cuja geometria não cabe num retângulo: ela guarda os pontos por onde o mouse passou, e a caixa é a que os envolve. Mover e redimensionar reescalam os pontos da caixa velha para a nova, e com isso a seleção, as alças e o histórico valem para o rabisco como valem para as outras.

**O traço é uma curva, não uma polilinha.** Os pontos vêm do mouse, que treme, e ligá-los por retas deixa o traço com quinas. Uma curva cardinal passa por todos eles suavizando o caminho entre um e o seguinte, e é o que o GDI+ desenha.

**Dois pontos vizinhos demais não entram.** O mouse manda dezenas de posições por segundo, e guardar todas engorda a cena sem melhorar o traço. Só entra o ponto que já se afastou três pixels do anterior.

**A linha e a seta guardam o canto, não as pontas.** Elas atravessam a caixa que o arrasto descreve, e o que a cena guarda é de qual dos quatro cantos ele partiu. Guardar as duas pontas obrigaria a seleção, o mover e o redimensionar a tratá-las à parte; guardando a caixa mais o canto, tudo isso vale para elas sem nenhum caso especial. São quatro cantos e não duas diagonais porque a ponta da seta fica onde o arrasto terminou, e a mesma diagonal percorrida ao contrário aponta ao contrário.

**O Shift é decidido num lugar só, pela ferramenta.** Cada ferramenta diz o que o Shift faz com a ponta do arrasto — prender o ângulo, fechar o quadrado ou nada —, numa função pura que os testes chamam sem teclado. Antes a regra era uma lista solta dentro do cálculo do arrasto, e a seta tinha ficado fora dela: o README dizia que ela se prendia, e ela não se prendia.

**A ponta da seta não usa ângulo.** As duas asas saem de um vetor unitário e do perpendicular dele, o que dá as quatro pontas sem trigonometria: as duas cheias são um polígono de sete pontos, e as duas de traço são a haste mais dois segmentos.

**Acertar um traço é chegar perto dele.** Quase toda a caixa de uma diagonal ou de um rabisco é vazia, então tanto escolher quanto agarrar medem a distância até o traço, e não a caixa — no traço livre, até o trecho mais próximo do caminho. Isso já esteve certo na escolha e errado no agarrar, e clicar longe do traço de uma linha selecionada começava a arrastá-la.

**O painel se ajusta à ferramenta.** Cada ferramenta declara quais botões de estilo oferece, e a largura do painel sai daí. A fila de botões é encostada na direita do painel em vez de medida a partir do controle, para o número deles mudar sem mexer em mais nada. Quando há uma marcação selecionada, quem manda é a ferramenta dela, e não a que está na mão.

**O painel não guarda estado.** O que ele mostra e qual opção está em vigor saem da cena e da seleção, calculados no momento de desenhar. Não há campo dizendo se ele está aberto nem posição memorizada, então não existe estado para ficar desencontrado do resto — e é por isso que ele some sozinho durante um arrasto, quando atrapalharia.

**Arrastar tira a marcação da cena.** Mover ou redimensionar uma marcação selecionada a retira da cena enquanto dura o arrasto e a mostra como prévia por cima da imagem. Sem isso, cada movimento do mouse teria de refazer a imagem inteira para a marcação sair do lugar antigo. Ela volta à cena, na posição nova e no mesmo lugar da pilha, quando o botão é solto.

**A marcação selecionada pega antes da ferramenta; as outras escolhem com um clique e desenham com um arrasto.** Com uma ferramenta de desenho na mão, apertar sobre uma alça da marcação selecionada a estica, e apertar sobre o corpo dela a move — como com a ferramenta de seleção. Sobre o corpo de uma marcação que não está selecionada, o que decide é o que acontece até o botão ser solto: se ele não saiu do lugar, foi um clique, e a marcação é escolhida; se saiu, foi um arrasto, e começa uma marcação nova por cima. Apertar e soltar a selecionada sem mexer também não é edição, e não deixa entrada no histórico. O preço é que desenhar por cima da marcação que acabou de nascer, e que por isso está selecionada, pede um `Esc` antes. Sem essa divisão, ou escolher uma marcação exigiria trocar de ferramenta, ou desenhar duas formas sobrepostas seria impossível. O numerador e o texto ficam de fora da regra do clique porque criam com ele: sem a exceção, não daria para pôr um número ou um texto dentro de um retângulo.

**A marcação é copiada inteira ao mudar um campo só.** Trocar espessura, estilo ou posição remonta a marcação a partir da anterior, e não campo a campo. Escrever os campos à mão já apagou os que ninguém lembrou de repetir, e é um defeito silencioso: o programa continua funcionando, só que devolvendo o objeto a um estado que o usuário não pediu.

**As alças e o painel não entram na imagem.** São desenhados na passada final, sobre o buffer da janela, e não na imagem de trabalho. É por isso que salvar ou copiar com algo selecionado não os leva junto.

**O histórico guarda cópias da cena.** A cena é um retângulo mais algumas dezenas de bytes por marcação, então copiá-la inteira a cada edição é barato, e desfazer e refazer viram trocas de estado. Guardar cópias da imagem custaria 8 MB por passo numa tela 1920x1080, e era o que impedia refazer.

**O buffer de pixels não passa pelo coletor.** Cada captura de tela cheia monta 8 MB de RGBA para o PNG. Esse buffer vem do alocador do sistema e é liberado assim que o arquivo é gravado, em vez de ficar esperando o coletor de lixo do V decidir mexer. Numa aplicação que fica residente por horas, a diferença é carregar ou não esse peso o tempo todo.

**A área de trabalho é devolvida depois de cada captura.** Comprimir o PNG deixa dezenas de megabytes de arena no alocador da runtime C, que não os devolve por conta própria. Ao fim de cada captura a aplicação pede ao Windows que recolha sua área de trabalho. Custa cerca de 12 ms na captura seguinte, em faltas de página, e economiza mais de 30 MB residentes durante todo o tempo ocioso entre uma captura e outra — que é quase todo o tempo.

**A imagem inteira é lida direto do congelado.** O caminho de recorte aloca um segundo bitmap e copia os pixels para ele. Quando a área pedida é a tela toda, que é o caso do `Ctrl+Shift+2`, isso seria alocar 8 MB e copiá-los para reproduzir o que já está ali, então a leitura sai direto do bitmap congelado.

**A imagem só é reduzida de novo quando ela ou a vista mudam.** Reduzir a captura para a janela é a parte cara da composição, e quase tudo que refaz a composição — um botão aceso, uma mensagem nova, a ferramenta trocada — só muda a barra. A imagem reduzida fica na própria composição, abaixo da barra, sem bitmap a mais, e numa janela de 1600×900 refazer a barra passou de 51 ms para 6 ms. Do mesmo jeito, quando só o bloco da cor vai para a tela, que é o que o movimento do mouse sobre uma foto pede, a prévia e os painéis não são desenhados, e essa pintura passou de 9 ms para menos de 3 ms.

**A conversão de cor anda de 32 bits por vez.** O GDI entrega BGRA e o PNG espera RGBA. São dois milhões de pixels por captura de tela cheia, e trocar os canais lendo e escrevendo byte a byte custa quatro vezes mais acessos do que tratar o pixel como um inteiro de 32 bits. A aritmética assume little-endian, que é o que o x86-64 desta aplicação sempre é.

**Todos os monitores.** "Tela toda" é a tela virtual — o retângulo que envolve todos os monitores —, e não apenas o principal. Um monitor à esquerda do principal tem coordenadas negativas, por isso o `BitBlt` parte de `SM_XVIRTUALSCREEN`/`SM_YVIRTUALSCREEN` e não de zero, e as coordenadas do mouse são lidas com sinal.

**Pixels físicos.** O programa se declara `PER_MONITOR_AWARE_V2` na primeira linha do `main`, antes de qualquer janela, porque o Windows recusa a mudança depois que a primeira janela do processo existe. Sem isso a captura sairia reescalada: numa tela 1920x1080 a 150%, viria com 1280x720.

**A janela é redimensionável, e o espaço da imagem acompanha.** Ela já foi fixa de propósito: com o tamanho travado, a redução que faz a imagem caber só mudava quando a própria imagem mudava, e não havia layout a refazer por conta da janela. O preço era não dar para maximizar numa captura grande, que é justamente onde a imagem reduzida esconde o detalhe. Agora o `WM_SIZE` refaz as duas superfícies de desenho no tamanho do cliente, recalcula o encaixe e recoloca a imagem, e o `WM_GETMINMAXINFO` impede a janela de encolher abaixo dos 1250 pixels de largura que a barra precisa, mais a faixa mínima de imagem. A janela abre do tamanho da imagem, nunca abaixo desse mínimo: pedindo menos, o Windows a criaria maior que o pedido e ela nasceria fora do centro. O que o usuário escolheu sobrevive: quem estava com a imagem inteira à vista continua com ela, maior; quem tinha escolhido uma escala — o tamanho real, por exemplo — fica com a mesma escala e passa a ver mais imagem, e não com a mesma proporção do encaixe, que mudaria a porcentagem na barra sozinha. A escala escolhida só não sobrevive em dois casos, e neles não há como: quando ela fica abaixo do encaixe novo, porque o editor não mostra a imagem menor do que cabendo inteira, e quando a imagem já cabe em tamanho real, porque aí escolher o tamanho real é estar no encaixe. Um gesto em curso termina antes de o espaço mudar, como quando outra janela toma o mouse, porque o traço guarda pixels da janela — com a diferença de que aqui o mouse ainda é da janela, e ele é devolvido junto, senão o editor continuaria recebendo todo clique da área de trabalho. Cada passo de redimensionamento custa uma recomposição do fundo — 58 ms numa captura 1920x1080, menos que os 188 ms de um passo de zoom, que refaz a mesma composição. Na moldura — a borda que redimensiona, o título — quem escolhe o ponteiro é o Windows: o editor só responde pela área de cliente. Respondendo por tudo, como fazia, ele punha na borda o ponteiro do último lugar em que o mouse esteve, e quem viesse da barra encontrava a seta no lugar da seta dupla de redimensionar.

**A área de transferência pertence à janela principal.** É ela, e não o editor, que abre a área de transferência, porque o editor fecha logo depois de copiar e um dono que morre é fonte clássica de conteúdo que some na hora de colar.

**Uma janela por vez.** Tanto a seleção quanto o editor rodam um laço de mensagens aninhado dentro do tratador do atalho. Sem trava, apertar um atalho de novo empilharia uma janela dentro da outra. Uma flag no estado da aplicação ignora os atalhos enquanto a anterior não terminar.

**Estado na pilha.** O estado de cada janela vive na pilha da função que roda o laço de mensagens correspondente, e o endereço é entregue ao Windows via `GWLP_USERDATA`. Guardar o ponteiro só dentro da estrutura de janela do Win32 esconderia o objeto do coletor de lixo do V.

**`@[typedef]` nas structs do Windows.** Sem esse atributo o V não usa a definição do `windows.h`: ele gera uma struct própria com os campos declarados no V, e o programa passa a trabalhar com um layout inventado que por acaso funciona até deixar de funcionar.

## Limitações

Conteúdo protegido por DRM aparece preto, porque o Windows bloqueia a cópia dessas janelas. Uma sessão sem área de trabalho renderizada — uma VM sem monitor, por exemplo — também produz uma imagem preta; isso é a tela real daquela sessão, não uma falha da captura.

## Diferenças em relação à referência

O painel de redimensionar da referência tem, além dos fatores, campos livres de largura e altura. Eles ficaram de fora: exigiriam campo de texto, que o editor não tem. A régua continua medindo em pixels da captura depois de redimensionar — o rótulo é desenhado antes do fator, junto com a marcação. E a memória acompanha o tamanho escolhido: em 4× uma captura 1920x1080 vira uma imagem de trabalho de 7680x4320; se a memória não der, o fator anterior fica valendo e a barra diz que falhou, caminho que os testes não provocam.

Os atalhos do zoom são os da referência com `Ctrl` no lugar do `⌘`. O sentido da roda — para longe de quem usa aproxima — foi conferido com giros enviados à janela, e não com uma roda física: a roda simulada por `mouse_event` não chega ao editor nesta máquina, e o ponteiro movido por `SetCursorPos` volta sozinho para onde estava, então o roteiro de validação avisa a posição ao editor antes de cada giro.

O conta-gotas da referência também copia a cor média de uma área selecionada, com a tecla `C`; ele ficou de fora, e o `C` sozinho continua sem uso. O formato é escolhido clicando no bloco, que passa por eles em ordem, e não num menu.

A régua mede segurando `1`, `2` ou uma seta, como a referência, mas a unidade é só o pixel: o painel da referência escolhe entre pixels e pontos, e o Windows não tem o ponto do macOS — a captura já está em pixels físicos. A caixa de ajuda não tem o botão *Got it!* nem a ilustração animada da referência: ela some sozinha na primeira medida, no primeiro clique ou com `Esc`, e volta cada vez que a régua é escolhida.

A moldura da referência é um diálogo com cinco controles deslizantes, três modos de preenchimento e uma galeria de dezoito gradientes. Aqui ela cabe no mesmo painel das outras ferramentas: cor sólida, largura, canto e sombra. Ficaram de fora o gradiente e a imagem de fundo, o deslocamento da imagem dentro da moldura, e o arredondamento do canto externo — este porque exigiria transparência no resultado, e o caminho de imagem daqui não guarda alfa.

A lente da lupa nasce na diagonal do arrasto — ou do outro lado da origem, num eixo em que não caiba no recorte — e, dali em diante, é reposicionável e redimensionável, como na referência. A ampliação não tem controle próprio: ela é a razão entre o tamanho da lente e o da origem, e muda esticando uma das duas.

Da ferramenta de borrar saíram os dois modos que a referência tem para texto — `Blur Text` e `Erase Text` —, que detectam sozinhos onde há escrita na área. A detecção por variação de contraste funciona em interface de cor chapada e mal em fotografia, e o plano já sugeria deixá-los de fora. Os dois modos que ficaram aparecem como miniatura desenhada, e não como o nome escrito que a referência usa: botões com palavra exigiriam largura por botão em todo o painel.

O balão de texto da referência tem um ponteiro, com alça própria para apontá-lo para o que se quiser. Aqui ele não tem: sem a alça, um ponteiro fixo seria enfeite. Quem precisa apontar tem o **Numerador**, cuja ponta tem alça própria e gira para qualquer ângulo.

O painel do traço livre tem, na referência, três botões de estilo — uma mancha, um quadrado e um círculo — cujo efeito não dá para deduzir da imagem. Ficaram de fora em vez de serem adivinhados.

A barra tem as doze ferramentas que aparecem em captura própria em `tmp/topbar_images/`, mais **Selecionar e recortar**, que fica por decisão explícita. Selecionar é o primeiro ícone da barra da referência e o único caminho até as alças, o mover e o redimensionar.

Saíram, por não terem imagem própria, três botões que já existiram: Nova captura, Holofote e Colar imagem. Nenhum dos três chegou a fazer nada.

**Recortar** também não tem imagem na referência — o CleanShot recorta em outro lugar do fluxo, não na barra de anotação —, e fica aqui pelo mesmo motivo que Selecionar: é funcionalidade pedida e não há outro caminho até ela. Ela não tem botão próprio: é o arrasto sobre a imagem vazia com o botão de selecionar.

Os ícones não são os da referência: são desenhos próprios, em `src/assets/icons/`, feitos a partir do que cada botão faz. Antes eram recortes da captura da referência, ampliados de uma tira de PNG.
