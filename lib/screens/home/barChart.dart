import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'dart:math';

class BarChart extends StatelessWidget {
  BarChart({Key? key, required this.barData}) : super(key: key);

  final List<Map> barData;

  @override
  Widget build(BuildContext context) {
    final double maxY = barData.fold<double>(0, (previousMax, data) {
      // Safely get quantity and maxQuantity, handling potential nulls and types
      final quantity = data['quantity'];
      final maxQuantity = data['maxQuantity'];

      double currentMax = 0;

      if (quantity != null && quantity is num && maxQuantity != null && maxQuantity is num) {
          currentMax = max(quantity.toDouble(), maxQuantity.toDouble());
      } else if (quantity != null && quantity is num){
        currentMax = quantity.toDouble();
      } else if (maxQuantity != null && maxQuantity is num){
        currentMax = maxQuantity.toDouble();
      }


      return max(previousMax, currentMax);
    }) * 1.2;

    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        majorGridLines: MajorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        axisLabelFormatter: (AxisLabelRenderDetails args) {
          return ChartAxisLabel(args.text + ' parts/billion', args.textStyle);
        },
        maximum: maxY,
      ),
      series: <CartesianSeries<Map, String>>[
        ColumnSeries<Map, String>(
          dataSource: barData,
          xValueMapper: (Map data, int index) => data['name'],
          yValueMapper: (Map data, int index) =>
              (data['quantity'] as num).toDouble(), // Explicit double conversion
          color: Colors.blue,
          animationDuration: 0,
          onCreateRenderer: (ChartSeries<Map, String> series) {
            return _ColumnSeriesRenderer();
          },
        ),
      ],
    );
  }
}

class _ColumnSeriesRenderer extends ColumnSeriesRenderer<Map, String> {
  @override
  ColumnSegment<Map, String> createSegment() => _ColumnSegment();
}

class _ColumnSegment extends ColumnSegment<Map, String> {
  void _reset() {
    segmentRect = null;
    points.clear();
  }

  @override
  void transformValues() {
    if (series.dataSource == null || series.dataSource!.isEmpty) {
      return;
    }

    _reset();
    final Function(num x, num y) transformX = series.pointToPixelX;
    final Function(num x, num y) transformY = series.pointToPixelY;
    final Map data = series.dataSource![currentSegmentIndex];
    final BorderRadius borderRadius = series.borderRadius;
    final num left = x + series.sbsInfo.minimum;
    final num right = x + series.sbsInfo.maximum;
    final double goal = (data['maxQuantity'] as num).toDouble();
    final double bottomX = transformX(right, bottom);
    final double bottomY = transformY(right, bottom);

    final Rect deflatedRect = _deflate(
      transformX(left, y),
      transformY(left, y),
      bottomX,
      bottomY,
    );

    segmentRect = toRRect(
      deflatedRect.left,
      deflatedRect.top,
      deflatedRect.right,
      deflatedRect.bottom,
      borderRadius,
    );

    points
      ..add(Offset(transformX(left, goal), transformY(left, goal)))
      ..add(Offset(transformX(right, goal), transformY(right, goal)));
  }

  RRect toRRect(double left, double top, double right, double bottom, BorderRadius borderRadius) {
    if (top > bottom) {
      final double temp = top;
      top = bottom;
      bottom = temp;
    }

    if (left > right) {
      final double temp = left;
      left = right;
      right = temp;
    }

    return RRect.fromLTRBAndCorners(
      left,
      top,
      right,
      bottom,
      topLeft: borderRadius.topLeft,
      topRight: borderRadius.topRight,
      bottomLeft: borderRadius.bottomLeft,
      bottomRight: borderRadius.bottomRight,
    );
  }

  Rect _deflate(double left, double top, double right, double bottom) {
    const double delta = 0.3;
    if (series.isTransposed) {
      final double height = (bottom - top) * delta;
      return Rect.fromLTRB(left, top - height, right, bottom + height);
    } else {
      final double width = (right - left) * delta;
      return Rect.fromLTRB(left + width, top, right - width, bottom);
    }
  }

  @override
  void onPaint(Canvas canvas) {
    Paint paint = getFillPaint();

    if (segmentRect != null) {
      paint = getFillPaint();
      if (paint.color != Colors.transparent && !segmentRect!.isEmpty) {
        canvas.drawRRect(segmentRect!, paint);
      }
    }

    if (points.isNotEmpty && points.length == 2) {
      paint = Paint()
        ..color = const Color.fromARGB(230, 216, 36, 23)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke;
      canvas.drawLine(points[0], points[1], paint);

      TextPainter label = TextPainter(
        text: TextSpan(
          text: "EPA Maximum Value",
          style: const TextStyle(color: Color.fromARGB(203, 112, 19, 12), fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout(minWidth: 0, maxWidth: double.infinity);

      final Offset labelOffset = Offset(points[0].dx + 5, points[0].dy - 15);
      label.paint(canvas, labelOffset);
    }
  }
}
