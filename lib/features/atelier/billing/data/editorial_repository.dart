import '../../../../core/supabase_config.dart';
import '../domain/manuscript.dart';

/// La ficha de producción editorial de un proyecto.
///
/// Guarda las páginas de cortesía —copyright, dedicatoria, agradecimientos,
/// ISBN— que los formatos de producción escriben en el libro. Si el plan no
/// incluye producción editorial, la fila simplemente no existe y los
/// exportadores se saltan esas páginas sin quejarse.
class EditorialRepository {
  Future<ManuscriptFrontMatter> fetchFrontMatter(String projectId) async {
    final row = await supabase
        .from('atelier_editorial_profiles')
        .select()
        .eq('project_id', projectId)
        .maybeSingle();

    if (row == null) return const ManuscriptFrontMatter();

    return ManuscriptFrontMatter.fromMap(Map<String, dynamic>.from(row));
  }

  /// Crea o actualiza la ficha. El trigger de Postgres rechaza la escritura si
  /// el plan no incluye producción editorial, así que aquí no hace falta
  /// comprobarlo: basta con dejar subir el error traducido.
  Future<void> saveFrontMatter({
    required String projectId,
    required ManuscriptFrontMatter frontMatter,
    bool manuscriptMode = true,
  }) async {
    await supabase.from('atelier_editorial_profiles').upsert({
      'project_id': projectId,
      'manuscript_mode': manuscriptMode,
      'copyright_notice': frontMatter.copyrightNotice,
      'dedication': frontMatter.dedication,
      'acknowledgements': frontMatter.acknowledgements,
      if (frontMatter.isbn.isNotEmpty) 'isbn': frontMatter.isbn,
      'front_matter': {
        'publisher': frontMatter.publisher,
        'table_of_contents': frontMatter.includeTableOfContents,
      },
    }, onConflict: 'project_id');
  }
}
