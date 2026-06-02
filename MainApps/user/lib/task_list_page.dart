import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskListPage extends StatefulWidget {
  final int workId;
  final String workTitle;
  final int applicationId;

  const TaskListPage({
    super.key,
    required this.workId,
    required this.workTitle,
    required this.applicationId,
  });

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<dynamic> tasks = [];
  final taskController = TextEditingController();

  // Premium Colors
  static const Color brandNavy = Color(0xFF102030);
  static const Color brandTeal = Color(0xFF20A0A0);
  static const Color brandGrey = Color(0xFFF4F7F9);

  @override
  void initState() {
    super.initState();
    fetchTasks();
  }

  Future<void> fetchTasks() async {
    setState(() => isLoading = true);
    try {
      final response = await supabase
          .from('tbl_task')
          .select()
          .eq('work_id', widget.workId)
          .order('created_at', ascending: true);

      setState(() {
        tasks = response as List<dynamic>;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching tasks: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> addTask() async {
    if (taskController.text.trim().isEmpty) return;

    try {
      await supabase.from('tbl_task').insert({
        'work_id': widget.workId,
        'task_name': taskController.text.trim(),
        'is_completed': false,
      });

      taskController.clear();
      Navigator.pop(context);
      fetchTasks();
      _updateProgress();
    } catch (e) {
      _showError("Failed to add task: $e");
    }
  }

  Future<void> toggleTask(int taskId, bool currentStatus) async {
    try {
      await supabase
          .from('tbl_task')
          .update({'is_completed': !currentStatus})
          .eq('task_id', taskId);

      fetchTasks();
      _updateProgress();
    } catch (e) {
      _showError("Failed to update task: $e");
    }
  }

  Future<void> deleteTask(int taskId) async {
    try {
      await supabase.from('tbl_task').delete().eq('task_id', taskId);
      fetchTasks();
      _updateProgress();
    } catch (e) {
      _showError("Failed to delete task: $e");
    }
  }

  Future<void> _updateProgress() async {
    if (tasks.isEmpty) return;
    
    // Wait for the next state cycle to get fresh tasks if needed, 
    // but here we can just calculate after fetch. 
    // Actually, it's better to fetch first or calculate from the local list.
    
    // Re-fetch to be sure
    final response = await supabase
        .from('tbl_task')
        .select()
        .eq('work_id', widget.workId);
    
    final allTasks = response as List;
    if (allTasks.isEmpty) return;

    final completed = allTasks.where((t) => t['is_completed'] == true).length;
    final int progressPercent = ((completed / allTasks.length) * 100).round();

    await supabase
        .from('tbl_application')
        .update({'work_progress': progressPercent})
        .eq('application_id', widget.applicationId);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    int completedCount = tasks.where((t) => t['is_completed'] == true).length;
    double progressVal = tasks.isEmpty ? 0 : completedCount / tasks.length;

    return Scaffold(
      backgroundColor: brandGrey,
      appBar: AppBar(
        title: Text("milestones", style: GoogleFonts.poppins(color: brandNavy, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: brandNavy),
      ),
      body: Column(
        children: [
          // Progress Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.workTitle,
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: brandNavy),
                    ),
                    Text(
                      "${(progressVal * 100).toInt()}%",
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: brandTeal),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progressVal,
                    minHeight: 10,
                    backgroundColor: brandTeal.withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(brandTeal),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "$completedCount of ${tasks.length} tasks completed",
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: brandTeal))
                : tasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          bool isDone = task['is_completed'];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: brandNavy.withOpacity(0.02), blurRadius: 10)],
                            ),
                            child: ListTile(
                              leading: Checkbox(
                                value: isDone,
                                activeColor: brandTeal,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (v) => toggleTask(task['task_id'], isDone),
                              ),
                              title: Text(
                                task['task_name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  color: isDone ? Colors.grey : brandNavy,
                                  fontWeight: isDone ? FontWeight.normal : FontWeight.w500,
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                                onPressed: () => deleteTask(task['task_id']),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskDialog,
        backgroundColor: brandNavy,
        label: Text("Add Task", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("New Task", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: taskController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "What needs to be done?",
            hintStyle: GoogleFonts.poppins(fontSize: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: addTask,
            style: ElevatedButton.styleFrom(backgroundColor: brandTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.listTodo, size: 60, color: brandNavy.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text("No tasks added yet", style: GoogleFonts.poppins(color: Colors.grey)),
          const SizedBox(height: 8),
          Text("Break your work into small milestones", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }
}
