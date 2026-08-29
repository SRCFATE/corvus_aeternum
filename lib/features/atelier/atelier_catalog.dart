// Catálogo creativo del Atelier.
//
// Datos puros: ramas creativas, tipos de obra, opciones de clasificación y el
// glosario de géneros/subgéneros por disciplina. No contiene widgets ni estado;
// se extrajo de atelier_page.dart para que el catálogo pueda crecer y ser
// consumido por otras pantallas sin arrastrar la página completa.

import 'package:flutter/material.dart';

import '../../models/atelier_models.dart';

const nodeKinds = <String, String>{
  'chapter': 'Capitulo',
  'scene': 'Escena',
  'fragment': 'Fragmento',
  'sketch': 'Boceto',
  'moodboard': 'Moodboard',
  'palette': 'Paleta',
  'reference': 'Referencia',
  'technical_sheet': 'Ficha tecnica',
  'photo': 'Foto',
  'photo_session': 'Sesion',
  'lighting': 'Iluminacion',
  'selection': 'Seleccion',
  'permission': 'Permiso',
  'track': 'Track',
  'lyric': 'Letra',
  'demo': 'Demo',
  'mix': 'Mezcla',
  'credits': 'Creditos',
  'script': 'Guion',
  'storyboard': 'Storyboard',
  'shot': 'Shot',
  'location': 'Locacion',
  'prop': 'Prop',
  'casting': 'Casting',
  'page': 'Pagina',
  'panel': 'Panel',
  'dialogue': 'Dialogo',
  'cover': 'Portada',
  'garment': 'Prenda',
  'collection': 'Coleccion',
  'material': 'Material',
  'size_run': 'Tallas',
  'supplier': 'Proveedor',
  'sample': 'Muestra',
  'lookbook': 'Lookbook',
  'gdd': 'GDD',
  'mechanic': 'Mecanica',
  'level': 'Nivel',
  'mission': 'Mision',
  'bug': 'Bug',
  'act': 'Acto',
  'rehearsal': 'Ensayo',
  'costume': 'Vestuario',
  'light_cue': 'Iluminacion',
  'zone': 'Zona',
  'plan': 'Plano',
  'furniture': 'Mobiliario',
  'budget': 'Presupuesto',
  'note': 'Nota',
  'universe': 'Universo',
  'map': 'Mapa',
  'character': 'Personaje',
  'place': 'Lugar',
  'faction': 'Faccion',
  'event': 'Evento',
  'object': 'Objeto',
  'system': 'Sistema',
  'asset': 'Asset',
};

class CreativeBranch {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final List<ProjectTypeOption> types;
  final Map<String, String> nodeKinds;
  final List<String> studioKinds;
  final String primaryKind;
  final String studioTitle;
  final String studioSubtitle;
  final String primaryAction;
  final String primaryMetricLabel;

  const CreativeBranch({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.types,
    required this.nodeKinds,
    required this.studioKinds,
    required this.primaryKind,
    required this.studioTitle,
    required this.studioSubtitle,
    required this.primaryAction,
    required this.primaryMetricLabel,
  });
}

class ProjectTypeOption {
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  const ProjectTypeOption({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class LanguageOption {
  final String code;
  final String label;
  final String shortLabel;

  const LanguageOption({
    required this.code,
    required this.label,
    required this.shortLabel,
  });
}

class SelectionOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const SelectionOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class AeternumMetadataField {
  final String key;
  final String label;
  final int minLines;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool datePicker;

  const AeternumMetadataField({
    required this.key,
    required this.label,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.datePicker = false,
  });
}

class AeternumReviewItem {
  final String label;
  final String detail;
  final bool done;

  const AeternumReviewItem({
    required this.label,
    required this.detail,
    required this.done,
  });
}

class ProjectStatusOption {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const ProjectStatusOption({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
}

class ProjectIdentityCopy {
  final String groupTitle;
  final IconData icon;
  final String titleLabel;
  final String genreLabel;
  final String universeLabel;
  final String rhythmTitle;
  final String goalLabel;

  const ProjectIdentityCopy({
    required this.groupTitle,
    required this.icon,
    required this.titleLabel,
    required this.genreLabel,
    required this.universeLabel,
    required this.rhythmTitle,
    required this.goalLabel,
  });
}

const languageOptions = <LanguageOption>[
  LanguageOption(code: 'es', label: 'Espanol', shortLabel: 'ES'),
  LanguageOption(code: 'en', label: 'English', shortLabel: 'EN'),
  LanguageOption(code: 'pt', label: 'Portugues', shortLabel: 'PT'),
  LanguageOption(code: 'fr', label: 'Francais', shortLabel: 'FR'),
  LanguageOption(code: 'it', label: 'Italiano', shortLabel: 'IT'),
  LanguageOption(code: 'de', label: 'Deutsch', shortLabel: 'DE'),
  LanguageOption(code: 'ja', label: 'Japones', shortLabel: 'JP'),
  LanguageOption(code: 'zh', label: 'Chino', shortLabel: 'ZH'),
  LanguageOption(code: 'ko', label: 'Coreano', shortLabel: 'KO'),
  LanguageOption(code: 'ru', label: 'Ruso', shortLabel: 'RU'),
  LanguageOption(code: 'nah', label: 'Nahuatl', shortLabel: 'NA'),
  LanguageOption(code: 'maya', label: 'Maya', shortLabel: 'MAYA'),
];

const projectStatusOptions = <ProjectStatusOption>[
  ProjectStatusOption(
    value: 'idea',
    label: 'Idea',
    icon: Icons.lightbulb_outline_rounded,
    color: Color(0xFFC9A84C),
  ),
  ProjectStatusOption(
    value: 'planeacion',
    label: 'Planeacion',
    icon: Icons.account_tree_outlined,
    color: Color(0xFF9B7FDF),
  ),
  ProjectStatusOption(
    value: 'concepto',
    label: 'Concepto',
    icon: Icons.auto_awesome_outlined,
    color: Color(0xFFC9A84C),
  ),
  ProjectStatusOption(
    value: 'borrador',
    label: 'Borrador',
    icon: Icons.edit_note_rounded,
    color: Color(0xFF5B8FDE),
  ),
  ProjectStatusOption(
    value: 'prototipo',
    label: 'Prototipo',
    icon: Icons.extension_outlined,
    color: Color(0xFF4CAF7E),
  ),
  ProjectStatusOption(
    value: 'desarrollo',
    label: 'Desarrollo',
    icon: Icons.timeline_rounded,
    color: Color(0xFFE67E22),
  ),
  ProjectStatusOption(
    value: 'produccion',
    label: 'Produccion',
    icon: Icons.precision_manufacturing_outlined,
    color: Color(0xFFE67E22),
  ),
  ProjectStatusOption(
    value: 'revision',
    label: 'Revision',
    icon: Icons.rate_review_outlined,
    color: Color(0xFFE63946),
  ),
  ProjectStatusOption(
    value: 'edicion',
    label: 'Edicion',
    icon: Icons.tune_rounded,
    color: Color(0xFF5B8FDE),
  ),
  ProjectStatusOption(
    value: 'mezcla',
    label: 'Mezcla',
    icon: Icons.graphic_eq_rounded,
    color: Color(0xFF9B7FDF),
  ),
  ProjectStatusOption(
    value: 'pruebas',
    label: 'Pruebas',
    icon: Icons.bug_report_outlined,
    color: Color(0xFFE67E22),
  ),
  ProjectStatusOption(
    value: 'final',
    label: 'Final',
    icon: Icons.flag_rounded,
    color: Color(0xFF6BAE6B),
  ),
  ProjectStatusOption(
    value: 'lista',
    label: 'Lista',
    icon: Icons.checklist_rounded,
    color: Color(0xFF4CAF7E),
  ),
  ProjectStatusOption(
    value: 'lista_para_publicar',
    label: 'Lista para publicar',
    icon: Icons.task_alt_rounded,
    color: Color(0xFF4CAF7E),
  ),
  ProjectStatusOption(
    value: 'publicada',
    label: 'Publicada',
    icon: Icons.rocket_launch_outlined,
    color: Color(0xFFCC3333),
  ),
  ProjectStatusOption(
    value: 'pausada',
    label: 'Pausada',
    icon: Icons.pause_circle_outline_rounded,
    color: Color(0xFF9BA3B0),
  ),
  ProjectStatusOption(
    value: 'rework',
    label: 'Rework',
    icon: Icons.restart_alt_rounded,
    color: Color(0xFFC9A84C),
  ),
  ProjectStatusOption(
    value: 'edicion_definitiva',
    label: 'Edicion definitiva',
    icon: Icons.verified_outlined,
    color: Color(0xFF6BAE6B),
  ),
  ProjectStatusOption(
    value: 'archivada',
    label: 'Archivada',
    icon: Icons.archive_outlined,
    color: Color(0xFF8A8090),
  ),
  ProjectStatusOption(
    value: 'cancelada',
    label: 'Cancelada',
    icon: Icons.block_rounded,
    color: Color(0xFF8A8090),
  ),
];

const visibilityOptions = <SelectionOption>[
  SelectionOption(
    value: 'private',
    label: 'Privada',
    icon: Icons.lock_outline_rounded,
    color: Color(0xFF9BA3B0),
  ),
  SelectionOption(
    value: 'collaborators',
    label: 'Colaboradores',
    icon: Icons.group_outlined,
    color: Color(0xFF5B8FDE),
  ),
  SelectionOption(
    value: 'members',
    label: 'Miembros',
    icon: Icons.workspace_premium_outlined,
    color: Color(0xFFC9A84C),
  ),
  SelectionOption(
    value: 'followers',
    label: 'Seguidores',
    icon: Icons.favorite_border_rounded,
    color: Color(0xFFE91E8C),
  ),
  SelectionOption(
    value: 'public',
    label: 'Publica',
    icon: Icons.public_rounded,
    color: Color(0xFF6BAE6B),
  ),
];

const licenseOptions = <SelectionOption>[
  SelectionOption(
    value: 'all_rights_reserved',
    label: 'Todos los derechos',
    icon: Icons.copyright_rounded,
    color: Color(0xFFE63946),
  ),
  SelectionOption(
    value: 'private_use',
    label: 'Uso privado',
    icon: Icons.lock_outline_rounded,
    color: Color(0xFF9BA3B0),
  ),
  SelectionOption(
    value: 'creative_commons',
    label: 'Creative Commons',
    icon: Icons.share_outlined,
    color: Color(0xFF5B8FDE),
  ),
  SelectionOption(
    value: 'commercial',
    label: 'Uso comercial',
    icon: Icons.storefront_outlined,
    color: Color(0xFFC9A84C),
  ),
  SelectionOption(
    value: 'exclusive',
    label: 'Licencia exclusiva',
    icon: Icons.verified_outlined,
    color: Color(0xFF6BAE6B),
  ),
];

const monetizationOptions = <SelectionOption>[
  SelectionOption(
    value: 'none',
    label: 'Sin monetizar',
    icon: Icons.money_off_rounded,
    color: Color(0xFF9BA3B0),
  ),
  SelectionOption(
    value: 'free',
    label: 'Gratis',
    icon: Icons.volunteer_activism_outlined,
    color: Color(0xFF6BAE6B),
  ),
  SelectionOption(
    value: 'digital_sale',
    label: 'Venta digital',
    icon: Icons.download_for_offline_outlined,
    color: Color(0xFF5B8FDE),
  ),
  SelectionOption(
    value: 'physical_sale',
    label: 'Venta fisica',
    icon: Icons.inventory_2_outlined,
    color: Color(0xFFC9A84C),
  ),
  SelectionOption(
    value: 'membership',
    label: 'Membresia',
    icon: Icons.workspace_premium_outlined,
    color: Color(0xFF9B7FDF),
  ),
  SelectionOption(
    value: 'auction',
    label: 'Subasta',
    icon: Icons.gavel_rounded,
    color: Color(0xFFE67E22),
  ),
  SelectionOption(
    value: 'limited_edition',
    label: 'Edicion limitada',
    icon: Icons.confirmation_number_outlined,
    color: Color(0xFFE91E8C),
  ),
];

const priorityOptions = <SelectionOption>[
  SelectionOption(
    value: 'low',
    label: 'Baja',
    icon: Icons.keyboard_arrow_down_rounded,
    color: Color(0xFF9BA3B0),
  ),
  SelectionOption(
    value: 'normal',
    label: 'Normal',
    icon: Icons.remove_rounded,
    color: Color(0xFF5B8FDE),
  ),
  SelectionOption(
    value: 'high',
    label: 'Alta',
    icon: Icons.keyboard_arrow_up_rounded,
    color: Color(0xFFE67E22),
  ),
  SelectionOption(
    value: 'critical',
    label: 'Prioritaria',
    icon: Icons.priority_high_rounded,
    color: Color(0xFFE63946),
  ),
];

const ageRatingOptions = <SelectionOption>[
  SelectionOption(
    value: 'all',
    label: 'Todo publico',
    icon: Icons.family_restroom_rounded,
    color: Color(0xFF6BAE6B),
  ),
  SelectionOption(
    value: '+13',
    label: '+13',
    icon: Icons.looks_one_rounded,
    color: Color(0xFF5B8FDE),
  ),
  SelectionOption(
    value: '+16',
    label: '+16',
    icon: Icons.warning_amber_rounded,
    color: Color(0xFFC9A84C),
  ),
  SelectionOption(
    value: '+18',
    label: '+18',
    icon: Icons.no_adult_content_rounded,
    color: Color(0xFFE63946),
  ),
];

const branchSpecs = <CreativeBranch>[
  CreativeBranch(
    id: 'writing',
    label: 'Escritura',
    description: 'Novelas, cuentos, poemas, ensayos y guiones.',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF6BAE6B),
    types: [
      ProjectTypeOption(
        name: 'Novela',
        description: 'Arco largo, capitulos y desarrollo narrativo.',
        icon: Icons.menu_book_rounded,
        color: Color(0xFF6BAE6B),
      ),
      ProjectTypeOption(
        name: 'Cuento',
        description: 'Pieza breve, precisa y de alto impacto.',
        icon: Icons.short_text_rounded,
        color: Color(0xFF5B8FDE),
      ),
      ProjectTypeOption(
        name: 'Guion',
        description: 'Escenas, dialogo y ritmo audiovisual.',
        icon: Icons.movie_creation_rounded,
        color: Color(0xFFE63946),
      ),
      ProjectTypeOption(
        name: 'Poesia',
        description: 'Verso, imagen y pulso interior.',
        icon: Icons.format_quote_rounded,
        color: Color(0xFF9B7FDF),
      ),
    ],
    nodeKinds: {
      'chapter': 'Capitulo',
      'scene': 'Escena',
      'fragment': 'Fragmento',
      'character': 'Personaje',
      'place': 'Lugar',
      'event': 'Evento',
      'object': 'Objeto',
      'note': 'Nota',
      'asset': 'Asset',
    },
    studioKinds: ['chapter', 'scene', 'fragment'],
    primaryKind: 'chapter',
    studioTitle: 'Editor y estructura',
    studioSubtitle: 'Capitulos, escenas y fragmentos guardados en tu proyecto.',
    primaryAction: 'Escribir',
    primaryMetricLabel: 'palabras',
  ),
  CreativeBranch(
    id: 'visual',
    label: 'Visual',
    description: 'Ilustracion, pintura, concept art, portadas y artbooks.',
    icon: Icons.palette_outlined,
    color: Color(0xFFC9A84C),
    types: [
      ProjectTypeOption(
        name: 'Ilustracion',
        description: 'Bocetos, referencias, color y version final.',
        icon: Icons.brush_rounded,
        color: Color(0xFFC9A84C),
      ),
      ProjectTypeOption(
        name: 'Pintura',
        description: 'Tecnica, materiales y ficha visual.',
        icon: Icons.format_paint_rounded,
        color: Color(0xFFE67E22),
      ),
      ProjectTypeOption(
        name: 'Concept art',
        description: 'Exploracion visual para mundos y personajes.',
        icon: Icons.auto_awesome_outlined,
        color: Color(0xFF9B7FDF),
      ),
      ProjectTypeOption(
        name: 'Artbook',
        description: 'Coleccion curada de piezas y proceso.',
        icon: Icons.collections_bookmark_outlined,
        color: Color(0xFF5B8FDE),
      ),
    ],
    nodeKinds: {
      'sketch': 'Boceto',
      'moodboard': 'Moodboard',
      'palette': 'Paleta',
      'reference': 'Referencia',
      'technical_sheet': 'Ficha tecnica',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['sketch', 'moodboard', 'palette', 'technical_sheet'],
    primaryKind: 'sketch',
    studioTitle: 'Bocetos y ficha visual',
    studioSubtitle: 'Moodboards, paletas, referencias y versiones de imagen.',
    primaryAction: 'Crear boceto',
    primaryMetricLabel: 'elementos',
  ),
  CreativeBranch(
    id: 'music',
    label: 'Musica',
    description: 'Canciones, albumes, demos, letras y soundtracks.',
    icon: Icons.music_note_rounded,
    color: Color(0xFFE67E22),
    types: [
      ProjectTypeOption(
        name: 'Cancion',
        description: 'Letra, demo, BPM, tonalidad y mezcla.',
        icon: Icons.audiotrack_rounded,
        color: Color(0xFFE67E22),
      ),
      ProjectTypeOption(
        name: 'Album',
        description: 'Tracks, portada, creditos y secuencia.',
        icon: Icons.album_outlined,
        color: Color(0xFFC9A84C),
      ),
      ProjectTypeOption(
        name: 'Demo',
        description: 'Idea musical en proceso.',
        icon: Icons.mic_none_rounded,
        color: Color(0xFF5B8FDE),
      ),
      ProjectTypeOption(
        name: 'Soundtrack',
        description: 'Motivos, escenas y ambiente sonoro.',
        icon: Icons.graphic_eq_rounded,
        color: Color(0xFF9B7FDF),
      ),
    ],
    nodeKinds: {
      'track': 'Track',
      'lyric': 'Letra',
      'demo': 'Demo',
      'mix': 'Mezcla',
      'credits': 'Creditos',
      'reference': 'Referencia',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['track', 'lyric', 'demo', 'mix'],
    primaryKind: 'track',
    studioTitle: 'Tracks y demos',
    studioSubtitle: 'Letras, demos, versiones de mezcla, BPM y creditos.',
    primaryAction: 'Crear track',
    primaryMetricLabel: 'tracks',
  ),
  CreativeBranch(
    id: 'video',
    label: 'Video',
    description: 'Corto, videoclip, trailer, animacion y reels narrativos.',
    icon: Icons.movie_creation_outlined,
    color: Color(0xFFE63946),
    types: [
      ProjectTypeOption(
        name: 'Cortometraje',
        description: 'Guion, escenas, shots y plan de rodaje.',
        icon: Icons.movie_rounded,
        color: Color(0xFFE63946),
      ),
      ProjectTypeOption(
        name: 'Videoclip',
        description: 'Visuales, musica, locaciones y montaje.',
        icon: Icons.video_camera_back_outlined,
        color: Color(0xFF9B7FDF),
      ),
      ProjectTypeOption(
        name: 'Animacion',
        description: 'Storyboard, escenas y assets visuales.',
        icon: Icons.animation_rounded,
        color: Color(0xFF5B8FDE),
      ),
    ],
    nodeKinds: {
      'script': 'Guion',
      'scene': 'Escena',
      'storyboard': 'Storyboard',
      'shot': 'Shot',
      'location': 'Locacion',
      'prop': 'Prop',
      'casting': 'Casting',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['script', 'scene', 'storyboard', 'shot'],
    primaryKind: 'scene',
    studioTitle: 'Produccion audiovisual',
    studioSubtitle: 'Guion, escenas, storyboards, shots y locaciones.',
    primaryAction: 'Crear escena',
    primaryMetricLabel: 'escenas',
  ),
  CreativeBranch(
    id: 'comic',
    label: 'Comic',
    description: 'Manga, webtoon, novela grafica y paginas secuenciales.',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF5B8FDE),
    types: [
      ProjectTypeOption(
        name: 'Manga',
        description: 'Capitulos, paginas, paneles y continuidad visual.',
        icon: Icons.auto_stories_rounded,
        color: Color(0xFF5B8FDE),
      ),
      ProjectTypeOption(
        name: 'Webtoon',
        description: 'Secuencia vertical y ritmo de lectura.',
        icon: Icons.view_stream_outlined,
        color: Color(0xFF6BAE6B),
      ),
      ProjectTypeOption(
        name: 'Novela grafica',
        description: 'Guion, pagina, panel y arte final.',
        icon: Icons.draw_rounded,
        color: Color(0xFFC9A84C),
      ),
    ],
    nodeKinds: {
      'chapter': 'Capitulo',
      'page': 'Pagina',
      'panel': 'Panel',
      'dialogue': 'Dialogo',
      'cover': 'Portada',
      'character': 'Personaje',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['chapter', 'page', 'panel', 'dialogue'],
    primaryKind: 'page',
    studioTitle: 'Paginas y paneles',
    studioSubtitle: 'Guion por pagina, paneles, dialogos y continuidad visual.',
    primaryAction: 'Crear pagina',
    primaryMetricLabel: 'paginas',
  ),
  CreativeBranch(
    id: 'photo',
    label: 'Fotografia',
    description: 'Series fotograficas, retrato, editorial y urbana.',
    icon: Icons.photo_camera_outlined,
    color: Color(0xFF7FBCD2),
    types: [
      ProjectTypeOption(
        name: 'Serie fotografica',
        description: 'Secuencia de imagenes, seleccion y narrativa visual.',
        icon: Icons.photo_library_outlined,
        color: Color(0xFF7FBCD2),
      ),
      ProjectTypeOption(
        name: 'Retrato',
        description: 'Modelo, luz, permisos y direccion.',
        icon: Icons.portrait_outlined,
        color: Color(0xFFC9A84C),
      ),
      ProjectTypeOption(
        name: 'Editorial',
        description: 'Concepto, styling, locacion y seleccion final.',
        icon: Icons.style_outlined,
        color: Color(0xFF9B7FDF),
      ),
      ProjectTypeOption(
        name: 'Fotografia urbana',
        description: 'Locaciones, rutas, atmosfera y permisos.',
        icon: Icons.location_city_outlined,
        color: Color(0xFF5B8FDE),
      ),
    ],
    nodeKinds: {
      'photo_session': 'Sesion',
      'photo': 'Foto',
      'lighting': 'Iluminacion',
      'selection': 'Seleccion',
      'permission': 'Permiso',
      'location': 'Locacion',
      'reference': 'Referencia',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['photo_session', 'photo', 'lighting', 'selection'],
    primaryKind: 'photo_session',
    studioTitle: 'Sesiones y seleccion',
    studioSubtitle: 'Fotos, modelos, locaciones, permisos y seleccion final.',
    primaryAction: 'Crear sesion',
    primaryMetricLabel: 'fotos',
  ),
  CreativeBranch(
    id: 'fashion',
    label: 'Moda',
    description: 'Prendas, colecciones, drops, patronaje y lookbooks.',
    icon: Icons.checkroom_outlined,
    color: Color(0xFF9B7FDF),
    types: [
      ProjectTypeOption(
        name: 'Prenda',
        description: 'Ficha tecnica, materiales, tallas y costos.',
        icon: Icons.checkroom_outlined,
        color: Color(0xFF9B7FDF),
      ),
      ProjectTypeOption(
        name: 'Coleccion',
        description: 'Drop, tema, prendas, lookbook y calendario.',
        icon: Icons.grid_view_rounded,
        color: Color(0xFFC9A84C),
      ),
      ProjectTypeOption(
        name: 'Lookbook',
        description: 'Fotos, estilismo y narrativa visual.',
        icon: Icons.photo_library_outlined,
        color: Color(0xFF5B8FDE),
      ),
    ],
    nodeKinds: {
      'garment': 'Prenda',
      'collection': 'Coleccion',
      'material': 'Material',
      'size_run': 'Tallas',
      'supplier': 'Proveedor',
      'sample': 'Muestra',
      'lookbook': 'Lookbook',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['garment', 'collection', 'material', 'sample'],
    primaryKind: 'garment',
    studioTitle: 'Prendas y colecciones',
    studioSubtitle: 'Fichas tecnicas, materiales, muestras, costos y drops.',
    primaryAction: 'Crear prenda',
    primaryMetricLabel: 'prendas',
  ),
  CreativeBranch(
    id: 'game',
    label: 'Juego',
    description: 'Videojuegos narrativos, RPG, visual novel y demos.',
    icon: Icons.sports_esports_outlined,
    color: Color(0xFF4CAF7E),
    types: [
      ProjectTypeOption(
        name: 'Videojuego narrativo',
        description: 'GDD, mecanicas, niveles, misiones y dialogos.',
        icon: Icons.sports_esports_outlined,
        color: Color(0xFF4CAF7E),
      ),
      ProjectTypeOption(
        name: 'Visual novel',
        description: 'Rutas, dialogos, personajes y escenas.',
        icon: Icons.forum_outlined,
        color: Color(0xFF9B7FDF),
      ),
      ProjectTypeOption(
        name: 'RPG',
        description: 'Misiones, progresion, lore y sistemas.',
        icon: Icons.map_outlined,
        color: Color(0xFFC9A84C),
      ),
    ],
    nodeKinds: {
      'gdd': 'GDD',
      'mechanic': 'Mecanica',
      'level': 'Nivel',
      'mission': 'Mision',
      'dialogue': 'Dialogo',
      'character': 'Personaje',
      'asset': 'Asset',
      'bug': 'Bug',
      'note': 'Nota',
    },
    studioKinds: ['gdd', 'mechanic', 'level', 'mission'],
    primaryKind: 'mechanic',
    studioTitle: 'Diseno interactivo',
    studioSubtitle: 'GDD, mecanicas, niveles, misiones, dialogos y assets.',
    primaryAction: 'Crear mecanica',
    primaryMetricLabel: 'sistemas',
  ),
  CreativeBranch(
    id: 'stage',
    label: 'Escena',
    description: 'Teatro, performance, danza, monologos y puesta en escena.',
    icon: Icons.theater_comedy_outlined,
    color: Color(0xFFE91E8C),
    types: [
      ProjectTypeOption(
        name: 'Obra teatral',
        description: 'Actos, escenas, bloqueo, vestuario y ensayos.',
        icon: Icons.theater_comedy_outlined,
        color: Color(0xFFE91E8C),
      ),
      ProjectTypeOption(
        name: 'Performance',
        description: 'Accion, cuerpo, espacio y direccion.',
        icon: Icons.accessibility_new_rounded,
        color: Color(0xFFC9A84C),
      ),
      ProjectTypeOption(
        name: 'Danza',
        description: 'Secuencias, musica, ensayos y escena.',
        icon: Icons.directions_run_rounded,
        color: Color(0xFF5B8FDE),
      ),
    ],
    nodeKinds: {
      'act': 'Acto',
      'scene': 'Escena',
      'rehearsal': 'Ensayo',
      'prop': 'Prop',
      'costume': 'Vestuario',
      'light_cue': 'Iluminacion',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['act', 'scene', 'rehearsal', 'prop'],
    primaryKind: 'scene',
    studioTitle: 'Puesta en escena',
    studioSubtitle: 'Actos, escenas, ensayos, props, vestuario e iluminacion.',
    primaryAction: 'Crear escena',
    primaryMetricLabel: 'escenas',
  ),
  CreativeBranch(
    id: 'space',
    label: 'Espacio',
    description: 'Instalaciones, sets, cafeterias, galerias e interiores.',
    icon: Icons.architecture_rounded,
    color: Color(0xFF9B8B7A),
    types: [
      ProjectTypeOption(
        name: 'Instalacion',
        description: 'Concepto espacial, zonas, materiales y recorrido.',
        icon: Icons.architecture_rounded,
        color: Color(0xFF9B8B7A),
      ),
      ProjectTypeOption(
        name: 'Set',
        description: 'Moodboard, props, mobiliario y luz.',
        icon: Icons.chair_outlined,
        color: Color(0xFFC9A84C),
      ),
      ProjectTypeOption(
        name: 'Galeria',
        description: 'Flujo, zonas, piezas, montaje y proveedores.',
        icon: Icons.account_balance_outlined,
        color: Color(0xFF5B8FDE),
      ),
    ],
    nodeKinds: {
      'zone': 'Zona',
      'plan': 'Plano',
      'material': 'Material',
      'furniture': 'Mobiliario',
      'light_cue': 'Iluminacion',
      'supplier': 'Proveedor',
      'budget': 'Presupuesto',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['zone', 'plan', 'material', 'furniture'],
    primaryKind: 'zone',
    studioTitle: 'Concepto espacial',
    studioSubtitle: 'Zonas, planos, materiales, mobiliario y flujo.',
    primaryAction: 'Crear zona',
    primaryMetricLabel: 'zonas',
  ),
  CreativeBranch(
    id: 'world',
    label: 'Mundo',
    description: 'Worldbuilding, lore, mapas, facciones y sistemas.',
    icon: Icons.public_rounded,
    color: Color(0xFFCC3333),
    types: [
      ProjectTypeOption(
        name: 'WorldBuilding',
        description: 'Lore, geografias, facciones, mapas y cronologia.',
        icon: Icons.public_rounded,
        color: Color(0xFFCC3333),
      ),
      ProjectTypeOption(
        name: 'Universo transmedia',
        description: 'Obras conectadas bajo un mismo mundo.',
        icon: Icons.hub_outlined,
        color: Color(0xFF9B7FDF),
      ),
      ProjectTypeOption(
        name: 'Mapa conceptual',
        description: 'Conexiones, simbolos, estetica y reglas.',
        icon: Icons.account_tree_outlined,
        color: Color(0xFFC9A84C),
      ),
    ],
    nodeKinds: {
      'universe': 'Universo',
      'place': 'Lugar',
      'faction': 'Faccion',
      'event': 'Evento',
      'map': 'Mapa',
      'system': 'Sistema',
      'character': 'Personaje',
      'asset': 'Asset',
      'note': 'Nota',
    },
    studioKinds: ['universe', 'place', 'faction', 'event'],
    primaryKind: 'universe',
    studioTitle: 'Mundiarium universal',
    studioSubtitle: 'Lore, lugares, facciones, mapas, sistemas y conexiones.',
    primaryAction: 'Crear mundo',
    primaryMetricLabel: 'nodos',
  ),
];

CreativeBranch branchSpec(String? id) {
  return branchSpecs.firstWhere(
    (branch) => branch.id == id,
    orElse: () => branchSpecs.first,
  );
}

String branchIdForProject(AtelierProject? project) {
  final raw = project?.metadata['atelier_branch'] as String?;
  if (raw != null && raw.trim().isNotEmpty) return raw.trim();
  final type = project?.type.toLowerCase() ?? '';
  if (type.contains('cancion') || type.contains('album')) return 'music';
  if (type.contains('ilustr') || type.contains('pintura')) return 'visual';
  if (type.contains('comic') || type.contains('manga')) return 'comic';
  if (type.contains('foto') ||
      type.contains('retr') ||
      type.contains('editorial')) {
    return 'photo';
  }
  if (type.contains('prenda') || type.contains('coleccion')) return 'fashion';
  if (type.contains('juego') || type.contains('rpg')) return 'game';
  if (type.contains('mundo') || type.contains('world')) return 'world';
  return 'writing';
}

Map<String, String> nodeKindsForBranch(String branchId) {
  return {
    ...branchSpec(branchId).nodeKinds,
    'note': nodeKinds['note']!,
    'asset': nodeKinds['asset']!,
  };
}

ProjectIdentityCopy identityCopyForBranch(String branchId) {
  return switch (branchId) {
    'visual' => const ProjectIdentityCopy(
        groupTitle: 'Ficha visual',
        icon: Icons.palette_outlined,
        titleLabel: 'Titulo de la pieza',
        genreLabel: 'Tecnica / estilo',
        universeLabel: 'Serie, personaje o universo',
        rhythmTitle: 'Avance',
        goalLabel: 'Objetivo semanal de bocetos',
      ),
    'music' => const ProjectIdentityCopy(
        groupTitle: 'Ficha musical',
        icon: Icons.music_note_rounded,
        titleLabel: 'Titulo de la cancion / album',
        genreLabel: 'Genero / mood sonoro',
        universeLabel: 'Album, era o universo',
        rhythmTitle: 'Produccion',
        goalLabel: 'Objetivo semanal de tracks',
      ),
    'video' => const ProjectIdentityCopy(
        groupTitle: 'Ficha audiovisual',
        icon: Icons.movie_creation_outlined,
        titleLabel: 'Titulo del proyecto',
        genreLabel: 'Genero / formato visual',
        universeLabel: 'Serie, universo o campana',
        rhythmTitle: 'Produccion',
        goalLabel: 'Objetivo semanal de escenas',
      ),
    'comic' => const ProjectIdentityCopy(
        groupTitle: 'Ficha secuencial',
        icon: Icons.auto_stories_rounded,
        titleLabel: 'Titulo del comic / manga',
        genreLabel: 'Genero / estilo grafico',
        universeLabel: 'Saga, universo o personaje',
        rhythmTitle: 'Produccion',
        goalLabel: 'Objetivo semanal de paginas',
      ),
    'photo' => const ProjectIdentityCopy(
        groupTitle: 'Ficha fotografica',
        icon: Icons.photo_camera_outlined,
        titleLabel: 'Titulo de la serie / sesion',
        genreLabel: 'Estilo / tipo de fotografia',
        universeLabel: 'Serie, editorial o concepto',
        rhythmTitle: 'Produccion',
        goalLabel: 'Objetivo semanal de fotos',
      ),
    'fashion' => const ProjectIdentityCopy(
        groupTitle: 'Ficha de moda',
        icon: Icons.checkroom_outlined,
        titleLabel: 'Nombre de la prenda / coleccion',
        genreLabel: 'Estilo / categoria',
        universeLabel: 'Drop, coleccion o linea',
        rhythmTitle: 'Produccion',
        goalLabel: 'Objetivo semanal de piezas',
      ),
    'game' => const ProjectIdentityCopy(
        groupTitle: 'Ficha interactiva',
        icon: Icons.sports_esports_outlined,
        titleLabel: 'Titulo del juego / demo',
        genreLabel: 'Genero / tipo de gameplay',
        universeLabel: 'Universo, saga o IP',
        rhythmTitle: 'Desarrollo',
        goalLabel: 'Objetivo semanal de sistemas',
      ),
    'stage' => const ProjectIdentityCopy(
        groupTitle: 'Ficha escenica',
        icon: Icons.theater_comedy_outlined,
        titleLabel: 'Titulo de la obra / pieza',
        genreLabel: 'Disciplina / tono escenico',
        universeLabel: 'Compania, ciclo o concepto',
        rhythmTitle: 'Ensayo',
        goalLabel: 'Objetivo semanal de escenas',
      ),
    'space' => const ProjectIdentityCopy(
        groupTitle: 'Ficha espacial',
        icon: Icons.architecture_rounded,
        titleLabel: 'Nombre del espacio / instalacion',
        genreLabel: 'Estilo / uso',
        universeLabel: 'Sede, serie o concepto',
        rhythmTitle: 'Desarrollo',
        goalLabel: 'Objetivo semanal de zonas',
      ),
    'world' => const ProjectIdentityCopy(
        groupTitle: 'Ficha de mundo',
        icon: Icons.public_rounded,
        titleLabel: 'Nombre del universo',
        genreLabel: 'Genero / tono del mundo',
        universeLabel: 'Proyecto matriz o saga',
        rhythmTitle: 'Construccion',
        goalLabel: 'Objetivo semanal de nodos',
      ),
    _ => const ProjectIdentityCopy(
        groupTitle: 'Identidad artistica',
        icon: Icons.auto_stories_outlined,
        titleLabel: 'Titulo',
        genreLabel: 'Genero',
        universeLabel: 'Universo vinculado',
        rhythmTitle: 'Ritmo',
        goalLabel: 'Objetivo semanal de palabras',
      ),
  };
}

List<AeternumMetadataField> disciplineFieldsForBranch(String branchId) {
  return switch (branchId) {
    'visual' => const [
        AeternumMetadataField(
            key: 'visual_scope', label: 'Obra, serie o artbook'),
        AeternumMetadataField(key: 'visual_dimensions', label: 'Dimensiones'),
        AeternumMetadataField(key: 'visual_resolution', label: 'Resolucion'),
        AeternumMetadataField(key: 'visual_technique', label: 'Tecnica'),
        AeternumMetadataField(key: 'visual_support', label: 'Soporte'),
        AeternumMetadataField(
          key: 'visual_palette',
          label: 'Paleta de color',
          minLines: 2,
          maxLines: 3,
        ),
        AeternumMetadataField(
          key: 'visual_materials',
          label: 'Materiales',
          minLines: 2,
          maxLines: 3,
        ),
      ],
    'music' => const [
        AeternumMetadataField(
          key: 'music_track_count',
          label: 'Tracks objetivo',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(
            key: 'music_duration', label: 'Duracion estimada'),
        AeternumMetadataField(
          key: 'music_bpm',
          label: 'BPM',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(key: 'music_key', label: 'Tonalidad'),
        AeternumMetadataField(
          key: 'music_structure',
          label: 'Estructura musical',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(key: 'music_instruments', label: 'Instrumentos'),
        AeternumMetadataField(
            key: 'music_vocals', label: 'Voces / interpretes'),
      ],
    'video' => const [
        AeternumMetadataField(
            key: 'video_duration', label: 'Duracion estimada'),
        AeternumMetadataField(key: 'video_format', label: 'Formato'),
        AeternumMetadataField(key: 'video_resolution', label: 'Resolucion'),
        AeternumMetadataField(
            key: 'video_aspect_ratio', label: 'Aspect ratio'),
        AeternumMetadataField(key: 'video_fps', label: 'FPS'),
        AeternumMetadataField(
          key: 'video_locations',
          label: 'Locaciones',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(
          key: 'video_casting',
          label: 'Casting',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(
          key: 'video_shooting_plan',
          label: 'Plan de rodaje',
          minLines: 2,
          maxLines: 4,
        ),
      ],
    'comic' => const [
        AeternumMetadataField(
            key: 'comic_format', label: 'Formato de lectura'),
        AeternumMetadataField(
          key: 'comic_pages',
          label: 'Numero de paginas',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(
          key: 'comic_panels',
          label: 'Numero de paneles',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(
            key: 'comic_art_style', label: 'Estilo de dibujo'),
        AeternumMetadataField(
            key: 'comic_script_stage', label: 'Estado del guion'),
        AeternumMetadataField(key: 'comic_lettering', label: 'Rotulacion'),
      ],
    'photo' => const [
        AeternumMetadataField(
            key: 'photo_session_type', label: 'Tipo de sesion'),
        AeternumMetadataField(key: 'photo_camera', label: 'Camara'),
        AeternumMetadataField(key: 'photo_lens', label: 'Lente'),
        AeternumMetadataField(key: 'photo_location', label: 'Locacion'),
        AeternumMetadataField(key: 'photo_model', label: 'Modelo / sujeto'),
        AeternumMetadataField(key: 'photo_lighting', label: 'Iluminacion'),
        AeternumMetadataField(
          key: 'photo_count',
          label: 'Numero de fotos',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(
          key: 'photo_final_selection',
          label: 'Seleccion final',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(
          key: 'photo_permissions',
          label: 'Permisos y releases',
          minLines: 2,
          maxLines: 4,
        ),
      ],
    'fashion' => const [
        AeternumMetadataField(
            key: 'fashion_garment_type', label: 'Tipo de prenda'),
        AeternumMetadataField(
            key: 'fashion_collection', label: 'Coleccion / drop'),
        AeternumMetadataField(key: 'fashion_season', label: 'Temporada'),
        AeternumMetadataField(key: 'fashion_sizes', label: 'Tallas'),
        AeternumMetadataField(
          key: 'fashion_materials',
          label: 'Materiales',
          minLines: 2,
          maxLines: 3,
        ),
        AeternumMetadataField(key: 'fashion_colors', label: 'Colores'),
        AeternumMetadataField(key: 'fashion_supplier', label: 'Proveedor'),
        AeternumMetadataField(key: 'fashion_sku', label: 'SKU'),
        AeternumMetadataField(
          key: 'fashion_cost',
          label: 'Costo de produccion',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(
          key: 'fashion_price',
          label: 'Precio sugerido',
          keyboardType: TextInputType.number,
        ),
      ],
    'game' => const [
        AeternumMetadataField(key: 'game_engine', label: 'Motor'),
        AeternumMetadataField(
            key: 'game_platforms', label: 'Plataformas objetivo'),
        AeternumMetadataField(
            key: 'game_playable_genre', label: 'Genero jugable'),
        AeternumMetadataField(
          key: 'game_mechanics',
          label: 'Mecanicas principales',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(key: 'game_levels', label: 'Niveles / misiones'),
        AeternumMetadataField(key: 'game_build', label: 'Build actual'),
        AeternumMetadataField(key: 'game_mode', label: 'Modo de juego'),
      ],
    'stage' => const [
        AeternumMetadataField(key: 'stage_acts', label: 'Actos / escenas'),
        AeternumMetadataField(key: 'stage_duration', label: 'Duracion'),
        AeternumMetadataField(
          key: 'stage_cast',
          label: 'Reparto',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(
          key: 'stage_blocking',
          label: 'Bloqueo escenico',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(key: 'stage_costumes', label: 'Vestuario'),
        AeternumMetadataField(key: 'stage_lighting', label: 'Iluminacion'),
        AeternumMetadataField(key: 'stage_rehearsals', label: 'Ensayos'),
      ],
    'space' => const [
        AeternumMetadataField(key: 'space_type', label: 'Tipo de espacio'),
        AeternumMetadataField(key: 'space_dimensions', label: 'Dimensiones'),
        AeternumMetadataField(
          key: 'space_zones',
          label: 'Zonas',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(
          key: 'space_materials',
          label: 'Materiales',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(key: 'space_furniture', label: 'Mobiliario'),
        AeternumMetadataField(
            key: 'space_people_flow', label: 'Flujo de personas'),
        AeternumMetadataField(
          key: 'space_budget',
          label: 'Costo estimado',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(key: 'space_suppliers', label: 'Proveedores'),
      ],
    'world' => const [
        AeternumMetadataField(key: 'world_scope', label: 'Alcance del mundo'),
        AeternumMetadataField(
          key: 'world_regions',
          label: 'Regiones / ciudades',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(
          key: 'world_factions',
          label: 'Facciones',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(
          key: 'world_systems',
          label: 'Sistemas magicos / politicos / tecnologicos',
          minLines: 2,
          maxLines: 4,
        ),
        AeternumMetadataField(key: 'world_timeline', label: 'Linea temporal'),
        AeternumMetadataField(key: 'world_maps', label: 'Mapas'),
        AeternumMetadataField(
          key: 'world_rules',
          label: 'Reglas internas',
          minLines: 2,
          maxLines: 4,
        ),
      ],
    _ => const [
        AeternumMetadataField(
          key: 'writing_estimated_words',
          label: 'Numero estimado de palabras',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(
          key: 'writing_estimated_chapters',
          label: 'Numero estimado de capitulos',
          keyboardType: TextInputType.number,
        ),
        AeternumMetadataField(key: 'writing_narrator', label: 'Narrador'),
        AeternumMetadataField(key: 'writing_tense', label: 'Tiempo verbal'),
      ],
  };
}

const technicalProductionFields = <AeternumMetadataField>[
  AeternumMetadataField(key: 'format_primary', label: 'Formato principal'),
  AeternumMetadataField(key: 'format_secondary', label: 'Formato secundario'),
  AeternumMetadataField(key: 'duration', label: 'Duracion'),
  AeternumMetadataField(key: 'dimensions', label: 'Dimensiones / tamano'),
  AeternumMetadataField(
    key: 'tools_used',
    label: 'Herramientas usadas',
    minLines: 2,
    maxLines: 3,
  ),
  AeternumMetadataField(
    key: 'software_used',
    label: 'Software usado',
    minLines: 2,
    maxLines: 3,
  ),
  AeternumMetadataField(key: 'hardware_used', label: 'Hardware usado'),
  AeternumMetadataField(key: 'started_at', label: 'Fecha de inicio'),
  AeternumMetadataField(key: 'finished_at', label: 'Fecha de finalizacion'),
  AeternumMetadataField(key: 'current_version', label: 'Version actual'),
];

const appendableSuggestionKeys = <String>{
  'visual_palette',
  'visual_materials',
  'music_instruments',
  'video_locations',
  'video_casting',
  'photo_permissions',
  'fashion_materials',
  'fashion_colors',
  'game_platforms',
  'game_mechanics',
  'stage_cast',
  'stage_costumes',
  'space_zones',
  'space_materials',
  'space_suppliers',
  'world_regions',
  'world_factions',
  'world_systems',
  'secondary_languages',
  'tools_used',
  'software_used',
  'related_characters',
  'related_places',
  'related_events',
  'related_factions',
  'secondary_themes',
  'inspirations',
  'references',
  'symbols',
  'collaborators',
  'credits',
  'collaborator_permissions',
};

const plainAeternumFieldKeys = <String>{
  'subtitle',
  'description',
  'primary_tags',
  'secondary_tags',
  'content_warnings',
  'rhythm_notes',
};

const genreSubgenreGlossaryByBranch = <String, Map<String, List<String>>>{
  'writing': {
    'Fantasia': [
      'Fantasia epica',
      'Fantasia oscura',
      'Fantasia urbana',
      'Espada y brujeria',
      'Mitologia',
      'Portal fantasy',
      'Folk fantasy',
    ],
    'Ciencia ficcion': [
      'Cyberpunk',
      'Solarpunk',
      'Space opera',
      'Distopia',
      'Biopunk',
      'Cli-fi',
      'Mexica futurista',
      'Afrofuturismo',
    ],
    'Terror': [
      'Terror gotico',
      'Horror cosmico',
      'Folk horror',
      'Body horror',
      'Suspenso sobrenatural',
      'Terror psicologico',
    ],
    'Drama': [
      'Drama psicologico',
      'Drama familiar',
      'Realismo sucio',
      'Coming of age',
      'Tragedia',
      'Drama historico',
    ],
    'Romance': [
      'Romance oscuro',
      'Romance gotico',
      'Romance contemporaneo',
      'Enemies to lovers',
      'Slow burn',
    ],
    'Thriller': [
      'Thriller politico',
      'Thriller psicologico',
      'Noir',
      'Misterio',
      'Conspiracion',
    ],
    'Ensayo': [
      'Ensayo cultural',
      'Ensayo filosofico',
      'Ensayo politico',
      'Manifiesto',
      'Critica artistica',
    ],
    'Poesia': [
      'Verso libre',
      'Prosa poetica',
      'Poesia oscura',
      'Poesia narrativa',
      'Spoken word',
    ],
    'Guion': [
      'Guion cinematografico',
      'Guion teatral',
      'Guion serial',
      'Guion interactivo',
      'Guion de comic',
    ],
    'Cronica': [
      'Cronica urbana',
      'Cronica personal',
      'Cronica cultural',
      'Cronica documental',
    ],
  },
  'visual': {
    'Ilustracion': [
      'Personaje',
      'Concept art',
      'Key art',
      'Splash art',
      'Editorial',
      'Portada',
      'Poster',
    ],
    'Pintura': [
      'Acrilico',
      'Oleo',
      'Acuarela',
      'Mixta',
      'Expresionista',
      'Abstracta',
      'Figurativa',
    ],
    'Diseno grafico': [
      'Identidad visual',
      'Poster',
      'Editorial',
      'Tipografico',
      'Collage digital',
    ],
    '3D': [
      'Modelado',
      'Escultura digital',
      'Render cinematografico',
      'Environment art',
      'Producto',
    ],
    'Escultura': [
      'Objeto',
      'Instalacion',
      'Maqueta',
      'Pieza textil',
      'Mixta',
    ],
    'Artbook': [
      'Proceso',
      'Coleccion curada',
      'Personajes',
      'Ambientes',
      'Props',
    ],
  },
  'music': {
    'Cancion': [
      'Balada oscura',
      'Rock alternativo',
      'Pop experimental',
      'Synthwave',
      'Industrial',
      'Folk oscuro',
    ],
    'Album': [
      'Album conceptual',
      'Album narrativo',
      'Album instrumental',
      'Album colaborativo',
      'Live session',
    ],
    'EP': [
      'EP conceptual',
      'EP acustico',
      'EP experimental',
      'EP de demos',
    ],
    'Soundtrack': [
      'Score cinematografico',
      'Tema de personaje',
      'Tema de ciudad',
      'Ambiental',
      'Combate',
      'Trailer music',
    ],
    'Beat': [
      'Trap',
      'Hip hop alternativo',
      'Lo-fi',
      'Industrial beat',
      'Cinematic beat',
    ],
    'Ambient': [
      'Drone',
      'Dark ambient',
      'Field recording',
      'Textural',
      'Ritual',
    ],
  },
  'video': {
    'Cortometraje': [
      'Drama',
      'Terror',
      'Experimental',
      'Ciencia ficcion',
      'Fantasia oscura',
      'Noir',
    ],
    'Videoclip': [
      'Performance',
      'Narrativo',
      'Conceptual',
      'Lyrics video',
      'Live session',
    ],
    'Documental': [
      'Biografico',
      'Cultural',
      'Observacional',
      'Ensayo audiovisual',
      'Making of',
    ],
    'Animacion': [
      '2D',
      '3D',
      'Stop motion',
      'Motion graphics',
      'Animatic',
    ],
    'Trailer': [
      'Teaser',
      'Book trailer',
      'Game trailer',
      'Fashion film',
      'Pitch trailer',
    ],
    'Reel narrativo': [
      'Vertical',
      'Serie breve',
      'Microficcion',
      'Proceso',
      'Behind the scenes',
    ],
  },
  'comic': {
    'Manga': [
      'Seinen',
      'Shonen',
      'Shojo',
      'Josei',
      'One-shot',
      'Dark fantasy',
      'Slice of life',
    ],
    'Webtoon': [
      'Vertical color',
      'Romance',
      'Accion',
      'Drama',
      'Terror',
      'Fantasia urbana',
    ],
    'Comic occidental': [
      'Superheroico',
      'Indie',
      'Noir',
      'Ciencia ficcion',
      'Fantasia',
      'Autobiografico',
    ],
    'Novela grafica': [
      'Literaria',
      'Historica',
      'Memoria',
      'Drama adulto',
      'Experimental',
    ],
    'Fanzine': [
      'DIY',
      'Antologia',
      'Ensayo visual',
      'Punk',
      'Experimental',
    ],
  },
  'photo': {
    'Retrato': [
      'Editorial',
      'Fine art',
      'Conceptual',
      'Moda',
      'Psicologico',
      'Autorretrato',
    ],
    'Fotografia urbana': [
      'Street',
      'Nocturna',
      'Arquitectura',
      'Documental urbano',
      'Ciudad futurista',
    ],
    'Documental': [
      'Social',
      'Cultural',
      'Archivo',
      'Proceso artistico',
      'Ensayo fotografico',
    ],
    'Producto': [
      'E-commerce',
      'Editorial de producto',
      'Still life',
      'Lujo',
      'Campana',
    ],
    'Evento': [
      'Concierto',
      'Performance',
      'Backstage',
      'Exhibicion',
      'Lanzamiento',
    ],
    'Moda': [
      'Lookbook',
      'Campana',
      'Editorial',
      'Runway',
      'Street style',
    ],
  },
  'fashion': {
    'Streetwear': [
      'Oversized',
      'Graphic tee',
      'Drop limitado',
      'Urban utility',
      'Skate',
    ],
    'Techwear': [
      'Utility',
      'Modular',
      'Waterproof',
      'Tactico',
      'Cyberpunk',
    ],
    'Alta costura': [
      'Avant-garde',
      'Pieza unica',
      'Bordado',
      'Volumen estructural',
      'Conceptual',
    ],
    'Ready-to-wear': [
      'Capsula',
      'Temporada',
      'Basicos elevados',
      'Coleccion comercial',
    ],
    'Accesorio': [
      'Bolsa',
      'Joyeria',
      'Mascara',
      'Sombrero',
      'Cinturon',
    ],
    'Calzado': [
      'Sneaker',
      'Bota',
      'Experimental',
      'Prototipo',
      'Custom',
    ],
  },
  'game': {
    'RPG': [
      'JRPG',
      'Action RPG',
      'Tactical RPG',
      'Narrative RPG',
      'Dungeon crawler',
    ],
    'Visual novel': [
      'Romance',
      'Terror',
      'Misterio',
      'Rutas multiples',
      'Kinetic novel',
    ],
    'Aventura': [
      'Point and click',
      'Exploracion',
      'Narrativa ambiental',
      'Puzzle adventure',
    ],
    'Puzzle': [
      'Logica',
      'Narrativo',
      'Fisica',
      'Escape room',
      'Abstracto',
    ],
    'Terror': [
      'Survival horror',
      'Psicologico',
      'Found footage',
      'Atmosferico',
    ],
    'Simulador': [
      'Gestion',
      'Vida',
      'Social',
      'Creativo',
      'Economico',
    ],
  },
  'stage': {
    'Teatro': [
      'Drama',
      'Tragedia',
      'Comedia oscura',
      'Experimental',
      'Teatro fisico',
    ],
    'Performance': [
      'Ritual',
      'Duracional',
      'Inmersiva',
      'Cuerpo',
      'Accion urbana',
    ],
    'Danza': [
      'Contemporanea',
      'Butoh',
      'Danza teatro',
      'Improvisacion',
      'Ritual',
    ],
    'Monologo': [
      'Dramatico',
      'Confesional',
      'Satirico',
      'Poetico',
      'Politico',
    ],
    'Opera experimental': [
      'Vocal',
      'Electronica',
      'Interdisciplinaria',
      'Ritual sonora',
    ],
  },
  'world': {
    'Worldbuilding': [
      'Universo transmedia',
      'Mundo secundario',
      'Linea temporal',
      'Cosmologia',
      'Sistema social',
    ],
    'Lore': [
      'Mitos fundacionales',
      'Cronicas',
      'Archivos',
      'Leyendas',
      'Canon historico',
    ],
    'Mapa': [
      'Mapa politico',
      'Mapa fisico',
      'Mapa urbano',
      'Mapa de facciones',
      'Mapa de rutas',
    ],
    'Sistema politico': [
      'Imperio',
      'Estado corporativo',
      'Ciudad estado',
      'Anarquia',
      'Teocracia',
    ],
    'Sistema magico': [
      'Magia ritual',
      'Tecnologia arcana',
      'Pacto',
      'Herencia',
      'Alquimia',
    ],
    'Bestiario': [
      'Criaturas miticas',
      'Mutaciones',
      'Entidades',
      'Fauna local',
      'Monstruos urbanos',
    ],
  },
};

const aeternumFieldSuggestions = <String, List<String>>{
  'style': [
    'Oscuro',
    'Melancolico',
    'Intimo',
    'Epico',
    'Minimalista',
    'Barroco',
    'Industrial',
    'Brutalista',
    'Elegante',
    'Caotico',
    'Ritual',
    'Documental',
    'Cinematografico',
    'Experimental',
    'Editorial',
  ],
  'artistic_movement': [
    'Dark academia',
    'Gotico moderno',
    'Brutalismo',
    'Surrealismo',
    'Expresionismo',
    'Romanticismo oscuro',
    'Cyberpunk',
    'Mexica futurista',
    'Norteno futurista',
    'Postinternet',
    'Arte conceptual',
    'Afrofuturismo',
    'Retrofuturismo',
    'Realismo social',
  ],
  'creative_format': [
    'Obra individual',
    'Serie',
    'Coleccion',
    'Capitulo',
    'Temporada',
    'Antologia',
    'Demo',
    'Prototipo',
    'Vertical slice',
    'Edicion limitada',
    'Archivo de proceso',
    'Pieza final',
    'Teaser',
    'Borrador publico',
  ],
  'target_audience': [
    'Todo publico',
    'Adolescentes',
    'Joven adulto',
    'Adulto',
    'Lectores de fantasia',
    'Lectores de ciencia ficcion',
    'Coleccionistas',
    'Cultura urbana',
    'Publico editorial',
    'Gamers narrativos',
    'Amantes de musica cinematografica',
    'Comunidad artistica',
    'Seguidores del universo',
  ],
  'secondary_languages': [
    'English',
    'Portugues',
    'Francais',
    'Italiano',
    'Deutsch',
    'Japones',
    'Coreano',
    'Chino',
    'Nahuatl',
    'Maya',
    'Lengua inventada',
    'Sin idiomas secundarios',
  ],
  'format_primary': [
    'Texto',
    'Imagen digital',
    'Imagen fisica',
    'Audio',
    'Video',
    'Comic',
    'Moda',
    'Juego',
    'Performance',
    'Instalacion',
    'Worldbuilding',
    'Archivo mixto',
  ],
  'format_secondary': [
    'PDF',
    'EPUB',
    'DOCX',
    'PNG',
    'JPG',
    'TIFF',
    'PSD',
    'MP3',
    'WAV',
    'MP4',
    'MOV',
    'Print',
    'Web',
    'Merch',
    'Build ejecutable',
  ],
  'duration': [
    '30 s',
    '1 min',
    '3 min',
    '5 min',
    '12 min',
    '24 min',
    '30 min',
    '45 min',
    '60 min',
    '90 min',
    'Variable',
    'No aplica',
  ],
  'dimensions': [
    '1080x1920',
    '1920x1080',
    '2048x2048',
    'A5',
    'A4',
    'A3',
    '50x70 cm',
    '60x90 cm',
    '3x3 m',
    '5x5 m',
    'A medida',
    'No definido',
  ],
  'tools_used': [
    'Atelier',
    'Cuaderno',
    'Tableta grafica',
    'iPad',
    'Camara',
    'Microfono',
    'Sintetizador',
    'Instrumento acustico',
    'Maniqui',
    'Patronaje',
    'Storyboard',
    'Moodboard',
    'Mapa mental',
    'Referencia fisica',
  ],
  'software_used': [
    'Atelier',
    'Photoshop',
    'Illustrator',
    'Clip Studio Paint',
    'Procreate',
    'Blender',
    'Ableton Live',
    'FL Studio',
    'Logic Pro',
    'DaVinci Resolve',
    'Premiere Pro',
    'Final Draft',
    'Obsidian',
    'Unity',
    'Unreal Engine',
    'Godot',
    'RenPy',
  ],
  'hardware_used': [
    'PC',
    'Mac',
    'iPad',
    'Tableta Wacom',
    'Camara mirrorless',
    'Camara analogica',
    'Lente 35mm',
    'Lente 50mm',
    'Microfono condensador',
    'Interfaz de audio',
    'Controlador MIDI',
    'Maquina de coser',
    'Luz continua',
    'Flash',
  ],
  'started_at': [
    'Hoy',
    'Esta semana',
    'Este mes',
    'Este trimestre',
    'Este ano',
    'Sin definir'
  ],
  'finished_at': [
    'Sin definir',
    'Fin de mes',
    'Proximo trimestre',
    'Este ano',
    'Cuando cierre revision'
  ],
  'current_version': [
    'v0.1',
    'v0.5',
    'v1.0',
    'Demo',
    'Alpha',
    'Beta',
    'Borrador',
    'Revision',
    'Final',
    'Edicion definitiva'
  ],
  'visual_scope': [
    'Obra individual',
    'Serie visual',
    'Artbook',
    'Coleccion de ilustraciones',
    'Concept sheet',
    'Portada',
    'Poster',
    'Key art',
    'Asset visual',
    'Estudio de personaje',
  ],
  'visual_dimensions': [
    '1080x1350',
    '1080x1920',
    '1920x1080',
    '2048x2048',
    '4K',
    'A4',
    'A3',
    '50x70 cm',
    '60x90 cm'
  ],
  'visual_resolution': [
    '72 dpi',
    '150 dpi',
    '300 dpi',
    '4K',
    '8K',
    '3000 px lado mayor',
    'Para impresion',
    'Para web'
  ],
  'visual_technique': [
    'Ilustracion digital',
    'Pintura acrilica',
    'Oleo',
    'Acuarela',
    'Tinta',
    'Carboncillo',
    'Collage',
    'Fotomontaje',
    '3D',
    'Escultura',
    'Mixta',
    'Pixel art',
    'Vectorial',
  ],
  'visual_support': [
    'Digital',
    'Lienzo',
    'Papel',
    'Madera',
    'Muro',
    'Tela',
    'Metal',
    'Objeto',
    'Impresion fine art',
    'NFT / digital collectible'
  ],
  'visual_palette': [
    'Rojo profundo',
    'Negro',
    'Dorado viejo',
    'Marfil',
    'Gris humo',
    'Verde militar',
    'Azul electrico',
    'Neon',
    'Tierra',
    'Monocromo',
    'Alto contraste'
  ],
  'visual_materials': [
    'Acrilico',
    'Oleo',
    'Acuarela',
    'Tinta',
    'Carboncillo',
    'Grafito',
    'Pastel',
    'Papel algodon',
    'Lienzo',
    'Tela',
    'Metal',
    'Madera',
    'Resina'
  ],
  'music_track_count': ['1', '3', '5', '8', '10', '12', '15', 'Variable'],
  'music_duration': [
    '0:30',
    '1:30',
    '2:30',
    '3:30',
    '5:00',
    '12:00',
    '30:00',
    '45:00',
    'Variable'
  ],
  'music_bpm': [
    '60',
    '70',
    '80',
    '90',
    '100',
    '110',
    '120',
    '128',
    '140',
    '160'
  ],
  'music_key': [
    'C',
    'Cm',
    'D',
    'Dm',
    'E',
    'Em',
    'F',
    'G',
    'Gm',
    'A',
    'Am',
    'Bb',
    'Bbm',
    'Modal',
    'Atonal'
  ],
  'music_structure': [
    'Intro, verso, coro, puente, outro',
    'Intro, verso, pre-coro, coro, verso, coro, outro',
    'A/B/A',
    'Suite',
    'Tema y variaciones',
    'Ambient loop',
    'Score por escenas',
    'Tracklist conceptual',
  ],
  'music_instruments': [
    'Piano',
    'Cuerdas',
    'Synth',
    'Bajo',
    'Guitarra',
    'Bateria',
    'Percusion',
    'Coros',
    'Voz',
    'Metales',
    'Maderas',
    'Field recording',
    'Sampler'
  ],
  'music_vocals': [
    'Voz principal',
    'Coros',
    'Dueto',
    'Narracion',
    'Voz procesada',
    'Voces ambientales',
    'Instrumental',
    'Sin voz'
  ],
  'video_duration': [
    '15 s',
    '30 s',
    '1 min',
    '3 min',
    '5 min',
    '12 min',
    '24 min',
    '45 min',
    '90 min'
  ],
  'video_format': [
    'Corto',
    'Videoclip',
    'Trailer',
    'Teaser',
    'Documental',
    'Animacion',
    'Reel',
    'Video ensayo',
    'Piloto',
    'Making of'
  ],
  'video_resolution': [
    '720p',
    '1080p',
    '2K',
    '4K',
    '8K',
    'Vertical 9:16',
    'Cuadrado 1:1'
  ],
  'video_aspect_ratio': ['16:9', '9:16', '1:1', '4:3', '2.39:1', '21:9'],
  'video_fps': ['24', '25', '30', '48', '60', '120'],
  'video_locations': [
    'Estudio',
    'Azotea',
    'Calle nocturna',
    'Interior',
    'Exterior',
    'Bosque',
    'Bodega',
    'Galeria',
    'Set construido',
    'Locacion virtual'
  ],
  'video_casting': [
    'Protagonista',
    'Antagonista',
    'Extra',
    'Voz en off',
    'Modelo',
    'Bailarin',
    'Performer',
    'Doble',
    'Cameo',
    'Sin casting'
  ],
  'video_shooting_plan': [
    'Guion, storyboard, shot list, rodaje, edicion',
    'Una jornada',
    'Dos jornadas',
    'Rodaje nocturno',
    'Rodaje en estudio',
    'Produccion remota'
  ],
  'comic_format': [
    'Manga',
    'Webtoon',
    'Comic occidental',
    'Novela grafica',
    'One-shot',
    'Fanzine',
    'Tira',
    'Storyboard comic'
  ],
  'comic_pages': ['8', '12', '16', '24', '32', '48', '96', '120', 'Variable'],
  'comic_panels': [
    '24',
    '48',
    '72',
    '96',
    'Flexible',
    'Por pagina',
    'Vertical continuo'
  ],
  'comic_art_style': [
    'Blanco y negro',
    'Color',
    'Lineart limpio',
    'Painterly',
    'Manga screentone',
    'Noir',
    'Cartoon',
    'Semi realista',
    'Experimental'
  ],
  'comic_script_stage': [
    'Sinopsis',
    'Escaleta',
    'Guion',
    'Storyboard',
    'Boceto',
    'Entintado',
    'Color',
    'Rotulacion',
    'Final'
  ],
  'comic_lettering': [
    'Pendiente',
    'Manual',
    'Digital',
    'Con efectos',
    'Final',
    'No aplica'
  ],
  'photo_session_type': [
    'Retrato',
    'Editorial',
    'Producto',
    'Urbana',
    'Moda',
    'Evento',
    'Documental',
    'Conceptual',
    'Autorretrato',
    'Still life'
  ],
  'photo_camera': [
    'Mirrorless',
    'DSLR',
    'Analogica 35mm',
    'Medio formato',
    'Movil',
    'Instantanea',
    'Camara de cine',
    'Por definir'
  ],
  'photo_lens': [
    '24mm',
    '35mm',
    '50mm',
    '85mm',
    '100mm macro',
    '24-70mm',
    '70-200mm',
    'Gran angular',
    'Telefoto'
  ],
  'photo_location': [
    'Estudio',
    'Exterior',
    'Calle',
    'Interior',
    'Naturaleza',
    'Azotea',
    'Galeria',
    'Casa',
    'Locacion rentada',
    'Por definir'
  ],
  'photo_model': [
    'Modelo confirmado',
    'Autorretrato',
    'Cliente',
    'Performer',
    'Producto',
    'Sin modelo',
    'Por confirmar'
  ],
  'photo_lighting': [
    'Natural',
    'Flash',
    'Luz continua',
    'Neon',
    'Low key',
    'High key',
    'Contraluz',
    'Rembrandt',
    'Softbox',
    'Experimental'
  ],
  'photo_count': ['12', '24', '36', '60', '100', 'Variable'],
  'photo_final_selection': ['3', '6', '9', '12', '24', 'Variable'],
  'photo_permissions': [
    'Release de modelo',
    'Permiso de locacion',
    'Uso editorial',
    'Uso comercial',
    'Credito obligatorio',
    'Sin permisos pendientes'
  ],
  'fashion_garment_type': [
    'Chaqueta',
    'Playera',
    'Camisa',
    'Pantalon',
    'Falda',
    'Vestido',
    'Abrigo',
    'Accesorio',
    'Bolsa',
    'Calzado',
    'Joyeria',
    'Prenda experimental'
  ],
  'fashion_collection': [
    'Drop',
    'Capsula',
    'Lookbook',
    'Prenda unica',
    'Coleccion completa',
    'Prototipo',
    'Sample',
    'Edicion limitada'
  ],
  'fashion_season': [
    'SS',
    'FW',
    'Resort',
    'Pre-fall',
    'Temporada 0',
    'Atemporal',
    'Drop mensual'
  ],
  'fashion_sizes': [
    'XS-XL',
    'XXS-XXL',
    'Unitalla',
    'Tallas extendidas',
    'A medida',
    'Sample size',
    'Por definir'
  ],
  'fashion_materials': [
    'Algodon',
    'Denim',
    'Cuero vegano',
    'Nylon',
    'Lana',
    'Lino',
    'Seda',
    'Poliester reciclado',
    'Metal',
    'Vinil',
    'Mesh',
    'Material experimental'
  ],
  'fashion_colors': [
    'Negro',
    'Rojo',
    'Marfil',
    'Gris',
    'Verde militar',
    'Azul noche',
    'Dorado',
    'Plateado',
    'Monocromo',
    'Paleta por definir'
  ],
  'fashion_supplier': [
    'Local',
    'Proveedor externo',
    'Taller propio',
    'Maquila',
    'Artesano',
    'Por definir'
  ],
  'fashion_sku': [
    'SKU pendiente',
    'DROP-001',
    'LOOK-001',
    'SAMPLE-001',
    'CAPSULE-001'
  ],
  'fashion_cost': ['250', '500', '1000', '2500', '5000'],
  'fashion_price': ['799', '1299', '1999', '2999', '4999'],
  'game_engine': [
    'Unity',
    'Unreal Engine',
    'Godot',
    'RenPy',
    'RPG Maker',
    'GameMaker',
    'Flutter',
    'Web',
    'Custom engine'
  ],
  'game_platforms': [
    'PC',
    'Mobile',
    'Web',
    'Steam',
    'Itch.io',
    'Android',
    'iOS',
    'Console',
    'VR',
    'AR'
  ],
  'game_playable_genre': [
    'RPG',
    'Visual novel',
    'Puzzle',
    'Narrativo',
    'Aventura',
    'Point and click',
    'Terror',
    'Simulador',
    'Estrategia',
    'Plataformas'
  ],
  'game_mechanics': [
    'Dialogos ramificados',
    'Inventario',
    'Combate',
    'Exploracion',
    'Misiones',
    'Crafting',
    'Sistema moral',
    'Romance',
    'Gestion',
    'Puzzles',
    'Stealth'
  ],
  'game_levels': [
    'Demo',
    'Capitulo 1',
    '3 niveles',
    'Vertical slice',
    'Tutorial',
    'Mapa abierto',
    'Hub central',
    'Final jugable'
  ],
  'game_build': [
    'Prototype',
    'Pre-alpha',
    'Alpha',
    'Beta',
    'Release candidate',
    'Demo publica',
    'Version final'
  ],
  'game_mode': [
    'Single player',
    'Co-op',
    'Online',
    'Local multiplayer',
    'Narrativo',
    'Sandbox',
    'Episodico'
  ],
  'stage_acts': [
    '1 acto',
    '2 actos',
    '3 actos',
    'Performance continua',
    'Escenas sueltas',
    'Improvisacion guiada'
  ],
  'stage_duration': [
    '10 min',
    '20 min',
    '30 min',
    '45 min',
    '60 min',
    '90 min',
    'Variable'
  ],
  'stage_cast': [
    'Solista',
    'Dueto',
    'Trio',
    'Ensamble',
    'Reparto completo',
    'Coro',
    'Performer invitado'
  ],
  'stage_blocking': [
    'Centro',
    'Frontal',
    'Circular',
    'Inmersivo',
    'Pasarela',
    'Multinivel',
    'Recorrido',
    'Libre'
  ],
  'stage_costumes': [
    'Negro',
    'Ritual',
    'Urbano',
    'Formal',
    'Historico',
    'Experimental',
    'Mascara',
    'Minimalista'
  ],
  'stage_lighting': [
    'Contraluz',
    'Rojo',
    'Frio',
    'Calido',
    'Estrobos',
    'Spot',
    'Silueta',
    'Sombras',
    'Natural'
  ],
  'stage_rehearsals': [
    '1 semanal',
    '2 semanales',
    '3 semanales',
    'Intensivo',
    'Ensayo tecnico',
    'Ensayo general'
  ],
  'space_type': [
    'Instalacion',
    'Galeria',
    'Set',
    'Interior',
    'Pop-up',
    'Cafeteria',
    'Exhibicion',
    'Escaparate',
    'Stand'
  ],
  'space_dimensions': [
    '3x3 m',
    '5x5 m',
    '10x10 m',
    'Habitacion',
    'Galeria completa',
    'Por definir'
  ],
  'space_zones': [
    'Entrada',
    'Recorrido',
    'Punto focal',
    'Backstage',
    'Zona de venta',
    'Zona inmersiva',
    'Photo spot',
    'Archivo'
  ],
  'space_materials': [
    'Metal',
    'Concreto',
    'Vidrio',
    'Tela',
    'Madera',
    'Acrilico',
    'Papel',
    'Luz',
    'Pantallas',
    'Material reciclado'
  ],
  'space_furniture': [
    'Mesas',
    'Sillas',
    'Vitrinas',
    'Modulos',
    'Paneles',
    'Barras',
    'Bancos',
    'Estantes',
    'Pedestales'
  ],
  'space_people_flow': [
    'Lineal',
    'Circular',
    'Libre',
    'Controlado',
    'Por estaciones',
    'Inmersivo',
    'Entrada-salida'
  ],
  'space_budget': ['5000', '10000', '25000', '50000', '100000'],
  'space_suppliers': [
    'Carpinteria',
    'Iluminacion',
    'Impresion',
    'Montaje',
    'Audio',
    'Video',
    'Mobiliario',
    'Seguridad'
  ],
  'world_scope': [
    'Habitacion',
    'Ciudad',
    'Region',
    'Pais',
    'Planeta',
    'Sistema solar',
    'Multiverso',
    'Linea temporal',
    'Civilizacion'
  ],
  'world_regions': [
    'Distrito central',
    'Frontera',
    'Ruinas',
    'Capital',
    'Zona industrial',
    'Barrio sagrado',
    'Bosque',
    'Desierto',
    'Costa',
    'Subsuelo'
  ],
  'world_factions': [
    'Gobierno',
    'Culto',
    'Corporacion',
    'Rebeldes',
    'Familia',
    'Gremio',
    'Orden religiosa',
    'Ejercito',
    'Comunidad marginal'
  ],
  'world_systems': [
    'Magia',
    'Tecnologia',
    'Politica',
    'Economia',
    'Religion',
    'Idioma',
    'Clases sociales',
    'Educacion',
    'Transporte',
    'Ley'
  ],
  'world_timeline': [
    'Era antigua',
    'Fundacion',
    'Crisis',
    'Presente',
    'Futuro',
    'Postcolapso',
    'Linea alterna'
  ],
  'world_maps': [
    'Mapa politico',
    'Mapa fisico',
    'Plano urbano',
    'Mapa de rutas',
    'Mapa de facciones',
    'Mapa historico'
  ],
  'world_rules': [
    'Reglas de magia',
    'Limites tecnologicos',
    'Leyes politicas',
    'Normas sociales',
    'Sistema economico',
    'Tabues culturales'
  ],
  'writing_estimated_words': [
    '1000',
    '5000',
    '15000',
    '50000',
    '80000',
    '120000'
  ],
  'writing_estimated_chapters': ['1', '5', '8', '12', '24', '36', 'Variable'],
  'writing_narrator': [
    'Primera persona',
    'Segunda persona',
    'Tercera limitada',
    'Tercera omnisciente',
    'Multiple',
    'Epistolar',
    'Experimental'
  ],
  'writing_tense': ['Pasado', 'Presente', 'Futuro', 'Mixto', 'Experimental'],
  'linked_world': [
    'Mundiarium principal',
    'Nuevo universo',
    'Universo existente',
    'Linea alterna',
    'Sin vincular'
  ],
  'linked_saga': [
    'Saga principal',
    'Spin-off',
    'Precuela',
    'Secuela',
    'Antologia',
    'Sin saga'
  ],
  'linked_series': [
    'Serie principal',
    'Temporada 1',
    'Temporada 2',
    'Linea editorial',
    'Miniserie',
    'Sin serie'
  ],
  'linked_collection': [
    'Coleccion privada',
    'Drop',
    'Archivo Aeternum',
    'Capsula',
    'Exhibicion',
    'Sin coleccion'
  ],
  'internal_timeline': [
    'Antes del canon',
    'Canon principal',
    'Despues del canon',
    'Linea alterna',
    'Futuro remoto',
    'Pasado mitico'
  ],
  'internal_period': [
    'Era fundacional',
    'Crisis',
    'Guerra',
    'Postcolapso',
    'Renacimiento',
    'Era industrial',
    'Era digital'
  ],
  'linked_city_region': [
    'Distrito 0',
    'Capital',
    'Frontera',
    'Ruinas',
    'Zona norte',
    'Costa',
    'Subsuelo',
    'Ciudad principal'
  ],
  'related_characters': [
    'Protagonista',
    'Antagonista',
    'Mentor',
    'Aliado',
    'Familia',
    'Coro',
    'Figura historica',
    'Personaje secundario'
  ],
  'related_places': [
    'Ciudad',
    'Casa',
    'Templo',
    'Estudio',
    'Bosque',
    'Mercado',
    'Fabrica',
    'Escuela',
    'Santuario'
  ],
  'related_events': [
    'Incidente inicial',
    'Climax',
    'Ritual',
    'Guerra',
    'Fundacion',
    'Traicion',
    'Desaparicion',
    'Revelacion'
  ],
  'related_factions': [
    'Orden',
    'Corporacion',
    'Familia',
    'Colectivo',
    'Culto',
    'Estado',
    'Rebeldes',
    'Gremio'
  ],
  'main_theme': [
    'Identidad',
    'Memoria',
    'Poder',
    'Duelo',
    'Deseo',
    'Fe',
    'Cuerpo',
    'Ciudad',
    'Legado',
    'Libertad',
    'Control'
  ],
  'secondary_themes': [
    'Familia',
    'Traicion',
    'Amor',
    'Venganza',
    'Comunidad',
    'Exilio',
    'Tecnologia',
    'Ritual',
    'Clase social',
    'Metamorfosis'
  ],
  'emotional_tone': [
    'Oscuro',
    'Melancolico',
    'Esperanzador',
    'Violento',
    'Intimo',
    'Epico',
    'Romantico',
    'Satirico',
    'Misterioso',
    'Contemplativo'
  ],
  'atmosphere': [
    'Nocturna',
    'Industrial',
    'Intima',
    'Ritual',
    'Onirica',
    'Urbana',
    'Sagrada',
    'Opresiva',
    'Calida',
    'Apocaliptica'
  ],
  'aesthetic': [
    'Cyberpunk',
    'Gotico moderno',
    'Dark academia',
    'Brutalista',
    'Industrial',
    'Barroco',
    'Mexica futurista',
    'Streetwear oscuro',
    'Folk futurista',
    'Minimalista editorial'
  ],
  'inspirations': [
    'Arquitectura brutalista',
    'Mitologia mexica',
    'Neon rojo',
    'Archivo familiar',
    'Musica ritual',
    'Cine noir',
    'Moda urbana',
    'Ruinas industriales',
    'Pintura barroca'
  ],
  'references': [
    'Moodboard',
    'Playlist',
    'Archivo visual',
    'Bibliografia',
    'Storyboard',
    'Lookbook',
    'Notas de campo',
    'Archivo fotografico',
    'Ensayo teorico'
  ],
  'symbols': [
    'Cuervo',
    'Llave',
    'Mascara',
    'Ciudad',
    'Fuego',
    'Agua',
    'Espejo',
    'Ojo',
    'Flor',
    'Corona',
    'Puerta'
  ],
  'central_message': [
    'La memoria tambien es territorio.',
    'Crear es resistir la desaparicion.',
    'El cuerpo guarda la historia.',
    'La ciudad tambien suena.',
    'Todo legado necesita forma.'
  ],
  'primary_creator': [
    'Yo',
    'Estudio Corvus',
    'Colectivo',
    'Coautoria',
    'Comisionado',
    'Por definir'
  ],
  'collaborators': [
    'Editor',
    'Ilustrador',
    'Productor',
    'Fotografo',
    'Modelo',
    'Compositor',
    'Vocalista',
    'Director',
    'Animador',
    'Colorista',
    'Traductor',
    'Lector beta',
    'Consultor'
  ],
  'credits': [
    'Direccion',
    'Guion',
    'Edicion',
    'Musica',
    'Arte',
    'Produccion',
    'Fotografia',
    'Vestuario',
    'Diseno sonoro',
    'Color',
    'Traduccion',
    'Correccion',
    'Asistencia'
  ],
  'collaborator_permissions': [
    'Puede ver',
    'Puede comentar',
    'Puede editar',
    'Puede subir assets',
    'Puede aprobar',
    'Puede publicar',
    'Puede administrar colaboradores'
  ],
  'rights_holder': [
    'Yo',
    'Estudio Corvus',
    'Coautoria',
    'Cliente',
    'Editorial',
    'Sello musical',
    'Colectivo',
    'Por definir'
  ],
  'property_type': [
    'Obra original',
    'Obra derivada',
    'Fanwork',
    'Dominio publico',
    'Comision',
    'Licencia compartida',
    'Adaptacion'
  ],
  'commercial_use': [
    'Permitido',
    'No permitido',
    'Requiere autorizacion',
    'Solo con contrato',
    'Solo edicion limitada'
  ],
  'derivative_use': [
    'Permitido',
    'No permitido',
    'Con credito',
    'Con autorizacion previa',
    'Solo uso interno'
  ],
  'external_registration': [
    'Pendiente',
    'ISBN',
    'ISRC',
    'Registro autoral',
    'SKU',
    'Contrato editorial',
    'Contrato musical',
    'Registro de marca'
  ],
  'identifier_code': [
    'ISBN pendiente',
    'ISRC pendiente',
    'SKU pendiente',
    'Codigo interno',
    'Registro pendiente',
    'Sin codigo'
  ],
  'publication_plan': [
    'Guardar como borrador',
    'Enviar a revision',
    'Publicar teaser',
    'Publicar oficialmente',
    'Programar publicacion',
    'Enviar a Corvus Publishing',
    'Agregar a coleccion',
    'Convertir en entrada de feed'
  ],
  'publish_date': [
    'Hoy',
    'Esta semana',
    'Fin de mes',
    'Proximo trimestre',
    'Programar despues',
    'Sin fecha publica'
  ],
  'availability': [
    'Siempre disponible',
    'Temporal',
    'Edicion limitada',
    'Solo miembros',
    'Solo seguidores',
    'Privada',
    'Por invitacion'
  ],
  'collection_target': [
    'Sin coleccion',
    'Archivo Aeternum',
    'Coleccion privada',
    'Drop',
    'Saga',
    'Exhibicion',
    'Antologia'
  ],
  'price': ['0', '49', '99', '149', '299', '499', '999', '1999'],
  'currency': ['MXN', 'USD', 'EUR', 'GBP', 'JPY', 'BRL'],
  'stock': ['Ilimitado', '1', '10', '25', '50', '100', 'Por pedido'],
  'limited_units': ['10', '25', '50', '100', '250', '500'],
  'platform_fee': ['0', '5%', '10%', '15%', '20%'],
  'production_cost': ['0', '250', '500', '1000', '2500', '5000'],
  'estimated_margin': ['10%', '20%', '30%', '40%', '50%', '60%', '70%'],
};

const branchAeternumFieldSuggestions = <String, Map<String, List<String>>>{
  'writing': {
    'style': [
      'Narrativo',
      'Lirico',
      'Fragmentario',
      'Epistolar',
      'Cinematografico',
      'Experimental',
      'Intimo',
      'Gotico',
      'Documental',
      'Mitologico',
    ],
    'artistic_movement': [
      'Realismo magico',
      'Gotico moderno',
      'Dark academia',
      'Realismo sucio',
      'Postmodernismo',
      'Romanticismo oscuro',
      'Cyberpunk literario',
      'Mexica futurista',
    ],
    'creative_format': [
      'Novela',
      'Cuento',
      'Poema',
      'Ensayo',
      'Guion',
      'Cronica',
      'Antologia',
      'Saga',
      'Serial',
    ],
    'target_audience': [
      'Lectores joven adulto',
      'Lectores adultos',
      'Lectores de fantasia',
      'Lectores de ciencia ficcion',
      'Lectores literarios',
      'Lectores de terror',
      'Clubes de lectura',
    ],
  },
  'visual': {
    'style': [
      'Painterly',
      'Lineart limpio',
      'Editorial',
      'Minimalista',
      'Surreal',
      'Cinematografico',
      'Brutalista',
      'Conceptual',
    ],
    'artistic_movement': [
      'Surrealismo',
      'Brutalismo',
      'Arte conceptual',
      'Postinternet',
      'Gotico moderno',
      'Expresionismo',
      'Retrofuturismo',
    ],
    'creative_format': [
      'Ilustracion',
      'Pintura',
      'Poster',
      'Portada',
      'Artbook',
      'Concept sheet',
      'Serie visual',
      'Pieza unica',
    ],
    'target_audience': [
      'Coleccionistas',
      'Clientes editoriales',
      'Fans del universo',
      'Galerias',
      'Publico digital',
      'Marcas',
      'Directores de arte',
    ],
  },
  'music': {
    'style': [
      'Cinematografico',
      'Ambiental',
      'Industrial',
      'Melancolico',
      'Ritual',
      'Orquestal',
      'Lo-fi',
      'Experimental',
    ],
    'artistic_movement': [
      'Darkwave',
      'Synthwave',
      'Post-rock',
      'Industrial',
      'Electronica experimental',
      'Folk oscuro',
      'Neoclasico',
    ],
    'creative_format': [
      'Cancion',
      'Album',
      'EP',
      'Demo',
      'Score',
      'Tema de personaje',
      'Live session',
      'Loop',
    ],
    'target_audience': [
      'Oyentes de soundtrack',
      'Fans del universo',
      'Curadores musicales',
      'Productores audiovisuales',
      'Publico alternativo',
      'Oyentes de ambient',
    ],
  },
  'video': {
    'style': [
      'Cinematografico',
      'Documental',
      'Nocturno',
      'Experimental',
      'Editorial',
      'Vertical',
      'Found footage',
      'Atmosferico',
    ],
    'artistic_movement': [
      'Videoarte',
      'Cine independiente',
      'Surrealismo',
      'Realismo social',
      'Cyberpunk',
      'Nuevo documental',
    ],
    'creative_format': [
      'Cortometraje',
      'Videoclip',
      'Documental',
      'Animacion',
      'Trailer',
      'Teaser',
      'Reel narrativo',
    ],
    'target_audience': [
      'Festivales',
      'Publico digital',
      'Fans del universo',
      'Marcas',
      'Productoras',
      'Comunidad audiovisual',
    ],
  },
  'comic': {
    'style': [
      'Manga',
      'Noir',
      'Lineart limpio',
      'Blanco y negro',
      'Color editorial',
      'Semi realista',
      'Experimental',
    ],
    'artistic_movement': [
      'Manga contemporaneo',
      'Comic independiente',
      'Novela grafica literaria',
      'Underground',
      'Webtoon',
      'Noir grafico',
    ],
    'creative_format': [
      'One-shot',
      'Capitulo',
      'Tomo',
      'Webtoon',
      'Novela grafica',
      'Fanzine',
      'Storyboard comic',
    ],
    'target_audience': [
      'Lectores de manga',
      'Lectores de webtoon',
      'Fans de novela grafica',
      'Comunidad indie',
      'Lectores joven adulto',
    ],
  },
  'photo': {
    'style': [
      'Editorial',
      'Fine art',
      'Urbano',
      'Nocturno',
      'Conceptual',
      'Documental',
      'Minimalista',
    ],
    'artistic_movement': [
      'Fotografia documental',
      'Fotografia conceptual',
      'Street photography',
      'Moda editorial',
      'Fine art contemporaneo',
    ],
    'creative_format': [
      'Serie fotografica',
      'Retrato',
      'Campana',
      'Lookbook',
      'Ensayo fotografico',
      'Archivo visual',
    ],
    'target_audience': [
      'Galerias',
      'Marcas',
      'Editoriales',
      'Coleccionistas',
      'Publico digital',
      'Agencias creativas',
    ],
  },
  'fashion': {
    'style': [
      'Streetwear',
      'Techwear',
      'Avant-garde',
      'Minimalista',
      'Utilitario',
      'Gotico',
      'Experimental',
    ],
    'artistic_movement': [
      'Moda conceptual',
      'Techwear',
      'Streetwear contemporaneo',
      'Alta costura experimental',
      'Slow fashion',
    ],
    'creative_format': [
      'Prenda',
      'Coleccion',
      'Drop',
      'Lookbook',
      'Capsula',
      'Accesorio',
      'Prototipo',
    ],
    'target_audience': [
      'Clientes de moda',
      'Coleccionistas',
      'Streetwear',
      'Editoriales',
      'Compradores boutique',
      'Fans del universo',
    ],
  },
  'game': {
    'style': [
      'Narrativo',
      'Atmosferico',
      'Pixel art',
      'Low poly',
      'Cinematografico',
      'Oscuro',
      'Tactico',
      'Experimental',
    ],
    'artistic_movement': [
      'Indie narrativo',
      'Immersive sim',
      'Interactive fiction',
      'Survival horror',
      'Game art experimental',
    ],
    'creative_format': [
      'Demo',
      'Vertical slice',
      'Prototipo',
      'Capitulo',
      'Build jugable',
      'Visual novel',
      'Campana RPG',
    ],
    'target_audience': [
      'Jugadores narrativos',
      'Fans de RPG',
      'Fans de terror',
      'Comunidad indie',
      'Playtesters',
      'Publishers',
    ],
  },
  'stage': {
    'style': [
      'Fisico',
      'Ritual',
      'Inmersivo',
      'Minimalista',
      'Experimental',
      'Poetico',
      'Politico',
    ],
    'artistic_movement': [
      'Teatro experimental',
      'Performance art',
      'Danza contemporanea',
      'Teatro fisico',
      'Arte interdisciplinario',
    ],
    'creative_format': [
      'Obra teatral',
      'Performance',
      'Danza',
      'Monologo',
      'Lectura dramatizada',
      'Pieza inmersiva',
    ],
    'target_audience': [
      'Publico escenico',
      'Festivales',
      'Galerias',
      'Programadores culturales',
      'Comunidad artistica',
    ],
  },
  'world': {
    'style': [
      'Enciclopedico',
      'Mitologico',
      'Archivistico',
      'Politico',
      'Cosmico',
      'Urbano',
      'Sistemico',
    ],
    'artistic_movement': [
      'Worldbuilding transmedia',
      'Speculative design',
      'Lore documental',
      'Fantasia historica',
      'Ciencia ficcion social',
    ],
    'creative_format': [
      'Biblia de universo',
      'Mapa',
      'Cronologia',
      'Bestiario',
      'Sistema magico',
      'Sistema politico',
      'Archivo de facciones',
    ],
    'target_audience': [
      'Writers room',
      'Lectores de lore',
      'Fans del universo',
      'Jugadores de rol',
      'Equipo transmedia',
    ],
  },
};

List<String> suggestionsForAeternumField(String key) {
  return aeternumFieldSuggestions[key] ?? const [];
}

bool shouldAppendAeternumSuggestion(String key) {
  return appendableSuggestionKeys.contains(key);
}

Map<String, List<String>> glossaryForBranch(String branchId) {
  return genreSubgenreGlossaryByBranch[branchId] ??
      genreSubgenreGlossaryByBranch['writing']!;
}

String normalizeGlossaryKey(String value) {
  return value.trim().toLowerCase();
}

List<String> genreSuggestionsForBranch(String branchId) {
  return glossaryForBranch(branchId).keys.toList(growable: false);
}

List<String> subgenreSuggestionsForGenre(String branchId, String genre) {
  final normalizedGenre = normalizeGlossaryKey(genre);
  if (normalizedGenre.isEmpty) return const [];

  final glossary = glossaryForBranch(branchId);
  for (final entry in glossary.entries) {
    if (normalizeGlossaryKey(entry.key) == normalizedGenre) {
      return entry.value;
    }
  }

  final matches = <String>[];
  for (final entry in glossary.entries) {
    final normalizedKey = normalizeGlossaryKey(entry.key);
    if (normalizedKey.startsWith(normalizedGenre) ||
        normalizedKey.contains(normalizedGenre) ||
        normalizedGenre.contains(normalizedKey)) {
      matches.addAll(entry.value);
    }
  }

  return matches.toSet().toList(growable: false);
}

List<String> classificationSuggestionsForField(
  String key,
  String branchId,
  String genre,
) {
  if (key == 'subgenre') {
    return subgenreSuggestionsForGenre(branchId, genre);
  }

  return branchAeternumFieldSuggestions[branchId]?[key] ??
      suggestionsForAeternumField(key);
}
