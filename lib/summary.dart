// summary.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'job_model.dart';
import 'data_service.dart';

class MechanicPerformance {
  final String name;
  final int jobsCompleted;
  final double avgTime;

  MechanicPerformance({
    required this.name,
    required this.jobsCompleted,
    required this.avgTime,
  });
}

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool isMonthly = true;
  bool isLoading = true;
  Map<String, dynamic>? _currentData;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Ensure current mechanic is loaded first
    await DataService.getCurrentMechanic();
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    try {
      List<Job> jobs;
      if (isMonthly) {
        jobs = await DataService.getMonthlyJobs();
      } else {
        jobs = await DataService.getYearlyJobs();
      }

      final data = _calculateStats(jobs);
      setState(() {
        _currentData = data;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        isLoading = false;
        _currentData = _getEmptyStats();
      });
    }
  }

  Map<String, dynamic> _getEmptyStats() {
    return {
      'totalJobs': 0,
      'completed': 0,
      'pending': 0,
      'revenue': 0,
      'avgCompletionTime': null,
      'topServices': <Map<String, dynamic>>[],
      'mechanics': <MechanicPerformance>[],
      'revenueTrend': <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _calculateStats(List<Job> jobs) {
    int totalJobs = jobs.length;
    int completed = jobs.where((job) => job.status == "Completed").length;
    int inProgress = jobs.where((job) => job.status == "In Progress").length;
    int assigned = jobs.where((job) => job.status == "Assigned").length;
    int pending = assigned + inProgress;

    // Calculate revenue based on parts cost
    double revenue = jobs.fold(0.0, (sum, job) => sum + job.totalPartsCost);

    // Count service types
    Map<String, int> serviceCount = {};
    for (Job job in jobs) {
      for (String service in job.services) {
        serviceCount[service] = (serviceCount[service] ?? 0) + 1;
      }
    }

    // Get top 3 most popular services
    List<MapEntry<String, int>> sortedServices = serviceCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> topServices = sortedServices
        .take(3)
        .map((entry) => {'name': entry.key, 'count': entry.value})
        .toList();

    // Calculate mechanic performance (only count completed jobs)
    Map<String, List<Job>> mechanicJobs = {};
    for (Job job in jobs.where((j) => j.status == "Completed")) {
      String assignedTo = job.assignedTo.isNotEmpty ? job.assignedTo : "Unassigned";
      if (!mechanicJobs.containsKey(assignedTo)) {
        mechanicJobs[assignedTo] = [];
      }
      mechanicJobs[assignedTo]!.add(job);
    }

    List<MechanicPerformance> mechanics = mechanicJobs.entries.map((entry) {
      String mechanicName = entry.key;
      List<Job> mechanicCompletedJobs = entry.value;

      // Calculate real average time (from job's totalTimeSpent field) - no fallback
      double? avgTime;
      List<double> times = [];
      for (Job job in mechanicCompletedJobs) {
        if (job.totalTimeSpent != "-" && job.totalTimeSpent.isNotEmpty) {
          String timeStr = job.totalTimeSpent.replaceAll('h', '').trim();
          double? time = double.tryParse(timeStr);
          if (time != null) {
            times.add(time);
          }
        }
      }
      if (times.isNotEmpty) {
        avgTime = times.reduce((a, b) => a + b) / times.length;
      }

      return MechanicPerformance(
        name: mechanicName,
        jobsCompleted: mechanicCompletedJobs.length,
        avgTime: avgTime != null ? double.parse(avgTime.toStringAsFixed(1)) : 0.0,
      );
    }).toList();

    // Sort by number of completed jobs
    mechanics.sort((a, b) => b.jobsCompleted.compareTo(a.jobsCompleted));

    // Calculate average completion time - no fallback
    double? avgCompletionTime;
    List<double> completionTimes = [];
    for (Job job in jobs.where((j) => j.status == "Completed")) {
      if (job.totalTimeSpent != "-" && job.totalTimeSpent.isNotEmpty) {
        String timeStr = job.totalTimeSpent.replaceAll('h', '').trim();
        double? time = double.tryParse(timeStr);
        if (time != null) {
          completionTimes.add(time);
        }
      }
    }
    if (completionTimes.isNotEmpty) {
      avgCompletionTime = completionTimes.reduce((a, b) => a + b) / completionTimes.length;
    }

    // Calculate real revenue trend data
    List<Map<String, dynamic>> revenueTrend = _calculateRevenueTrend(jobs);

    return {
      'totalJobs': totalJobs,
      'completed': completed,
      'pending': pending,
      'revenue': revenue.toInt(),
      'avgCompletionTime': avgCompletionTime != null ? double.parse(avgCompletionTime.toStringAsFixed(1)) : null,
      'topServices': topServices,
      'mechanics': mechanics,
      'revenueTrend': revenueTrend,
    };
  }

  List<Map<String, dynamic>> _calculateRevenueTrend(List<Job> jobs) {
    if (jobs.isEmpty) return [];

    // Sort jobs by date
    List<Job> sortedJobs = List.from(jobs);
    sortedJobs.sort((a, b) => DateTime.parse(a.createdDate).compareTo(DateTime.parse(b.createdDate)));

    if (isMonthly) {
      // For monthly view, group by weeks of the current month
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

      List<Map<String, dynamic>> weeklyRevenue = [];

      for (int week = 0; week < 6; week++) {
        final weekStart = firstDayOfMonth.add(Duration(days: week * 7));
        final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);

        if (weekStart.isAfter(lastDayOfMonth)) break;

        final weekJobs = sortedJobs.where((job) {
          final jobDate = DateTime.parse(job.createdDate);
          return jobDate.isAfter(weekStart.subtract(Duration(days: 1))) &&
              jobDate.isBefore(weekEnd.add(Duration(days: 1)));
        }).toList();

        final weekRevenue = weekJobs.fold(0.0, (sum, job) => sum + job.totalPartsCost);

        weeklyRevenue.add({
          'period': 'Week ${week + 1}',
          'revenue': weekRevenue,
          'index': week,
        });
      }

      return weeklyRevenue;
    } else {
      // For yearly view, group by months of the current year
      final now = DateTime.now();
      List<Map<String, dynamic>> monthlyRevenue = [];

      for (int month = 1; month <= 12; month++) {
        final monthJobs = sortedJobs.where((job) {
          final jobDate = DateTime.parse(job.createdDate);
          return jobDate.year == now.year && jobDate.month == month;
        }).toList();

        final monthRevenue = monthJobs.fold(0.0, (sum, job) => sum + job.totalPartsCost);

        final monthNames = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];

        monthlyRevenue.add({
          'period': monthNames[month - 1],
          'revenue': monthRevenue,
          'index': month - 1,
        });
      }

      return monthlyRevenue;
    }
  }

  Map<String, dynamic> get currentData {
    return _currentData ?? _getEmptyStats();
  }

  List<Map<String, dynamic>> get currentRevenueTrend {
    final data = currentData['revenueTrend'] as List<Map<String, dynamic>>? ?? [];
    return data;
  }

  String _getCurrentPeriodDisplay() {
    if (isMonthly) {
      final now = DateTime.now();
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return "${months[now.month - 1]} ${now.year} Performance";
    } else {
      final now = DateTime.now();
      return "${now.year} Performance";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bar_chart, color: Colors.indigo, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Workshop Summary",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _getCurrentPeriodDisplay(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Monthly/Yearly Toggle
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggleButton("Monthly", true),
                        _buildToggleButton("Yearly", false),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: isLoading
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text(
                      "Loading summary data...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards Row
                    _buildStatsCards(),
                    const SizedBox(height: 16),

                    // Performance Metrics
                    _buildPerformanceMetrics(),
                    const SizedBox(height: 16),

                    // Revenue Chart
                    _buildRevenueChart(),
                    const SizedBox(height: 16),

                    // Services Chart
                    _buildServicesChart(),
                    const SizedBox(height: 16),

                    // Mechanic Performance
                    _buildMechanicPerformance(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(String text, bool isFirst) {
    final isSelected = (isFirst && isMonthly) || (!isFirst && !isMonthly);
    return GestureDetector(
      onTap: () async {
        if ((isFirst && !isMonthly) || (!isFirst && isMonthly)) {
          setState(() {
            isMonthly = isFirst;
          });
          await _loadData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Total Jobs",
            currentData['totalJobs'].toString(),
            Icons.work,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            "Completed",
            currentData['completed'].toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChart() {
    final revenueTrend = currentRevenueTrend;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Revenue Trend",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "RM ${_formatNumber(currentData['revenue'])}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: revenueTrend.isEmpty
                ? const Center(
              child: Text(
                "No Data",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            )
                : LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getRevenueSpots(),
                    isCurved: true,
                    color: Colors.indigo,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.indigo.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesChart() {
    final topServices = currentData['topServices'] as List;
    if (topServices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "No service data available",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Top Services",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Pie Chart
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 80,
                  child: PieChart(
                    PieChartData(
                      sections: _getServicesSections(),
                      centerSpaceRadius: 20,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              // Legend
              Expanded(
                flex: 3,
                child: Column(
                  children: _buildServicesLegend(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    final avgTime = currentData['avgCompletionTime'];
    final avgTimeDisplay = avgTime != null ? "${avgTime}h" : "No Data";

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Performance Metrics",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Avg Time: $avgTimeDisplay", style: const TextStyle(fontSize: 11)),
              Text("Pending: ${currentData['pending']}", style: const TextStyle(fontSize: 11)),
              Text("Revenue: RM ${_formatNumber(currentData['revenue'])}", style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicPerformance() {
    final mechanics = currentData['mechanics'] as List<MechanicPerformance>;
    if (mechanics.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text(
            "No mechanic data available",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Mechanic Performance",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...mechanics.take(3).map((mechanic) => _buildMechanicCard(mechanic)).toList(),
        ],
      ),
    );
  }

  Widget _buildMechanicCard(MechanicPerformance mechanic) {
    bool isCurrentMechanic = DataService.isCurrentMechanic(mechanic.name);
    String avgTimeDisplay = mechanic.avgTime > 0 ? "${mechanic.avgTime}h" : "No Data";

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrentMechanic ? Colors.indigo.withOpacity(0.3) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      mechanic.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isCurrentMechanic ? Colors.indigo : Colors.black,
                      ),
                    ),
                    if (isCurrentMechanic) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.indigo,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "YOU",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "Jobs: ${mechanic.jobsCompleted}     Avg: $avgTimeDisplay",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _getRevenueSpots() {
    final revenueTrend = currentRevenueTrend;

    if (revenueTrend.isEmpty) {
      return [];
    }

    // Create spots from real revenue trend data only
    List<FlSpot> spots = [];
    for (int i = 0; i < revenueTrend.length; i++) {
      final revenue = revenueTrend[i]['revenue'] as double;
      spots.add(FlSpot(i.toDouble(), revenue));
    }

    return spots;
  }

  List<PieChartSectionData> _getServicesSections() {
    final services = currentData['topServices'] as List;
    final colors = [Colors.indigo, Colors.orange, Colors.green];

    return services.asMap().entries.map((entry) {
      final index = entry.key;
      final service = entry.value;
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: service['count'].toDouble(),
        title: '',
        radius: 30,
      );
    }).toList();
  }

  List<Widget> _buildServicesLegend() {
    final services = currentData['topServices'] as List;
    final colors = [Colors.indigo, Colors.orange, Colors.green];

    return services.asMap().entries.map((entry) {
      final index = entry.key;
      final service = entry.value;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                "${index + 1}. ${service['name']}",
                style: const TextStyle(fontSize: 10),
              ),
            ),
            Text(
              service['count'].toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return "${(number / 1000000).toStringAsFixed(1)}M";
    } else if (number >= 1000) {
      return "${(number / 1000).toStringAsFixed(1)}K";
    }
    return number.toString();
  }
}