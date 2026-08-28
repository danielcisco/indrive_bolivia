import 'package:flutter/material.dart';

import '../domain/marcas_vehiculo.dart';

/// Selector de color de vehículo (Sprint 20) — lista de swatches, cada
/// fila con el círculo de color real al lado del nombre.
Future<String?> mostrarSelectorColorVehiculo(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Color del vehículo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: coloresVehiculo.length,
              itemBuilder: (context, index) {
                final (nombre, colorHex) = coloresVehiculo[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(colorHex),
                    radius: 12,
                  ),
                  title: Text(nombre),
                  onTap: () => Navigator.of(context).pop(nombre),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
