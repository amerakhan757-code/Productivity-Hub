import 'package:flutter/material.dart';
import 'api_service.dart';

void main() {
  runApp(const ProductivityApp());
}

// ============================================================
// APP
// ============================================================

class ProductivityApp extends StatelessWidget {
  const ProductivityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Productivity Hub',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090611),
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9B5CFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

// ============================================================
// MODELS
// ============================================================

class Goal {
  String? id;
  String title;
  String description;
  DateTime deadline;

  Goal({
    this.id,
    required this.title,
    required this.description,
    required this.deadline,
  });
}

class Task {
  String? id;
  String? goalId;
  String title;
  String goalTitle;
  DateTime deadline;
  bool completed;
  String priority;

  Task({
    this.id,
    this.goalId,
    required this.title,
    required this.goalTitle,
    required this.deadline,
    this.completed = false,
    this.priority = 'Medium',
  });
}

// ============================================================
// MAIN DASHBOARD
// ============================================================

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  int selectedIndex = 0;

  // ----------------------------------------------------------
  // DATA
  // ----------------------------------------------------------

  final List<Goal> goals = [];
  final List<Task> tasks = [];

  bool isLoading = true;

  // ----------------------------------------------------------
  // INITIAL LOAD
  // ----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ApiService.getGoals(),
        ApiService.getTasks(),
      ]);

      final goalData = results[0] as List<dynamic>;
      final taskData = results[1] as List<dynamic>;

      final loadedGoals = goalData.map((item) {
        final data = Map<String, dynamic>.from(item);

        return Goal(
          id: data['id']?.toString(),
          title: data['title']?.toString() ?? '',
          description: data['description']?.toString() ?? '',
          deadline: DateTime.parse(
            data['deadline'].toString(),
          ),
        );
      }).toList();

      final loadedTasks = taskData.map((item) {
        final data = Map<String, dynamic>.from(item);

        final goalId = data['goal_id']?.toString();

        String goalTitle = 'Unknown Goal';

        for (final goal in loadedGoals) {
          if (goal.id == goalId) {
            goalTitle = goal.title;
            break;
          }
        }

        return Task(
          id: data['id']?.toString(),
          goalId: goalId,
          title: data['title']?.toString() ?? '',
          goalTitle: goalTitle,
          deadline: DateTime.parse(
            data['deadline'].toString(),
          ),
          completed: data['completed'] == true,
          priority: data['priority']?.toString() ?? 'Medium',
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        goals
          ..clear()
          ..addAll(loadedGoals);

        tasks
          ..clear()
          ..addAll(loadedTasks);

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load saved data: $e',
          ),
        ),
      );
    }
  }

  // ----------------------------------------------------------
  // PROGRESS
  // ----------------------------------------------------------

  double goalProgress(Goal goal) {
    final goalTasks = tasks
        .where((task) => task.goalId == goal.id)
        .toList();

    if (goalTasks.isEmpty) {
      return 0;
    }

    final completed =
        goalTasks.where((task) => task.completed).length;

    return (completed / goalTasks.length) * 100;
  }

  double get overallProgress {
    if (goals.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final goal in goals) {
      total += goalProgress(goal);
    }

    return total / goals.length;
  }

  int get completedTasks {
    return tasks.where((task) => task.completed).length;
  }

  int get pendingTasks {
    return tasks.where((task) => !task.completed).length;
  }

  int get overdueTasks {
    final now = DateTime.now();

    return tasks.where((task) {
      return !task.completed && task.deadline.isBefore(now);
    }).length;
  }

  // ----------------------------------------------------------
  // MOTIVATIONAL QUOTES
  // ----------------------------------------------------------

  String get motivationalQuote {
    final progress = overallProgress;

    if (overdueTasks > 0) {
      return "Every day, a step closer to your goals.";
    }

    if (progress >= 100) {
      return "Keep on, with the force, don't stop 'til you get enough.";
    }

    if (progress < 20) {
      return "A goal is a personal promise to your future self.";
    }

    if (progress < 40) {
      return "Stick to your plan, not your mood.";
    }

    if (progress < 60) {
      return "The most important thing about a goal is having one.";
    }

    if (progress < 80) {
      return "Will it be easy? Nope. Worth it? Absolutely.";
    }

    return "Be so disciplined it looks like madness.";
  }

  String get quoteLabel {
    if (overdueTasks > 0) {
      return 'GET BACK ON TRACK';
    }

    if (overallProgress >= 100) {
      return 'GOAL CRUSHED';
    }

    return "TODAY'S MINDSET";
  }

  // ----------------------------------------------------------
  // PRODUCTIVITY
  // ----------------------------------------------------------

  int get productivityScore {
    if (tasks.isEmpty) {
      return 0;
    }

    return ((completedTasks / tasks.length) * 100).round();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        goals: goals,
        tasks: tasks,
        overallProgress: overallProgress,
        completedTasks: completedTasks,
        pendingTasks: pendingTasks,
        overdueTasks: overdueTasks,
        productivityScore: productivityScore,
        motivationalQuote: motivationalQuote,
        quoteLabel: quoteLabel,
        goalProgress: goalProgress,
        onAddGoal: _addGoal,
        onAddTask: _addTask,
        onToggleTask: _toggleTask,
        onDeleteTask: _deleteTask,
      ),
      GoalsPage(
        goals: goals,
        tasks: tasks,
        goalProgress: goalProgress,
        onAddGoal: _addGoal,
        onDeleteGoal: _deleteGoal,
      ),
      TasksPage(
        tasks: tasks,
        goals: goals,
        onAddTask: _addTask,
        onToggleTask: _toggleTask,
        onDeleteTask: _deleteTask,
      ),
      ProgressPage(
        goals: goals,
        tasks: tasks,
        overallProgress: overallProgress,
        goalProgress: goalProgress,
        productivityScore: productivityScore,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF9B5CFF),
                ),
              )
            : pages[selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF110B1D),
          border: Border(
            top: BorderSide(
              color: Color(0xFF292035),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            setState(() {
              selectedIndex = index;
            });
          },
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFFB878FF),
          unselectedItemColor: const Color(0xFF756C82),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.flag_rounded),
              label: 'Goals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_rounded),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              label: 'Progress',
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ERROR MESSAGE
  // ==========================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ==========================================================
  // ADD GOAL
  // ==========================================================

  void _addGoal() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    DateTime? selectedDate;
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171021),
              title: const Text(
                'Create New Goal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: inputDecoration('Goal name'),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: inputDecoration('Description'),
                    ),
                    const SizedBox(height: 15),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFB878FF),
                      ),
                      title: const Text('Set deadline'),
                      subtitle: Text(
                        selectedDate == null
                            ? 'Choose your deadline'
                            : formatDate(selectedDate!),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF9B5CFF),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D4FFF),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) {
                            _showError(
                              'Please enter a goal name.',
                            );
                            return;
                          }

                          if (selectedDate == null) {
                            _showError(
                              'Please choose a deadline.',
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final result =
                                await ApiService.createGoal(
                              title: titleController.text.trim(),
                              description:
                                  descriptionController.text
                                          .trim()
                                          .isEmpty
                                      ? 'No description added.'
                                      : descriptionController.text
                                          .trim(),
                              deadline: selectedDate!,
                            );

                            final data =
                                Map<String, dynamic>.from(result);

                            final newGoal = Goal(
                              id: data['id']?.toString(),
                              title:
                                  data['title']?.toString() ??
                                      titleController.text.trim(),
                              description: data['description']
                                      ?.toString() ??
                                  (descriptionController.text
                                          .trim()
                                          .isEmpty
                                      ? 'No description added.'
                                      : descriptionController.text
                                          .trim()),
                              deadline: DateTime.parse(
                                data['deadline'].toString(),
                              ),
                            );

                            if (!mounted) return;

                            setState(() {
                              goals.add(newGoal);
                            });

                            Navigator.pop(dialogContext);
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                            });

                            _showError(
                              'Failed to create goal: $e',
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Goal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // ADD TASK
  // ==========================================================

  void _addTask() {
    if (goals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create a goal first before adding a task.',
          ),
        ),
      );

      return;
    }

    final titleController = TextEditingController();

    DateTime? selectedDate;

    String selectedGoal = goals.first.title;
    String priority = 'Medium';
    bool saving = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF171021),
              title: const Text(
                'Add New Task',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: inputDecoration('Task name'),
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGoal,
                      decoration: inputDecoration('Goal'),
                      items: goals.map(
                        (goal) {
                          return DropdownMenuItem(
                            value: goal.title,
                            child: Text(
                              goal.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedGoal = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: inputDecoration('Priority'),
                      items: const [
                        DropdownMenuItem(
                          value: 'Low',
                          child: Text('Low'),
                        ),
                        DropdownMenuItem(
                          value: 'Medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: 'High',
                          child: Text('High'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            priority = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.calendar_month_rounded,
                        color: Color(0xFFB878FF),
                      ),
                      title: const Text('Set deadline'),
                      subtitle: Text(
                        selectedDate == null
                            ? 'Choose your deadline'
                            : formatDate(selectedDate!),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2035),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF9B5CFF),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );

                        if (picked != null) {
                          setDialogState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8D4FFF),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) {
                            _showError(
                              'Please enter a task name.',
                            );
                            return;
                          }

                          if (selectedDate == null) {
                            _showError(
                              'Please choose a deadline.',
                            );
                            return;
                          }

                          final selectedGoalObject =
                              goals.firstWhere(
                            (goal) =>
                                goal.title == selectedGoal,
                          );

                          if (selectedGoalObject.id == null) {
                            _showError(
                              'This goal has no valid ID.',
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                          });

                          try {
                            final result =
                                await ApiService.createTask(
                              title: titleController.text.trim(),
                              goalId: selectedGoalObject.id!,
                              deadline: selectedDate!,
                              priority: priority,
                            );

                            final data =
                                Map<String, dynamic>.from(result);

                            final newTask = Task(
                              id: data['id']?.toString(),
                              goalId:
                                  data['goal_id']?.toString() ??
                                      selectedGoalObject.id,
                              title:
                                  data['title']?.toString() ??
                                      titleController.text.trim(),
                              goalTitle: selectedGoalObject.title,
                              deadline: DateTime.parse(
                                data['deadline'].toString(),
                              ),
                              completed:
                                  data['completed'] == true,
                              priority:
                                  data['priority']?.toString() ??
                                      priority,
                            );

                            if (!mounted) return;

                            setState(() {
                              tasks.add(newTask);
                            });

                            Navigator.pop(dialogContext);
                          } catch (e) {
                            setDialogState(() {
                              saving = false;
                            });

                            _showError(
                              'Failed to create task: $e',
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Add Task'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================================
  // TASK ACTIONS
  // ==========================================================

  Future<void> _toggleTask(int index) async {
    if (index < 0 || index >= tasks.length) {
      return;
    }

    final task = tasks[index];

    if (task.id == null) {
      setState(() {
        task.completed = !task.completed;
      });

      return;
    }

    try {
      final result = await ApiService.toggleTask(task.id!);

      final data = Map<String, dynamic>.from(result);

      if (!mounted) return;

      setState(() {
        task.completed = data['completed'] == true;
      });
    } catch (e) {
      _showError(
        'Failed to update task: $e',
      );
    }
  }

  Future<void> _deleteTask(int index) async {
    if (index < 0 || index >= tasks.length) {
      return;
    }

    final task = tasks[index];

    if (task.id == null) {
      setState(() {
        tasks.removeAt(index);
      });

      return;
    }

    try {
      await ApiService.deleteTask(task.id!);

      if (!mounted) return;

      setState(() {
        tasks.removeAt(index);
      });
    } catch (e) {
      _showError(
        'Failed to delete task: $e',
      );
    }
  }

  Future<void> _deleteGoal(int index) async {
    if (index < 0 || index >= goals.length) {
      return;
    }

    final goal = goals[index];

    if (goal.id == null) {
      setState(() {
        goals.removeAt(index);

        tasks.removeWhere(
          (task) =>
              task.goalId == goal.id ||
              task.goalTitle == goal.title,
        );
      });

      return;
    }

    try {
      await ApiService.deleteGoal(goal.id!);

      if (!mounted) return;

      setState(() {
        goals.removeAt(index);

        tasks.removeWhere(
          (task) => task.goalId == goal.id,
        );
      });
    } catch (e) {
      _showError(
        'Failed to delete goal: $e',
      );
    }
  }
}

// ============================================================
// DASHBOARD
// ============================================================

class DashboardPage extends StatelessWidget {
  final List<Goal> goals;
  final List<Task> tasks;
  final double overallProgress;
  final int completedTasks;
  final int pendingTasks;
  final int overdueTasks;
  final int productivityScore;
  final String motivationalQuote;
  final String quoteLabel;
  final double Function(Goal) goalProgress;
  final VoidCallback onAddGoal;
  final VoidCallback onAddTask;
  final Function(int) onToggleTask;
  final Function(int) onDeleteTask;

  const DashboardPage({
    super.key,
    required this.goals,
    required this.tasks,
    required this.overallProgress,
    required this.completedTasks,
    required this.pendingTasks,
    required this.overdueTasks,
    required this.productivityScore,
    required this.motivationalQuote,
    required this.quoteLabel,
    required this.goalProgress,
    required this.onAddGoal,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 950;

        return SingleChildScrollView(
          padding: EdgeInsets.all(wide ? 30 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 25),

              MotivationCard(
                quote: motivationalQuote,
                label: quoteLabel,
              ),

              const SizedBox(height: 20),

              GridView.count(
                crossAxisCount: wide ? 4 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: wide ? 1.55 : 1.3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  StatCard(
                    title: 'TOTAL GOALS',
                    value: '${goals.length}',
                    subtitle: 'Your current goals',
                    icon: Icons.flag_rounded,
                  ),
                  StatCard(
                    title: 'TASKS DONE',
                    value: '$completedTasks',
                    subtitle: '$pendingTasks remaining',
                    icon: Icons.task_alt_rounded,
                  ),
                  StatCard(
                    title: 'PROGRESS',
                    value: '${overallProgress.round()}%',
                    subtitle: 'Overall progress',
                    icon: Icons.trending_up_rounded,
                  ),
                  StatCard(
                    title: 'PRODUCTIVITY',
                    value: '$productivityScore%',
                    subtitle: overdueTasks > 0
                        ? '$overdueTasks overdue'
                        : 'You are on track',
                    icon: Icons.bolt_rounded,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              SectionTitle(
                title: 'YOUR GOALS',
                buttonText: 'Add Goal',
                onPressed: onAddGoal,
              ),

              const SizedBox(height: 12),

              if (goals.isEmpty)
                const EmptyState(
                  icon: Icons.flag_outlined,
                  title: 'No goals yet',
                  subtitle:
                      'Create your first goal and start turning plans into progress.',
                )
              else
                ...goals.take(3).map(
                  (goal) {
                    return DashboardGoalCard(
                      goal: goal,
                      progress: goalProgress(goal),
                    );
                  },
                ),

              const SizedBox(height: 20),

              SectionTitle(
                title: 'YOUR TASKS',
                buttonText: 'Add Task',
                onPressed: onAddTask,
              ),

              const SizedBox(height: 12),

              if (tasks.isEmpty)
                const EmptyState(
                  icon: Icons.checklist_rounded,
                  title: 'No tasks yet',
                  subtitle:
                      'Break your goals into small tasks.',
                )
              else
                ...tasks.take(4).toList().asMap().entries.map(
                  (entry) {
                    return TaskTile(
                      task: entry.value,
                      onToggle: () {
                        onToggleTask(entry.key);
                      },
                      onDelete: () {
                        onDeleteTask(entry.key);
                      },
                    );
                  },
                ),

              const SizedBox(height: 20),

              const WeeklyChart(),

              const SizedBox(height: 25),

              Center(
                child: Text(
                  'PRODUCTIVITY HUB • MAKE IT HAPPEN',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.3),
                    letterSpacing: 2,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8E4DFF),
                Color(0xFFE35BFF),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9B5CFF).withOpacity(.35),
                blurRadius: 20,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: Colors.white,
          ),
        ),

        const SizedBox(width: 14),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PRODUCTIVITY HUB',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Set goals. Take action. Track progress.',
                style: TextStyle(
                  color: Color(0xFF91889E),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// MOTIVATION CARD
// ============================================================

class MotivationCard extends StatelessWidget {
  final String quote;
  final String label;

  const MotivationCard({
    super.key,
    required this.quote,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF211035),
            Color(0xFF120B1D),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF9B5CFF).withOpacity(.35),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B5CFF).withOpacity(.12),
            blurRadius: 30,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF9B5CFF).withOpacity(.15),
            ),
            child: const Icon(
              Icons.format_quote_rounded,
              color: Color(0xFFD09CFF),
              size: 30,
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFC084FF),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  quote,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STAT CARD
// ============================================================

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF120D1B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF2A2134),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: const Color(0xFFB878FF),
              ),
              const Spacer(),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 15,
                color: Color(0xFF6E6479),
              ),
            ],
          ),

          const Spacer(),

          Text(
            value,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFFB878FF),
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF756C82),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DASHBOARD GOAL CARD
// ============================================================

class DashboardGoalCard extends StatelessWidget {
  final Goal goal;
  final double progress;

  const DashboardGoalCard({
    super.key,
    required this.goal,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF120D1B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2A2134),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: const Color(0xFF9B5CFF).withOpacity(.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFFC084FF),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Deadline: ${formatDate(goal.deadline)}',
                      style: const TextStyle(
                        color: Color(0xFF756C82),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Text(
                '${progress.round()}%',
                style: const TextStyle(
                  color: Color(0xFFC084FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: progress / 100,
            minHeight: 7,
            borderRadius: BorderRadius.circular(10),
            backgroundColor: const Color(0xFF292034),
            valueColor: const AlwaysStoppedAnimation(
              Color(0xFF9B5CFF),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SECTION TITLE
// ============================================================

class SectionTitle extends StatelessWidget {
  final String title;
  final String buttonText;
  final VoidCallback onPressed;

  const SectionTitle({
    super.key,
    required this.title,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFFB878FF),
              letterSpacing: 1.8,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(
            Icons.add,
            size: 15,
          ),
          label: Text(buttonText),
        ),
      ],
    );
  }
}

// ============================================================
// TASK TILE
// ============================================================

class TaskTile extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  bool get isOverdue {
    return !task.completed &&
        task.deadline.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF120D1B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isOverdue
              ? const Color(0xFF9B5CFF)
              : const Color(0xFF241B2E),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: task.completed
                      ? const Color(0xFFB878FF)
                      : const Color(0xFF655B70),
                  width: 2,
                ),
                color: task.completed
                    ? const Color(0xFF8D4FFF)
                    : Colors.transparent,
              ),
              child: task.completed
                  ? const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.completed
                        ? const Color(0xFF756C82)
                        : Colors.white,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  task.goalTitle,
                  style: const TextStyle(
                    color: Color(0xFFC084FF),
                    fontSize: 9,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  isOverdue
                      ? 'Overdue • ${formatDate(task.deadline)}'
                      : formatDate(task.deadline),
                  style: TextStyle(
                    color: isOverdue
                        ? const Color(0xFFE58BFF)
                        : const Color(0xFF756C82),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          PriorityBadge(
            priority: task.priority,
          ),

          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              size: 18,
              color: Color(0xFF756C82),
            ),
            onSelected: (value) {
              if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PRIORITY BADGE
// ============================================================

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({
    super.key,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF9B5CFF).withOpacity(.1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        priority.toUpperCase(),
        style: const TextStyle(
          fontSize: 7,
          color: Color(0xFFC084FF),
          fontWeight: FontWeight.bold,
          letterSpacing: .8,
        ),
      ),
    );
  }
}

// ============================================================
// WEEKLY CHART
// ============================================================

class WeeklyChart extends StatelessWidget {
  const WeeklyChart({super.key});

  @override
  Widget build(BuildContext context) {
    final values = [
      0.35,
      0.52,
      0.45,
      0.78,
      0.62,
      0.90,
      0.72,
    ];

    final days = [
      'M',
      'T',
      'W',
      'T',
      'F',
      'S',
      'S',
    ];

    return Container(
      height: 280,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF120D1B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF2A2134),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'WEEKLY PRODUCTIVITY',
            style: TextStyle(
              color: Color(0xFFB878FF),
              letterSpacing: 1.8,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 18),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                values.length,
                (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${(values[index] * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Color(0xFF756C82),
                            ),
                          ),

                          const SizedBox(height: 5),

                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: values[index],
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(8),
                                    gradient:
                                        const LinearGradient(
                                      begin:
                                          Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Color(0xFF6334C7),
                                        Color(0xFFC16AFF),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 7),

                          Text(
                            days[index],
                            style: const TextStyle(
                              color: Color(0xFF91889E),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GOALS PAGE
// ============================================================

class GoalsPage extends StatelessWidget {
  final List<Goal> goals;
  final List<Task> tasks;
  final double Function(Goal) goalProgress;
  final VoidCallback onAddGoal;
  final Function(int) onDeleteGoal;

  const GoalsPage({
    super.key,
    required this.goals,
    required this.tasks,
    required this.goalProgress,
    required this.onAddGoal,
    required this.onDeleteGoal,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'MY GOALS',
            subtitle: 'Choose what you want to achieve.',
            icon: Icons.flag_rounded,
            buttonText: 'New Goal',
            onPressed: onAddGoal,
          ),

          const SizedBox(height: 22),

          if (goals.isEmpty)
            const EmptyState(
              icon: Icons.flag_outlined,
              title: 'No goals yet',
              subtitle:
                  'Create your first goal and start your journey.',
            )
          else
            ...goals.asMap().entries.map(
              (entry) {
                return GoalCard(
                  goal: entry.value,
                  progress: goalProgress(entry.value),
                  taskCount: tasks
                      .where(
                        (task) =>
                            task.goalId == entry.value.id,
                      )
                      .length,
                  onDelete: () {
                    onDeleteGoal(entry.key);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// GOAL CARD
// ============================================================

class GoalCard extends StatelessWidget {
  final Goal goal;
  final double progress;
  final int taskCount;
  final VoidCallback onDelete;

  const GoalCard({
    super.key,
    required this.goal,
    required this.progress,
    required this.taskCount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF120D1B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF2A2134),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFF9B5CFF).withOpacity(.12),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFFC084FF),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      goal.description,
                      style: const TextStyle(
                        color: Color(0xFF756C82),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFF756C82),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Color(0xFF756C82),
              ),

              const SizedBox(width: 7),

              Text(
                'Deadline: ${formatDate(goal.deadline)}',
                style: const TextStyle(
                  color: Color(0xFF91889E),
                  fontSize: 11,
                ),
              ),

              const Spacer(),

              Text(
                '$taskCount tasks',
                style: const TextStyle(
                  color: Color(0xFF756C82),
                  fontSize: 10,
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(10),
                  backgroundColor: const Color(0xFF292034),
                  valueColor: const AlwaysStoppedAnimation(
                    Color(0xFF9B5CFF),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Text(
                '${progress.round()}%',
                style: const TextStyle(
                  color: Color(0xFFC084FF),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// TASKS PAGE
// ============================================================

class TasksPage extends StatelessWidget {
  final List<Task> tasks;
  final List<Goal> goals;
  final VoidCallback onAddTask;
  final Function(int) onToggleTask;
  final Function(int) onDeleteTask;

  const TasksPage({
    super.key,
    required this.tasks,
    required this.goals,
    required this.onAddTask,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'MY TASKS',
            subtitle: 'Turn your goals into daily actions.',
            icon: Icons.check_circle_rounded,
            buttonText: 'New Task',
            onPressed: onAddTask,
          ),

          const SizedBox(height: 22),

          if (tasks.isEmpty)
            const EmptyState(
              icon: Icons.checklist_rounded,
              title: 'No tasks yet',
              subtitle:
                  'Create a goal first, then break it into tasks.',
            )
          else
            ...tasks.asMap().entries.map(
              (entry) {
                return TaskTile(
                  task: entry.value,
                  onToggle: () {
                    onToggleTask(entry.key);
                  },
                  onDelete: () {
                    onDeleteTask(entry.key);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

// ============================================================
// PROGRESS PAGE
// ============================================================

class ProgressPage extends StatelessWidget {
  final List<Goal> goals;
  final List<Task> tasks;
  final double overallProgress;
  final double Function(Goal) goalProgress;
  final int productivityScore;

  const ProgressPage({
    super.key,
    required this.goals,
    required this.tasks,
    required this.overallProgress,
    required this.goalProgress,
    required this.productivityScore,
  });

  @override
  Widget build(BuildContext context) {
    final completed =
        tasks.where((task) => task.completed).length;

    final isWide =
        MediaQuery.of(context).size.width > 800;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'PROGRESS',
            subtitle: 'See how far you have come.',
            icon: Icons.bar_chart_rounded,
          ),

          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF211035),
                  Color(0xFF120D1B),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF9B5CFF).withOpacity(.3),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'OVERALL PROGRESS',
                  style: TextStyle(
                    color: Color(0xFFB878FF),
                    letterSpacing: 2,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: 190,
                  height: 190,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 190,
                        height: 190,
                        child: CircularProgressIndicator(
                          value: overallProgress / 100,
                          strokeWidth: 15,
                          backgroundColor:
                              const Color(0xFF292034),
                          valueColor:
                              const AlwaysStoppedAnimation(
                            Color(0xFFB45CFF),
                          ),
                        ),
                      ),

                      Text(
                        '${overallProgress.round()}%',
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          GridView.count(
            crossAxisCount: isWide ? 3 : 1,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: isWide ? 2 : 3,
            children: [
              StatCard(
                title: 'GOALS',
                value: '${goals.length}',
                subtitle: 'Your goals',
                icon: Icons.flag_rounded,
              ),
              StatCard(
                title: 'TASKS DONE',
                value: '$completed',
                subtitle: '${tasks.length} total tasks',
                icon: Icons.check_circle_rounded,
              ),
              StatCard(
                title: 'PRODUCTIVITY',
                value: '$productivityScore%',
                subtitle: 'Task completion',
                icon: Icons.bolt_rounded,
              ),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF120D1B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF2A2134),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GOAL BREAKDOWN',
                  style: TextStyle(
                    color: Color(0xFFB878FF),
                    letterSpacing: 1.8,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 18),

                if (goals.isEmpty)
                  const Text(
                    'Create goals to see your progress here.',
                    style: TextStyle(
                      color: Color(0xFF756C82),
                    ),
                  )
                else
                  ...goals.map(
                    (goal) {
                      final progress = goalProgress(goal);

                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: 18,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    goal.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),

                                Text(
                                  '${progress.round()}%',
                                  style: const TextStyle(
                                    color: Color(0xFFC084FF),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 7),

                            LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 7,
                              borderRadius:
                                  BorderRadius.circular(10),
                              backgroundColor:
                                  const Color(0xFF292034),
                              valueColor:
                                  const AlwaysStoppedAnimation(
                                Color(0xFF9B5CFF),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const WeeklyChart(),
        ],
      ),
    );
  }
}

// ============================================================
// PAGE HEADER
// ============================================================

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? buttonText;
  final VoidCallback? onPressed;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.buttonText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: const Color(0xFF9B5CFF).withOpacity(.12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFFC084FF),
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF756C82),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        if (buttonText != null)
          ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(
              Icons.add,
              size: 17,
            ),
            label: Text(buttonText!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D4FFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(45),
      decoration: BoxDecoration(
        color: const Color(0xFF120D1B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF2A2134),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 50,
            color: const Color(0xFF70577F),
          ),

          const SizedBox(height: 15),

          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF756C82),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// INPUT DECORATION
// ============================================================

InputDecoration inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(
      color: Color(0xFF91889E),
    ),
    filled: true,
    fillColor: const Color(0xFF0D0914),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Color(0xFF2A2134),
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Color(0xFF2A2134),
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: Color(0xFF9B5CFF),
      ),
    ),
  );
}

// ============================================================
// DATE FORMAT
// ============================================================

String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}