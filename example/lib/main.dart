import 'package:flutter/material.dart';
import 'package:thinking_orbs_dart/thinking_orbs_dart.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Demo(),
    ));

class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          for (final s in OrbState.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(children: [
                ThinkingOrb(state: s, size: OrbSize.large),
                const SizedBox(width: 16),
                ThinkingOrb(state: s, size: OrbSize.small),
                const SizedBox(width: 16),
                Text('${s.name} · ${s.label}',
                    style: const TextStyle(color: Color(0xFFF2EFE8))),
              ]),
            ),
        ]),
      );
}
