import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_models.dart';
import '../state/finance_controller.dart';

const String _kGoogleAppsScriptCode = '''
function doGet(e) {
  var action = (e && e.parameter && e.parameter.action) ? e.parameter.action : 'sync';
  if (action === 'recover') {
    var to = (e && e.parameter && e.parameter.to) ? e.parameter.to : Session.getActiveUser().getEmail();
    var pin = (e && e.parameter && e.parameter.pin) ? e.parameter.pin : '';
    MailApp.sendEmail(to, 'Recuperacion de PIN - App COFIPER', 'Hola, tu PIN actual de 4 digitos en COFIPER es: ' + pin);
    return ContentService.createTextOutput(JSON.stringify({ sent: true }))
      .setMimeType(ContentService.MimeType.JSON);
  }
  var query = 'BAC OR Credomatic OR Banpro OR Promerica OR LAFISE OR Ficohsa OR BDF OR Avanz';
  var threads = GmailApp.search(query, 0, 25);
  var blocks = [];
  for (var i = 0; i < threads.length; i++) {
    var msgs = threads[i].getMessages();
    for (var j = 0; j < msgs.length; j++) {
      var m = msgs[j];
      blocks.push('UID ' + m.getId() + ' FROM: ' + m.getFrom() + ' SUBJECT: ' + m.getSubject() + ' ' + m.getPlainBody());
    }
  }
  return ContentService.createTextOutput(JSON.stringify({
    success: true,
    statusMessage: 'OK',
    blocks: blocks
  })).setMimeType(ContentService.MimeType.JSON);
}
''';

Future<void> showBankGmailSyncModal(
  BuildContext context,
  FinanceController controller,
) async {
  final prefs = await SharedPreferences.getInstance();
  final savedScriptUrl = prefs.getString('cofiper_google_script_url_v1') ?? '';

  final emailCtrl = TextEditingController(text: controller.gmailAddress);
  final passCtrl = TextEditingController(text: controller.gmailAppPassword);
  final scriptUrlCtrl = TextEditingController(text: savedScriptUrl);
  final rateCtrl = TextEditingController(
    text: controller.usdToCordobaRate.toStringAsFixed(4),
  );
  final pasteAlertCtrl = TextEditingController();
  bool showPassword = false;

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return ListenableBuilder(
            listenable: controller,
            builder: (ctx, _) {
              final isSyncing = controller.isSyncingGmail;

              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            child: Icon(Icons.mark_email_read_rounded),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Conectar Bancos vía Gmail',
                                  style: Theme.of(ctx)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const Text(
                                  'BAC • Banpro • LAFISE • Ficohsa • BDF • Avanz',
                                  style: TextStyle(
                                      fontSize: 11.5, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Bloque 1: Conexión directa a Gmail (Safari Google Script + IMAP Nativo)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF4F46E5).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                const Color(0xFF4F46E5).withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '1. Sincronización Automática con tu Gmail',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Lee automáticamente los correos de alertas de compras de tus bancos y los suma al saldo de cada tarjeta en Córdobas (C\$).',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Tu correo de Gmail',
                                hintText: 'tucorreo@gmail.com',
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (kIsWeb) ...[
                              TextField(
                                controller: scriptUrlCtrl,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText:
                                      'Enlace Puente Google para Safari (script.google.com)',
                                  hintText:
                                      'https://script.google.com/macros/s/.../exec',
                                  prefixIcon: Icon(Icons.cloud_sync_rounded),
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(
                                      const ClipboardData(
                                          text: _kGoogleAppsScriptCode),
                                    );
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          '¡Código de conexión copiado! Pégalo en script.google.com -> Implementar -> Aplicación web.',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 18),
                                  label: const Text(
                                    'Copiar Código para Activar Gmail en Safari (1 vez)',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text(
                                  '¿Cómo activar el enlace para Safari en 1 minuto?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                children: const [
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Como Safari bloquea el puerto IMAP tradicional, Google permite crear tu propio puente seguro gratis:\n'
                                      '1. Toca el botón de arriba "Copiar Código para Activar Gmail en Safari".\n'
                                      '2. Abre script.google.com en tu navegador y toca "Nuevo proyecto".\n'
                                      '3. Borra lo que salga, pega el código copiado y toca arriba en "Implementar" → "Nueva implementación".\n'
                                      '4. Elige Tipo: "Aplicación web" y en "Quién tiene acceso" elige "Cualquier persona".\n'
                                      '5. Copia el link que termina en /exec y pégalo arriba. ¡Listo para siempre en tu iPhone!',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              TextField(
                                controller: passCtrl,
                                obscureText: !showPassword,
                                decoration: InputDecoration(
                                  labelText:
                                      'Contraseña de Aplicación Google (16 letras)',
                                  hintText: 'xxxx xxxx xxxx xxxx',
                                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      showPassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                    onPressed: () => setModalState(
                                        () => showPassword = !showPassword),
                                  ),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            const SizedBox(height: 6),
                            TextField(
                              controller: rateCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText:
                                    'Tipo de Cambio si cobraron en Dólares (1 USD = C\$)',
                                prefixIcon:
                                    Icon(Icons.currency_exchange_rounded),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            if (controller.lastBankSyncMessage != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  controller.lastBankSyncMessage!,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: isSyncing
                                    ? null
                                    : () async {
                                        if (scriptUrlCtrl.text
                                            .trim()
                                            .isNotEmpty) {
                                          await prefs.setString(
                                            'cofiper_google_script_url_v1',
                                            scriptUrlCtrl.text.trim(),
                                          );
                                        }
                                        final parsedRate = double.tryParse(
                                              rateCtrl.text
                                                  .replaceAll(',', '.'),
                                            ) ??
                                            36.6243;
                                        await controller.syncWithGmailBanks(
                                          emailOverride: emailCtrl.text,
                                          passwordOverride: kIsWeb
                                              ? scriptUrlCtrl.text.trim()
                                              : passCtrl.text,
                                          rateOverride: parsedRate,
                                        );
                                      },
                                icon: isSyncing
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.sync_rounded),
                                label: Text(
                                  isSyncing
                                      ? 'Buscando alertas de bancos en tu Gmail...'
                                      : 'Sincronizar mis Compras de Gmail Ahora',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Bloque 2: Pegar o Probar cualquier correo / SMS bancario al instante
                      const Text(
                        '2. Pegar Correo de Gmail o SMS del Banco al Instante',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'También puedes copiar el texto del correo de BAC, Banpro, LAFISE o Ficohsa y pegarlo aquí (o tocar un ejemplo para probar cómo suma a tu tarjeta y recalcula tus 2 quincenas):',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            label: const Text('Ejemplo BAC (C\$)',
                                style: TextStyle(fontSize: 11.5)),
                            onPressed: () {
                              setModalState(() {
                                pasteAlertCtrl.text =
                                    'BAC Credomatic informa: Compra aprobada en SUPERMERCADO LA COLONIA por C\$ 1,450.00 con su tarjeta *4512 el dia de hoy.';
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('Ejemplo Banpro (US\$ a C\$)',
                                style: TextStyle(fontSize: 11.5)),
                            onPressed: () {
                              setModalState(() {
                                pasteAlertCtrl.text =
                                    'Notificacion Banpro: Consumo aprobado en AMAZON / NETFLIX por US\$ 25.00 con tarjeta terminacion 8890.';
                              });
                            },
                          ),
                          ActionChip(
                            label: const Text('Ejemplo LAFISE (C\$)',
                                style: TextStyle(fontSize: 11.5)),
                            onPressed: () {
                              setModalState(() {
                                pasteAlertCtrl.text =
                                    'Banco LAFISE Bancentro: Se realizo transaccion en PUMA METROCENTRO por NIO 980.00 con tarjeta *3310.';
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: pasteAlertCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Texto del correo o notificación del banco',
                          hintText:
                              'Pega aquí el mensaje de BAC, Banpro, LAFISE o Ficohsa...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text(
                              'Detectar Compra, Sumar a Tarjeta y Recalcular'),
                          onPressed: () {
                            final parsedRate = double.tryParse(
                                  rateCtrl.text.replaceAll(',', '.'),
                                ) ??
                                36.6243;
                            controller.saveGmailBankSettings(
                              gmail: emailCtrl.text,
                              appPassword: passCtrl.text,
                              exchangeRate: parsedRate,
                            );

                            final tx = controller
                                .processBankAlertText(pasteAlertCtrl.text);
                            if (tx == null) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'No se encontró un monto válido en el texto. Asegúrate de incluir el monto (C\$ o US\$).'),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(
                                  '¡Listo! Se detectó ${tx.bank.name} en ${tx.merchant} por ${formatCordobas(tx.amountInCordobas)} y se recalcularon tus 2 quincenas.',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
