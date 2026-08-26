import 'package:flutter/material.dart';

import '../../../../shared/widgets/session_status_view.dart';
import 'gestion_usuarios_screen.dart';
import 'kyc_pending_screen.dart';
import 'live_map_screen.dart';
import 'pagos_pendientes_screen.dart';

/// Shell del panel Admin (Sprint 5.1): navegación entre Mapa en vivo y
/// Verificación KYC. `SessionStatusView` (rol/verificación + cerrar
/// sesión) queda accesible desde el ícono de cuenta del AppBar en vez de
/// ocupar toda la pantalla, como antes de este sprint.
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _destinoSeleccionado = 0;

  static const _pantallas = [
    LiveMapScreen(),
    KycPendingScreen(),
    PagosPendientesScreen(),
    GestionUsuariosScreen(),
  ];
  static const _titulos = [
    'Mapa en vivo',
    'Verificación KYC',
    'Pagos QR',
    'Usuarios',
  ];

  void _abrirSesion(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        content: const SessionStatusView(
          appLabel: 'Panel de Administración — Villazón, Potosí',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'inDrive Entregas — ${_titulos[_destinoSeleccionado]}',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Cuenta',
            onPressed: () => _abrirSesion(context),
          ),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _destinoSeleccionado,
            onDestinationSelected: (index) =>
                setState(() => _destinoSeleccionado = index),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: Text('Mapa'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user),
                label: Text('KYC'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.qr_code_outlined),
                selectedIcon: Icon(Icons.qr_code),
                label: Text('Pagos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Usuarios'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _destinoSeleccionado,
              children: _pantallas,
            ),
          ),
        ],
      ),
    );
  }
}
