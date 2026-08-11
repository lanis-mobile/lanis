import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/utils/cached_network_image.dart';

import '../helpers/test_app.dart';

void main() {
  tearDown(LanisClient.reset);

  testWidgets('dispose during load does not throw setState-after-dispose', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: CachedNetworkImage(
        placeholder: const Text('placeholder'),
        imageUrl: Uri.parse('https://example.test/school.jpg'),
        builder: (context, image) => Image(image: image),
      ),
    );

    expect(find.text('placeholder'), findsOneWidget);

    // Dispose widget while async loadData may still be in flight.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });

  testWidgets('malformed data URI payload stays on placeholder', (tester) async {
    // Construct without Uri.parse so invalid base64 reaches _loadBase64Data.
    final badDataUri = Uri(scheme: 'data', path: 'image/png;base64,@@@');
    await pumpTestApp(
      tester,
      child: CachedNetworkImage(
        placeholder: const Text('placeholder'),
        imageUrl: badDataUri,
        builder: (context, image) => const Text('loaded'),
      ),
    );

    expect(find.text('placeholder'), findsOneWidget);
    expect(find.text('loaded'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
