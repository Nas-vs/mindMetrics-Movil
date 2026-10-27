import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/consentimiento/presentation/consentimiento_pagina.dart';
import '../../features/auth/inicio_sesion/presentation/inicio_sesion_pagina.dart';
import '../../features/auth/recuperar_contrasena/presentation/recuperar_contrasena_pagina.dart';
import '../../features/auth/recuperar_contrasena/presentation/restablecer_contrasena_pagina.dart';
import '../../features/auth/registro/presentation/registro_pagina.dart';
import '../../features/auth/verificacion/domain/argumentos_verificacion.dart';
import '../../features/auth/verificacion/presentation/verificacion_pagina.dart';
import '../../features/onboarding/games/presentation/viewmodels/games_viewmodel.dart';
import '../../features/onboarding/games/presentation/views/games_view.dart';
import '../../features/onboarding/home/presentation/viewmodels/home_viewmodel.dart';
import '../../features/onboarding/home/presentation/views/home_view.dart';
import '../../features/onboarding/profile/presentation/viewmodels/profile_viewmodel.dart';
import '../../features/onboarding/profile/presentation/views/profile_view.dart';
import '../../features/onboarding/shell/presentation/views/main_shell_view.dart';
import '../../features/onboarding/survey/presentation/views/daily_survey_view.dart';
import '../widgets/con_view_model.dart';
import 'estado_recuperacion.dart';
import 'rutas.dart';

/// Router de la app (RF-10).
///
/// [haySesion] se inyecta para poder probar el router sin Supabase.
/// [refrescar] vuelve a evaluar el redirect cuando cambia la sesión
/// (ej. al cerrar sesión se envía al usuario a /login).
/// [recuperacion] lleva el estado del enlace de recuperación (RF-06); es
/// opcional para que las pruebas que no lo usan sigan igual.
GoRouter crearRouter({
  required bool Function() haySesion,
  Listenable? refrescar,
  EstadoRecuperacion? recuperacion,
  String rutaInicial = Rutas.inicio,
}) {
  // Navigator raíz: las pantallas de profundidad se apilan aquí, ENCIMA del
  // shell, por eso no muestran la barra inferior (CA-2).
  final navegadorRaiz = GlobalKey<NavigatorState>(debugLabel: 'raiz');

  return GoRouter(
    navigatorKey: navegadorRaiz,
    initialLocation: rutaInicial,
    refreshListenable: Listenable.merge([refrescar, recuperacion]),
    redirect: (_, estado) => redirigirPorSesion(
      estado.matchedLocation,
      haySesion: haySesion(),
      recuperando: recuperacion?.activa ?? false,
      enlaceInvalido: recuperacion?.enlaceInvalido ?? false,
    ),
    routes: [
      GoRoute(
        // RF-04. `extra` opcional: aviso al llegar (ej. desde RF-05 CA-7).
        path: Rutas.login,
        builder: (context, estado) => InicioSesionPagina(
          mensajeInicial: estado.extra is String
              ? estado.extra! as String
              : null,
          onOlvidoContrasena: () => context.go(Rutas.recuperarContrasena),
        ),
      ),
      GoRoute(
        // RF-06: pedir el enlace por correo. También muestra el aviso de
        // enlace vencido o usado (CA-7).
        path: Rutas.recuperarContrasena,
        builder: (_, _) => RecuperarContrasenaPagina(
          enlaceInvalido: recuperacion?.enlaceInvalido ?? false,
          onAvisoMostrado: recuperacion?.limpiarEnlaceInvalido,
        ),
      ),
      GoRoute(
        // RF-06: nueva contraseña. Solo se llega con la sesión temporal del
        // enlace (ver redirigirPorSesion).
        path: Rutas.restablecerContrasena,
        builder: (_, _) => const RestablecerContrasenaPagina(),
      ),
      GoRoute(
        // RF-02: consentimiento informado antes de crear la cuenta.
        path: Rutas.consentimiento,
        builder: (context, _) =>
            ConsentimientoPagina(onVolver: () => context.go(Rutas.login)),
      ),
      GoRoute(
        path: Rutas.registro,
        redirect: (_, estado) {
          final version = estado.extra;
          if (version is String && version.isNotEmpty) return null;
          return Rutas.consentimiento;
        },
        builder: (context, estado) => RegistroPagina(
          versionPolitica: estado.extra! as String,
          onIniciarSesion: () => context.go(Rutas.login),
        ),
      ),
      GoRoute(
        // RF-05. Desde el registro llega el correo (String); desde el login,
        // un ArgumentosVerificacion. Sin datos (ej. al reiniciar la app, o
        // cuando el router se reevalúa al crearse la sesión) no hay a quién
        // verificar: con sesión se va al Inicio y sin sesión al login.
        path: Rutas.verificacion,
        redirect: (_, estado) {
          if (ArgumentosVerificacion.desdeExtra(estado.extra) != null) {
            return null;
          }
          return haySesion() ? Rutas.inicio : Rutas.login;
        },
        builder: (_, estado) => VerificacionPagina(
          argumentos: ArgumentosVerificacion.desdeExtra(estado.extra)!,
        ),
      ),

      // CA-1: Inicio, Juegos y Perfil son ramas del shell → muestran la barra.
      // indexedStack conserva el estado de cada pestaña al cambiar entre ellas.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.inicio,
                builder: (_, _) => ConViewModel<HomeViewModel>(
                  crear: HomeViewModel.new,
                  builder: (_, vm) => HomeView(viewModel: vm),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.juegos,
                builder: (_, _) => ConViewModel<GamesViewModel>(
                  crear: GamesViewModel.new,
                  builder: (_, vm) => GamesView(viewModel: vm),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rutas.perfil,
                builder: (_, _) => ConViewModel<ProfileViewModel>(
                  crear: ProfileViewModel.new,
                  builder: (_, vm) => ProfileView(viewModel: vm),
                ),
              ),
            ],
          ),
        ],
      ),

      // CA-2: pantallas de profundidad en el navigator raíz → sin barra.
      // Las siguientes (ej. detalle de juego, RF-15) se agregan igual.
      GoRoute(
        path: Rutas.encuesta,
        parentNavigatorKey: navegadorRaiz,
        builder: (_, _) => const DailySurveyView(),
      ),
    ],
  );
}

/// Regla de protección de rutas.
///
/// - Recuperando contraseña (RF-06): con la sesión temporal del enlace solo
///   se permite /restablecer-contrasena.
/// - Enlace de recuperación inválido (RF-06 CA-7): sin sesión, se muestra
///   /recuperar-contrasena con el aviso.
/// - Sin sesión, cualquier ruta que no sea pública lleva a /login (RF-04).
/// - Con sesión, /login lleva al Inicio (ya entró: p. ej. al verificar el
///   código de RF-05 o al entrar desde un celular conocido). Las demás rutas
///   no se redirigen, para no interrumpir el flujo de registro y verificación.
String? redirigirPorSesion(
  String ubicacion, {
  required bool haySesion,
  bool recuperando = false,
  bool enlaceInvalido = false,
}) {
  if (haySesion && recuperando) {
    return ubicacion == Rutas.restablecerContrasena
        ? null
        : Rutas.restablecerContrasena;
  }
  if (!haySesion && enlaceInvalido) {
    return ubicacion == Rutas.recuperarContrasena
        ? null
        : Rutas.recuperarContrasena;
  }
  if (haySesion) return ubicacion == Rutas.login ? Rutas.inicio : null;
  if (Rutas.publicas.contains(ubicacion)) return null;
  return Rutas.login;
}

/// Convierte un Stream (ej. `supabase.auth.onAuthStateChange`) en un
/// Listenable para `refreshListenable` del router.
class RefrescoPorStream extends ChangeNotifier {
  RefrescoPorStream(Stream<Object?> stream) {
    // onError: Supabase también emite errores por este stream (p. ej. un
    // enlace vencido); el router solo necesita saber que algo cambió.
    _suscripcion = stream.listen(
      (_) => notifyListeners(),
      onError: (Object _) => notifyListeners(),
    );
  }

  late final StreamSubscription<Object?> _suscripcion;

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }
}

//test
