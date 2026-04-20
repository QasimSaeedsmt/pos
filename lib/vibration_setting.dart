import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'vibration_provider.dart';

class VibrationSettingsScreen extends StatelessWidget {
  const VibrationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vibrationProvider = Provider.of<VibrationProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haptic Settings'),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Consumer<VibrationProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.vibration,
                              color: Colors.blue.shade700,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Haptic Feedback',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Customize haptic feedback for different actions',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Enable Haptic Feedback',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Master switch for all haptic feedback',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          value: provider.vibrationEnabled,
                          onChanged: (value) {
                            provider.toggleVibration(value);
                            if (value) {
                              provider.vibrate();
                            }
                          },
                          secondary: Icon(
                            provider.vibrationEnabled ? Icons.vibration : Icons.vibration_outlined,
                            color: provider.vibrationEnabled ? Colors.green : Colors.grey,
                          ),
                        ),
                        const Divider(),
                        SwitchListTile(
                          title: const Text(
                            'Restock Increment Feedback',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            'Vibrate when increasing quantity during restocking',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          value: provider.incrementHapticEnabled,
                          onChanged: provider.vibrationEnabled
                              ? (value) {
                            provider.toggleIncrementHaptic(value);
                            if (value) {
                              provider.vibrateForIncrement();
                            }
                          }
                              : null,
                          secondary: Icon(
                            provider.incrementHapticEnabled ? Icons.add_circle : Icons.add_circle_outline,
                            color: provider.incrementHapticEnabled ? Colors.blue : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Haptic Feedback',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap buttons to test different vibration patterns',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ElevatedButton.icon(
                              onPressed: provider.vibrationEnabled
                                  ? () async {
                                await provider.vibrateForIncrement();
                              }
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Increment'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade50,
                                foregroundColor: Colors.blue.shade700,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: provider.vibrationEnabled
                                  ? () async {
                                await provider.vibrateSuccess();
                              }
                                  : null,
                              icon: const Icon(Icons.check_circle),
                              label: const Text('Success'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                foregroundColor: Colors.green.shade700,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: provider.vibrationEnabled
                                  ? () async {
                                await provider.vibrateError();
                              }
                                  : null,
                              icon: const Icon(Icons.error),
                              label: const Text('Error'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade50,
                                foregroundColor: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}