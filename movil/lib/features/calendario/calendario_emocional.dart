import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/tema/app_tema.dart';
import '../../core/widgets/fondo_mindmetrics.dart';
import '../animo/domain/registro_animo.dart';

// ---------------------------------------------------------------------------
// Datos (back de Samuel: 20261110225333_rf11_calendario_emocional.sql)
// ---------------------------------------------------------------------------

class DiaCalendario {
  const DiaCalendario({required this.fecha, this.nivel, this.totalActividades = 0});
  final DateTime fecha;
  final int? nivel; // null = sin registro ese día
  final int totalActividades;
}

class Actividad {
  const Actividad({required this.titulo, required this.categoria, this.hora, this.completada = false});
  final String titulo;
  final String categoria;
  final String? hora; // 'HH:MM:SS'
  final bool completada;
}

abstract class CalendarioRepositorio {
  Future<List<DiaCalendario>> mes(int anio, int mes);
  Future<List<Actividad>> actividadesDe(DateTime dia);
}

class CalendarioSupabase implements CalendarioRepositorio {
  CalendarioSupabase(this._db);
  final SupabaseClient _db;

  @override
  Future<List<DiaCalendario>> mes(int anio, int mes) async {
    final filas = await _db.rpc('obtener_resumen_calendario_mes',
        params: {'p_anio': anio, 'p_mes': mes}) as List;
    return [
      for (final f in filas.cast<Map<String, dynamic>>())
        DiaCalendario(
          fecha: DateTime.parse(f['fecha'] as String),
          nivel: (f['nivel_animo'] as num?)?.toInt(),
          totalActividades: (f['total_actividades'] as num).toInt(),
        ),
    ];
  }

  @override
  Future<List<Actividad>> actividadesDe(DateTime dia) async {
    final filas = await _db
        .from('actividades')
        .select('titulo, categoria, hora, completada')
        .eq('fecha', fechaLocal(dia))
        .order('hora', nullsFirst: true);
    return [
      for (final f in filas)
        Actividad(
          titulo: f['titulo'] as String,
          categoria: f['categoria'] as String,
          hora: f['hora'] as String?,
          completada: f['completada'] as bool,
        ),
    ];
  }
}

final calendarioRepositorioProvider = Provider<CalendarioRepositorio>(
  (_) => CalendarioSupabase(Supabase.instance.client),
);

// ---------------------------------------------------------------------------
// ViewModel
// ---------------------------------------------------------------------------

class CalendarioVistaModelo extends ChangeNotifier {
  CalendarioVistaModelo(this._repo, {DateTime? hoy})
      : mesVisible = DateTime((hoy ?? DateTime.now()).year, (hoy ?? DateTime.now()).month);

  final CalendarioRepositorio _repo;
  DateTime mesVisible;
  bool cargando = true;
  String? error;
  Map<int, DiaCalendario> dias = {}; // día del mes → datos
  bool _destruido = false;

  Future<void> cargar() async {
    cargando = true;
    error = null;
    _avisar();
    try {
      final lista = await _repo.mes(mesVisible.year, mesVisible.month);
      dias = {for (final d in lista) d.fecha.day: d};
    } catch (_) {
      error = 'No pudimos cargar el calendario. Revisa tu conexión.';
      dias = {};
    }
    cargando = false;
    _avisar();
  }

  void cambiarMes(int delta) {
    mesVisible = DateTime(mesVisible.year, mesVisible.month + delta);
    cargar();
  }

  Future<List<Actividad>> actividadesDe(DateTime dia) => _repo.actividadesDe(dia);

  void _avisar() {
    if (!_destruido) notifyListeners();
  }

  @override
  void dispose() {
    _destruido = true;
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Pantalla
// ---------------------------------------------------------------------------

/// Color por nivel (1 rojo … 5 verde). Se acompaña de emoji para no
/// depender solo del color (accesibilidad).
Color colorNivel(int nivel) => const [
      Color(0xFFEF4444),
      Color(0xFFF59E0B),
      Color(0xFFFACC15),
      Color(0xFF84CC16),
      Color(0xFF22C55E),
    ][nivel - 1];

class CalendarioPagina extends ConsumerStatefulWidget {
  const CalendarioPagina({super.key});

  @override
  ConsumerState<CalendarioPagina> createState() => _CalendarioPaginaState();
}

class _CalendarioPaginaState extends ConsumerState<CalendarioPagina> {
  late final CalendarioVistaModelo _vm =
      CalendarioVistaModelo(ref.read(calendarioRepositorioProvider))..cargar();

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        final m = _vm.mesVisible;
        return FondoMindMetrics(
          contenido: Column(children: [
            const IconoCircular(Icons.calendar_month_rounded),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppMedidas.margenPantalla),
                child: Column(children: [
                  const TituloTarjeta('Calendario emocional'),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Mes anterior',
                        icon: const Icon(Icons.chevron_left, color: AppColores.primario),
                        onPressed: () => _vm.cambiarMes(-1),
                      ),
                      Text(
                        '${_meses[m.month - 1]} ${m.year}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColores.texto,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      IconButton(
                        tooltip: 'Mes siguiente',
                        icon: const Icon(Icons.chevron_right, color: AppColores.primario),
                        onPressed: () => _vm.cambiarMes(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const _CabeceraSemana(),
                  if (_vm.cargando)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: CircularProgressIndicator(),
                    )
                  else if (_vm.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(_vm.error!, textAlign: TextAlign.center),
                    )
                  else
                    _Cuadricula(vm: _vm, alTocar: _abrirDia),
                  const Divider(height: 24, color: AppColores.borde),
                  const _Leyenda(),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }

  void _abrirDia(DateTime dia, DiaCalendario? datos) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColores.tarjeta,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${dia.day} de ${_meses[dia.month - 1].toLowerCase()}',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      color: AppColores.grafico2,
                      fontWeight: FontWeight.w800,
                    )),
            const SizedBox(height: 8),
            Text(datos?.nivel == null
                ? 'Sin registro de ánimo'
                : 'Ánimo: ${NivelAnimo.de(datos!.nivel!).emoji} ${NivelAnimo.de(datos.nivel!).etiqueta}'),
            const SizedBox(height: 12),
            if ((datos?.totalActividades ?? 0) == 0)
              const Text('No hay actividades programadas')
            else
              FutureBuilder<List<Actividad>>(
                future: _vm.actividadesDe(dia),
                builder: (_, s) => s.hasData
                    ? Column(children: [
                        for (final a in s.data!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              a.completada ? Icons.check_circle : Icons.circle_outlined,
                              color: AppColores.primario,
                            ),
                            title: Text(a.titulo),
                            subtitle: Text(a.hora == null ? a.categoria : '${a.hora!.substring(0, 5)} · ${a.categoria}'),
                          ),
                      ])
                    : s.hasError
                        ? const Text('No pudimos cargar las actividades')
                        : const LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CabeceraSemana extends StatelessWidget {
  const _CabeceraSemana();
  @override
  Widget build(BuildContext context) => Row(children: [
        for (final d in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
          Expanded(child: Center(child: Text(d, style: Theme.of(context).textTheme.labelMedium))),
      ]);
}

class _Cuadricula extends StatelessWidget {
  const _Cuadricula({required this.vm, required this.alTocar});
  final CalendarioVistaModelo vm;
  final void Function(DateTime, DiaCalendario?) alTocar;

  @override
  Widget build(BuildContext context) {
    final primero = vm.mesVisible;
    final vacios = primero.weekday - 1; // la semana empieza el lunes
    final totalDias = DateTime(primero.year, primero.month + 1, 0).day;
    final hoy = DateTime.now();

    return GridView.builder(
      shrinkWrap: true, // va dentro de la tarjeta, que ya se desplaza
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemCount: vacios + totalDias,
      itemBuilder: (context, i) {
        if (i < vacios) return const SizedBox.shrink();
        final n = i - vacios + 1;
        final fecha = DateTime(primero.year, primero.month, n);
        final datos = vm.dias[n];
        final nivel = datos?.nivel;
        final esHoy = DateUtils.isSameDay(fecha, hoy);
        return InkWell(
          customBorder: const CircleBorder(),
          onTap: () => alTocar(fecha, datos),
          child: Semantics(
            label: '$n${nivel == null ? '' : ', ánimo ${NivelAnimo.de(nivel).etiqueta}'}'
                '${(datos?.totalActividades ?? 0) > 0 ? ', con actividades' : ''}',
            child: Stack(alignment: Alignment.center, children: [
              Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nivel == null ? null : colorNivel(nivel).withValues(alpha: .35),
                  border: esHoy ? Border.all(color: AppColores.primario, width: 2) : null,
                ),
                alignment: Alignment.center,
                child: Text('$n'),
              ),
              if ((datos?.totalActividades ?? 0) > 0)
                Positioned(
                  bottom: 6,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColores.grafico2,
                    ),
                  ),
                ),
            ]),
          ),
        );
      },
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (final n in NivelAnimo.todos)
            Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 6, backgroundColor: colorNivel(n.valor)),
              const SizedBox(width: 4),
              Text(n.etiqueta, style: Theme.of(context).textTheme.labelSmall),
            ]),
        ],
      );
}
