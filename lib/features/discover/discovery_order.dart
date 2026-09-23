import '../../models/work.dart';

/// Afinidad explícita con las disciplinas del perfil, dentro de los resultados
/// públicos recuperados. En empates conserva el orden del archivo.
List<Work> orderDiscoveryWorks(List<Work> works, Iterable<String> disciplines) {
  final preferred = disciplines.map((value) => value.toLowerCase()).toSet();
  final unique = {for (final work in works) work.id: work}.values.toList();
  return [
    ...unique
        .where((work) => preferred.contains(work.discipline.toLowerCase())),
    ...unique
        .where((work) => !preferred.contains(work.discipline.toLowerCase())),
  ];
}
