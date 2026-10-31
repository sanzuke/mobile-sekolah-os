import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Loads [load] once, shows spinner / error with retry / [builder], and
/// supports pull-to-refresh. A 401 calls [onUnauthorized] (token expired).
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    required this.onUnauthorized,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onUnauthorized;

  @override
  State<AsyncView<T>> createState() => AsyncViewState<T>();
}

class AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = _run();
  }

  Future<T> _run() async {
    try {
      return await widget.load();
    } on ApiException catch (e) {
      if (e.isUnauthorized) widget.onUnauthorized();
      rethrow;
    }
  }

  Future<void> reload() async {
    final next = _run();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {
      // Error is rendered by the FutureBuilder below.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          final msg = snap.error is ApiException
              ? (snap.error as ApiException).message
              : 'Tidak dapat terhubung ke server.';
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 80),
                Icon(Icons.cloud_off,
                    size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text(msg, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Center(
                  child: FilledButton(
                      onPressed: reload, child: const Text('Coba lagi')),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: reload,
          child: widget.builder(context, snap.data as T),
        );
      },
    );
  }
}
