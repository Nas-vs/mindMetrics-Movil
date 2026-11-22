import 'package:flutter/material.dart';

import '../../../core/tema/app_tema.dart';
import '../../auth/compartido/presentation/fondo_auth.dart';

/// Contenido de cada pantalla del carrusel (RF-01 CA-1).
class _Diapositiva {
  const _Diapositiva({
    required this.titulo,
    required this.texto,
    this.icono,
    this.conEmojis = false,
  });

  final String titulo;
  final String texto;

  /// null = logo de la app.
  final IconData? icono;
  final bool conEmojis;
}

const _diapositivas = [
  _Diapositiva(
    titulo: 'Registra cómo te sientes cada día',
    texto: 'Elige cómo estás con un toque. Toma menos de un minuto.',
    conEmojis: true,
  ),
  _Diapositiva(
    titulo: 'Descubre patrones en tu bienestar',
    texto: 'Tu calendario y tus registros te muestran qué días y qué hábitos te hacen bien.',
    icono: Icons.trending_up_rounded,
  ),
  _Diapositiva(
    titulo: 'Esta app no reemplaza la atención profesional',
    texto: 'Si estás en crisis, busca ayuda profesional o comunícate con una línea de atención.',
    icono: Icons.favorite_border_rounded,
  ),
];

/// RF-01: carrusel de bienvenida que se ve solo la primera vez.
class BienvenidaPagina extends StatefulWidget {
  const BienvenidaPagina({super.key, required this.onTerminar});

  /// "Comenzar" (CA-3) o "Saltar" (CA-2): guarda la marca y va a RF-02.
  final VoidCallback onTerminar;

  @override
  State<BienvenidaPagina> createState() => _BienvenidaPaginaState();
}

class _BienvenidaPaginaState extends State<BienvenidaPagina> {
  final _paginas = PageController();
  int _actual = 0;

  bool get _esUltima => _actual == _diapositivas.length - 1;

  void _siguiente() => _paginas.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTema.claro(),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(
              child: Image(
                image: AssetImage(ImagenesAuth.fondo),
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: ColoredBox(color: Colors.white.withValues(alpha: 0.45)),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppMedidas.margenPantalla),
                child: Column(
                  children: [
                    // CA-2: "Saltar" solo en las pantallas 1 y 2.
                    SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _esUltima
                            ? null
                            : EnlaceAuth(
                                texto: 'Saltar',
                                secundario: true,
                                onPressed: widget.onTerminar,
                              ),
                      ),
                    ),
                    // CA-2: swipe horizontal.
                    Expanded(
                      child: PageView.builder(
                        controller: _paginas,
                        itemCount: _diapositivas.length,
                        onPageChanged: (i) => setState(() => _actual = i),
                        itemBuilder: (_, i) =>
                            _VistaDiapositiva(diapositiva: _diapositivas[i]),
                      ),
                    ),
                    _Puntos(total: _diapositivas.length, actual: _actual),
                    const SizedBox(height: 20),
                    // CA-2 / CA-3: "Siguiente" o "Comenzar" en la última.
                    SizedBox(
                      width: double.infinity,
                      child: _esUltima
                          ? BotonConLogo(
                              texto: 'Comenzar',
                              logoAntes: true,
                              onPressed: widget.onTerminar,
                            )
                          : FilledButton(
                              onPressed: _siguiente,
                              child: const Text('Siguiente'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }
}

class _VistaDiapositiva extends StatelessWidget {
  const _VistaDiapositiva({required this.diapositiva});

  final _Diapositiva diapositiva;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppMedidas.anchoMaximoFormulario),
          child: Column(
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: AppColores.primario,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: diapositiva.icono == null
                    ? Image.asset(
                        ImagenesAuth.logoBlanco,
                        width: 96,
                        excludeFromSemantics: true,
                      )
                    : Icon(diapositiva.icono, size: 88, color: Colors.white),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppMedidas.relleno),
                  child: Column(
                    children: [
                      Text(
                        diapositiva.titulo,
                        textAlign: TextAlign.center,
                        style: textos.headlineSmall?.copyWith(
                          color: AppColores.grafico2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        diapositiva.texto,
                        textAlign: TextAlign.center,
                        style: textos.bodyLarge?.copyWith(color: AppColores.texto),
                      ),
                      if (diapositiva.conEmojis) ...[
                        const SizedBox(height: 12),
                        const ExcludeSemantics(
                          child: Text(
                            '😞  🙁  😐  🙂  😄',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CA-2: indicador de puntos de la pantalla actual.
class _Puntos extends StatelessWidget {
  const _Puntos({required this.total, required this.actual});

  final int total;
  final int actual;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pantalla ${actual + 1} de $total',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == actual ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == actual ? AppColores.primario : AppColores.sobreAtenuado,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
