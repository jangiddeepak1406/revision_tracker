import 'package:flutter/material.dart';
import 'revision_logic.dart';
import 'db_helper.dart';
import 'notification_service.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() async {
  // 1. Setup a global UI error handler
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                const SizedBox(height: 10),
                const Text(
                  "Something went wrong.\nThe app will now exit.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => SystemNavigator.pop(), // Clean exit on Android
                  child: const Text("Exit App"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  };

  // 2. Catch initialization or logic errors
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await NotificationService.init(); 
    runApp(const RevisionApp());
  } catch (e) {
    // If the database fails to load or notifications crash during startup
    debugPrint("Critical Error: $e");
    SystemNavigator.pop(); 
  }
}
class RevisionApp extends StatelessWidget {
  const RevisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Revision Tracker',
      theme: ThemeData(primarySwatch: Colors.deepPurple, useMaterial3: true),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _revisionTasks = []; 
  String? _selectedSubject;
List<String> _subjects = [];
  String _currentPanel = "Coaching"; // Default panel
List<String> _panels = [];

@override
void initState() {
  super.initState();
  _initPanels();
  _refreshTasks();
}

void _initPanels() async {
  _panels = await DBHelper.getPanels();
  if (_panels.isEmpty) {
    await DBHelper.insertPanel("Coaching");
    await DBHelper.insertPanel("College");
    _panels = await DBHelper.getPanels();
  }
  setState(() {});
}

// Update your refresh logic to filter by the current panel
void _refreshTasks() async {
  final data = await DBHelper.getTasks();
  setState(() {
    // Only show tasks that belong to the active panel
    _revisionTasks = data.where((task) => task['panel'] == _currentPanel).toList();
  });
}
  Future<String?> _showNewPanelDialog() async {
  final TextEditingController panelController = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add New Panel'),
      content: TextField(
        controller: panelController,
        decoration: const InputDecoration(hintText: 'e.g. Trading or Personal'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), 
          child: const Text('Cancel')
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, panelController.text),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}
  Future<String?> _showNewSubjectDialog() async {
  final TextEditingController subController = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add New Subject'),
      content: TextField(
        controller: subController,
        decoration: const InputDecoration(hintText: 'e.g. Geography'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, subController.text),
          child: const Text('Add'),
        ),
      ],
    ),
  );
}
void _showAddTopicDialog() async {
  _subjects = await DBHelper.getSubjects();
  if (_subjects.isEmpty) {
    await DBHelper.insertSubject("History"); // Default subjects for you
    await DBHelper.insertSubject("Philosophy");
    _subjects = await DBHelper.getSubjects();
  }

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('New Revision Topic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _controller, decoration: const InputDecoration(hintText: 'Topic Name')),
            const SizedBox(height: 15),
            DropdownButton<String>(
              value: _selectedSubject,
              hint: const Text("Select Subject"),
              isExpanded: true,
              items: [..._subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                      const DropdownMenuItem(value: "ADD_NEW", child: Text("+ Add New Subject", style: TextStyle(color: Colors.blue)))],
              onChanged: (value) async {
                if (value == "ADD_NEW") {
                  // Show another small dialog to type new subject
                  String? newSub = await _showNewSubjectDialog();
                  if (newSub != null) {
                    await DBHelper.insertSubject(newSub);
                    final updated = await DBHelper.getSubjects();
                    setDialogState(() { _subjects = updated; _selectedSubject = newSub; });
                  }
                } else {
                  setDialogState(() { _selectedSubject = value; });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            // Inside _showAddTopicDialog -> ElevatedButton
onPressed: () async {
  if (_controller.text.isNotEmpty && _selectedSubject != null) {
    await DBHelper.insertTask(
      _controller.text, 
      DateTime.now().toIso8601String(), 
      0, 
      _selectedSubject!,
      _currentPanel // <--- CRITICAL: Make sure this is here!
    );
    _controller.clear();
    Navigator.pop(context);
    _refreshTasks();
  }
},
            child: const Text('Start Tracking'),
          ),
        ],
      ),
    ),
  );
}
 

 
  Widget _buildSubjectGroup(List<Map<String, dynamic>> tasks) {
  // 1. Group tasks by subject name
  Map<String, List<Map<String, dynamic>>> grouped = {};
  for (var task in tasks) {
    String sub = task['subject'] ?? "General";
    grouped.putIfAbsent(sub, () => []).add(task);
  }

  // 2. Create an ExpansionTile for each subject
  return Column(
    children: grouped.entries.map((entry) {
      return ExpansionTile(
        title: Text(
          entry.key, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)
        ),
        initiallyExpanded: true,
        children: entry.value.map((task) => _buildTaskCard(task)).toList(),
      );
    }).toList(),
  );
}
  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: color, 
          fontWeight: FontWeight.bold, 
          letterSpacing: 1.2,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final DateTime initialDate = DateTime.parse(task['date']);
  final int step = task['step'];
  final nextDate = RevisionLogic.getScheduledDate(initialDate, step);
  final status = nextDate == null ? "Completed" : RevisionLogic.getStatus(nextDate);
  const months = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  
  // Add this logic to fetch the last revision date for completed tasks
  String completionDateDisplay = "";
  if (status == "Completed") {
    // We can assume the 'date' field in the task was updated to the last revision 
    // or we can show the current date if you just clicked it.
    final lastDone = DateTime.parse(task['date']); 
    completionDateDisplay = "Finished on: ${lastDone.day} ${months[lastDone.month]} ${lastDone.year}";
  }

    return Dismissible(
      key: ValueKey(task['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        await DBHelper.deleteTask(task['id']);
        _refreshTasks();
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        color: status == "Completed" ? Colors.green[50] : (status == "Overdue" ? Colors.red[50] : Colors.white),
        child: ListTile(
          onTap: () async {
            final history = await DBHelper.getRevisionHistory(task['id']);
            if (!mounted) return;
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text("${task['name']}  "),
                content: SizedBox(
                  width: double.maxFinite,
                  child: history.isEmpty 
                    ? const Text("No revisions yet.")
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: history.length,
                        itemBuilder: (context, i) {
                          final actualDateStr = history[i]['revision_date'];
                          final targetDateStr = history[i]['target_date'];
                          
                          String actualDisplay = "Unknown";
                          if (actualDateStr != null) {
                            final d = DateTime.parse(actualDateStr);
                            actualDisplay = "${d.day} ${months[d.month]} ${d.year}";
                          }

                          String targetDisplay = "Not Set";
                          if (targetDateStr != null && targetDateStr != "N/A") {
                            final d = DateTime.parse(targetDateStr);
                            targetDisplay = "${d.day} ${months[d.month]} ${d.year}";
                          }

                          return ListTile(
                            leading: const Icon(Icons.history_edu),
                            title: Text("Revision ${history.length - i}"),
                            subtitle: Text("Done: $actualDisplay\nTarget: $targetDisplay"),
                          );
                        },
                        
                        
                      ),
                ),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
              ),
            );
          },
          title: Text(task['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      status == "Completed" ? "Mastered!" : "Next: ${nextDate!.day} ${months[nextDate.month]} ${nextDate.year}",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: status == "Completed" ? Colors.green[800] : (status == "Overdue" ? Colors.red[700] : Colors.grey[700]),
      ),
    ),
    // ADD THIS SECTION:
    if (status == "Completed")
      Text(
        completionDateDisplay,
        style: TextStyle(color: Colors.green[600], fontSize: 12),
      ),
    if (status != "Completed")
      Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          "Progress: Revision ${step + 1} of 4",
          style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple),
        ),
      ),
  ],
),
          trailing: status == "Completed" 
            ? const Icon(Icons.stars, color: Colors.orange)
            : IconButton(
                icon: const Icon(Icons.check_circle, color: Colors.green),
                onPressed: () async {
                  final target = RevisionLogic.getScheduledDate(initialDate, step);
                  await DBHelper.updateTaskStep(task['id'], step + 1, target?.toIso8601String() ?? "N/A");
                  _refreshTasks();
                },
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filtering logic - now inside the correct class
    final overdueTasks = _revisionTasks.where((task) {
      final nextDate = RevisionLogic.getScheduledDate(DateTime.parse(task['date']), task['step']);
      return nextDate != null && RevisionLogic.getStatus(nextDate) == "Overdue";
    }).toList();

    final completedTasks = _revisionTasks.where((task) {
      final nextDate = RevisionLogic.getScheduledDate(DateTime.parse(task['date']), task['step']);
      return nextDate == null;
    }).toList();

    final scheduledTasks = _revisionTasks.where((task) {
      final nextDate = RevisionLogic.getScheduledDate(DateTime.parse(task['date']), task['step']);
      bool isOverdue = nextDate != null && RevisionLogic.getStatus(nextDate) == "Overdue";
      bool isCompleted = nextDate == null;
      return !isOverdue && !isCompleted;
    }).toList();

    return Scaffold(
    appBar: AppBar(title: const Text('Revision Tracker')),
    body: _revisionTasks.isEmpty
        ? const Center(child: Text('Add a task!'))
        : ListView(
            children: [
              if (overdueTasks.isNotEmpty) ...[
                _buildSectionHeader("Overdue", Colors.red),
                _buildSubjectGroup(overdueTasks), // Use the new helper
              ],
              if (scheduledTasks.isNotEmpty) ...[
                _buildSectionHeader("On Schedule", Colors.blue),
                _buildSubjectGroup(scheduledTasks), // Use the new helper
              ],
              if (completedTasks.isNotEmpty) ...[
                _buildSectionHeader("Completed", Colors.green),
                _buildSubjectGroup(completedTasks), // Use the new helper
              ],
            ],
          ),
    floatingActionButton: FloatingActionButton(
      onPressed: _showAddTopicDialog,
      child: const Icon(Icons.add),
    ),
    drawer: Drawer(
  child: ListView(
    children: [
      const DrawerHeader(
        decoration: BoxDecoration(color: Colors.deepPurple),
        child: Text('My Study Spaces', style: TextStyle(color: Colors.white, fontSize: 24)),
      ),
      // List existing panels
      ..._panels.map((panel) => ListTile(
        leading: const Icon(Icons.dashboard_customize),
        title: Text(panel, style: TextStyle(fontWeight: _currentPanel == panel ? FontWeight.bold : FontWeight.normal)),
        onTap: () {
          setState(() => _currentPanel = panel);
          _refreshTasks();
          Navigator.pop(context); // Close drawer
        },
      )),
      const Divider(),
      // Add New Panel Button
      ListTile(
        leading: const Icon(Icons.add, color: Colors.blue),
        title: const Text('Add New Panel', style: TextStyle(color: Colors.blue)),
        onTap: () async {
          String? newPanel = await _showNewPanelDialog();
          if (newPanel != null && newPanel.isNotEmpty) {
            await DBHelper.insertPanel(newPanel);
            _initPanels();
          }
        },
      ),
    ],
  ),
),
  );
    
  }
}
