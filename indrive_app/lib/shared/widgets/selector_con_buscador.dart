import 'package:flutter/material.dart';

/// Selector desplegable con buscador (Sprint 20) — pantalla completa con
/// un campo de filtro arriba y la lista abajo, agrupada por letra
/// inicial. Genérico: se usa para marca de vehículo, y sirve para
/// cualquier selector de lista larga que necesite la app más adelante.
Future<String?> mostrarSelectorConBuscador(
  BuildContext context, {
  required String titulo,
  required List<String> opciones,
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => _SelectorConBuscador(titulo: titulo, opciones: opciones),
    ),
  );
}

class _SelectorConBuscador extends StatefulWidget {
  const _SelectorConBuscador({required this.titulo, required this.opciones});

  final String titulo;
  final List<String> opciones;

  @override
  State<_SelectorConBuscador> createState() => _SelectorConBuscadorState();
}

class _SelectorConBuscadorState extends State<_SelectorConBuscador> {
  final _filtroController = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _filtroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordenadas = [...widget.opciones]..sort();
    final filtradas = _filtro.isEmpty
        ? ordenadas
        : ordenadas
              .where((o) => o.toLowerCase().contains(_filtro.toLowerCase()))
              .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _filtroController,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Empezá a escribir',
              ),
              onChanged: (valor) => setState(() => _filtro = valor),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtradas.length,
              itemBuilder: (context, index) {
                final opcion = filtradas[index];
                return ListTile(
                  title: Text(opcion),
                  onTap: () => Navigator.of(context).pop(opcion),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
