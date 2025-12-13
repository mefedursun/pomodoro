import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'dart:async';
import 'dart:convert';

// ============================================================================
// MAIN FUNCTION
// ============================================================================

void main() {
  runApp(const PomodoroApp());
}

// ============================================================================
// MODELS
// ============================================================================

enum TaskPriority { low, medium, high }

class TodoItem {
  final String id;
  String text;
  bool isCompleted;
  TaskPriority priority;

  TodoItem({
    required this.id,
    required this.text,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isCompleted': isCompleted,
        'priority': priority.name,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as String,
        text: json['text'] as String,
        isCompleted: json['isCompleted'] as bool? ?? false,
        priority: TaskPriority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => TaskPriority.medium,
        ),
      );
}

// ============================================================================
// PROVIDERS - SERVICE CLASSES
// ============================================================================

enum TimerType { work, shortBreak, longBreak }

class TimerService extends ChangeNotifier {
  Timer? _timer;
  int _workMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  TimerType _currentType = TimerType.work;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  bool _isPaused = false;
  ConfettiController? _confettiController;
  int _completedPomodoros = 0;
  int _dailyGoal = 8;
  bool _soundEnabled = true;
  DateTime? _lastResetDate;

  static const String _workKey = 'work_minutes';
  static const String _shortBreakKey = 'short_break_minutes';
  static const String _longBreakKey = 'long_break_minutes';
  static const String _completedPomodorosKey = 'completed_pomodoros';
  static const String _dailyGoalKey = 'daily_goal';
  static const String _soundEnabledKey = 'sound_enabled';
  static const String _lastResetDateKey = 'last_reset_date';

  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  TimerType get currentType => _currentType;
  int get workMinutes => _workMinutes;
  int get shortBreakMinutes => _shortBreakMinutes;
  int get longBreakMinutes => _longBreakMinutes;
  int get completedPomodoros => _completedPomodoros;
  int get dailyGoal => _dailyGoal;
  bool get soundEnabled => _soundEnabled;
  
  int get todayPomodoros {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_lastResetDate == null || !_isSameDay(_lastResetDate!, today)) {
      return 0;
    }
    return _completedPomodoros;
  }
  
  double get dailyProgress {
    if (_dailyGoal == 0) return 0.0;
    return (todayPomodoros / _dailyGoal).clamp(0.0, 1.0);
  }
  
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  int get _currentDuration {
    switch (_currentType) {
      case TimerType.work:
        return _workMinutes * 60;
      case TimerType.shortBreak:
        return _shortBreakMinutes * 60;
      case TimerType.longBreak:
        return _longBreakMinutes * 60;
    }
  }

  double get progress {
    final duration = _currentDuration;
    if (duration == 0) return 0.0;
    return 1.0 - (_remainingSeconds / duration);
  }

  void setConfettiController(ConfettiController controller) {
    _confettiController = controller;
  }

  TimerService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _workMinutes = prefs.getInt(_workKey) ?? 25;
      _shortBreakMinutes = prefs.getInt(_shortBreakKey) ?? 5;
      _longBreakMinutes = prefs.getInt(_longBreakKey) ?? 15;
      _dailyGoal = prefs.getInt(_dailyGoalKey) ?? 8;
      _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
      
      final lastResetDateStr = prefs.getString(_lastResetDateKey);
      if (lastResetDateStr != null) {
        _lastResetDate = DateTime.parse(lastResetDateStr);
      }
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Reset daily count if it's a new day
      if (_lastResetDate == null || !_isSameDay(_lastResetDate!, today)) {
        _completedPomodoros = 0;
        _lastResetDate = today;
        await _savePomodoroCount();
      } else {
        _completedPomodoros = prefs.getInt(_completedPomodorosKey) ?? 0;
      }
      
      _remainingSeconds = _workMinutes * 60;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading timer settings: $e');
    }
  }

  Future<void> updateSettings({
    required int workMinutes,
    required int shortBreakMinutes,
    required int longBreakMinutes,
  }) async {
    _workMinutes = workMinutes;
    _shortBreakMinutes = shortBreakMinutes;
    _longBreakMinutes = longBreakMinutes;

    if (!_isRunning && !_isPaused) {
      _remainingSeconds = _currentDuration;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_workKey, _workMinutes);
      await prefs.setInt(_shortBreakKey, _shortBreakMinutes);
      await prefs.setInt(_longBreakKey, _longBreakMinutes);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving timer settings: $e');
    }
  }

  void setTimerType(TimerType type) {
    if (_isRunning || _isPaused) {
      reset();
    }
    _currentType = type;
    _remainingSeconds = _currentDuration;
    notifyListeners();
  }

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        _complete();
      }
    });
  }

  void pause() {
    _timer?.cancel();
    _isRunning = false;
    _isPaused = true;
    notifyListeners();
  }

  void resume() {
    if (!_isPaused) return;
    start();
  }

  void reset() {
    _timer?.cancel();
    _remainingSeconds = _currentDuration;
    _isRunning = false;
    _isPaused = false;
    notifyListeners();
  }

  void _complete() {
    _timer?.cancel();
    final completedType = _currentType;
    
    _isRunning = false;
    _isPaused = false;
    
    // Trigger confetti for work sessions and increment pomodoro count
    if (_currentType == TimerType.work) {
      _confettiController?.play();
      _completedPomodoros++;
      _savePomodoroCount();
      // Auto-switch to short break after work
      _currentType = TimerType.shortBreak;
      _remainingSeconds = _shortBreakMinutes * 60;
    } else if (_currentType == TimerType.shortBreak) {
      // Auto-switch back to work after short break
      _currentType = TimerType.work;
      _remainingSeconds = _workMinutes * 60;
    } else if (_currentType == TimerType.longBreak) {
      // Auto-switch back to work after long break
      _currentType = TimerType.work;
      _remainingSeconds = _workMinutes * 60;
    }
    
    notifyListeners();
    
    // Notify about completion
    _onSessionComplete?.call(completedType, _currentType);
  }

  Future<void> _savePomodoroCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_completedPomodorosKey, _completedPomodoros);
      if (_lastResetDate != null) {
        await prefs.setString(_lastResetDateKey, _lastResetDate!.toIso8601String());
      }
    } catch (e) {
      debugPrint('Error saving pomodoro count: $e');
    }
  }
  
  Future<void> setDailyGoal(int goal) async {
    if (goal < 1) return;
    _dailyGoal = goal;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_dailyGoalKey, _dailyGoal);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving daily goal: $e');
    }
  }
  
  Future<void> setSoundEnabled(bool enabled) async {
    _soundEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundEnabledKey, _soundEnabled);
      notifyListeners();
    } catch (e) {
      debugPrint('Error saving sound setting: $e');
    }
  }
  
  Future<void> resetDailyGoal() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _completedPomodoros = 0;
    _lastResetDate = today;
    await _savePomodoroCount();
    notifyListeners();
  }

  void Function(TimerType completed, TimerType next)? _onSessionComplete;
  void setOnSessionComplete(void Function(TimerType completed, TimerType next)? callback) {
    _onSessionComplete = callback;
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Note: ConfettiController is owned by the widget, not this service
    super.dispose();
  }
}

class TaskService extends ChangeNotifier {
  List<TodoItem> _tasks = [];
  static const String _storageKey = 'pomodoro_tasks';

  List<TodoItem> get tasks => List.unmodifiable(_tasks);
  List<TodoItem> get activeTasks =>
      _tasks.where((task) => !task.isCompleted).toList();
  List<TodoItem> get completedTasks =>
      _tasks.where((task) => task.isCompleted).toList();

  TaskService() {
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getStringList(_storageKey) ?? [];
      _tasks = tasksJson
          .map((json) => TodoItem.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      _tasks = [];
    }
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = _tasks
          .map((task) => jsonEncode(task.toJson()))
          .toList();
      await prefs.setStringList(_storageKey, tasksJson);
    } catch (e) {
      debugPrint('Error saving tasks: $e');
    }
  }

  Future<void> addTask(String text, {TaskPriority priority = TaskPriority.medium}) async {
    if (text.trim().isEmpty) return;

    final task = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      priority: priority,
    );
    _tasks.add(task);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> toggleTask(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index != -1) {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
      notifyListeners();
      await _saveTasks();
    }
  }

  Future<void> updateTask(String id, String newText, TaskPriority newPriority) async {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index != -1 && newText.trim().isNotEmpty) {
      _tasks[index].text = newText.trim();
      _tasks[index].priority = newPriority;
      notifyListeners();
      await _saveTasks();
    }
  }

  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> clearCompletedTasks() async {
    _tasks.removeWhere((task) => task.isCompleted);
    notifyListeners();
    await _saveTasks();
  }

  Future<void> clearAllTasks() async {
    _tasks.clear();
    notifyListeners();
    await _saveTasks();
  }
}

// ============================================================================
// MAIN APP WIDGET
// ============================================================================

class PomodoroApp extends StatelessWidget {
  const PomodoroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TimerService()),
        ChangeNotifierProvider(create: (_) => TaskService()),
      ],
      child: MaterialApp(
        title: 'Pomodoro Timer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1F1F1F),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD97757),
            surface: Color(0xFF2A2A2A),
            onSurface: Color(0xFFEAEAEA),
            onSurfaceVariant: Color(0xFFA0A0A0),
          ),
          useMaterial3: true,
        ),
        home: const PomodoroScreen(),
      ),
    );
  }
}

// ============================================================================
// MAIN SCREEN
// ============================================================================

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set confetti controller and completion callback after context is available
    final timerService = Provider.of<TimerService>(context, listen: false);
    timerService.setConfettiController(_confettiController);
    timerService.setOnSessionComplete((completed, next) {
      _showCompletionDialog(context, completed, next);
    });
  }

  void _showCompletionDialog(BuildContext context, TimerType completed, TimerType next) {
    final completedText = completed == TimerType.work
        ? 'Work Session Complete!'
        : completed == TimerType.shortBreak
            ? 'Short Break Complete!'
            : 'Long Break Complete!';
    
    final nextText = next == TimerType.work
        ? 'Ready for work?'
        : next == TimerType.shortBreak
            ? 'Time for a short break!'
            : 'Time for a long break!';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        title: Text(
          completedText,
          style: GoogleFonts.merriweather(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFEAEAEA),
          ),
        ),
        content: Text(
          nextText,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFFA0A0A0),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Continue',
              style: GoogleFonts.inter(
                color: const Color(0xFFD97757),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside text fields
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1F1F1F),
                const Color(0xFF1A1A1A),
              ],
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                child: isLandscape
                    ? _buildLandscapeLayout(context)
                    : _buildPortraitLayout(context),
              ),
              // Confetti overlay
              Align(
                alignment: Alignment.center,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: 3.14 / 2, // Upward
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  gravity: 0.1,
                  shouldLoop: false,
                  colors: const [
                    Color(0xFFD97757),
                    Color(0xFFEF5350),
                    Color(0xFF66BB6A),
                    Color(0xFF42A5F5),
                    Color(0xFFAB47BC),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        // Timer Section
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Pomodoro Timer',
                        style: GoogleFonts.merriweather(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFEAEAEA),
                        ),
                      ),
                    ),
                    Consumer<TimerService>(
                      builder: (context, timerService, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 16,
                                color: const Color(0xFFD97757),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${timerService.todayPomodoros}/${timerService.dailyGoal}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFEAEAEA),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showSettingsDialog(context),
                      icon: const Icon(Icons.settings),
                      color: const Color(0xFFA0A0A0),
                      tooltip: 'Settings',
                      iconSize: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const TimerTypeSelector(),
                const SizedBox(height: 12),
                const TimerWidget(),
                const SizedBox(height: 12),
                const TimerControls(),
                const SizedBox(height: 12),
                Consumer<TimerService>(
                  builder: (context, timerService, child) {
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daily Goal',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFFA0A0A0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${timerService.todayPomodoros}/${timerService.dailyGoal}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFFEAEAEA),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: timerService.dailyProgress,
                              minHeight: 5,
                              backgroundColor: const Color(0xFF1F1F1F),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                timerService.dailyProgress >= 1.0
                                    ? const Color(0xFF66BB6A)
                                    : const Color(0xFFD97757),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Consumer<TaskService>(
                  builder: (context, taskService, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2A2A2A),
                            const Color(0xFF252525),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD97757).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TasksPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.task_alt, size: 20),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Tasks',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (taskService.activeTasks.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97757),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${taskService.activeTasks.length}',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFEAEAEA),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: const Color(0xFFEAEAEA),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Pomodoro Timer',
                  style: GoogleFonts.merriweather(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEAEAEA),
                  ),
                ),
              ),
              Consumer<TimerService>(
                builder: (context, timerService, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: const Color(0xFFD97757),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${timerService.todayPomodoros}/${timerService.dailyGoal}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFEAEAEA),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showSettingsDialog(context),
                icon: const Icon(Icons.settings),
                color: const Color(0xFFA0A0A0),
                tooltip: 'Settings',
                iconSize: 22,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    const TimerTypeSelector(),
                    const SizedBox(height: 16),
                    const TimerWidget(),
                    const SizedBox(height: 16),
                    const TimerControls(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Consumer<TimerService>(
                      builder: (context, timerService, child) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Daily Goal',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFFA0A0A0),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${timerService.todayPomodoros}/${timerService.dailyGoal}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: const Color(0xFFEAEAEA),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: timerService.dailyProgress,
                                  minHeight: 6,
                                  backgroundColor: const Color(0xFF1F1F1F),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    timerService.dailyProgress >= 1.0
                                        ? const Color(0xFF66BB6A)
                                        : const Color(0xFFD97757),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Consumer<TaskService>(
                      builder: (context, taskService, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2A2A2A),
                                const Color(0xFF252525),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TasksPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.task_alt, size: 20),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tasks',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (taskService.activeTasks.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97757),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${taskService.activeTasks.length}',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFEAEAEA),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: const Color(0xFFEAEAEA),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _SettingsDialog(dialogContext: dialogContext),
    );
  }
}

// ============================================================================
// TIMER TYPE SELECTOR
// ============================================================================

class TimerTypeSelector extends StatelessWidget {
  const TimerTypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerService>(
      builder: (context, timerService, child) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTypeButton(
                context: context,
                label: 'Work',
                type: TimerType.work,
                timerService: timerService,
                icon: Icons.work_outline,
              ),
              const SizedBox(width: 4),
              _buildTypeButton(
                context: context,
                label: 'Short',
                type: TimerType.shortBreak,
                timerService: timerService,
                icon: Icons.coffee_outlined,
              ),
              const SizedBox(width: 4),
              _buildTypeButton(
                context: context,
                label: 'Long',
                type: TimerType.longBreak,
                timerService: timerService,
                icon: Icons.hotel_outlined,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeButton({
    required BuildContext context,
    required String label,
    required TimerType type,
    required TimerService timerService,
    required IconData icon,
  }) {
    final isSelected = timerService.currentType == type;
    final isRunning = timerService.isRunning || timerService.isPaused;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isRunning ? null : () => timerService.setTimerType(type),
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD97757)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8.0),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD97757).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? const Color(0xFFEAEAEA)
                      : const Color(0xFFA0A0A0),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? const Color(0xFFEAEAEA)
                        : const Color(0xFFA0A0A0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TIMER WIDGET
// ============================================================================

class TimerWidget extends StatelessWidget {
  const TimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerService>(
      builder: (context, timerService, child) {
        final isBreak = timerService.currentType != TimerType.work;
        final progressColor = isBreak
            ? const Color(0xFF66BB6A)
            : const Color(0xFFD97757);
        
        String statusText;
        if (timerService.isRunning) {
          statusText = isBreak ? 'Break Time' : 'Focus Time';
        } else if (timerService.isPaused) {
          statusText = 'Paused';
        } else {
          statusText = isBreak ? 'Break Ready' : 'Ready';
        }

        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: progressColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircularPercentIndicator(
            radius: 110.0,
            lineWidth: 10.0,
            percent: timerService.progress.clamp(0.0, 1.0),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timerService.formattedTime,
                  style: GoogleFonts.inter(
                    fontSize: 40,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFEAEAEA),
                    letterSpacing: 2,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  statusText,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFA0A0A0),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            progressColor: progressColor,
            backgroundColor: const Color(0xFF2A2A2A),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animateFromLastPercent: true,
          ),
        );
      },
    );
  }
}

// ============================================================================
// TIMER CONTROLS
// ============================================================================

class TimerControls extends StatelessWidget {
  const TimerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TimerService>(
      builder: (context, timerService, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!timerService.isRunning && !timerService.isPaused)
              _buildButton(
                context: context,
                icon: Icons.play_arrow,
                label: 'Start',
                onPressed: () => timerService.start(),
                isPrimary: true,
              )
            else if (timerService.isRunning)
              _buildButton(
                context: context,
                icon: Icons.pause,
                label: 'Pause',
                onPressed: () => timerService.pause(),
                isPrimary: true,
              )
            else
              _buildButton(
                context: context,
                icon: Icons.play_arrow,
                label: 'Resume',
                onPressed: () => timerService.resume(),
                isPrimary: true,
              ),
            const SizedBox(width: 16),
            _buildButton(
              context: context,
              icon: Icons.refresh,
              label: 'Reset',
              onPressed: () => timerService.reset(),
              isPrimary: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? const Color(0xFFD97757)
            : const Color(0xFF2A2A2A),
        foregroundColor: const Color(0xFFEAEAEA),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        elevation: isPrimary ? 4 : 2,
        shadowColor: isPrimary
            ? const Color(0xFFD97757).withOpacity(0.4)
            : Colors.black.withOpacity(0.2),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ============================================================================
// TASKS PAGE
// ============================================================================

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1F1F1F),
              const Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F).withOpacity(0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: const Color(0xFFEAEAEA),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Tasks',
                      style: GoogleFonts.merriweather(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFEAEAEA),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(child: TaskListWidget()),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TASK LIST WIDGET
// ============================================================================

class TaskListWidget extends StatefulWidget {
  const TaskListWidget({super.key});

  @override
  State<TaskListWidget> createState() => _TaskListWidgetState();
}

class _TaskListWidgetState extends State<TaskListWidget> {
  bool _showCompleted = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Consumer<TaskService>(
                builder: (context, taskService, child) {
                  final completedCount = taskService.completedTasks.length;
                  final activeCount = taskService.activeTasks.length;
                  if (completedCount > 0 || activeCount > 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$activeCount / ${taskService.tasks.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFFA0A0A0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<TaskService>(
                    builder: (context, taskService, child) {
                      if (taskService.completedTasks.isNotEmpty) {
                        return PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xFFA0A0A0),
                            size: 22,
                          ),
                          color: const Color(0xFF2A2A2A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    _showCompleted ? Icons.visibility_off : Icons.visibility,
                                    size: 18,
                                    color: const Color(0xFFEAEAEA),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    _showCompleted ? 'Hide completed' : 'Show completed',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFFEAEAEA),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'clear_completed',
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.delete_sweep,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Clear completed',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (taskService.tasks.isNotEmpty)
                              PopupMenuItem(
                                value: 'clear_all',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Clear all tasks',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          onSelected: (value) {
                            if (value == 'toggle') {
                              setState(() {
                                _showCompleted = !_showCompleted;
                              });
                            } else if (value == 'clear_completed') {
                              _showClearCompletedDialog(context);
                            } else if (value == 'clear_all') {
                              _showClearAllDialog(context);
                            }
                          },
                        );
                      }
                      return IconButton(
                        onPressed: () {
                          setState(() {
                            _showCompleted = !_showCompleted;
                          });
                        },
                        icon: Icon(
                          _showCompleted ? Icons.visibility_off : Icons.visibility,
                        ),
                        color: const Color(0xFFA0A0A0),
                        iconSize: 22,
                        tooltip: _showCompleted ? 'Hide completed' : 'Show completed',
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () => _showAddTaskDialog(context),
                    icon: const Icon(Icons.add_circle_outline),
                    color: const Color(0xFFD97757),
                    iconSize: 28,
                  ),
                ],
              ),
            ],
          ),
        ),
        Consumer<TaskService>(
          builder: (context, taskService, child) {
            if (taskService.tasks.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: GoogleFonts.inter(
                  color: const Color(0xFFEAEAEA),
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFFA0A0A0),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFFA0A0A0),
                    size: 18,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            color: Color(0xFFA0A0A0),
                            size: 18,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF1F1F1F),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Color(0xFFD97757), width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
              ),
            );
          },
        ),
        Expanded(
          child: Consumer<TaskService>(
            builder: (context, taskService, child) {
              var tasksToShow = (_showCompleted
                  ? taskService.tasks
                  : taskService.activeTasks).toList();

              // Filter by search query
              if (_searchQuery.isNotEmpty) {
                tasksToShow = tasksToShow
                    .where((task) => task.text
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                    .toList();
              }

              // Sort by priority first (high > medium > low)
              tasksToShow.sort((a, b) {
                final priorityOrder = {
                  TaskPriority.high: 3,
                  TaskPriority.medium: 2,
                  TaskPriority.low: 1,
                };
                final priorityDiff = priorityOrder[b.priority]! - priorityOrder[a.priority]!;
                if (priorityDiff != 0) return priorityDiff;
                // Then by completion status (incomplete first)
                if (a.isCompleted != b.isCompleted) {
                  return a.isCompleted ? 1 : -1;
                }
                return 0;
              });

              if (tasksToShow.isEmpty) {
                return Center(
                  child: Text(
                    taskService.tasks.isEmpty
                        ? 'No tasks yet.\nAdd one to get started!'
                        : 'All tasks completed!\nGreat job! 🎉',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFFA0A0A0),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: tasksToShow.length,
                itemBuilder: (context, index) {
                  final task = tasksToShow[index];
                  return TaskItemWidget(task: task);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => _AddTaskDialog(dialogContext: dialogContext),
    );
  }

  void _showClearCompletedDialog(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        title: Text(
          'Clear Completed Tasks?',
          style: GoogleFonts.merriweather(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFEAEAEA),
          ),
        ),
        content: Text(
          'This will permanently delete all completed tasks.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFFA0A0A0),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xFFA0A0A0),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              taskService.clearCompletedTasks();
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Completed tasks cleared!',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAEAEA),
                    ),
                  ),
                  backgroundColor: const Color(0xFF2A2A2A),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Clear',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        title: Text(
          'Clear All Tasks?',
          style: GoogleFonts.merriweather(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFEAEAEA),
          ),
        ),
        content: Text(
          'This will permanently delete all tasks. This action cannot be undone.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFFA0A0A0),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(0xFFA0A0A0),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              taskService.clearAllTasks();
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'All tasks cleared!',
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEAEAEA),
                    ),
                  ),
                  backgroundColor: const Color(0xFF2A2A2A),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Clear All',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADD TASK DIALOG
// ============================================================================

class _AddTaskDialog extends StatefulWidget {
  final BuildContext dialogContext;

  const _AddTaskDialog({required this.dialogContext});

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  TaskPriority _selectedPriority = TaskPriority.medium;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(widget.dialogContext, listen: false);

    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      title: Text(
        'New Task',
        style: GoogleFonts.merriweather(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFEAEAEA),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            autofocus: true,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAEAEA),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Enter task...',
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFFA0A0A0),
              ),
              filled: true,
              fillColor: const Color(0xFF1F1F1F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFFD97757), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                taskService.addTask(value, priority: _selectedPriority);
                Navigator.pop(widget.dialogContext);
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Priority',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFFA0A0A0),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPriorityButton('Low', TaskPriority.low, Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPriorityButton('Medium', TaskPriority.medium, Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPriorityButton('High', TaskPriority.high, Colors.red),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(widget.dialogContext),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: const Color(0xFFA0A0A0),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            if (_textController.text.trim().isNotEmpty) {
              taskService.addTask(_textController.text, priority: _selectedPriority);
              Navigator.pop(widget.dialogContext);
            }
          },
          child: Text(
            'Add',
            style: GoogleFonts.inter(
              color: const Color(0xFFD97757),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityButton(String label, TaskPriority priority, Color color) {
    final isSelected = _selectedPriority == priority;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPriority = priority;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF2A2A2A),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isSelected ? color : const Color(0xFFA0A0A0),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// EDIT TASK DIALOG
// ============================================================================

class _EditTaskDialog extends StatefulWidget {
  final BuildContext dialogContext;
  final TodoItem task;

  const _EditTaskDialog({
    required this.dialogContext,
    required this.task,
  });

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  late TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  late TaskPriority _selectedPriority;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.task.text);
    _selectedPriority = widget.task.priority;
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(widget.dialogContext, listen: false);

    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      title: Text(
        'Edit Task',
        style: GoogleFonts.merriweather(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFEAEAEA),
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _textController,
            focusNode: _focusNode,
            autofocus: true,
            style: GoogleFonts.inter(
              color: const Color(0xFFEAEAEA),
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Enter task...',
              hintStyle: GoogleFonts.inter(
                color: const Color(0xFFA0A0A0),
              ),
              filled: true,
              fillColor: const Color(0xFF1F1F1F),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFFD97757), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                taskService.updateTask(widget.task.id, value, _selectedPriority);
                Navigator.pop(widget.dialogContext);
              }
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Priority',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFFA0A0A0),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildPriorityButton('Low', TaskPriority.low, Colors.grey),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPriorityButton('Medium', TaskPriority.medium, Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPriorityButton('High', TaskPriority.high, Colors.red),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(widget.dialogContext),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: const Color(0xFFA0A0A0),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            if (_textController.text.trim().isNotEmpty) {
              taskService.updateTask(widget.task.id, _textController.text, _selectedPriority);
              Navigator.pop(widget.dialogContext);
            }
          },
          child: Text(
            'Save',
            style: GoogleFonts.inter(
              color: const Color(0xFFD97757),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityButton(String label, TaskPriority priority, Color color) {
    final isSelected = _selectedPriority == priority;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPriority = priority;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF2A2A2A),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: isSelected ? color : const Color(0xFFA0A0A0),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SETTINGS DIALOG
// ============================================================================

class _SettingsDialog extends StatefulWidget {
  final BuildContext dialogContext;

  const _SettingsDialog({required this.dialogContext});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late TextEditingController _workController;
  late TextEditingController _shortBreakController;
  late TextEditingController _longBreakController;
  late TextEditingController _dailyGoalController;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    final timerService = Provider.of<TimerService>(widget.dialogContext, listen: false);
    _workController = TextEditingController(text: timerService.workMinutes.toString());
    _shortBreakController = TextEditingController(text: timerService.shortBreakMinutes.toString());
    _longBreakController = TextEditingController(text: timerService.longBreakMinutes.toString());
    _dailyGoalController = TextEditingController(text: timerService.dailyGoal.toString());
    _soundEnabled = timerService.soundEnabled;
  }

  @override
  void dispose() {
    _workController.dispose();
    _shortBreakController.dispose();
    _longBreakController.dispose();
    _dailyGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerService = Provider.of<TimerService>(widget.dialogContext, listen: false);

    return AlertDialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      title: Text(
        'Settings',
        style: GoogleFonts.merriweather(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFEAEAEA),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Work Duration (minutes)',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA0A0A0),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _workController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAEAEA),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFD97757), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Short Break (minutes)',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA0A0A0),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _shortBreakController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAEAEA),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFD97757), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Long Break (minutes)',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA0A0A0),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _longBreakController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAEAEA),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFD97757), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Daily Goal (pomodoros)',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: const Color(0xFFA0A0A0),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dailyGoalController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.inter(
                color: const Color(0xFFEAEAEA),
                fontSize: 16,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  borderSide: const BorderSide(color: Color(0xFFD97757), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sound Effects',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFA0A0A0),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() {
                      _soundEnabled = value;
                    });
                  },
                  activeColor: const Color(0xFFD97757),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Divider(
              color: const Color(0xFF2A2A2A),
              thickness: 1,
            ),
            const SizedBox(height: 16),
            Consumer<TimerService>(
              builder: (context, timerService, child) {
                if (timerService.todayPomodoros > 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Progress',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFFA0A0A0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today: ${timerService.todayPomodoros} pomodoros',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFFEAEAEA),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              showDialog(
                                context: widget.dialogContext,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF2A2A2A),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  title: Text(
                                    'Reset Daily Goal?',
                                    style: GoogleFonts.merriweather(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFEAEAEA),
                                    ),
                                  ),
                                  content: Text(
                                    'This will reset today\'s pomodoro count to 0.',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: const Color(0xFFA0A0A0),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Cancel',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFA0A0A0),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        timerService.resetDailyGoal();
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(widget.dialogContext).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Daily goal reset!',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFEAEAEA),
                                              ),
                                            ),
                                            backgroundColor: const Color(0xFF2A2A2A),
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Reset',
                                        style: GoogleFonts.inter(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.refresh,
                              size: 16,
                              color: Colors.red,
                            ),
                            label: Text(
                              'Reset',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(widget.dialogContext),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(
              color: const Color(0xFFA0A0A0),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            final workMinutes = int.tryParse(_workController.text) ?? 25;
            final shortBreakMinutes = int.tryParse(_shortBreakController.text) ?? 5;
            final longBreakMinutes = int.tryParse(_longBreakController.text) ?? 15;
            final dailyGoal = int.tryParse(_dailyGoalController.text) ?? 8;

            if (workMinutes > 0 && shortBreakMinutes > 0 && longBreakMinutes > 0 && dailyGoal > 0) {
              timerService.updateSettings(
                workMinutes: workMinutes,
                shortBreakMinutes: shortBreakMinutes,
                longBreakMinutes: longBreakMinutes,
              );
              timerService.setDailyGoal(dailyGoal);
              timerService.setSoundEnabled(_soundEnabled);
              Navigator.pop(widget.dialogContext);
            }
          },
          child: Text(
            'Save',
            style: GoogleFonts.inter(
              color: const Color(0xFFD97757),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// TASK ITEM WIDGET
// ============================================================================

class TaskItemWidget extends StatelessWidget {
  final TodoItem task;

  const TaskItemWidget({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context) {
    final taskService = Provider.of<TaskService>(context, listen: false);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12.0),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: 28,
        ),
      ),
      onDismissed: (direction) {
        taskService.deleteTask(task.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Checkbox(
            value: task.isCompleted,
            onChanged: (value) => taskService.toggleTask(task.id),
            activeColor: const Color(0xFFD97757),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  task.text,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: task.isCompleted
                        ? const Color(0xFFA0A0A0)
                        : const Color(0xFFEAEAEA),
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: task.priority == TaskPriority.high
                      ? Colors.red
                      : task.priority == TaskPriority.medium
                          ? Colors.orange
                          : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                color: const Color(0xFFA0A0A0),
                onPressed: () => _showEditTaskDialog(context, task),
                iconSize: 20,
                tooltip: 'Edit task',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red.withOpacity(0.7),
                onPressed: () => taskService.deleteTask(task.id),
                iconSize: 22,
                tooltip: 'Delete task',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, TodoItem task) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditTaskDialog(
        dialogContext: dialogContext,
        task: task,
      ),
    );
  }
}
