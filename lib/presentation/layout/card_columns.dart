import 'package:flutter/widgets.dart';

import 'app_layout.dart';

/// Cards in as many columns as fit (each at least [AppLayout.cardMin]
/// wide), dealt out in turn so they read across then down; one column on a
/// phone, exactly as a plain list would be.
class CardColumns extends StatelessWidget {
  final List<Widget> children;
  final double gap;

  const CardColumns({super.key, required this.children, this.gap = 14});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final columns = AppLayout.columnsFor(constraints.maxWidth);
      if (columns == 1) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++) ...[
            if (c > 0) SizedBox(width: gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = c; i < children.length; i += columns) ...[
                    if (i >= columns) SizedBox(height: gap),
                    children[i],
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}
