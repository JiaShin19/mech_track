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

  Map<String, dynamic> _calculateStats(List<Job> jobs) {
    int totalJobs = jobs.length;
    int completed = jobs.where((job) => job.status == "Completed").length;
    int inProgress = jobs.where((job) => job.status == "In Progress").length;
    int assigned = jobs.where((job) => job.status == "Assigned").length;
    int pending = assigned + inProgress;

    // 计算收入（基于配件成本）
    double revenue = jobs.fold(0.0, (sum, job) => sum + job.totalPartsCost);

    // 统计服务类型
    Map<String, int> serviceCount = {};
    for (Job job in jobs) {
      for (String service in job.services) {
        serviceCount[service] = (serviceCount[service] ?? 0) + 1;
      }
    }

    // 获取最受欢迎的3个服务
    List<MapEntry<String, int>> sortedServices = serviceCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> topServices = sortedServices
        .take(3)
        .map((entry) => {'name': entry.key, 'count': entry.value})
        .toList();

    // 计算技师表现（只统计已完成的工作）
    Map<String, List<Job>> mechanicJobs = {};
    for (Job job in jobs.where((j) => j.status == "Completed")) {
      if (!mechanicJobs.containsKey(job.assignedTo)) {
        mechanicJobs[job.assignedTo] = [];
      }
      mechanicJobs[job.assignedTo]!.add(job);
    }

    List<MechanicPerformance> mechanics = mechanicJobs.entries.map((entry) {
      String mechanicName = entry.key;
      List<Job> mechanicCompletedJobs = entry.value;

      // 计算真实的平均时间（从job的totalTimeSpent字段）
      double avgTime = 2.5; // 默认值
      List<double> times = [];
      for (Job job in mechanicCompletedJobs) {
        if (job.totalTimeSpent != "-") {
          String timeStr = job.totalTimeSpent.replaceAll('h', '');
          double time = double.tryParse(timeStr) ?? 2.5;
          times.add(time);
        }
      }
      if (times.isNotEmpty) {
        avgTime = times.reduce((a, b) => a + b) / times.length;
      }

      return MechanicPerformance(
        name: mechanicName,
        jobsCompleted: mechanicCompletedJobs.length,
        avgTime: double.parse(avgTime.toStringAsFixed(1)),
      );
    }).toList();

    // 按完成工作数量排序
    mechanics.sort((a, b) => b.jobsCompleted.compareTo(a.jobsCompleted));

    // 计算平均完成时间
    List<double> completionTimes = [];
    for (Job job in jobs.where((j) => j.status == "Completed")) {
      if (job.totalTimeSpent != "-") {
        String timeStr = job.totalTimeSpent.replaceAll('h', '');
        double time = double.tryParse(timeStr) ?? 2.5;
        completionTimes.add(time);
      }
    }
    double avgCompletionTime = completionTimes.isEmpty
        ? 2.5
        : completionTimes.reduce((a, b) => a + b) / completionTimes.length;

    return {
      'totalJobs': totalJobs,
      'completed': completed,
      'pending': pending,
      'revenue': revenue.toInt(),
      'avgCompletionTime': double.parse(avgCompletionTime.toStringAsFixed(1)),
      'topServices': topServices,
      'mechanics': mechanics,
    };
  }

  Map<String, dynamic> get currentData {
    List<Job> jobs;

    if (isMonthly) {
      // 月度数据：当前月份的工作（2025年7月）
      jobs = DataService.getMonthlyJobs();
    } else {
      // 年度数据：真实的历史数据（2024年完整 + 2025年当前）
      jobs = DataService.getYearlyJobs();
    }

    return _calculateStats(jobs);
  }

  @override
  Widget build(BuildContext context) {
    final stats = currentData;

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
                          isMonthly ? "July 2025 Performance" : "2024-2025 Performance",
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
              child: SingleChildScrollView(
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
      onTap: () {
        setState(() {
          isMonthly = isFirst;
        });
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
            child: LineChart(
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
              Text("Avg Time: ${currentData['avgCompletionTime']}h", style: TextStyle(fontSize: 11)),
              Text("Pending: ${currentData['pending']}", style: TextStyle(fontSize: 11)),
              Text("Revenue: RM ${_formatNumber(currentData['revenue'])}", style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMechanicPerformance() {
    final mechanics = currentData['mechanics'] as List;
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

  Widget _buildMechanicCard(dynamic mechanic) {
    bool isCurrentMechanic = mechanic.name == DataService.currentMechanic;

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
                  "Jobs: ${mechanic.jobsCompleted}     Avg: ${mechanic.avgTime}h",
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
    double baseRevenue = currentData['revenue'].toDouble();

    return [
      FlSpot(0, baseRevenue * 0.7),
      FlSpot(1, baseRevenue * 0.8),
      FlSpot(2, baseRevenue * 0.85),
      FlSpot(3, baseRevenue * 0.9),
      FlSpot(4, baseRevenue * 0.95),
      FlSpot(5, baseRevenue),
    ];
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