import 'package:flutter/material.dart';

/// `Image.network` con estado de carga y de error — sin esto, una foto
/// lenta o rota (comprobante QR, cédula, foto de paquete) deja el espacio
/// en blanco o el ícono roto genérico de Flutter, sin ningún indicio para
/// el usuario, algo que pesa más en un contexto de conectividad real de
/// frontera que en uno ideal.
class RedNetworkImage extends StatelessWidget {
  const RedNetworkImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, progreso) {
        if (progreso == null) return child;
        return SizedBox(
          width: width,
          height: height,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progreso.expectedTotalBytes != null
                  ? progreso.cumulativeBytesLoaded /
                        progreso.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => Container(
        width: width,
        height: height,
        color: scheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
