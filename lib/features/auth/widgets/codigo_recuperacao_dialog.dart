import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> mostrarCodigoRecuperacao(
  BuildContext context,
  String codigo,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Guarde seu c\u00f3digo de recupera\u00e7\u00e3o'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Este c\u00f3digo aparece uma \u00fanica vez e permite redefinir a senha do '
              'administrador. Anote-o em local seguro.',
            ),
            const SizedBox(height: 16),
            SelectableText(
              codigo,
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('C\u00f3digo copiado')),
                );
              }
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('J\u00e1 anotei, continuar'),
          ),
        ],
      );
    },
  );
}
