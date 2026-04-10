class LogEntry {
  int? id;
  String timestamp;
  String projeto;
  String descricao;
  int? duracaoMinutos;
  String categoria;
  String tipo;
  String? conteudo;
  String? tags;
  LogEntry({
    this.id,
    required this.timestamp,
    required this.projeto,
    required this.descricao,
    this.duracaoMinutos,
    required this.categoria,
    required this.tipo,
    this.conteudo,
    this.tags,
  });

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['id'],
      timestamp: map['timestamp'],
      projeto: map['projeto'],
      descricao: map['descricao'],
      duracaoMinutos: map['duracao_minutos'],
      categoria: map['categoria'],
      tipo: map['tipo'],
      conteudo: map['conteudo'],
      tags: map['tags'],
    );
  }

  Map<String, dynamic> toMap({bool withId = false}) {
    final map = {
      'timestamp': timestamp,
      'projeto': projeto,
      'descricao': descricao,
      'duracao_minutos': duracaoMinutos,
      'categoria': categoria,
      'tipo': tipo,
      'conteudo': conteudo,
      'tags': tags,
    };
    if (withId && id != null) map['id'] = id;
    return map;
  }
}
