import 'package:flutter/material.dart';
import '../models/animated_object.dart';

class SpellReferenceWidget extends StatelessWidget {
  const SpellReferenceWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3F2B96), Color(0xFFA8C0FF)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Animate Objects',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  '5th-level Transmutation | Casting Time: 1 Action | Range: 120 feet',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  'Components: V, S | Duration: Concentration, up to 1 minute',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Spell Description
          const Text(
            'SPELL DESCRIPTION',
            style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Objects come to life at your command. Choose up to ten nonmagical objects within range that are not being worn or carried. Medium targets count as two objects, Large targets count as four objects, Huge targets count as eight objects. You can\'t animate an object larger than Huge.',
            style: TextStyle(color: Color(0xE6FFFFFF), height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'As a bonus action, you can mentally command any object you made with this spell if the object is within 500 feet of you. If you command multiple objects, you can give the same command to each of them.',
            style: TextStyle(color: Color(0xE6FFFFFF), height: 1.4),
          ),
          const SizedBox(height: 20),

          // RAW Stat Table
          const Text(
            'OBJECT STATISTICS TABLE',
            style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF242038)),
              dataRowColor: WidgetStateProperty.all(const Color(0xFF1E1B2E)),
              border: TableBorder.all(color: Colors.white24, width: 0.5),
              columns: const [
                DataColumn(label: Text('Size', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('Pts', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('HP', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('AC', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('Attack', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('Damage', style: TextStyle(color: Colors.amber))),
                DataColumn(label: Text('STR/DEX', style: TextStyle(color: Colors.amber))),
              ],
              rows: ObjectSize.values.map((size) {
                return DataRow(
                  cells: [
                    DataCell(Text(size.displayName, style: TextStyle(color: size.accentColor, fontWeight: FontWeight.bold))),
                    DataCell(Text('${size.pointCost}', style: const TextStyle(color: Colors.white))),
                    DataCell(Text('${size.maxHp}', style: const TextStyle(color: Colors.white))),
                    DataCell(Text('${size.ac}', style: const TextStyle(color: Colors.white))),
                    DataCell(Text('+${size.attackBonus} to hit', style: const TextStyle(color: Colors.white))),
                    DataCell(Text(size.damageFormula, style: const TextStyle(color: Colors.white))),
                    DataCell(Text('${size.strScore} / ${size.dexScore}', style: const TextStyle(color: Colors.white70))),
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
            'Maximum Damage Output (DPR)',
            '10 Tiny objects (e.g. silver coins or daggers) yield 10 attacks at +8 to hit dealing 1d4+4 each (avg 65 damage/round if all hit). This is widely considered the highest single-target DPR option.',
          ),
          _buildTipCard(
            'Damage Types & Resistance',
            'Animated objects deal nonmagical bludgeoning, piercing, or slashing damage depending on their form. Silvering coins or daggers overcomes resistance to nonmagical attacks for silver-susceptible creatures!',
          ),
          _buildTipCard(
            'Upcasting',
            'If you cast this spell using a slot of 6th level or higher, you can animate two additional objects for each slot level above 5th (+2 points per spell slot level above 5th).',
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
