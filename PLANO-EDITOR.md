# Plano do editor

Planejamento das ferramentas mostradas em `tmp/topbar_images/`. As imagens são do CleanShot X (macOS) e servem como referência de funcionalidade, não de aparência.

## O que a referência tem

Quinze ferramentas, com atalho de uma tecla:

| Ferramenta | Tecla | O que faz |
|---|---|---|
| Arrow | `A` | Seta com quatro estilos de ponta |
| Text | `T` | Texto, solto ou dentro de um balão com ponteiro |
| Ruler | — | Mede distâncias detectando bordas sozinho |
| Rectangle | `R` | Retângulo |
| Backdrop | `K` | Moldura decorativa em volta da imagem toda |
| Freehand Drawing | `D` | Traço livre |
| Magnifier | `M` | Lupa: recorte ampliado ligado à origem por uma linha |
| Add Capture | `Ctrl+A` | Captura de novo e junta à imagem atual |
| Blur/Erase | `B` | Borra ou apaga uma região, com variante só para texto |
| Highlighter | `H` | Marca-texto translúcido |
| Spotlight | `S` | Escurece tudo menos a região escolhida |
| Counter | `C` | Balões numerados em sequência |
| Oval | `O` | Elipse |
| Line | `L` | Linha reta |
| Paste Image | `Ctrl+V` | Cola uma imagem da área de transferência como objeto |

E na barra, à direita: a cor sob o cursor com `Tab` para copiar, o tamanho da imagem (que abre o redimensionamento) e o nível de zoom.

## A decisão que vem antes de tudo

O editor de hoje aplica cada edição direto nos pixels e guarda a sequência de operações para poder refazer. Isso funciona para recortar e para carimbar um retângulo, mas não sustenta nada do que está nas imagens.

Em todas as capturas de referência, o objeto recém-criado aparece com alças de seleção: a seta tem alças nas pontas e no meio, o texto tem alças em volta do balão, o blur tem oito alças. Ou seja, **nada é queimado na imagem** — cada elemento continua existindo, selecionável, movível e reconfigurável até o momento de exportar. Trocar a cor de uma seta desenhada há cinco passos precisa ser possível sem desfazer os cinco.

Isso significa trocar a fundação: sai a lista de operações reaplicadas, entra uma **cena de objetos**. A imagem passa a ser a captura de fundo mais uma pilha de objetos com geometria e estilo próprios, redesenhados a cada quadro. Salvar e copiar passam a ser "achatar a cena numa imagem".

Não dá para adiar essa troca e ir acrescentando ferramenta por ferramenta no modelo atual: cada ferramenta acrescentada no modelo destrutivo vira retrabalho quando a fundação mudar.

## Fundação

Cinco itens, todos pré-requisito das ferramentas. Nenhum deles entrega valor visível sozinho, e é justamente por isso que precisam ser feitos primeiro e de uma vez.

### F1 — Cena de objetos

Substitui `history.v`. Um objeto tem tipo, geometria em coordenadas da imagem, e estilo (cor, espessura, variante). A cena é uma lista ordenada; desenhar é percorrer a lista sobre a captura de fundo.

Desfazer deixa de reconstruir a imagem e passa a ser o que deveria ter sido desde sempre: uma pilha de estados da cena, que é barata porque a cena são dezenas de bytes por objeto, não megabytes de pixels. Refazer (`Ctrl+Shift+Z`) passa a ser possível, o que hoje não é.

O recorte continua sendo destrutivo sobre a imagem de fundo, mas precisa deslocar a geometria de todos os objetos junto.

Tamanho: médio. Reescreve `history.v` e boa parte de `editor_view.v`.

### F2 — Seleção e manipulação

Clicar seleciona o objeto sob o cursor, o que exige teste de acerto por tipo — a distância até uma linha não se calcula como a área de um retângulo. O objeto selecionado ganha alças; arrastar o corpo move, arrastar uma alça redimensiona ou move um vértice. `Delete` apaga, `Esc` desmarca, `Tab` percorre.

É o item que decide se o editor parece um editor ou um carimbador. Também é o mais fácil de subestimar: teste de acerto, prioridade entre objetos sobrepostos, cursores por alça, restrição de proporção com `Shift`.

Tamanho: médio para grande. Depende de F1.

Feito, removido e devolvido. A poda que deixou na barra só as ferramentas com imagem própria em `tmp/topbar_images/` tirou Selecionar junto, e com ela as alças, o mover, o redimensionar e o `Delete`, porque era o único caminho até a seleção. Ficou de fora por um commit e voltou por decisão explícita.

Duas coisas ficaram pendentes: `Tab` percorrendo os objetos, que perdeu a disputa — o `Tab` ficou com o conta-gotas, como na referência —; e a restrição de proporção com `Shift`, que só passa a fazer diferença quando existir alguma ferramenta em que proporção importe.

### F3 — Trocar o desenho para GDI+

O GDI que uso hoje não tem suavização de serrilhado, não tem transparência por objeto e não tem espessura fracionária. Uma seta desenhada com ele sai com a borda escadeada, e marca-texto e sombra são simplesmente impossíveis.

O `gdiplus.dll` acompanha o Windows, não é dependência externa, e tem uma API C plana que dá para declarar em V do mesmo jeito que já declaro o resto do Win32. Resolve serrilhado, alfa, gradiente, curva e transformação de uma vez.

A alternativa seria desenhar tudo à mão sobre o buffer de pixels, que já tenho em RGBA. Dá controle total e nenhuma dependência nova, mas significa escrever rasterização de linha com espessura, de curva e de texto — muito mais código para um resultado pior.

**Recomendação: GDI+.** Sem isso, metade das ferramentas fica com aparência amadora e três delas não saem do papel.

Tamanho: médio. É interop mais a troca da camada de desenho.

Feito. O `gdiplus.h` que acompanha o compilador é C++, então a API plana está declarada à mão em `gdipflat.h`. O GDI+ é ligado na abertura do editor e desligado no fechamento, e não na partida da aplicação, para a bandeja não carregar o custo dele o tempo todo. Por enquanto só o retângulo passa por ali; gradiente, sombra e curva ficam para quando houver ferramenta que os use.

### F4 — Painel de opções flutuante

A referência mostra um painel que aparece perto do objeto selecionado e muda conforme a ferramenta: cor e espessura para quase todas, estilo de ponta para a seta, variante para o texto, quatro modos para o blur.

Tamanho: médio. Depende de F2 para saber o que está selecionado.

Feito. O painel fica no canto superior direito, logo abaixo da barra, como na referência, e aparece com uma marcação selecionada ou com uma ferramenta que desenhe. Traz o controle deslizante de espessura e os botões de estilo do objeto, que hoje são os quatro do retângulo: cantos e preenchimento. Os estilos de ponta da seta, os de linha e os quatro modos do blur entram junto com as ferramentas que os usam — no painel cada um é uma linha de dados, não uma estrutura nova. A cor, que na referência fica entre a seta de voltar e o controle, entra em F5.

### F5 — Paleta de cores

Oito cores fixas mais "Custom", que abre o seletor do Windows (`ChooseColor`, do `comdlg32`). A cor escolhida vale para o objeto selecionado e vira o padrão dos próximos.

Tamanho: pequeno.

Feito por inteiro. Primeiro só o `ChooseColor`, com as oito cores nos lugares "personalizados" do diálogo; depois a paleta, quando a imagem `07 Freehand Drawing - d.png` mostrou que ela existe em captura — quatro colunas por duas fileiras e o botão do seletor embaixo. As oito cores da paleta são as mesmas que o diálogo carrega, então não há duas listas para manter.

## Ferramentas

Todas dependem de F1, F2, F3 e F4. Estão agrupadas por custo, não pela ordem da barra.

### Baratas depois da fundação

**Rectangle (`R`)** — já existe, só precisa migrar de carimbo para objeto. Ganha de graça a borda suavizada, o preenchimento opcional e a edição depois de criado.

**Oval (`O`)** — mesma geometria do retângulo com outra primitiva de desenho.

Feito. Trouxe junto os botões de estilo por ferramenta: elipse não tem canto, então o painel dela encolhe para os dois do preenchimento. É por esse mesmo mecanismo que a seta, a linha e o blur vão declarar os estilos deles.

**Line (`L`)** — dois pontos e uma espessura. `Shift` prende em 0°, 45° e 90°.

Feito, com traço contínuo ou pontilhado. Trouxe junto o teste de acerto por distância, que era o item que a fundação previa e não tinha: a caixa de uma linha diagonal é quase toda vazia.

**Spotlight (`S`)** — inverso do recorte: escurece tudo menos a região. É um objeto que desenha um retângulo semitransparente com um buraco.

**Paste Image (`Ctrl+V`)** — lê um bitmap da área de transferência e vira um objeto imagem. O caminho de leitura é o inverso do `clipboard.v` que já existe.

### Custo médio

**Arrow (`A`)** — uma linha mais a geometria da ponta, com os quatro estilos da referência: cheia com curva, fina, reta simples e dupla. A ponta é um triângulo orientado pelo ângulo da linha; a variante curva precisa de uma curva de Bézier, que o GDI+ tem pronta.

Feita, com as quatro pontas. Sem Bézier e sem ângulo: as asas saem do vetor unitário e do perpendicular dele, e as duas variantes cheias são um polígono de sete pontos. A direção passou a ser guardada como o canto de onde o arrasto partiu, e não a diagonal, porque a mesma diagonal ao contrário aponta ao contrário.

**Freehand Drawing (`D`)** — acumula os pontos do arrasto e desenha uma polilinha. Sem suavização o traço fica trêmulo, então vale interpolar com curva.

Feito, com curva cardinal e uma peneira de três pixels entre pontos vizinhos. É a primeira marcação cuja geometria não é uma caixa: ela guarda o caminho, e a caixa vem dele. Mover e redimensionar reescalam os pontos, e por isso a seleção e o histórico valem para ela sem nada novo.

Os três botões de estilo que a referência mostra — mancha, quadrado e círculo — ficaram de fora: não dá para deduzir da imagem o que fazem.

**Highlighter (`H`)** — traço livre com transparência e mistura multiplicativa, para escurecer o que está embaixo em vez de cobrir. Depende inteiramente de F3.

Feito, com transparência e sem a multiplicação. Sobre fundo claro as duas são praticamente iguais; sobre fundo escuro a transparência cobre em vez de tingir. Multiplicar de verdade exigiria ler de volta os pixels sob o traço a cada quadro da prévia, e a prévia tem de bater com o resultado. Fica anotado como a diferença conhecida entre o que o plano previa e o que está aqui.

**Counter (`C`)** — cada clique põe um balão com o próximo número. Guardar o contador na cena e renumerar quando um balão do meio é apagado.

Feito, com o ponteiro que a referência mostra. Sem contador guardado: o número sai da contagem de balões anteriores na cena, então renumerar não custa código. Ficou de fora o controle de passo que a referência tem no painel, para escolher em que número a sequência recomeça.

Depois ganhou as três formas da referência, escolhidas no painel — o círculo, que continua sendo o padrão, a ponta fina e a ponta grossa, em gota —, e a ponta ganhou uma alça que a gira para qualquer ângulo. O ponteiro comprido que o arrasto puxava saiu: o arrasto ao criar o balão passou a apontar a ponta.

**Magnifier (`M`)** — dois retângulos ligados: a região de origem e a ampliação, unidas por uma linha. O desenho é um recorte da imagem de fundo esticado, com borda. Reposicionar qualquer uma das pontas atualiza a outra.

Feita, com as duas formas que a referência oferece — redonda e retangular — e ampliação fixa de três vezes. A lente não tem alça própria: ela sai na diagonal de onde o arrasto partiu, o que dá quatro posições, e acompanha a origem quando esta é movida. Uma alça só para ela sairia da máquina de seleção que vale para todas as marcações, que trabalha com uma caixa e oito alças.

Depois a lente ganhou controle próprio, como na referência: a posição e o tamanho dela ficam guardados na marcação, cada ponta tem as suas alças, e mover ou esticar uma não mexe na outra. A ampliação passou a ser a razão entre a lente e a origem. A máquina de seleção continuou sendo a de uma caixa só; o que ela ganhou foi saber em qual das duas pontas o clique caiu.

**Add Capture (`Ctrl+A`)** — esconde o editor, dispara uma captura nova, e traz o resultado como objeto imagem. Precisa cuidar do ciclo de esconder e reexibir a janela sem se capturar.

### Caras

**Text (`T`)** — a mais cara de todas, e a que mais parece simples. Precisa de cursor piscando, seleção de trecho, teclas de navegação, quebra de linha, escolha de fonte e tamanho, comportamento de IME para acentuação, e as duas variantes da referência (texto solto e balão com ponteiro reposicionável). Um campo de texto próprio é um projeto dentro do projeto; a alternativa é sobrepor um controle `EDIT` nativo durante a digitação e converter para objeto ao confirmar, que é feio por dentro mas resolve acentuação e seleção de graça.

Feito, e sem o controle nativo: a digitação acontece na própria janela, e o que se vê enquanto se escreve já é o resultado — mesma fonte, mesma cor, mesmo balão. Um `EDIT` sobreposto desenharia com a aparência dele e o texto saltaria ao ser confirmado. A acentuação, que era o motivo de considerar o controle nativo, saiu de graça: o `TranslateMessage` compõe a tecla morta antes da mensagem de caractere. As duas variantes estão lá, pelo mesmo mecanismo de estilo por ferramenta que as outras usam, e o duplo clique reabre um texto para reescrever.

Ficaram de fora a seleção de trecho, o cursor que anda pelo texto, o colar, e o ponteiro do balão — este porque sem alça própria para apontá-lo seria enfeite, e o Numerador já tem um que funciona.

**Blur/Erase (`B`)** — quatro modos. `Blur` é uma convolução sobre a região, e um desfoque de caixa em duas passagens é barato e suficiente. `Erase` preenche com a cor de fundo. Os modos `Blur Text` e `Erase Text` da referência detectam onde há texto na região, o que exige análise de imagem — variação local de contraste resolve casos simples, mas não é confiável. **Sugiro entregar `Blur` e `Erase` e deixar as variantes de texto de fora**, porque o esforço é desproporcional e o resultado é incerto.

Feito, com os dois modos previstos e sem convolução nenhuma: a área encolhe com interpolação e volta sem ela, e o que sobra é o mosaico que a própria referência mostra. `Erase` também não usa cor de fundo — ele cobre com a média do que havia na área, que se acomoda no que está em volta sem precisar de cor escolhida. É por isso que o painel desta ferramenta é o único sem disco de cor.

**Backdrop (`K`)** — a moldura decorativa em volta da imagem, com sombra, recuo, raio interno e externo, e preenchimento sólido, em gradiente ou com imagem. É a feature que mais muda a aparência do resultado e a que tem mais controles: são cinco sliders e uma galeria de gradientes. Não é difícil, é grande.

Feita no tamanho que cabe no painel das outras ferramentas, em vez do diálogo próprio da referência: cor sólida pelo disco, largura pelo controle, e quatro botões para o canto da imagem e a sombra. Ficaram de fora o gradiente, a imagem de fundo, o recuo e o raio externo — este último porque pede transparência no resultado, que o caminho de imagem daqui não carrega.

Ela é guardada na cena como as marcações, o que lhe dá desfazer, refazer, painel e Delete de graça. O custo real não foi o desenho: foi a folga que ela acrescenta, que desloca a origem da imagem de trabalho e entra nas quatro conversões entre a janela e a captura.

**Ruler** — mede distâncias detectando bordas sozinha, como mostra a caixa de ajuda da referência: segurando uma tecla e passando o mouse, ela acha a extensão do elemento sob o cursor e mostra a medida. A detecção de borda por diferença de cor funciona bem em interfaces de cor chapada e mal em fotografia. É a ferramenta de maior risco de resultado ruim.

Feita, e o risco foi contido de um jeito simples: a medida manual é a de sempre — um traço como a linha, com as pontas marcadas e o comprimento escrito —, e a automática é um clique que lê a faixa de cor sob o ponteiro. Onde a leitura funciona, que é interface de cor chapada, ela poupa a mira; onde não funciona, a faixa sai curta e o arrasto manual continua lá. Não há modo em que a ferramenta só dê resultado ruim. Ficou de fora a unidade em pontos.

Depois a medida automática passou a ser a da referência: escolher a régua abre a caixa *Use the keyboard*, segurar `1` mede a faixa na vertical, `2` na horizontal, e uma seta do ponteiro até a borda naquela direção. A prévia acompanha o mouse enquanto a tecla está apertada, e soltar guarda a régua. O clique com `Ctrl`, que era o substituto provisório da tecla segurada, saiu.

## Barra superior

**Cor sob o cursor com `Tab` para copiar** — mostra o valor do pixel sob o ponteiro e copia no formato escolhido. A referência oferece oito formatos: `#FFC200`, `FFC200`, `rgba()` do CSS, RGB em ponto flutuante, Android, `UIColor`, `C# Color.fromArgb()` e OKLCH. Tem também "copiar a cor média de uma área". Custo médio, valor alto para quem trabalha com interface.

Feito com os oito formatos e com o `Shift+Tab` da referência, que copia a cor mais escura em volta do ponteiro — a da letra, sobre texto. O formato é trocado clicando no bloco. Ficou de fora a cor média de uma área.

**Tamanho da imagem e redimensionamento** — mostra as dimensões e abre o diálogo com atalhos de 25%, 33%, 50%, 1×, 2×, 4× mais campos livres. A referência avisa que não dá para desfazer; com a cena de objetos de F1, dá — basta escalar a geometria junto.

Feito, e sem escalar a geometria: o fator fica guardado na cena e é aplicado sobre a imagem pronta, e quem muda é o caminho entre a captura e a janela. Desfaz como qualquer edição. Ficaram de fora os campos livres de largura e altura, que pediriam campo de texto.

**Zoom** — nível de ampliação da visualização, com deslocamento quando a imagem não cabe. Mexe em toda a conversão entre coordenadas de tela e de imagem, que hoje é um fator de escala só. Fazer isso depois de F1 e F2 é bem mais barato do que refazer depois.

Feito como zoom da vista, fora da cena: roda com o ponto sob o ponteiro parado, botão direito para deslocar, painel com − e +, e os atalhos da referência com `Ctrl` — mais, menos, imagem inteira, tamanho real e aproximar a marcação escolhida. Custou pouco justamente pelo que este item previa: a conversão já passava por um fator e uma posição, e o zoom só mudou os dois.

## A barra que existe

A barra da aplicação tem as doze ferramentas que aparecem em imagem própria na pasta de referência — Seta, Texto, Régua, Retângulo, Moldura, Traço livre, Lupa, Borrar, Marca-texto, Numerador, Elipse e Linha — mais Selecionar e Cortar, que ficam por decisão explícita.

Nova captura, Holofote e Colar imagem aparecem só na foto da barra inteira e na lista de atalhos, sem tela dedicada, e por isso saíram.

Cortar não aparece em imagem nenhuma: o CleanShot recorta em outro ponto do fluxo, e não na barra de anotação. Chegou a sair junto com os outros e voltou, porque é funcionalidade pedida e não há outro caminho até ela dentro do editor. Depois deixou de ter botão próprio: ela divide o botão com Selecionar, e é o arrasto sobre a imagem vazia.

A ordem da barra foi pedida explicitamente: copiar e salvar, e depois Selecionar e recortar, Seta, Texto, Régua, Retângulo, Moldura, Traço livre, Lupa, Borrar, Marca-texto, Numerador, Elipse e Linha; à direita, a cor, o tamanho e o zoom. Desfazer, refazer e fechar saíram da barra e ficaram no teclado.

## Ordem sugerida

**Fase 1 — fundação.** F1, F2, F3, F4, F5. Feita. Nada de novo apareceu na barra, e o retângulo passou a ser editável depois de criado: cor, espessura, canto, preenchimento, posição e tamanho.

**Fase 2 — as formas.** Feita: Rectangle, Oval, Line, Arrow, Freehand e Highlighter. Spotlight saiu da barra por não ter imagem própria. Sete ferramentas que compartilham quase toda a infraestrutura; depois da primeira, cada uma seguinte é pequena. É aqui que o editor passa a parecer completo.

**Fase 3 — texto e numeração.** Feita: Counter primeiro, Text depois. Text saiu bem menor do que o previsto por não usar controle nativo: o que ela não faz — selecionar trecho, andar com o cursor, colar — é justamente o que o controle traria, e é o que ficou pendente.

**Fase 4 — pixels.** Feita: Blur e Erase no mesmo botão da barra, e Magnifier. As três leem a imagem em vez de só escrever nela, e nenhuma precisou de laço sobre pixels — o GDI encolhe e amplia sozinho.

**Fase 5 — imagem inteira.** Feita: Backdrop, Resize e Zoom, que vive no último bloco da direita. Add Capture e Paste Image saíram da barra por não terem imagem de referência própria.

**Fase 6 — utilidades.** Feita: Ruler e o color picker com formatos.

## Riscos e pontos em aberto

**O tamanho.** São quinze ferramentas mais três funções de barra. O editor hoje tem cerca de mil linhas; isso multiplica o projeto várias vezes. Não é trabalho de uma sessão nem de uma semana.

**Aparência.** Resolvida. A barra e o painel são desenhados à mão, com ícones próprios em SVG e cantos arredondados, e a faixa de botões nativos que ficava embaixo da janela deixou de existir: as ações viraram ícones à esquerda da mesma barra. Não sobrou controle do Windows na janela do editor.

**O que eu deixaria de fora.** As variantes `Blur Text` e `Erase Text`, pelo esforço desproporcional e resultado incerto. A galeria de gradientes do Backdrop pode começar com quatro opções em vez de dezoito. E o Ruler só vale se você medir interfaces com frequência.

**O que eu faria primeiro se fosse só um pedaço.** F1 a F5 mais a Fase 2. Isso entrega sete ferramentas editáveis com aparência decente, e é o ponto em que o editor deixa de ser um carimbador e vira uma ferramenta de anotação de verdade.
