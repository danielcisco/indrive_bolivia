package com.example.indrive_app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity, no FlutterActivity (sprint extra: bloqueo
// local con huella) — local_auth necesita una FragmentActivity para
// mostrar el diálogo nativo de biometría; con FlutterActivity el plugin
// falla en tiempo de ejecución al pedir autenticación.
class MainActivity : FlutterFragmentActivity()
