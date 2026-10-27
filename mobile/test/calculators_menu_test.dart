import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironpeak_mobile/l10n/app_localizations.dart';
import 'package:ironpeak_mobile/theme/app_colors.dart';
import 'package:ironpeak_mobile/widgets/calculators_menu.dart';

void main() {
  testWidgets('the ⋮ menu lists the three calculators and opens the picked one', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(extensions: const [AppColors.light]),
      home: const Scaffold(body: Align(alignment: Alignment.topRight, child: CalculatorsMenuButton())),
    ));
    final t = await AppLocalizations.delegate.load(const Locale('en'));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(t.titlePlateCalculator), findsOneWidget);
    expect(find.text(t.title1rmCalculator), findsOneWidget);
    expect(find.text(t.titleCalorieCalculator), findsOneWidget);

    await tester.tap(find.text(t.title1rmCalculator));
    await tester.pumpAndSettle();
    // The menu is gone; the 1RM sheet is up.
    expect(find.text(t.titlePlateCalculator), findsNothing);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text(t.title1rmCalculator), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Training's ⋮ menu mixes its own enum with these items in one
  // PopupMenuButton<Object>; picking a calculator must hand back the
  // Calculator itself, not trip a type check.
  testWidgets('calculator items work inside a menu of other values', (tester) async {
    final picked = <Object>[];
    late AppLocalizations t;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(builder: (context) {
          t = AppLocalizations.of(context)!;
          return PopupMenuButton<Object>(
            icon: const Icon(Icons.more_vert),
            onSelected: picked.add,
            itemBuilder: (context) => [
              const PopupMenuItem<Object>(value: 'settings', child: Text('Settings')),
              const PopupMenuDivider(),
              ...calculatorMenuItems(t),
            ],
          );
        }),
      ),
    ));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.titleCalorieCalculator));
    await tester.pumpAndSettle();
    expect(picked, [Calculator.calories]);
    expect(tester.takeException(), isNull);
  });
}
