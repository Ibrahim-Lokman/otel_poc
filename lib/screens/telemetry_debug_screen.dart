import 'package:flutter/material.dart';
import 'package:otel_poc/global_instances.dart';

class TelemetryDebugScreen extends StatelessWidget {
  const TelemetryDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = sessionTracker.sessions;
    final currentSession = sessionTracker.currentSession;
    final analytics = sessionTracker.getSessionAnalytics();

    return Scaffold(
      appBar: AppBar(title: Text('OpenTelemetry & Session Debug')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Session Card
            if (currentSession != null)
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 12),
                          SizedBox(width: 8),
                          Text(
                            'Current Session',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('User: ${currentSession.userName}'),
                      Text(
                          'Session ID: ${currentSession.sessionId.substring(0, 8)}...'),
                      Text('Duration: ${currentSession.duration}'),
                      SizedBox(height: 8),
                      Text(
                        'User Flow:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Text(
                          currentSession.formattedFlow.isEmpty
                              ? 'No actions yet'
                              : currentSession.formattedFlow,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Session Analytics
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Session Analytics',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildMetricTile(
                        'Total Sessions', '${analytics['total_sessions']}'),
                    _buildMetricTile(
                        'Active Sessions', '${analytics['active_sessions']}'),
                    _buildMetricTile('Completed Sessions',
                        '${analytics['completed_sessions']}'),
                    _buildMetricTile('Avg Session Duration',
                        '${(analytics['avg_session_duration_seconds'] as num).toStringAsFixed(0)}s'),
                    SizedBox(height: 8),
                    Text('Most Common Actions:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if ((analytics['most_common_actions'] as List).isNotEmpty)
                      ...(analytics['most_common_actions'] as List)
                          .map((action) => Padding(
                                padding: EdgeInsets.only(left: 16, top: 4),
                                child: Text('• $action',
                                    style: TextStyle(fontSize: 12)),
                              ))
                    else
                      Padding(
                        padding: EdgeInsets.only(left: 16, top: 4),
                        child: Text('No actions recorded yet',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Previous Sessions
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📝 Session History',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    if (sessions.isEmpty)
                      Text('No sessions recorded yet')
                    else
                      ...sessions.reversed.take(5).map((session) => Container(
                            margin: EdgeInsets.only(bottom: 16),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: session.isActive
                                  ? Colors.green[50]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: session.isActive
                                    ? Colors.green[200]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (session.isActive)
                                      Icon(Icons.circle,
                                          color: Colors.green, size: 10),
                                    if (session.isActive) SizedBox(width: 4),
                                    Text(
                                      'Session ${sessions.indexOf(session) + 1} - ${session.userName}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Spacer(),
                                    Text(
                                      session.duration,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Start: ${_formatTime(session.startTime)}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[600]),
                                ),
                                if (!session.isActive &&
                                    session.endTime != null)
                                  Text(
                                    'End: ${_formatTime(session.endTime!)}',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.grey[600]),
                                  ),
                                SizedBox(height: 8),
                                Text(
                                  'User Flow:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  session.formattedFlow.isEmpty
                                      ? 'No actions recorded'
                                      : session.formattedFlow,
                                  style: TextStyle(fontSize: 11),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Real-time Metrics Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Real-time Metrics',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildMetricTile('Conversion Rate',
                        '${metricsCollector.getConversionRate().toStringAsFixed(1)}%'),
                    _buildMetricTile('Cart Abandonment Rate',
                        '${metricsCollector.getCartAbandonmentRate().toStringAsFixed(1)}%'),
                    _buildMetricTile('Avg Response Time',
                        '${metricsCollector.getAverageResponseTime().toStringAsFixed(0)}ms'),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Raw Metrics Data
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔢 Raw Metrics Data',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatMetrics(metricsCollector.getAllMetrics()),
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // OpenTelemetry Features Card
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🔍 OpenTelemetry Features',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureTile('✅ Distributed Tracing',
                        'User journey spans across BLoCs'),
                    _buildFeatureTile(
                        '✅ Session Tracking', 'Complete user flow monitoring'),
                    _buildFeatureTile('✅ Custom Events',
                        'login_attempt, product_viewed, cart_updated, etc.'),
                    _buildFeatureTile(
                        '✅ Error Tracking', 'Payment failures, network errors'),
                    _buildFeatureTile('✅ Custom Metrics',
                        'Conversion rate, abandonment rate, response times'),
                    _buildFeatureTile('✅ Context Propagation',
                        'Parent-child span relationships'),
                    _buildFeatureTile('✅ Resource Attributes',
                        'App version, device info, user demographics'),
                    _buildFeatureTile('✅ Console Exporter',
                        'Check console for detailed span output'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Widget _buildMetricTile(String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(String title, String description) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(description,
              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  String _formatMetrics(Map<String, dynamic> metrics) {
    return metrics.entries.map((e) {
      var value = e.value;
      if (value is double) {
        value = value.toStringAsFixed(2);
      } else if (value is Map || value is List) {
        value = value.toString();
      }
      return '${e.key}: $value';
    }).join('\n');
  }
}
