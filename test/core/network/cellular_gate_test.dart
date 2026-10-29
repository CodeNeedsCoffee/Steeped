import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/core/network/cellular_gate.dart';
import 'package:steeped/features/settings/data/app_settings.dart';

void main() {
  test('never on cellular blocks; off cellular always allows', () {
    expect(
      decideCellular(CellularPolicy.never, onCellular: true),
      CellularDecision.block,
    );
    expect(
      decideCellular(CellularPolicy.never, onCellular: false),
      CellularDecision.allow,
    );
  });

  test('always allows', () {
    expect(
      decideCellular(CellularPolicy.always, onCellular: true),
      CellularDecision.allow,
    );
  });

  test('ask prompts once, then remembers the answer', () {
    expect(
      decideCellular(CellularPolicy.ask, onCellular: true),
      CellularDecision.prompt,
    );
    expect(
      decideCellular(CellularPolicy.ask, onCellular: true, sessionAnswer: true),
      CellularDecision.allow,
    );
    expect(
      decideCellular(
        CellularPolicy.ask,
        onCellular: true,
        sessionAnswer: false,
      ),
      CellularDecision.block,
    );
    expect(
      decideCellular(CellularPolicy.ask, onCellular: false),
      CellularDecision.allow,
    );
  });
}
