import 'package:flutter/widgets.dart';

/// Crea un ViewModel (ChangeNotifier) una sola vez y lo libera al salir.
///
/// Las pestañas del shell (RF-10) son ramas del router y ya no se construyen
/// dentro de MainShell; este widget conserva el mismo ciclo de vida que
/// antes tenían los ViewModels creados en `MainShell.initState`.
class ConViewModel<T extends ChangeNotifier> extends StatefulWidget {
  const ConViewModel({super.key, required this.crear, required this.builder});

  final T Function() crear;
  final Widget Function(BuildContext context, T viewModel) builder;

  @override
  State<ConViewModel<T>> createState() => _ConViewModelState<T>();
}

class _ConViewModelState<T extends ChangeNotifier>
    extends State<ConViewModel<T>> {
  late final T _viewModel = widget.crear();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _viewModel);
}
