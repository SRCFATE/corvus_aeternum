import 'package:flutter/material.dart';

// ─── Modelos ──────────────────────────────────────────────────────────────────

class GlossaryTerm {
  final String term;
  final String definition;
  final String? example;
  final List<GlossaryTerm> children;

  const GlossaryTerm(
    this.term,
    this.definition, {
    this.example,
    this.children = const [],
  });

  int get termCount =>
      1 + children.fold<int>(0, (total, child) => total + child.termCount);
}

class GlossaryCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<GlossaryTerm> terms;

  const GlossaryCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.terms,
  });

  int get termCount =>
      terms.fold<int>(0, (total, term) => total + term.termCount);
}

class GlossaryArtisticCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<GlossaryCategory> sections;

  const GlossaryArtisticCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.sections,
  });

  int get termCount =>
      sections.fold<int>(0, (total, section) => total + section.termCount);
}

// ─── Contenido del glosario ───────────────────────────────────────────────────

GlossaryTerm _genreTerm(
  String term,
  String definition,
  List<String> subgenres, {
  String? example,
}) {
  return GlossaryTerm(
    term,
    definition,
    example: example,
    children: [
      for (final subgenre in subgenres)
        GlossaryTerm(
          subgenre,
          'Subgenero o linea especifica dentro de $term. Precisa tono, formato, escala o tradicion creativa sin sacar la obra de su genero principal.',
        ),
    ],
  );
}

final glossaryArtisticCategories = <GlossaryArtisticCategory>[
  GlossaryArtisticCategory(
    id: 'writing',
    title: 'Escritura',
    subtitle: 'Narrativa, poesia, ensayo, guion y lenguaje literario.',
    icon: Icons.menu_book_rounded,
    sections: [
      GlossaryCategory(
        id: 'writing_genres',
        title: 'Generos y subgeneros literarios',
        subtitle: 'Familias narrativas con sus corrientes internas.',
        icon: Icons.auto_stories_rounded,
        terms: [
          _genreTerm(
              'Fantasia',
              'Lo imposible opera como regla interna: magia, mitologia, criaturas o cosmologias inventadas.',
              [
                'Fantasia epica',
                'Fantasia oscura',
                'Fantasia urbana',
                'Espada y brujeria',
                'Mitologia',
                'Portal fantasy',
                'Folk fantasy'
              ]),
          _genreTerm(
              'Ciencia ficcion',
              'Ficcion especulativa basada en tecnologia, futuros posibles, sociedades alternativas o premisas racionales.',
              [
                'Cyberpunk',
                'Solarpunk',
                'Space opera',
                'Distopia',
                'Biopunk',
                'Cli-fi',
                'Mexica futurista',
                'Afrofuturismo'
              ]),
          _genreTerm(
              'Terror',
              'Relato construido para producir inquietud, miedo, angustia o ruptura de lo cotidiano.',
              [
                'Terror gotico',
                'Horror cosmico',
                'Folk horror',
                'Body horror',
                'Suspenso sobrenatural',
                'Terror psicologico'
              ]),
          _genreTerm(
              'Drama',
              'Conflicto humano con peso emocional, social o moral; la transformacion interior sostiene la pieza.',
              [
                'Drama psicologico',
                'Drama familiar',
                'Realismo sucio',
                'Coming of age',
                'Tragedia',
                'Drama historico'
              ]),
          _genreTerm(
              'Romance',
              'La relacion afectiva estructura el conflicto central, sus obstaculos y su resolucion.',
              [
                'Romance oscuro',
                'Romance gotico',
                'Romance contemporaneo',
                'Enemies to lovers',
                'Slow burn'
              ]),
          _genreTerm(
              'Thriller',
              'Tension sostenida, peligro progresivo, informacion dosificada y ritmo de urgencia.',
              [
                'Thriller politico',
                'Thriller psicologico',
                'Noir',
                'Misterio',
                'Conspiracion'
              ]),
          _genreTerm(
              'Ensayo',
              'Texto reflexivo o argumentativo donde una idea se desarrolla con voz, postura e investigacion.',
              [
                'Ensayo cultural',
                'Ensayo filosofico',
                'Ensayo politico',
                'Manifiesto',
                'Critica artistica'
              ]),
          _genreTerm(
              'Poesia',
              'Escritura organizada por imagen, ritmo, respiracion y concentracion verbal.',
              [
                'Verso libre',
                'Prosa poetica',
                'Poesia oscura',
                'Poesia narrativa',
                'Spoken word'
              ]),
          _genreTerm(
              'Guion',
              'Texto diseñado para pantalla, escena, comic, audio o interaccion; organiza accion, dialogo y ritmo.',
              [
                'Guion cinematografico',
                'Guion teatral',
                'Guion serial',
                'Guion interactivo',
                'Guion de comic'
              ]),
          _genreTerm(
              'Cronica',
              'Hechos reales narrados con herramientas literarias: escena, punto de vista, contexto y voz.',
              [
                'Cronica urbana',
                'Cronica personal',
                'Cronica cultural',
                'Cronica documental'
              ]),
        ],
      ),
      GlossaryCategory(
        id: 'writing_language',
        title: 'Narrativa, tiempo y voz',
        subtitle: 'Recursos formales para contar, ordenar y modular texto.',
        icon: Icons.record_voice_over_outlined,
        terms: const [
          GlossaryTerm('Narrador protagonista',
              'Primera persona que cuenta su propia historia; da intimidad, sesgo y vision limitada.'),
          GlossaryTerm('Narrador testigo',
              'Voz periferica que observa a otro personaje central; permite misterio y distancia.'),
          GlossaryTerm('Narrador omnisciente',
              'Tercera persona que conoce pensamientos, pasado, futuro y motivaciones de varios personajes.'),
          GlossaryTerm('Narrador no confiable',
              'Voz incompleta, interesada o distorsionada; obliga a leer entre lineas.'),
          GlossaryTerm('Analepsis',
              'Salto temporal hacia atras para mostrar hechos anteriores al presente narrativo.'),
          GlossaryTerm('Prolepsis',
              'Anticipacion de un hecho futuro antes de que la historia llegue a ese punto.'),
          GlossaryTerm('Verso libre',
              'Forma poetica sin metrica ni rima fija; el ritmo surge de respiracion, imagen y pausa.'),
          GlossaryTerm('Cadencia',
              'Curva ritmica con que cae una frase, escena o verso; afecta tono, velocidad y cierre.'),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'visual',
    title: 'Visual',
    subtitle: 'Ilustracion, pintura, concept art, portadas y arte digital.',
    icon: Icons.palette_outlined,
    sections: [
      GlossaryCategory(
        id: 'visual_genres',
        title: 'Disciplinas y subgeneros visuales',
        subtitle: 'Formatos de imagen y variantes de produccion.',
        icon: Icons.brush_rounded,
        terms: [
          _genreTerm(
              'Ilustracion',
              'Imagen creada para comunicar escena, personaje, atmosfera, portada o idea editorial.',
              [
                'Personaje',
                'Concept art',
                'Key art',
                'Splash art',
                'Editorial',
                'Portada',
                'Poster'
              ]),
          _genreTerm(
              'Pintura',
              'Obra visual basada en pigmento, gesto, superficie y composicion; fisica, digital o mixta.',
              [
                'Acrilico',
                'Oleo',
                'Acuarela',
                'Mixta',
                'Expresionista',
                'Abstracta',
                'Figurativa'
              ]),
          _genreTerm(
              'Diseno grafico',
              'Sistema visual aplicado a comunicacion, identidad, cartel, editorial o tipografia.',
              [
                'Identidad visual',
                'Poster',
                'Editorial',
                'Tipografico',
                'Collage digital'
              ]),
          _genreTerm(
              '3D',
              'Imagen o asset producido con modelado, materiales, iluminacion, camara virtual y render.',
              [
                'Modelado',
                'Escultura digital',
                'Render cinematografico',
                'Environment art',
                'Producto'
              ]),
          _genreTerm(
              'Escultura',
              'Objeto tridimensional fisico o digital pensado desde volumen, materia, escala y presencia.',
              ['Objeto', 'Instalacion', 'Maqueta', 'Pieza textil', 'Mixta']),
          _genreTerm(
              'Artbook',
              'Archivo curado de arte, proceso y decisiones visuales de una obra, universo o coleccion.',
              [
                'Proceso',
                'Coleccion curada',
                'Personajes',
                'Ambientes',
                'Props'
              ]),
        ],
      ),
      GlossaryCategory(
        id: 'visual_styles',
        title: 'Estilos y movimientos visuales',
        subtitle: 'Lenguajes esteticos para orientar la imagen.',
        icon: Icons.museum_outlined,
        terms: const [
          GlossaryTerm('Surrealismo',
              'Imagen del sueño, lo imposible o el inconsciente presentada con logica visual propia.'),
          GlossaryTerm('Brutalismo',
              'Estetica de masa, aspereza, estructura expuesta y presencia material contundente.'),
          GlossaryTerm('Expresionismo',
              'Deformacion de figura, color o gesto para priorizar emocion sobre apariencia objetiva.'),
          GlossaryTerm('Minimalismo',
              'Reduccion a elementos esenciales: forma, espacio, contraste y economia visual.'),
          GlossaryTerm('Arte conceptual',
              'La idea, instruccion o sistema pesa mas que el objeto final como pieza estetica.'),
          GlossaryTerm('Postinternet',
              'Sensibilidad marcada por cultura digital, interfaces, archivo, glitch y circulacion online.'),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'music',
    title: 'Musica',
    subtitle: 'Canciones, albums, demos, soundtracks y arquitectura sonora.',
    icon: Icons.music_note_rounded,
    sections: [
      GlossaryCategory(
        id: 'music_genres',
        title: 'Generos y subgeneros musicales',
        subtitle: 'Territorios sonoros con sus ramas internas.',
        icon: Icons.queue_music_rounded,
        terms: [
          _genreTerm(
              'Cancion',
              'Pieza breve, vocal o instrumental, con centro emocional y estructura memorable.',
              [
                'Balada oscura',
                'Rock alternativo',
                'Pop experimental',
                'Synthwave',
                'Industrial',
                'Folk oscuro'
              ]),
          _genreTerm(
              'Album',
              'Conjunto de piezas pensado como obra mayor, con arco sonoro, concepto o identidad curatorial.',
              [
                'Album conceptual',
                'Album narrativo',
                'Album instrumental',
                'Album colaborativo',
                'Live session'
              ]),
          _genreTerm(
              'EP',
              'Publicacion musical intermedia, mas amplia que un single y mas concentrada que un album.',
              [
                'EP conceptual',
                'EP acustico',
                'EP experimental',
                'EP de demos'
              ]),
          _genreTerm(
              'Soundtrack',
              'Musica diseñada para acompañar imagen, escena, personaje, videojuego, trailer o mundo.',
              [
                'Score cinematografico',
                'Tema de personaje',
                'Tema de ciudad',
                'Ambiental',
                'Combate',
                'Trailer music'
              ]),
          _genreTerm(
              'Beat',
              'Base ritmica o instrumental centrada en groove, textura y posible escritura vocal.',
              [
                'Trap',
                'Hip hop alternativo',
                'Lo-fi',
                'Industrial beat',
                'Cinematic beat'
              ]),
          _genreTerm(
              'Ambient',
              'Musica de atmosfera, espacio y textura; el paisaje sonoro pesa mas que la progresion tradicional.',
              [
                'Drone',
                'Dark ambient',
                'Field recording',
                'Textural',
                'Ritual'
              ]),
        ],
      ),
      GlossaryCategory(
        id: 'music_rhythm',
        title: 'Ritmo y forma sonora',
        subtitle: 'Parametros para describir pulso, estructura y escucha.',
        icon: Icons.graphic_eq_rounded,
        terms: const [
          GlossaryTerm('Pulso',
              'Latido regular sobre el que se organizan acentos, compases y patrones ritmicos.'),
          GlossaryTerm('Tempo',
              'Velocidad del pulso, usualmente medida en BPM o indicada con terminos expresivos.'),
          GlossaryTerm('Sincopa',
              'Acento desplazado hacia una parte debil del compas para generar tension y movimiento.'),
          GlossaryTerm('Ostinato',
              'Patron ritmico, melodico o armonico repetido mientras otros elementos evolucionan.'),
          GlossaryTerm('Groove',
              'Sensacion corporal de fluidez ritmica creada por microdesplazamientos y repeticion eficaz.'),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'video',
    title: 'Video',
    subtitle: 'Corto, videoclip, trailer, animacion y ensayo audiovisual.',
    icon: Icons.movie_creation_outlined,
    sections: [
      GlossaryCategory(
        id: 'video_formats',
        title: 'Formatos audiovisuales',
        subtitle: 'Piezas de imagen en movimiento y sus variantes.',
        icon: Icons.slideshow_rounded,
        terms: [
          _genreTerm(
              'Cortometraje',
              'Obra audiovisual breve con unidad dramatica, conceptual o atmosferica.',
              [
                'Drama',
                'Terror',
                'Experimental',
                'Ciencia ficcion',
                'Fantasia oscura',
                'Noir'
              ]),
          _genreTerm(
              'Videoclip',
              'Pieza audiovisual articulada alrededor de una cancion, performance o concepto musical.',
              [
                'Performance',
                'Narrativo',
                'Conceptual',
                'Lyrics video',
                'Live session'
              ]),
          _genreTerm(
              'Documental',
              'Registro o construccion audiovisual de hechos, procesos, personas o contextos reales.',
              [
                'Biografico',
                'Cultural',
                'Observacional',
                'Ensayo audiovisual',
                'Making of'
              ]),
          _genreTerm(
              'Animacion',
              'Imagen en movimiento creada cuadro a cuadro, por interpolacion, modelado o composicion.',
              ['2D', '3D', 'Stop motion', 'Motion graphics', 'Animatic']),
          _genreTerm(
              'Trailer',
              'Pieza promocional que condensa tono, promesa narrativa y energia de una obra mayor.',
              [
                'Teaser',
                'Book trailer',
                'Game trailer',
                'Fashion film',
                'Pitch trailer'
              ]),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'comic',
    title: 'Comic',
    subtitle: 'Manga, webtoon, novela grafica y narrativa secuencial.',
    icon: Icons.chrome_reader_mode_outlined,
    sections: [
      GlossaryCategory(
        id: 'comic_formats',
        title: 'Formatos secuenciales',
        subtitle: 'Familias de comic y sus lineas internas.',
        icon: Icons.view_week_rounded,
        terms: [
          _genreTerm(
              'Manga',
              'Comic de tradicion japonesa o inspirado en sus codigos graficos, narrativos y editoriales.',
              [
                'Seinen',
                'Shonen',
                'Shojo',
                'Josei',
                'One-shot',
                'Dark fantasy',
                'Slice of life'
              ]),
          _genreTerm(
              'Webtoon',
              'Comic vertical pensado para lectura digital continua en pantalla.',
              [
                'Vertical color',
                'Romance',
                'Accion',
                'Drama',
                'Terror',
                'Fantasia urbana'
              ]),
          _genreTerm(
              'Comic occidental',
              'Tradicion de pagina, viñeta y serialidad asociada a mercados americanos y europeos.',
              [
                'Superheroico',
                'Indie',
                'Noir',
                'Ciencia ficcion',
                'Fantasia',
                'Autobiografico'
              ]),
          _genreTerm(
              'Novela grafica',
              'Obra secuencial de arco cerrado o ambicion literaria, usualmente publicada como volumen.',
              [
                'Literaria',
                'Historica',
                'Memoria',
                'Drama adulto',
                'Experimental'
              ]),
          _genreTerm(
              'Fanzine',
              'Publicacion independiente, autogestionada y de circulacion flexible.',
              ['DIY', 'Antologia', 'Ensayo visual', 'Punk', 'Experimental']),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'photo',
    title: 'Fotografia',
    subtitle: 'Retrato, editorial, documental, producto y archivo visual.',
    icon: Icons.photo_camera_outlined,
    sections: [
      GlossaryCategory(
        id: 'photo_genres',
        title: 'Generos fotograficos',
        subtitle: 'Campos de produccion fotografica y sus sublineas.',
        icon: Icons.camera_alt_outlined,
        terms: [
          _genreTerm(
              'Retrato',
              'Imagen centrada en identidad, presencia, rostro, cuerpo o psicologia del sujeto.',
              [
                'Editorial',
                'Fine art',
                'Conceptual',
                'Moda',
                'Psicologico',
                'Autorretrato'
              ]),
          _genreTerm(
              'Fotografia urbana',
              'Lectura visual de ciudad, calle, arquitectura, flujo social o noche urbana.',
              [
                'Street',
                'Nocturna',
                'Arquitectura',
                'Documental urbano',
                'Ciudad futurista'
              ]),
          _genreTerm(
              'Documental',
              'Registro fotografico de procesos, comunidades, hechos o contextos reales.',
              [
                'Social',
                'Cultural',
                'Archivo',
                'Proceso artistico',
                'Ensayo fotografico'
              ]),
          _genreTerm(
              'Producto',
              'Imagen orientada a presentar objeto, material, marca o pieza comercial.',
              [
                'E-commerce',
                'Editorial de producto',
                'Still life',
                'Lujo',
                'Campana'
              ]),
          _genreTerm(
              'Evento',
              'Cobertura visual de una accion temporal: concierto, exhibicion, lanzamiento o performance.',
              [
                'Concierto',
                'Performance',
                'Backstage',
                'Exhibicion',
                'Lanzamiento'
              ]),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'fashion',
    title: 'Moda',
    subtitle: 'Prenda, coleccion, drop, patronaje y lenguaje vestible.',
    icon: Icons.checkroom_outlined,
    sections: [
      GlossaryCategory(
        id: 'fashion_lines',
        title: 'Lineas de diseno',
        subtitle: 'Familias de moda con sus variantes de pieza y coleccion.',
        icon: Icons.dry_cleaning_outlined,
        terms: [
          _genreTerm(
              'Streetwear',
              'Moda urbana de identidad grafica, silueta cotidiana y circulacion por drops o comunidad.',
              [
                'Oversized',
                'Graphic tee',
                'Drop limitado',
                'Urban utility',
                'Skate'
              ]),
          _genreTerm(
              'Techwear',
              'Diseño funcional de inspiracion tecnica: capas, utilidad, resistencia y modularidad.',
              ['Utility', 'Modular', 'Waterproof', 'Tactico', 'Cyberpunk']),
          _genreTerm(
              'Alta costura',
              'Pieza de alto oficio, construccion compleja y presencia escenica o conceptual.',
              [
                'Avant-garde',
                'Pieza unica',
                'Bordado',
                'Volumen estructural',
                'Conceptual'
              ]),
          _genreTerm(
              'Ready-to-wear',
              'Coleccion lista para uso, produccion y venta sin patronaje a medida.',
              [
                'Capsula',
                'Temporada',
                'Basicos elevados',
                'Coleccion comercial'
              ]),
          _genreTerm(
              'Accesorio',
              'Objeto vestible complementario que define silueta, identidad o gesto de styling.',
              ['Bolsa', 'Joyeria', 'Mascara', 'Sombrero', 'Cinturon']),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'game',
    title: 'Juego',
    subtitle: 'Videojuego, visual novel, RPG, puzzle y sistemas interactivos.',
    icon: Icons.sports_esports_outlined,
    sections: [
      GlossaryCategory(
        id: 'game_genres',
        title: 'Generos jugables',
        subtitle: 'Formas de interaccion y sus subfamilias.',
        icon: Icons.gamepad_outlined,
        terms: [
          _genreTerm(
              'RPG',
              'Juego centrado en progresion, rol, decisiones, combate, estadisticas o construccion de personaje.',
              [
                'JRPG',
                'Action RPG',
                'Tactical RPG',
                'Narrative RPG',
                'Dungeon crawler'
              ]),
          _genreTerm(
              'Visual novel',
              'Obra interactiva de lectura, decisiones, rutas y presentacion audiovisual.',
              [
                'Romance',
                'Terror',
                'Misterio',
                'Rutas multiples',
                'Kinetic novel'
              ]),
          _genreTerm(
              'Aventura',
              'Juego de exploracion, descubrimiento, dialogo, objetos o resolucion de situaciones.',
              [
                'Point and click',
                'Exploracion',
                'Narrativa ambiental',
                'Puzzle adventure'
              ]),
          _genreTerm(
              'Puzzle',
              'Juego donde el reto central es logico, espacial, sistemico o de patrones.',
              ['Logica', 'Narrativo', 'Fisica', 'Escape room', 'Abstracto']),
          _genreTerm(
              'Terror',
              'Experiencia interactiva que usa vulnerabilidad, tension, amenaza o atmosfera para generar miedo.',
              [
                'Survival horror',
                'Psicologico',
                'Found footage',
                'Atmosferico'
              ]),
        ],
      ),
      GlossaryCategory(
        id: 'game_systems',
        title: 'Sistemas y produccion',
        subtitle: 'Conceptos base para describir diseno interactivo.',
        icon: Icons.account_tree_outlined,
        terms: const [
          GlossaryTerm('Loop jugable',
              'Ciclo de accion, respuesta y recompensa que sostiene la experiencia principal.'),
          GlossaryTerm('Prototipo',
              'Version temprana para validar una mecanica, tono o flujo antes de producir contenido final.'),
          GlossaryTerm('Vertical slice',
              'Fragmento pulido que demuestra la experiencia objetivo con calidad cercana al producto final.'),
          GlossaryTerm('Narrativa ambiental',
              'Historia comunicada por espacio, objetos, sonido, arquitectura y detalles no verbales.'),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'stage',
    title: 'Escena',
    subtitle: 'Teatro, danza, performance, monologo y puesta en espacio.',
    icon: Icons.theater_comedy_outlined,
    sections: [
      GlossaryCategory(
        id: 'stage_forms',
        title: 'Artes escenicas',
        subtitle: 'Formatos de presencia viva y sus variantes.',
        icon: Icons.local_activity_outlined,
        terms: [
          _genreTerm(
              'Teatro',
              'Obra escenica basada en accion, texto, cuerpo, espacio, conflicto y presencia ante publico.',
              [
                'Drama',
                'Tragedia',
                'Comedia oscura',
                'Experimental',
                'Teatro fisico'
              ]),
          _genreTerm(
              'Performance',
              'Accion artistica donde cuerpo, tiempo, gesto y presencia son el soporte principal.',
              ['Ritual', 'Duracional', 'Inmersiva', 'Cuerpo', 'Accion urbana']),
          _genreTerm(
              'Danza',
              'Composicion de movimiento, ritmo, cuerpo y espacio como lenguaje primario.',
              [
                'Contemporanea',
                'Butoh',
                'Danza teatro',
                'Improvisacion',
                'Ritual'
              ]),
          _genreTerm(
              'Monologo',
              'Pieza centrada en una voz o presencia que sostiene el arco dramatico.',
              ['Dramatico', 'Confesional', 'Satirico', 'Poetico', 'Politico']),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'world',
    title: 'Mundo',
    subtitle: 'Worldbuilding, lore, mapas, facciones, sistemas y canon.',
    icon: Icons.public_rounded,
    sections: [
      GlossaryCategory(
        id: 'worldbuilding',
        title: 'Sectores de mundo',
        subtitle: 'Piezas del archivo narrativo que sostienen universos.',
        icon: Icons.travel_explore_rounded,
        terms: [
          _genreTerm(
              'Worldbuilding',
              'Diseño integral de universo: reglas, historia, geografia, cultura, economia y tono.',
              [
                'Universo transmedia',
                'Mundo secundario',
                'Linea temporal',
                'Cosmologia',
                'Sistema social'
              ]),
          _genreTerm(
              'Lore',
              'Conjunto de mitos, archivos, relatos, versiones y conocimiento interno de un mundo.',
              [
                'Mitos fundacionales',
                'Cronicas',
                'Archivos',
                'Leyendas',
                'Canon historico'
              ]),
          _genreTerm(
              'Mapa',
              'Representacion espacial de territorio, rutas, fronteras, ciudades o zonas de conflicto.',
              [
                'Mapa politico',
                'Mapa fisico',
                'Mapa urbano',
                'Mapa de facciones',
                'Mapa de rutas'
              ]),
          _genreTerm(
              'Sistema politico',
              'Arquitectura de poder, gobierno, ley, conflicto institucional y legitimidad.',
              [
                'Imperio',
                'Estado corporativo',
                'Ciudad estado',
                'Anarquia',
                'Teocracia'
              ]),
          _genreTerm(
              'Sistema magico',
              'Reglas, limites, costos y fuentes de lo extraordinario dentro de un universo.',
              [
                'Magia ritual',
                'Tecnologia arcana',
                'Pacto',
                'Herencia',
                'Alquimia'
              ]),
        ],
      ),
    ],
  ),
  GlossaryArtisticCategory(
    id: 'rights',
    title: 'Archivo legal',
    subtitle:
        'Derechos, propiedad, licencias y uso derivado para cualquier obra.',
    icon: Icons.verified_user_outlined,
    sections: [
      GlossaryCategory(
        id: 'rights_types',
        title: 'Propiedad y derechos',
        subtitle:
            'Conceptos legales transversales a todas las categorias artisticas.',
        icon: Icons.inventory_2_outlined,
        terms: const [
          GlossaryTerm('Propiedad material',
              'Posesion del soporte fisico de una obra. Comprar el objeto no implica recibir derechos de autor.'),
          GlossaryTerm('Propiedad intelectual',
              'Derechos sobre la creacion misma, independientes del soporte material.'),
          GlossaryTerm('Derechos morales',
              'Vinculo personal entre autor y obra: autoria, integridad y decision de divulgacion.'),
          GlossaryTerm('Derechos patrimoniales',
              'Derechos economicos de explotacion: reproduccion, distribucion, comunicacion publica y transformacion.'),
          GlossaryTerm('Creative Commons',
              'Familia de licencias que permite autorizar usos por adelantado mediante condiciones estandarizadas.'),
        ],
      ),
      GlossaryCategory(
        id: 'derivative_use',
        title: 'Uso derivado',
        subtitle: 'Crear a partir de obras previas, con o sin autorizacion.',
        icon: Icons.call_split_rounded,
        terms: const [
          GlossaryTerm('Obra derivada',
              'Creacion basada en una obra preexistente: adaptacion, traduccion, arreglo, remix o version.'),
          GlossaryTerm('Adaptacion',
              'Traslado de una obra a otro medio, formato o lenguaje artistico.'),
          GlossaryTerm('Remix',
              'Recombinacion de materiales existentes para crear una pieza nueva.'),
          GlossaryTerm('Fan art',
              'Obra hecha por seguidores a partir de personajes, mundos o marcas ajenas.'),
          GlossaryTerm('Parodia',
              'Imitacion critica o humoristica que transforma el sentido de la obra original.'),
        ],
      ),
    ],
  ),
];

const glossaryCategories = <GlossaryCategory>[
  // ── GÉNEROS LITERARIOS ──────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'literary_genres',
    title: 'Géneros literarios',
    subtitle: 'Las grandes familias de la narrativa y sus corrientes.',
    icon: Icons.menu_book_rounded,
    terms: [
      GlossaryTerm(
        'Fantasía',
        'Narrativa ambientada en mundos con reglas propias, donde lo imposible —magia, criaturas, mitologías inventadas— opera como realidad. Su fuerza está en la coherencia interna del mundo construido.',
      ),
      GlossaryTerm(
        'Ciencia ficción',
        'Explora futuros posibles, tecnología especulativa o realidades alternativas partiendo de premisas racionales. Pregunta "¿qué pasaría si…?" con lógica científica o social.',
      ),
      GlossaryTerm(
        'Terror',
        'Busca provocar miedo, inquietud o angustia mediante lo desconocido, lo sobrenatural o lo monstruoso —incluido el monstruo humano. El horror puede ser explícito o puramente atmosférico.',
      ),
      GlossaryTerm(
        'Romance',
        'Centra su conflicto en la relación amorosa entre personajes; la tensión emocional, sus obstáculos y su resolución estructuran la trama.',
      ),
      GlossaryTerm(
        'Drama',
        'Retrata conflictos humanos íntimos o sociales con peso emocional realista. El interés no está en la acción externa sino en la transformación interior de los personajes.',
      ),
      GlossaryTerm(
        'Thriller',
        'Construye tensión sostenida, ritmo acelerado y sensación de peligro constante. El lector avanza empujado por la urgencia: cada capítulo cierra con un motivo para seguir.',
      ),
      GlossaryTerm(
        'Misterio',
        'Gira alrededor de un enigma —un crimen, una desaparición, un secreto— que el relato desvela mediante pistas dosificadas. Invita al lector a resolver antes que el protagonista.',
      ),
      GlossaryTerm(
        'Histórico',
        'Sitúa la ficción en un periodo real del pasado, con rigor documental en ambientes, costumbres y hechos. Los personajes pueden ser reales, inventados o ambos.',
      ),
      GlossaryTerm(
        'Experimental',
        'Rompe deliberadamente convenciones de forma, estructura o lenguaje: fragmentación, collage, flujos de conciencia, tipografía expresiva. La forma es parte del significado.',
      ),
      GlossaryTerm(
        'Corriente contemporánea',
        'Escritura actual de registro cercano y directo, atenta a los temas y sensibilidades del presente. No busca imitar formas canónicas sino hablar desde su tiempo.',
      ),
      GlossaryTerm(
        'Corriente clásica',
        'Se inscribe en las formas canónicas de la tradición: estructura ordenada, lenguaje cuidado, arcos narrativos reconocibles. Dialoga con los grandes modelos de la literatura.',
      ),
      GlossaryTerm(
        'Corriente experimental',
        'Trabaja el texto como material de laboratorio: estructuras no lineales, géneros híbridos, ruptura sintáctica. Hereda la actitud de las neovanguardias.',
      ),
      GlossaryTerm(
        'Corriente vanguardista',
        'Ruptura radical con la tradición, heredera de las vanguardias del siglo XX (surrealismo, dadaísmo, creacionismo). Manifiesta una voluntad explícita de fundar un lenguaje nuevo.',
      ),
    ],
  ),

  // ── GÉNEROS MUSICALES ───────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'music_genres',
    title: 'Géneros musicales',
    subtitle: 'Los territorios sonoros principales del archivo.',
    icon: Icons.music_note_rounded,
    terms: [
      GlossaryTerm(
        'Ambient',
        'Música de texturas y atmósferas donde el paisaje sonoro importa más que la melodía o el pulso. Pensada tanto para escucha activa como para habitar el espacio.',
      ),
      GlossaryTerm(
        'Rock',
        'Género construido sobre guitarras eléctricas, bajo y batería, con energía rítmica marcada. Abarca desde la canción directa hasta formas progresivas extensas.',
      ),
      GlossaryTerm(
        'Jazz',
        'Tradición basada en la improvisación, el swing y la armonía extendida. El intérprete es co-autor: cada ejecución es una versión única de la pieza.',
      ),
      GlossaryTerm(
        'Electrónica',
        'Música producida con sintetizadores, samplers y procesos digitales o analógicos. Va del club al ambient experimental; el estudio es el instrumento.',
      ),
      GlossaryTerm(
        'Clásica',
        'Tradición académica occidental escrita en partitura, del barroco a la música contemporánea de concierto. Composición formal para intérpretes acústicos, vocales u orquestales.',
      ),
      GlossaryTerm(
        'Folk',
        'Música de raíz popular y tradición oral, generalmente acústica, centrada en la canción y la narración. Recoge o reinterpreta el cancionero de una comunidad.',
      ),
      GlossaryTerm(
        'Hip-Hop',
        'Cultura y género construidos sobre el beat, el sampleo y la palabra rimada (rap). La producción y el flow del MC son sus dos motores expresivos.',
      ),
      GlossaryTerm(
        'Experimental',
        'Música que cuestiona las convenciones de género, forma o timbre: ruido, procesos aleatorios, instrumentos inventados, duraciones extremas.',
      ),
      GlossaryTerm(
        'Pop',
        'Canción de vocación amplia y estructura memorable (verso–coro), producción pulida y melodía protagonista. Su aparente sencillez exige precisión artesanal.',
      ),
      GlossaryTerm(
        'Metal',
        'Derivación extrema del rock: guitarras distorsionadas, densidad rítmica y potencia vocal. Sus ramas van del heavy clásico al metal progresivo o atmosférico.',
      ),
    ],
  ),

  // ── SUBGÉNEROS MUSICALES ────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'music_subgenres',
    title: 'Subgéneros musicales',
    subtitle: 'Las ramificaciones finas de cada territorio sonoro.',
    icon: Icons.queue_music_rounded,
    terms: [
      GlossaryTerm(
        'Synthwave',
        'Electrónica retrofuturista inspirada en las bandas sonoras y sintetizadores de los años 80: arpegios, reverberación amplia y estética neón.',
      ),
      GlossaryTerm(
        'House',
        'Electrónica de club a ~120–130 BPM con bombo en cada tiempo (four on the floor), nacida en Chicago. Cálida, repetitiva y corporal.',
      ),
      GlossaryTerm(
        'Minimal',
        'Electrónica reducida a sus elementos esenciales: pocos sonidos, repetición hipnótica y cambios milimétricos que se perciben con la escucha sostenida.',
      ),
      GlossaryTerm(
        'Techno',
        'Electrónica de pulso mecánico e industrial nacida en Detroit. Abstracta y propulsiva, privilegia el ritmo y la textura sobre la melodía.',
      ),
      GlossaryTerm(
        'Barroco',
        'Periodo académico (~1600–1750): contrapunto, bajo continuo y ornamentación. Bach, Vivaldi y Händel son sus referencias mayores.',
      ),
      GlossaryTerm(
        'Romántico',
        'Periodo del siglo XIX que privilegia la expresión subjetiva, el virtuosismo y las grandes formas orquestales. Chopin, Brahms, Wagner.',
      ),
      GlossaryTerm(
        'Contemporáneo (académico)',
        'Música de concierto posterior a 1945: atonalidad, espectralismo, música concreta y nuevas notaciones. Explora el límite de lo que se considera música.',
      ),
      GlossaryTerm(
        'Minimalismo (musical)',
        'Corriente académica basada en la repetición de patrones con desfases graduales. Steve Reich, Philip Glass y Terry Riley la fundaron en los 60.',
      ),
      GlossaryTerm(
        'Neoclásico',
        'Hoy: piano y cuerdas de lenguaje clásico con sensibilidad ambient y producción moderna (Ólafur Arnalds, Nils Frahm). Históricamente, el retorno a formas clásicas en el siglo XX.',
      ),
      GlossaryTerm(
        'Bebop',
        'Jazz de los años 40: tempos rápidos, armonía compleja y virtuosismo improvisador. Charlie Parker y Dizzy Gillespie lo convirtieron en arte de músicos.',
      ),
      GlossaryTerm(
        'Fusion',
        'Cruce del jazz con rock, funk o músicas del mundo, con instrumentación eléctrica. Miles Davis abrió el camino con "Bitches Brew".',
      ),
      GlossaryTerm(
        'Swing',
        'Jazz de big band de los años 30–40, bailable y de fraseo elástico. También nombra la subdivisión rítmica desigual característica del jazz.',
      ),
      GlossaryTerm(
        'Free Jazz',
        'Improvisación liberada de armonía, métrica y forma predeterminadas. Ornette Coleman y Albert Ayler lo llevaron al límite expresivo.',
      ),
      GlossaryTerm(
        'Latin Jazz',
        'Jazz sobre claves y percusiones afrocaribeñas o brasileñas: son, mambo, bossa nova. El ritmo es protagonista estructural.',
      ),
      GlossaryTerm(
        'Alternative',
        'Rock surgido fuera del circuito comercial dominante, con actitud independiente y sonoridades no estandarizadas.',
      ),
      GlossaryTerm(
        'Progressive',
        'Rock o metal de composición extensa, métricas cambiantes y ambición conceptual. Los álbumes funcionan como obras integrales.',
      ),
      GlossaryTerm(
        'Heavy',
        'La forma clásica del metal: riffs contundentes, voz aguda potente y solos virtuosos. Black Sabbath, Iron Maiden, Judas Priest.',
      ),
      GlossaryTerm(
        'Post-rock',
        'Instrumentación de rock al servicio de estructuras atmosféricas y crescendos largos, generalmente sin voz. La textura reemplaza a la canción.',
      ),
      GlossaryTerm(
        'Indie',
        'Producción independiente de las grandes discográficas; por extensión, una estética de intimidad, imperfección deliberada y autonomía creativa.',
      ),
      GlossaryTerm(
        'Dark Ambient',
        'Ambient de atmósferas densas y oscuras: drones graves, resonancias industriales, espacios abandonados. Paisaje sonoro del inquietante.',
      ),
      GlossaryTerm(
        'New Age',
        'Música atmosférica orientada a la calma y la contemplación, con sintetizadores suaves e instrumentos acústicos etéreos.',
      ),
      GlossaryTerm(
        'Drone',
        'Composición sostenida sobre notas o acordes prolongados que evolucionan lentamente. La escucha se vuelve estado, no relato.',
      ),
      GlossaryTerm(
        'Field Recordings',
        'Grabaciones de campo: sonido ambiente del mundo real (ciudades, bosques, máquinas) usado como material compositivo o pieza en sí.',
      ),
      GlossaryTerm(
        'Ethereal',
        'Estética vaporosa de reverberaciones amplias, voces difuminadas y armonías suspendidas, heredera del dream pop y el 4AD de los 80.',
      ),
      GlossaryTerm(
        'Noise',
        'El ruido como material musical: saturación, feedback y masas sonoras extremas. Cuestiona la frontera entre sonido organizado y caos.',
      ),
      GlossaryTerm(
        'Glitch',
        'Estética del error digital: clics, cortes, artefactos de compresión convertidos en ritmo y textura.',
      ),
      GlossaryTerm(
        'Acusmática',
        'Música compuesta para altavoces sin intérprete visible, heredera de la música concreta. El oyente escucha sin ver la fuente del sonido.',
      ),
      GlossaryTerm(
        'Electroacústica',
        'Combina fuentes acústicas grabadas o en vivo con procesamiento electrónico. Tradición académica del sonido manipulado.',
      ),
    ],
  ),

  // ── ESTILOS VISUALES ────────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'visual_styles',
    title: 'Estilos visuales',
    subtitle: 'Maneras de mirar y construir la imagen.',
    icon: Icons.palette_outlined,
    terms: [
      GlossaryTerm(
        'Realismo',
        'Representación fiel de lo visible: proporción, luz y materia tratadas como las percibe el ojo. Su reto es la precisión sin frialdad.',
      ),
      GlossaryTerm(
        'Impresionismo',
        'Captura la impresión luminosa del instante con pincelada suelta y color vibrante, sacrificando el detalle por la atmósfera.',
      ),
      GlossaryTerm(
        'Abstracto',
        'Renuncia a representar el mundo visible: color, forma, gesto y composición son el contenido mismo de la obra.',
      ),
      GlossaryTerm(
        'Surrealismo',
        'Imágenes del sueño y el inconsciente: yuxtaposiciones imposibles pintadas con precisión realista. Lo irracional presentado como evidencia.',
      ),
      GlossaryTerm(
        'Expresionismo',
        'Deforma color y figura para transmitir emoción interior antes que apariencia externa. La angustia, el vértigo o el éxtasis dictan la forma.',
      ),
      GlossaryTerm(
        'Contemporáneo',
        'Producción actual sin adscripción a un estilo histórico: híbrida, consciente de la tradición y en diálogo con el presente.',
      ),
      GlossaryTerm(
        'Figurativo',
        'Mantiene la figura reconocible —cuerpo, objeto, paisaje— sin obligarse al realismo estricto. El referente permanece visible.',
      ),
      GlossaryTerm(
        'Minimalismo',
        'Reducción a lo esencial: formas geométricas, superficies limpias, color contenido. Lo que se quita importa tanto como lo que queda.',
      ),
      GlossaryTerm(
        'Pixel art',
        'Imagen digital construida píxel a píxel con paletas limitadas, heredera del videojuego clásico. La restricción técnica es el lenguaje.',
      ),
      GlossaryTerm(
        'Render 3D',
        'Imagen generada por modelado, texturizado e iluminación en software tridimensional, desde el fotorrealismo hasta la estilización.',
      ),
      GlossaryTerm(
        'Vectorial',
        'Gráficos definidos por curvas matemáticas, escalables sin pérdida: líneas limpias, planos de color, precisión geométrica.',
      ),
      GlossaryTerm(
        'Concept art',
        'Diseño visual para mundos de ficción —personajes, criaturas, escenarios— destinado a cine, videojuegos o animación. Explora antes de que exista la obra final.',
      ),
      GlossaryTerm(
        'Motion',
        'Diseño en movimiento: animación de gráficos, tipografía y composiciones para pantalla. El tiempo es parte de la composición.',
      ),
      GlossaryTerm(
        'UI/UX',
        'Diseño de interfaces y experiencias digitales: jerarquía visual, interacción y usabilidad como disciplinas estéticas.',
      ),
      GlossaryTerm(
        'Character design',
        'Creación de personajes con identidad visual coherente: silueta, proporción, paleta y expresividad al servicio de una personalidad.',
      ),
    ],
  ),

  // ── MOVIMIENTOS ARTÍSTICOS ──────────────────────────────────────────────────
  GlossaryCategory(
    id: 'art_movements',
    title: 'Movimientos artísticos',
    subtitle: 'Las corrientes que marcaron la historia del arte.',
    icon: Icons.museum_outlined,
    terms: [
      GlossaryTerm(
        'Renacimiento',
        'Siglos XV–XVI: redescubrimiento de la antigüedad clásica, perspectiva matemática y humanismo. Leonardo, Miguel Ángel y Rafael definieron el canon occidental.',
      ),
      GlossaryTerm(
        'Barroco',
        'Siglos XVII–XVIII: teatralidad, claroscuro dramático y movimiento. Caravaggio, Rubens y Velázquez pintaron la emoción como espectáculo.',
      ),
      GlossaryTerm(
        'Neoclasicismo',
        'Finales del XVIII: retorno al orden y la línea clásica como reacción al exceso barroco. David y Canova, arte de la razón ilustrada.',
      ),
      GlossaryTerm(
        'Romanticismo',
        'Primera mitad del XIX: la emoción, lo sublime y la naturaleza indomable frente a la razón. Friedrich, Turner, Delacroix.',
      ),
      GlossaryTerm(
        'Realismo (movimiento)',
        'Mediados del XIX: pintar la vida común sin idealizarla —campesinos, obreros, calles. Courbet lo convirtió en postura política.',
      ),
      GlossaryTerm(
        'Impresionismo (movimiento)',
        '1870–1890: pintura al aire libre, luz cambiante y pincelada visible. Monet, Renoir y Pissarro rompieron con el salón académico.',
      ),
      GlossaryTerm(
        'Postimpresionismo',
        'Finales del XIX: cada autor lleva el color y la forma a un lenguaje propio. Van Gogh (emoción), Cézanne (estructura), Gauguin (símbolo).',
      ),
      GlossaryTerm(
        'Simbolismo',
        'Finales del XIX: la imagen como símbolo del mundo interior —sueño, mito, misterio— contra el materialismo realista. Moreau, Redon, Klimt.',
      ),
      GlossaryTerm(
        'Art Nouveau / Modernismo',
        '1890–1910: línea orgánica, ornamento vegetal y unión de arte y diseño en arquitectura, cartel y objeto. Gaudí, Mucha, Horta.',
      ),
      GlossaryTerm(
        'Fauvismo',
        '~1905: color puro y arbitrario, liberado de la descripción. Matisse y Derain, "las fieras" del color.',
      ),
      GlossaryTerm(
        'Expresionismo (movimiento)',
        'Inicios del XX, ámbito germánico: angustia y crítica social en color violento y figura deformada. Kirchner, Munch como precursor.',
      ),
      GlossaryTerm(
        'Cubismo',
        '1907–1920: el objeto descompuesto en planos simultáneos, visto desde varios ángulos a la vez. Picasso y Braque reinventaron la representación.',
      ),
      GlossaryTerm(
        'Futurismo',
        'Italia, 1909: culto a la máquina, la velocidad y la ciudad moderna. Boccioni y Balla pintaron el movimiento mismo.',
      ),
      GlossaryTerm(
        'Dadaísmo',
        '1916: anti-arte nacido del absurdo de la guerra —azar, collage, provocación. Duchamp expuso un urinario y cambió la pregunta del arte.',
      ),
      GlossaryTerm(
        'Surrealismo (movimiento)',
        'Desde 1924: automatismo, sueño e inconsciente como método, bajo el manifiesto de Breton. Dalí, Magritte, Ernst, Varo.',
      ),
      GlossaryTerm(
        'Expresionismo abstracto',
        'Nueva York, años 40–50: gesto monumental y campo de color. Pollock goteando, Rothko flotando; la pintura como acción o presencia.',
      ),
      GlossaryTerm(
        'Pop Art',
        'Años 50–60: iconografía del consumo y los medios —publicidad, cómic, celebridad— elevada a arte. Warhol, Lichtenstein, Hamilton.',
      ),
      GlossaryTerm(
        'Minimalismo (movimiento)',
        'Años 60: objetos literales, geometría industrial, ausencia de gesto. Judd, Flavin y Andre; "lo que ves es lo que ves".',
      ),
      GlossaryTerm(
        'Arte conceptual',
        'Desde los 60: la idea vale más que el objeto; la obra puede ser una instrucción, un documento o un acto. Kosuth, LeWitt, Weiner.',
      ),
      GlossaryTerm(
        'Arte urbano',
        'Del grafiti al muralismo contemporáneo: intervención del espacio público, a menudo anónima o ilegal en origen. Basquiat, Banksy, Os Gêmeos.',
      ),
      GlossaryTerm(
        'Arte contemporáneo',
        'Producción desde ~1970: instalación, performance, video, arte digital y prácticas híbridas. Se define menos por estilo que por contexto y discurso.',
      ),
    ],
  ),

  // ── TIPOS DE RITMO ──────────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'rhythm_types',
    title: 'Tipos de ritmo',
    subtitle: 'El pulso del sonido y del verso.',
    icon: Icons.graphic_eq_rounded,
    terms: [
      GlossaryTerm(
        'Pulso',
        'La unidad regular de tiempo que subyace a la música: el "latido" sobre el que se organizan los demás valores rítmicos.',
      ),
      GlossaryTerm(
        'Tempo',
        'La velocidad del pulso, medida en BPM (pulsos por minuto) o indicada con términos como adagio, andante, allegro.',
      ),
      GlossaryTerm(
        'Compás binario',
        'Agrupación del pulso en dos tiempos (2/4, 2/2): marcha, fuerte–débil. La base de marchas y buena parte del pop.',
        example: 'UN-dos · UN-dos',
      ),
      GlossaryTerm(
        'Compás ternario',
        'Agrupación en tres tiempos (3/4, 3/8): el vals es su forma emblemática. Fuerte–débil–débil.',
        example: 'UN-dos-tres · UN-dos-tres',
      ),
      GlossaryTerm(
        'Compás compuesto',
        'Cada tiempo se subdivide en tres (6/8, 9/8, 12/8). Produce el balanceo característico de la giga, el blues lento o la tarantela.',
      ),
      GlossaryTerm(
        'Amalgama',
        'Compases de agrupación irregular (5/4, 7/8) que combinan grupos de dos y tres. Frecuentes en el progresivo, el folclore balcánico y el jazz moderno.',
      ),
      GlossaryTerm(
        'Síncopa',
        'Acento desplazado al tiempo débil que se prolonga sobre el fuerte, rompiendo la expectativa. Motor rítmico del jazz, el funk y las músicas latinas.',
      ),
      GlossaryTerm(
        'Contratiempo',
        'Ataques que suenan solo en las partes débiles, callando en las fuertes. Da el "skank" del reggae o el ritmo de habanera.',
      ),
      GlossaryTerm(
        'Polirritmia',
        'Superposición simultánea de ritmos distintos (tres contra dos, cuatro contra tres). Central en las músicas africanas y en la percusión afrocubana.',
      ),
      GlossaryTerm(
        'Ostinato',
        'Patrón rítmico o melódico repetido con obstinación mientras el resto evoluciona. Del basso continuo barroco al riff y al loop electrónico.',
      ),
      GlossaryTerm(
        'Rubato',
        'Flexibilización expresiva del tempo: robar tiempo a unas notas para dárselo a otras. Esencial en el romanticismo pianístico.',
      ),
      GlossaryTerm(
        'Groove',
        'La sensación de fluidez corporal que produce una sección rítmica trabada: micro-desplazamientos que hacen que la música "camine".',
      ),
      GlossaryTerm(
        'Swing (subdivisión)',
        'Subdivisión desigual del pulso (larga–corta) característica del jazz: las corcheas escritas iguales se tocan flotando.',
      ),
      GlossaryTerm(
        'Ritmo métrico (poesía)',
        'Ritmo del verso regulado por el conteo de sílabas y la posición de acentos: endecasílabos, octosílabos, alejandrinos.',
        example: 'Un endecasílabo: "Ande yo caliente y ríase la gente".',
      ),
      GlossaryTerm(
        'Verso libre',
        'Verso sin métrica ni rima fijas; el ritmo surge de la respiración de la frase, las pausas y las imágenes.',
      ),
      GlossaryTerm(
        'Cadencia',
        'En música, la fórmula que cierra una frase o sección; en poesía y prosa, la curva rítmica con que cae el final de un periodo.',
      ),
    ],
  ),

  // ── TIPOS DE NARRADOR ───────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'narrator_types',
    title: 'Tipos de narrador',
    subtitle: 'Quién cuenta la historia y desde dónde.',
    icon: Icons.record_voice_over_outlined,
    terms: [
      GlossaryTerm(
        'Narrador protagonista',
        'Primera persona: el personaje central cuenta su propia historia. Máxima intimidad, visión limitada a lo que él sabe y quiere contar.',
        example: '"Aquella mañana decidí no volver nunca."',
      ),
      GlossaryTerm(
        'Narrador testigo',
        'Primera persona periférica: un personaje secundario narra lo que observa del verdadero protagonista. El doctor Watson ante Sherlock Holmes.',
        example: '"Lo vi cruzar la plaza como quien va a morir."',
      ),
      GlossaryTerm(
        'Narrador en segunda persona',
        'Narra en "tú", convirtiendo al lector —o al propio personaje desdoblado— en protagonista. Raro y de gran intensidad. "Aura" de Carlos Fuentes.',
        example: '"Entras al cuarto y sabes que ya es tarde."',
      ),
      GlossaryTerm(
        'Narrador omnisciente',
        'Tercera persona que lo sabe todo: pensamientos de todos los personajes, pasado y futuro, juicios incluidos. La voz clásica de la novela del XIX.',
      ),
      GlossaryTerm(
        'Narrador equisciente',
        'Tercera persona limitada: acompaña a un solo personaje y sabe únicamente lo que él sabe. Combina cercanía emocional con distancia gramatical.',
      ),
      GlossaryTerm(
        'Narrador deficiente (objetivo)',
        'Tercera persona conductista: registra solo lo visible y audible, como una cámara, sin acceso a ningún pensamiento. Hemingway lo llevó al extremo.',
      ),
      GlossaryTerm(
        'Narrador no confiable',
        'Su versión de los hechos es dudosa —por ceguera, interés o locura— y el lector debe leer entre líneas. El mayordomo de "Lo que queda del día".',
      ),
      GlossaryTerm(
        'Narrador coral (múltiple)',
        'La historia se cuenta desde varias voces alternadas que se complementan o contradicen. "Mientras agonizo" de Faulkner, "La casa de los espíritus".',
      ),
      GlossaryTerm(
        'Metanarrador',
        'Narrador consciente de estar narrando, que interpela al lector o exhibe el artificio del relato. Del "Quijote" a la autoficción contemporánea.',
      ),
    ],
  ),

  // ── TIEMPOS VERBALES NARRATIVOS ─────────────────────────────────────────────
  GlossaryCategory(
    id: 'verb_tenses',
    title: 'Tiempos verbales narrativos',
    subtitle: 'El tiempo gramatical como decisión estética.',
    icon: Icons.history_edu_rounded,
    terms: [
      GlossaryTerm(
        'Presente narrativo',
        'Narra en presente lo que ocurre: inmediatez, urgencia, efecto de cámara en mano. Frecuente en el thriller y la narrativa contemporánea.',
        example: '"Abre la puerta. La casa está vacía."',
      ),
      GlossaryTerm(
        'Pretérito perfecto simple',
        'El tiempo narrativo por excelencia: acciones concluidas que hacen avanzar la trama. La columna vertebral del relato en pasado.',
        example: '"Llegó, miró alrededor y cerró la puerta."',
      ),
      GlossaryTerm(
        'Pretérito imperfecto',
        'Pasado sin límites definidos: describe ambientes, costumbres y acciones en curso. Es el tiempo del telón de fondo.',
        example: '"Llovía y las calles olían a tierra."',
      ),
      GlossaryTerm(
        'Pretérito pluscuamperfecto',
        'El pasado del pasado: lo ocurrido antes del momento que se narra. Herramienta natural del flashback breve.',
        example: '"Cuando llegué, ella ya se había ido."',
      ),
      GlossaryTerm(
        'Pretérito perfecto compuesto',
        'Pasado conectado con el presente del hablante. En narrativa aparece sobre todo en diálogo y en primera persona reciente.',
        example: '"He visto cosas que no sabría nombrar."',
      ),
      GlossaryTerm(
        'Futuro simple',
        'Anticipa lo que vendrá; en narración, crea profecía o fatalidad. También expresa conjetura ("serán las diez").',
        example: '"Muchos años después, frente al pelotón de fusilamiento…"',
      ),
      GlossaryTerm(
        'Condicional narrativo',
        'El futuro visto desde el pasado: lo que habría de ocurrir. Tiñe el relato de destino ya cumplido.',
        example: '"Aquella carta cambiaría su vida."',
      ),
      GlossaryTerm(
        'Analepsis (flashback)',
        'Salto temporal hacia atrás para narrar hechos anteriores al punto donde va la historia. Se marca con pluscuamperfecto o por corte de escena.',
      ),
      GlossaryTerm(
        'Prolepsis (flashforward)',
        'Anticipación de hechos futuros antes de que la historia llegue a ellos. García Márquez abrió "Cien años de soledad" con una.',
      ),
    ],
  ),

  // ── TIPOS DE PROPIEDAD ──────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'property_types',
    title: 'Tipos de propiedad',
    subtitle: 'Qué se posee cuando se posee una obra.',
    icon: Icons.inventory_2_outlined,
    terms: [
      GlossaryTerm(
        'Propiedad material',
        'La posesión del soporte físico: el lienzo, la escultura, la copia impresa. Comprar el objeto no transfiere los derechos de autor sobre la obra.',
      ),
      GlossaryTerm(
        'Propiedad intelectual',
        'El conjunto de derechos sobre la creación misma, independiente del soporte. Nace automáticamente con la creación; no requiere registro, aunque registrar ayuda a probar autoría.',
      ),
      GlossaryTerm(
        'Copropiedad',
        'Titularidad compartida entre varios autores de una obra en colaboración. Las decisiones de explotación requieren acuerdo entre los cotitulares.',
      ),
      GlossaryTerm(
        'Propiedad fraccionada',
        'División de la propiedad de una pieza en participaciones (frecuente en coleccionismo contemporáneo y tokenización). Cada titular posee un porcentaje del objeto, no de los derechos de autor.',
      ),
      GlossaryTerm(
        'Obra por encargo',
        'Creada bajo contrato para un cliente. Quién conserva qué derechos depende del contrato: por defecto, en la mayoría de legislaciones el autor conserva los derechos salvo cesión expresa.',
      ),
      GlossaryTerm(
        'Dominio público',
        'Estado de las obras cuyos derechos patrimoniales expiraron (en general, 70–100 años tras la muerte del autor) o que nunca los tuvieron. Cualquiera puede usarlas, incluso comercialmente; los derechos morales de atribución suelen persistir.',
      ),
      GlossaryTerm(
        'Obra huérfana',
        'Obra protegida cuyo titular no puede ser identificado o localizado. Su uso está restringido y regulado de forma especial en varias legislaciones.',
      ),
    ],
  ),

  // ── TIPOS DE DERECHOS ───────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'rights_types',
    title: 'Tipos de derechos',
    subtitle: 'Lo que la ley reconoce al creador.',
    icon: Icons.verified_user_outlined,
    terms: [
      GlossaryTerm(
        'Derechos morales',
        'Vínculo personal e irrenunciable entre autor y obra: paternidad, integridad, divulgación. En la tradición continental no se pueden vender ni ceder.',
      ),
      GlossaryTerm(
        'Derecho de paternidad',
        'Derecho a ser reconocido como autor de la obra —o a publicarla bajo seudónimo o anónimo. Persiste aunque se cedan los derechos económicos.',
      ),
      GlossaryTerm(
        'Derecho de integridad',
        'Facultad de oponerse a deformaciones o mutilaciones de la obra que dañen su sentido o la reputación del autor.',
      ),
      GlossaryTerm(
        'Derecho de divulgación',
        'Decidir si la obra se hace pública, cuándo y cómo. Publicar en Corvus es un acto de divulgación.',
      ),
      GlossaryTerm(
        'Derechos patrimoniales',
        'Los derechos económicos de explotación: reproducción, distribución, comunicación pública y transformación. Son cedibles, licenciables y tienen plazo de expiración.',
      ),
      GlossaryTerm(
        'Derecho de reproducción',
        'Autorizar o prohibir copias de la obra en cualquier medio: impresión, fotografía, digitalización, descarga.',
      ),
      GlossaryTerm(
        'Derecho de distribución',
        'Controlar la puesta en circulación de ejemplares físicos: venta, alquiler, préstamo.',
      ),
      GlossaryTerm(
        'Derecho de comunicación pública',
        'Autorizar que la obra se haga accesible al público sin entrega de ejemplares: exposición, streaming, publicación en línea.',
      ),
      GlossaryTerm(
        'Derecho de transformación',
        'Autorizar adaptaciones, traducciones, arreglos o cualquier obra derivada. Sin esta autorización, el uso derivado infringe.',
      ),
      GlossaryTerm(
        'Copyright',
        'El sistema angloamericano de derechos de autor, centrado en el derecho económico de copia. El símbolo © indica reserva de derechos ("todos los derechos reservados").',
      ),
      GlossaryTerm(
        'Copyleft',
        'Estrategia que usa el copyright para garantizar libertades: permite copiar y transformar a condición de que las obras derivadas mantengan la misma licencia libre.',
      ),
      GlossaryTerm(
        'Licencias Creative Commons',
        'Familia de licencias estandarizadas con las que el autor autoriza usos por adelantado, combinando cuatro módulos: BY, SA, NC y ND. "Algunos derechos reservados".',
      ),
      GlossaryTerm(
        'CC BY (Atribución)',
        'Permite cualquier uso, incluso comercial, con la única condición de acreditar al autor.',
      ),
      GlossaryTerm(
        'CC SA (CompartirIgual)',
        'Las obras derivadas deben distribuirse bajo la misma licencia que el original. Es el módulo copyleft de Creative Commons.',
      ),
      GlossaryTerm(
        'CC NC (NoComercial)',
        'Autoriza el uso solo con fines no comerciales; cualquier explotación económica requiere permiso adicional del autor.',
      ),
      GlossaryTerm(
        'CC ND (SinDerivadas)',
        'Permite copiar y compartir la obra íntegra, pero no transformarla ni crear obras derivadas.',
      ),
      GlossaryTerm(
        'Droit de suite (derecho de participación)',
        'Derecho del artista plástico a recibir un porcentaje del precio en las reventas de su obra en el mercado del arte. Reconocido en la UE y otros países.',
      ),
      GlossaryTerm(
        'Derechos conexos',
        'Derechos de quienes no son el autor pero aportan a la obra: intérpretes, productores fonográficos, entidades de radiodifusión.',
      ),
    ],
  ),

  // ── USO DERIVADO ────────────────────────────────────────────────────────────
  GlossaryCategory(
    id: 'derivative_use',
    title: 'Uso derivado',
    subtitle: 'Crear a partir de lo que otros crearon.',
    icon: Icons.call_split_rounded,
    terms: [
      GlossaryTerm(
        'Obra derivada',
        'Toda creación basada en una obra preexistente: adaptación, traducción, arreglo, remix. Requiere autorización del titular del derecho de transformación, salvo dominio público o licencia que lo permita.',
      ),
      GlossaryTerm(
        'Adaptación',
        'Trasladar una obra a otro medio o formato: novela a película, cómic a serie, poema a canción. La obra resultante tiene su propio autor, sobre la base autorizada.',
      ),
      GlossaryTerm(
        'Traducción',
        'Versión de una obra en otro idioma. Es obra derivada protegida: el traductor tiene derechos sobre su traducción, y necesita permiso del autor original si la obra no es libre.',
      ),
      GlossaryTerm(
        'Remix',
        'Recombinación de material existente —audio, imagen, texto— en una obra nueva. Su legalidad depende de permisos, licencias o de que el material sea libre.',
      ),
      GlossaryTerm(
        'Cover / Versión',
        'Nueva interpretación de una canción ajena. En muchos países funciona con licencias obligatorias o gestionadas colectivamente; el compositor original siempre conserva el crédito.',
      ),
      GlossaryTerm(
        'Sampleo',
        'Incorporar fragmentos de grabaciones ajenas en una pieza propia. Involucra dos permisos: el de la composición y el de la grabación (máster).',
      ),
      GlossaryTerm(
        'Fan art',
        'Obra creada por seguidores a partir de personajes o mundos ajenos. Técnicamente derivada y no autorizada, suele tolerarse si no hay lucro, pero el titular puede reclamarla.',
      ),
      GlossaryTerm(
        'Apropiacionismo',
        'Corriente artística que toma imágenes existentes y las resignifica (Duchamp, Warhol, Sherrie Levine). Habita deliberadamente la frontera legal y conceptual de la autoría.',
      ),
      GlossaryTerm(
        'Parodia',
        'Imitación humorística o crítica de una obra. Muchas legislaciones la eximen de autorización como límite al derecho de autor, si no genera confusión ni daño desproporcionado.',
      ),
      GlossaryTerm(
        'Cita',
        'Reproducción de fragmentos ajenos con fines de análisis, crítica o docencia, con fuente y autor indicados. Es lícita en la medida que justifique el fin.',
      ),
      GlossaryTerm(
        'Uso legítimo (fair use)',
        'Doctrina angloamericana que permite usos no autorizados según propósito, naturaleza, proporción y efecto en el mercado. No existe como tal en la mayoría de sistemas continentales, que usan límites tasados.',
      ),
      GlossaryTerm(
        'Transformación sustancial',
        'Grado de modificación que convierte el material ajeno en expresión nueva con significado propio. Es el criterio central en disputas sobre apropiación y fair use.',
      ),
    ],
  ),
];

List<GlossaryArtisticCategory> get expandedGlossaryArtisticCategories {
  return [
    for (final category in glossaryArtisticCategories)
      GlossaryArtisticCategory(
        id: category.id,
        title: category.title,
        subtitle: category.subtitle,
        icon: category.icon,
        sections: _dedupeSections([
          ...category.sections,
          ..._extraSectionsFor(category.id),
          ..._legacySectionsFor(category.id),
        ]),
      ),
  ];
}

List<GlossaryCategory> _dedupeSections(List<GlossaryCategory> sections) {
  final seen = <String>{};
  final result = <GlossaryCategory>[];
  for (final section in sections) {
    if (seen.add(section.id)) result.add(section);
  }
  return result;
}

GlossaryCategory _legacySection(String id, {String? title}) {
  final source = glossaryCategories.firstWhere(
    (section) => section.id == id,
    orElse: () => GlossaryCategory(
      id: 'missing_$id',
      title: id,
      subtitle: '',
      icon: Icons.library_books_outlined,
      terms: const [],
    ),
  );
  return GlossaryCategory(
    id: 'legacy_${source.id}',
    title: title ?? source.title,
    subtitle: source.subtitle,
    icon: source.icon,
    terms: source.terms,
  );
}

List<GlossaryCategory> _legacySectionsFor(String categoryId) {
  return switch (categoryId) {
    'writing' => [
        _legacySection('literary_genres', title: 'Biblioteca literaria'),
        _legacySection('narrator_types'),
        _legacySection('verb_tenses'),
      ],
    'visual' => [
        _legacySection('visual_styles'),
        _legacySection('art_movements'),
      ],
    'music' => [
        _legacySection('music_genres', title: 'Biblioteca musical'),
        _legacySection('music_subgenres'),
        _legacySection('rhythm_types'),
      ],
    'rights' => [
        _legacySection('property_types'),
        _legacySection('rights_types'),
        _legacySection('derivative_use'),
      ],
    _ => const [],
  };
}

List<GlossaryCategory> _extraSectionsFor(String categoryId) {
  return switch (categoryId) {
    'writing' => const [
        GlossaryCategory(
          id: 'writing_structure',
          title: 'Estructura literaria',
          subtitle: 'Arquitectura interna para construir obras narrativas.',
          icon: Icons.account_tree_outlined,
          terms: [
            GlossaryTerm('Premisa',
                'Idea nuclear de una obra: personaje, conflicto, mundo y promesa dramatica comprimidos.'),
            GlossaryTerm('Logline',
                'Descripcion de una frase que comunica protagonista, objetivo, obstaculo y tono.'),
            GlossaryTerm('Sinopsis',
                'Resumen funcional del arco principal, con conflicto, desarrollo y resolucion.'),
            GlossaryTerm('Escaleta',
                'Mapa de escenas o capitulos ordenados antes de escribir el texto completo.'),
            GlossaryTerm('Arco de personaje',
                'Transformacion emocional, moral o ideologica de un personaje durante la obra.'),
            GlossaryTerm('Subtrama',
                'Linea narrativa secundaria que refuerza tema, contraste o tension del arco principal.'),
            GlossaryTerm('Climax',
                'Punto de maxima tension donde el conflicto central exige una decision irreversible.'),
            GlossaryTerm('Resolucion',
                'Consecuencia posterior al climax; muestra el nuevo estado del mundo o personaje.'),
          ],
        ),
      ],
    'video' => const [
        GlossaryCategory(
          id: 'video_language',
          title: 'Lenguaje audiovisual',
          subtitle: 'Recursos de camara, montaje, plano, sonido y puesta.',
          icon: Icons.videocam_outlined,
          terms: [
            GlossaryTerm('Plano general',
                'Encuadre amplio que ubica personajes, escala y geografia de la escena.'),
            GlossaryTerm('Primer plano',
                'Encuadre cerrado sobre rostro o detalle para concentrar informacion emocional.'),
            GlossaryTerm('Plano secuencia',
                'Toma continua sin cortes aparentes; sostiene tiempo, coreografia y tension espacial.'),
            GlossaryTerm('Montaje paralelo',
                'Alternancia entre acciones simultaneas para generar comparacion, ritmo o suspense.'),
            GlossaryTerm('Raccord',
                'Continuidad visual, espacial o de accion entre planos consecutivos.'),
            GlossaryTerm('Diegetico',
                'Sonido o musica que pertenece al mundo de la escena y puede ser percibido por personajes.'),
            GlossaryTerm('No diegetico',
                'Musica, narracion o sonido externo al mundo de la escena.'),
            GlossaryTerm('Color grading',
                'Tratamiento de color final que define contraste, temperatura, atmosfera y continuidad visual.'),
          ],
        ),
        GlossaryCategory(
          id: 'video_pipeline',
          title: 'Produccion audiovisual',
          subtitle:
              'Etapas y documentos para llevar una pieza a rodaje o edicion.',
          icon: Icons.movie_filter_outlined,
          terms: [
            GlossaryTerm('Tratamiento',
                'Documento narrativo previo al guion que expone tono, estructura y escenas principales.'),
            GlossaryTerm('Storyboard',
                'Secuencia visual de planos que anticipa composicion, accion y continuidad.'),
            GlossaryTerm('Shot list',
                'Lista tecnica de planos necesarios para cubrir una escena.'),
            GlossaryTerm('Call sheet',
                'Orden de rodaje diaria con horarios, locaciones, equipo y necesidades.'),
            GlossaryTerm('Animatic',
                'Storyboard editado con tiempo, sonido o dialogo provisional.'),
          ],
        ),
      ],
    'comic' => const [
        GlossaryCategory(
          id: 'comic_page_language',
          title: 'Pagina y narrativa secuencial',
          subtitle: 'Elementos propios de la lectura por viñetas.',
          icon: Icons.view_quilt_outlined,
          terms: [
            GlossaryTerm('Viñeta',
                'Unidad visual de accion dentro de la pagina o lectura vertical.'),
            GlossaryTerm('Gutter',
                'Espacio entre viñetas donde el lector completa saltos de tiempo o accion.'),
            GlossaryTerm('Splash page',
                'Pagina completa ocupada por una sola imagen de alto impacto.'),
            GlossaryTerm('Doble pagina',
                'Composicion que usa dos paginas enfrentadas como una sola unidad visual.'),
            GlossaryTerm('Bocadillo',
                'Contenedor grafico del dialogo o pensamiento de un personaje.'),
            GlossaryTerm('Rotulacion',
                'Diseño e integracion de texto, globos, efectos y jerarquia de lectura.'),
            GlossaryTerm('Entintado',
                'Fase que define linea final, contraste, volumen y claridad sobre el boceto.'),
          ],
        ),
      ],
    'photo' => const [
        GlossaryCategory(
          id: 'photo_technique',
          title: 'Tecnica fotografica',
          subtitle:
              'Parametros que controlan luz, nitidez, movimiento y archivo.',
          icon: Icons.camera_outdoor_outlined,
          terms: [
            GlossaryTerm('Apertura',
                'Abertura del diafragma; controla entrada de luz y profundidad de campo.'),
            GlossaryTerm('ISO',
                'Sensibilidad del sensor o pelicula; afecta exposicion y ruido.'),
            GlossaryTerm('Velocidad de obturacion',
                'Tiempo durante el cual entra luz; congela o arrastra movimiento.'),
            GlossaryTerm('Profundidad de campo',
                'Zona de nitidez aceptable delante y detras del punto enfocado.'),
            GlossaryTerm('Balance de blancos',
                'Ajuste de temperatura de color para neutralizar o estilizar la luz.'),
            GlossaryTerm('RAW',
                'Archivo con informacion amplia de sensor para edicion flexible.'),
            GlossaryTerm('Clave alta',
                'Iluminacion luminosa, baja sombra y predominio de tonos claros.'),
            GlossaryTerm('Clave baja',
                'Iluminacion contrastada con sombras dominantes y atmosfera dramatica.'),
          ],
        ),
      ],
    'fashion' => const [
        GlossaryCategory(
          id: 'fashion_production',
          title: 'Produccion de moda',
          subtitle: 'De la idea al patron, muestra, drop y lookbook.',
          icon: Icons.design_services_outlined,
          terms: [
            GlossaryTerm('Moodboard',
                'Tablero de referencias que fija atmosfera, silueta, color, textura y direccion.'),
            GlossaryTerm('Patron',
                'Molde tecnico de una prenda, base para corte y confeccion.'),
            GlossaryTerm('Toile',
                'Muestra de prueba en tela economica para validar patron y volumen.'),
            GlossaryTerm('Fitting',
                'Prueba sobre cuerpo o maniqui para ajustar caida, talla y proporcion.'),
            GlossaryTerm('Ficha tecnica',
                'Documento con medidas, materiales, construccion, avios y especificaciones.'),
            GlossaryTerm('Line sheet',
                'Documento comercial con prendas, codigos, precios, colores y tallas.'),
            GlossaryTerm('Drop',
                'Lanzamiento limitado o calendarizado de piezas seleccionadas.'),
          ],
        ),
      ],
    'game' => const [
        GlossaryCategory(
          id: 'game_design_terms',
          title: 'Diseño de sistemas',
          subtitle:
              'Conceptos para construir experiencia, progresion y balance.',
          icon: Icons.memory_outlined,
          terms: [
            GlossaryTerm('Core loop',
                'Ciclo principal de accion, feedback y recompensa que sostiene el juego.'),
            GlossaryTerm('Meta loop',
                'Capa de progreso a largo plazo que da continuidad entre sesiones.'),
            GlossaryTerm('Economia',
                'Sistema de recursos, costos, recompensas, escasez y conversiones.'),
            GlossaryTerm('Balance',
                'Ajuste de dificultad, poder, ritmo y recompensas para sostener tension justa.'),
            GlossaryTerm('Onboarding',
                'Primera experiencia que enseña reglas sin detener el flujo de juego.'),
            GlossaryTerm('Hitbox',
                'Zona invisible que determina colisiones, impacto o deteccion.'),
            GlossaryTerm('Juice',
                'Conjunto de feedback visual, sonoro y tactil que hace satisfactoria una accion.'),
          ],
        ),
      ],
    'stage' => const [
        GlossaryCategory(
          id: 'stage_production',
          title: 'Puesta en escena',
          subtitle: 'Componentes vivos de teatro, danza y performance.',
          icon: Icons.lightbulb_outline_rounded,
          terms: [
            GlossaryTerm('Mise-en-scene',
                'Organizacion de cuerpos, objetos, luz, espacio y ritmo frente al publico.'),
            GlossaryTerm('Blocking',
                'Marcaje de posiciones y desplazamientos de interpretes en escena.'),
            GlossaryTerm('Cue',
                'Señal para activar luz, sonido, entrada, movimiento o cambio tecnico.'),
            GlossaryTerm('Blackout',
                'Apagon total usado como transicion, corte o golpe dramatico.'),
            GlossaryTerm('Dramaturgia',
                'Estructura de sentido que organiza accion, texto, cuerpo, tiempo y conflicto.'),
            GlossaryTerm('Partitura corporal',
                'Secuencia precisa de gestos, acciones o movimientos repetibles.'),
            GlossaryTerm('Cuarta pared',
                'Convencion que separa al publico del mundo escenico representado.'),
          ],
        ),
      ],
    'world' => const [
        GlossaryCategory(
          id: 'world_canon',
          title: 'Canon y continuidad',
          subtitle:
              'Control interno de versiones, reglas, historia y consistencia.',
          icon: Icons.schema_outlined,
          terms: [
            GlossaryTerm('Canon',
                'Conjunto de hechos oficialmente validos dentro de un universo.'),
            GlossaryTerm('Continuidad',
                'Coherencia entre eventos, edades, lugares, reglas y consecuencias.'),
            GlossaryTerm('Retcon',
                'Cambio retroactivo que modifica interpretacion o hechos previos del canon.'),
            GlossaryTerm('Linea temporal',
                'Orden interno de eventos, eras y consecuencias historicas.'),
            GlossaryTerm('Biblia de mundo',
                'Documento rector con reglas, tono, geografia, personajes, sistemas y canon.'),
            GlossaryTerm('Sistema social',
                'Estructura de clases, instituciones, costumbres y conflictos colectivos.'),
            GlossaryTerm('Cosmologia',
                'Modelo de origen, fuerzas, planos, dioses, ciencia o metafisica del mundo.'),
          ],
        ),
      ],
    'rights' => const [
        GlossaryCategory(
          id: 'rights_publishing',
          title: 'Publicacion y cesiones',
          subtitle:
              'Terminos contractuales frecuentes al publicar o licenciar.',
          icon: Icons.description_outlined,
          terms: [
            GlossaryTerm('Cesion',
                'Transferencia contractual de derechos patrimoniales bajo condiciones especificas.'),
            GlossaryTerm('Licencia exclusiva',
                'Autorizacion otorgada a una sola parte, excluyendo a terceros segun contrato.'),
            GlossaryTerm('Licencia no exclusiva',
                'Autorizacion que permite conceder permisos similares a otras partes.'),
            GlossaryTerm('Territorio',
                'Ambito geografico donde una licencia o cesion tiene efecto.'),
            GlossaryTerm('Plazo',
                'Duracion temporal de una licencia, cesion o permiso.'),
            GlossaryTerm('Regalias',
                'Porcentaje o pago derivado de explotacion comercial de la obra.'),
            GlossaryTerm('Opcion',
                'Derecho preferente para adquirir, adaptar o publicar una obra en el futuro.'),
          ],
        ),
      ],
    _ => const [],
  };
}
