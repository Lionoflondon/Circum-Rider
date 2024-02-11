import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../utils/theme/theme.dart';

class EarningsBarChartWidget extends StatelessWidget {
  final Map<String, double>? weeklyEarnings;

  EarningsBarChartWidget({super.key, this.weeklyEarnings});

  // final Color barBackgroundColor = Color(0xFF1F292E);
  final Color barColor = AppColors.primary;

  Map<String, double> placeholderWeeklyEarnings = {
    "Sun": 0,
    "Mon": 0,
    "Tue": 0,
    "Wed": 0,
    "Thu": 0,
    "Fri": 0,
    "Sat": 0
  };

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Expanded(
              child: BarChart(
                randomData(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxEarning(Map<String, double> earnings) {
    double maxEarning = 0;
    earnings.forEach((key, value) {
      if (value > maxEarning) {
        maxEarning = value;
      }
    });
    return maxEarning * 1.2; // Add a buffer to make bars fit nicely
  }

  Widget getTitles(double value, TitleMeta meta) {
    List<String> daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Get the current day of the week (0 for Sunday, 1 for Monday, ..., 6 for Saturday)
    int currentDayIndex = DateTime.now().weekday;

    // Arrange the days of the week starting from the current day
    List<String> orderedDays = daysOfWeek.sublist(currentDayIndex)
      ..addAll(daysOfWeek.sublist(0, currentDayIndex));

    Widget text = AppText.text(orderedDays[value.toInt()],
        fontWeight: FontWeight.w600, fontSize: 12);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 16,
      child: text,
    );
  }

  Widget getLeftTitles(double value, TitleMeta meta) {
    return SideTitleWidget(
        axisSide: meta.axisSide, child: AppText.text(value.toStringAsFixed(0)));
  }

  BarChartData randomData() {
    return BarChartData(
      maxY:
          weeklyEarnings != null ? _calculateMaxEarning(weeklyEarnings!) : 100,
      barTouchData: BarTouchData(
        enabled: false,
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: getTitles,
            reservedSize: 38,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
              reservedSize: 35,
              showTitles: true,
              getTitlesWidget: getLeftTitles),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(
            showTitles: false,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: false,
      ),
      barGroups: _createBarGroups(weeklyEarnings ?? placeholderWeeklyEarnings),
      gridData: const FlGridData(show: false),
    );
  }

  List<BarChartGroupData> _createBarGroups(Map<String, double> earnings) {
    List<BarChartGroupData> barGroups = [];
    List<String> daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Get the current day of the week (0 for Sunday, 1 for Monday, ..., 6 for Saturday)
    int currentDayIndex = DateTime.now().weekday;

    // Arrange the days of the week starting from the current day
    List<String> orderedDays = daysOfWeek.sublist(currentDayIndex)
      ..addAll(daysOfWeek.sublist(0, currentDayIndex));

    // Create bar groups based on the ordered days
    for (String day in orderedDays) {
      double earningsForDay = earnings[day] ?? 0;
      barGroups.add(
        BarChartGroupData(
          x: orderedDays.indexOf(day), // Assign index as x-value
          barRods: [
            BarChartRodData(
                toY: earningsForDay,
                color: AppColors.primary,
                width: 20,
                borderRadius: BorderRadius.zero),
          ],
        ),
      );
    }

    return barGroups;
  }
}
