import 'package:flutter/material.dart';
import '../models/srd_summons.dart';

class SpellReferenceWidget extends StatefulWidget {
  final SummonPreset? initialPreset;

  const SpellReferenceWidget({super.key, this.initialPreset});

  @override
  State<SpellReferenceWidget> createState() => _SpellReferenceWidgetState();
}

class _SpellReferenceWidgetState extends State<SpellReferenceWidget> {
  late SummonPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.initialPreset ?? SrdSummonsLibrary.allPresets.first;
  }

  @override
  Widget build(BuildContext context) {
    final p = _selectedPreset;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF252236),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SummonPreset>(
                value: _selectedPreset,
                dropdownColor: const Color(0xFF252236),
                isExpanded: true,
                icon: const Icon(Icons.menu_book, color: Colors.amber),
                items: SrdSummonsLibrary.allPresets.map((preset) {
                  return DropdownMenuItem<SummonPreset>(
                    value: preset,
                    child: Text(
                      '${preset.name} (${preset.levelDisplay})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedPreset = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3F2B96), Color(0xFFA8C0FF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${p.levelDisplay} | Casting Time: ${p.castingTime} | Range: ${p.range}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  'Components: ${p.components} | Duration: ${p.duration}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Spell Description
          const Text(
            'SPELL / ITEM DESCRIPTION',
            style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            p.description,
            style: const TextStyle(color: Color(0xE6FFFFFF), height: 1.4),
          ),
          const SizedBox(height: 12),

          const Text(
            'UPCASTING & SCALING RULES',
            style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            p.upcastRules,
            style: const TextStyle(color: Color(0xE6FFFFFF), height: 1.4),
          ),
          const SizedBox(height: 20),

          // RAW Stat Table
          Text(
            '${p.name.toUpperCase()} STATISTICS TABLE',
            style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF242038)),
              dataRowColor: WidgetStateProperty.all(const Color(0xFF1E1B2E)),
              border: TableBorder.all(color: Colors.white24, width: 0.5),
              columns: const [
                DataColumn(label: Text('Name', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('Size / CR', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('HP', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('AC', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('Attack Bonus', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('Damage Formula', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('Special Traits', style: TextStyle(color: Colors.amber))),
              ],
              rows: p.statBlocks.map((sb) {
                return DataRow(
                  cells: [
                    DataCell(Text(sb.name, style: TextStyle(color: sb.accentColor, fontWeight: FontWeight.bold))),
                    DataCell(Text('${sb.sizeDisplay} (${sb.crDisplay})', style: const TextStyle(color: Colors.white))),
                    DataCell(Text('${sb.maxHp}', style: const TextStyle(color: Colors.white))),
                    DataCell(Text('${sb.ac}', style: const TextStyle(color: Colors.white))),
                    DataCell(Text('+${sb.attackBonus} to hit', style: const TextStyle(color: Colors.white))),
                    DataCell(Text(sb.fullDamageFormula, style: const TextStyle(color: Colors.white))),
                    DataCell(Text(sb.specialTrait ?? (sb.hasPackTactics ? 'Pack Tactics' : 'None'), style: const TextStyle(color: Colors.white70, fontSize: 11))),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // Tactical Tips
          const Text(
            '💡 TACTICAL TIPS & RAW CLARIFICATIONS',
            style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildTipCard(
            'SRD 5.1 Legal Notice',
            'All text, formulas, and creature stats above are strictly taken from the SRD 5.1 under Creative Commons CC-BY-4.0 attribution.',
          ),
          _buildTipCard(
            'Action Economy & Squad Management',
            'Summoning multiple creatures allows you to split attacks, control space, absorb incoming damage, or trigger Pack Tactics for team advantage!',
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252236),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }
}
