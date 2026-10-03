import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../domain/export_service.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Jobs'),
      ),
      body: Consumer<ExportService>(
        builder: (context, exportService, child) {
          final jobs = exportService.jobs;
          
          if (jobs.isEmpty) {
            return const Center(
              child: Text(
                'No active or completed exports.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                color: Colors.grey[900],
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              job.id,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusChip(job.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Target: ${job.resolutionTarget} @ ${job.fpsTarget}fps', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      if (job.status == ExportStatus.processing)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            LinearProgressIndicator(
                              value: job.progress,
                              backgroundColor: Colors.grey[800],
                              color: Colors.amber,
                            ),
                            const SizedBox(height: 8),
                            Text('${(job.progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white54)),
                          ],
                        ),
                      if (job.status == ExportStatus.failed && job.error != null)
                        Text(job.error!, style: const TextStyle(color: Colors.redAccent)),
                      if (job.status == ExportStatus.processing || job.status == ExportStatus.pending)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => exportService.cancelJob(job.id),
                            child: const Text('Cancel', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(ExportStatus status) {
    Color color;
    String label;
    
    switch (status) {
      case ExportStatus.pending:
        color = Colors.grey; label = 'Pending'; break;
      case ExportStatus.processing:
        color = Colors.blue; label = 'Processing'; break;
      case ExportStatus.completed:
        color = Colors.green; label = 'Completed'; break;
      case ExportStatus.failed:
        color = Colors.red; label = 'Failed'; break;
      case ExportStatus.cancelled:
        color = Colors.orange; label = 'Cancelled'; break;
      case ExportStatus.paused:
        color = Colors.amber; label = 'Paused'; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
