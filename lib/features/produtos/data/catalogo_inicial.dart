class CatalogoItem {
  final String nome;
  final String categoria;
  final String unidade;
  const CatalogoItem(this.nome, this.categoria, this.unidade);
}

const String catProteinas = 'Proteínas';
const String catMercearia = 'Mercearia';
const String catLaticinios = 'Laticínios e derivados';
const String catHortifruti = 'Hortifrutigranjeiros';
const String catDescartaveis = 'Descartáveis e utensílios';
const String catLimpeza = 'Material de limpeza';

const List<String> categoriasCatalogo = [
  catProteinas,
  catMercearia,
  catLaticinios,
  catHortifruti,
  catDescartaveis,
  catLimpeza,
];

const List<CatalogoItem> catalogoInicial = [
  // Proteínas
  CatalogoItem('Baby beef', catProteinas, 'kg'),
  CatalogoItem('Bacon defumado em cubos', catProteinas, 'kg'),
  CatalogoItem('Bife bovino', catProteinas, 'kg'),
  CatalogoItem('Carne em cubos marinada', catProteinas, 'kg'),
  CatalogoItem('Carne moída', catProteinas, 'kg'),
  CatalogoItem('Carne para assar', catProteinas, 'kg'),
  CatalogoItem('Contra filé (chorizo)', catProteinas, 'kg'),
  CatalogoItem('Filé de pangasius congelado', catProteinas, 'kg'),
  CatalogoItem('Isca bovina marinada', catProteinas, 'kg'),
  CatalogoItem('Linguiça calabresa', catProteinas, 'kg'),
  CatalogoItem('Lombo suíno congelado', catProteinas, 'kg'),
  CatalogoItem('Músculo em peça congelado', catProteinas, 'kg'),
  CatalogoItem('Peito de frango sem pele e sem osso congelado', catProteinas, 'kg'),
  CatalogoItem('Pernil suíno em cubos congelado', catProteinas, 'kg'),
  CatalogoItem('Sassami congelado', catProteinas, 'kg'),
  CatalogoItem('Sobrecoxa congelada', catProteinas, 'kg'),
  // Mercearia
  CatalogoItem('Açúcar cristal', catMercearia, 'kg'),
  CatalogoItem('Alho descascado congelado', catMercearia, 'kg'),
  CatalogoItem('Ameixa em calda 300 g', catMercearia, 'lata'),
  CatalogoItem('Ameixa seca', catMercearia, 'kg'),
  CatalogoItem('Amido de milho', catMercearia, 'kg'),
  CatalogoItem('Arroz integral 1 kg', catMercearia, 'pct'),
  CatalogoItem('Arroz parboilizado 5 kg', catMercearia, 'pct'),
  CatalogoItem('Arroz tipo 1 5 kg', catMercearia, 'pct'),
  CatalogoItem('Aveia em flocos 150 g', catMercearia, 'pct'),
  CatalogoItem('Azeite de oliva sachê 4 ml (caixa com 200)', catMercearia, 'cx'),
  CatalogoItem('Batata palha 500 g', catMercearia, 'pct'),
  CatalogoItem('Biscoito de água sachê 10 g (caixa com 180)', catMercearia, 'cx'),
  CatalogoItem('Biscoito de leite sachê 10 g (caixa com 180)', catMercearia, 'cx'),
  CatalogoItem('Biscoito maisena sachê 10 g (caixa com 180)', catMercearia, 'cx'),
  CatalogoItem('Brócolis congelado 2 kg', catMercearia, 'pct'),
  CatalogoItem('Café em pó 500 g', catMercearia, 'pct'),
  CatalogoItem('Catchup', catMercearia, 'L'),
  CatalogoItem('Chocolate em pó 50%', catMercearia, 'kg'),
  CatalogoItem('Chocolate granulado', catMercearia, 'kg'),
  CatalogoItem('Ervilha em conserva 170 g', catMercearia, 'pct'),
  CatalogoItem('Extrato de tomate 300 g', catMercearia, 'pct'),
  CatalogoItem('Farinha de aveia 170 g', catMercearia, 'pct'),
  CatalogoItem('Farinha de mandioca', catMercearia, 'kg'),
  CatalogoItem('Farinha de trigo', catMercearia, 'kg'),
  CatalogoItem('Farinha láctea 210 g', catMercearia, 'pct'),
  CatalogoItem('Feijão carioca 1 kg', catMercearia, 'pct'),
  CatalogoItem('Feijão preto', catMercearia, 'kg'),
  CatalogoItem('Gelatina em pó sabor abacaxi 1 kg', catMercearia, 'pct'),
  CatalogoItem('Gelatina em pó sabor morango 1 kg', catMercearia, 'pct'),
  CatalogoItem('Geleia diet sachê 15 g (caixa com 144)', catMercearia, 'cx'),
  CatalogoItem('Leite de coco 500 ml', catMercearia, 'fr'),
  CatalogoItem('Linhaça 200 g', catMercearia, 'pct'),
  CatalogoItem('Macarrão espaguete 500 g', catMercearia, 'pct'),
  CatalogoItem('Macarrão espaguete integral 500 g', catMercearia, 'pct'),
  CatalogoItem('Macarrão parafuso 500 g', catMercearia, 'pct'),
  CatalogoItem('Macarrão parafuso integral 500 g', catMercearia, 'pct'),
  CatalogoItem('Maionese', catMercearia, 'kg'),
  CatalogoItem('Massa para lasanha seca 200 g', catMercearia, 'pct'),
  CatalogoItem('Mel', catMercearia, 'kg'),
  CatalogoItem('Mostarda amarela', catMercearia, 'L'),
  CatalogoItem('Mousse sabor chocolate em pó 500 g', catMercearia, 'pct'),
  CatalogoItem('Mucilon de arroz 360 g', catMercearia, 'pct'),
  CatalogoItem('Mucilon de milho 360 g', catMercearia, 'pct'),
  CatalogoItem('Óleo de soja 900 ml', catMercearia, 'fr'),
  CatalogoItem('Pó para gelatina diet de abacaxi 200 g', catMercearia, 'pct'),
  CatalogoItem('Pó para mousse de limão 500 g', catMercearia, 'pct'),
  CatalogoItem('Pó para pudim de baunilha', catMercearia, 'kg'),
  CatalogoItem('Pó para pudim diet de coco 200 g', catMercearia, 'pct'),
  CatalogoItem('Sal refinado', catMercearia, 'kg'),
  CatalogoItem('Vagem em cubos congelada 2,5 kg', catMercearia, 'pct'),
  CatalogoItem('Vinagre de álcool branco 750 ml', catMercearia, 'fr'),
  // Laticínios e derivados
  CatalogoItem('Leite em pó integral 400 g', catLaticinios, 'pct'),
  CatalogoItem('Leite integral longa vida 1 L', catLaticinios, 'un'),
  CatalogoItem('Leite zero lactose longa vida 1 L', catLaticinios, 'un'),
  CatalogoItem('Manteiga com sal blister 10 g (caixa com 192)', catLaticinios, 'cx'),
  CatalogoItem('Margarina com sal 500 g', catLaticinios, 'pct'),
  CatalogoItem('Margarina sem sal 500 g', catLaticinios, 'pct'),
  CatalogoItem('Requeijão blister 18 g (caixa com 144)', catLaticinios, 'cx'),
  // Hortifrutigranjeiros
  CatalogoItem('Abóbora seca com casca', catHortifruti, 'kg'),
  CatalogoItem('Batata comum/inglesa', catHortifruti, 'kg'),
  CatalogoItem('Batata-doce', catHortifruti, 'kg'),
  CatalogoItem('Beterraba', catHortifruti, 'kg'),
  CatalogoItem('Cebola', catHortifruti, 'kg'),
  CatalogoItem('Cenoura', catHortifruti, 'kg'),
  CatalogoItem('Chuchu', catHortifruti, 'kg'),
  CatalogoItem('Laranja pera', catHortifruti, 'un'),
  CatalogoItem('Maçã Fuji', catHortifruti, 'un'),
  CatalogoItem('Ovo grande (bandeja com 30)', catHortifruti, 'bandeja'),
  CatalogoItem('Pera Williams', catHortifruti, 'un'),
  // Descartáveis e utensílios
  CatalogoItem('Assadeira FN 8 ovos GN 50x30x2', catDescartaveis, 'un'),
  CatalogoItem('Bandeja light 4 divisões (caixa com 600)', catDescartaveis, 'cx'),
  CatalogoItem('Colher descartável fast food refeição (caixa com 1.000)', catDescartaveis, 'cx'),
  CatalogoItem('Marmitex de isopor 750 ml (fardo com 100)', catDescartaveis, 'fardo'),
  CatalogoItem('Marmitex redondo de isopor 500 ml (pacote com 100)', catDescartaveis, 'pct'),
  CatalogoItem('Tampa para marmitex redondo de isopor 500 ml (pacote com 100)', catDescartaveis, 'pct'),
];