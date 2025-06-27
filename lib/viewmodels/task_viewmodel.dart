import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:todo_app/services/firebase';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';

class TaskViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final Uuid _uuid = const Uuid();

  // State variables
  List<TaskModel> _tasks = [];
  List<TaskModel> _sharedTasks = [];
  List<TaskModel> _filteredTasks = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  String _searchQuery = '';
  String _selectedFilter = 'all'; // all, completed, pending, overdue
  String _selectedSort = 'createdAt'; // createdAt, title, priority, dueDate
  bool _sortAscending = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreTasks = true;
  Map<String, dynamic> _analytics = {};

  // Getters
  List<TaskModel> get tasks => _tasks;
  List<TaskModel> get sharedTasks => _sharedTasks;
  List<TaskModel> get filteredTasks => _filteredTasks;
  List<TaskModel> get allTasks => [..._tasks, ..._sharedTasks];
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String get selectedFilter => _selectedFilter;
  String get selectedSort => _selectedSort;
  bool get sortAscending => _sortAscending;
  bool get hasMoreTasks => _hasMoreTasks;
  Map<String, dynamic> get analytics => _analytics;

  // Initialize
  Future<void> initialize() async {
    if (_firebaseService.currentUserId == null) return;
    
    _setLoading(true);
    try {
      await loadTasks();
      await loadAnalytics();
      _setupRealTimeListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Load tasks
  Future<void> loadTasks() async {
    if (_firebaseService.currentUserId == null) return;

    try {
      final tasks = await _firebaseService.getPaginatedTasks(
        _firebaseService.currentUserId!,
        limit: 20,
      );
      _tasks = tasks;
      _lastDocument = tasks.isNotEmpty ? null : null; // Will be set by Firestore
      _applyFiltersAndSort();
    } catch (e) {
      _setError('Failed to load tasks: $e');
    }
  }

  // Load more tasks for infinite scroll
  Future<void> loadMoreTasks() async {
    if (_isLoadingMore || !_hasMoreTasks || _firebaseService.currentUserId == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final moreTasks = await _firebaseService.getPaginatedTasks(
        _firebaseService.currentUserId!,
        lastDocument: _lastDocument,
        limit: 20,
      );

      if (moreTasks.isEmpty) {
        _hasMoreTasks = false;
      } else {
        _tasks.addAll(moreTasks);
        _applyFiltersAndSort();
      }
    } catch (e) {
      _setError('Failed to load more tasks: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Setup real-time listeners
  void _setupRealTimeListeners() {
    if (_firebaseService.currentUserId == null) return;

    // Listen to owned tasks
    _firebaseService.getTasksStream(_firebaseService.currentUserId!).listen(
      (tasks) {
        _tasks = tasks;
        _applyFiltersAndSort();
      },
      onError: (e) => _setError('Real-time sync error: $e'),
    );

    // Listen to shared tasks
    _firebaseService.getSharedTasksStream(_firebaseService.currentUserId!).listen(
      (sharedTasks) {
        _sharedTasks = sharedTasks;
        _applyFiltersAndSort();
      },
      onError: (e) => _setError('Shared tasks sync error: $e'),
    );
  }

  // Create task
  Future<bool> createTask({
    required String title,
    required String description,
    String priority = 'medium',
    DateTime? dueDate,
    List<String> tags = const [],
  }) async {
    if (_firebaseService.currentUserId == null || _firebaseService.currentUser == null) {
      _setError('User not authenticated');
      return false;
    }

    _setLoading(true);
    try {
      final task = TaskModel(
        id: _uuid.v4(),
        title: title.trim(),
        description: description.trim(),
        isCompleted: false,
        ownerId: _firebaseService.currentUserId!,
        ownerEmail: _firebaseService.currentUser!.email!,
        sharedWith: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        lastModifiedBy: _firebaseService.currentUserId!,
        priority: priority,
        dueDate: dueDate,
        tags: tags,
      );

      await _firebaseService.createTask(task);
      await loadAnalytics();
      return true;
    } catch (e) {
      _setError('Failed to create task: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Update task
  Future<bool> updateTask(TaskModel task) async {
    if (_firebaseService.currentUserId == null) {
      _setError('User not authenticated');
      return false;
    }

    try {
      final updatedTask = task.copyWith(
        updatedAt: DateTime.now(),
        lastModifiedBy: _firebaseService.currentUserId!,
      );

      await _firebaseService.updateTask(updatedTask);
      await loadAnalytics();
      return true;
    } catch (e) {
      _setError('Failed to update task: $e');
      return false;
    }
  }

  // Toggle task completion
  Future<bool> toggleTaskCompletion(TaskModel task) async {
    return await updateTask(task.copyWith(isCompleted: !task.isCompleted));
  }

  // Delete task
  Future<bool> deleteTask(String taskId) async {
    _setLoading(true);
    try {
      await _firebaseService.deleteTask(taskId);
      await loadAnalytics();
      return true;
    } catch (e) {
      _setError('Failed to delete task: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Search tasks
  Future<void> searchTasks(String query) async {
    _searchQuery = query.trim();
    
    if (_searchQuery.isEmpty) {
      _applyFiltersAndSort();
      return;
    }

    if (_firebaseService.currentUserId == null) return;

    try {
      final searchResults = await _firebaseService.searchTasks(
        _firebaseService.currentUserId!,
        _searchQuery,
      );
      _filteredTasks = searchResults;
      _applySortToFiltered();
    } catch (e) {
      _setError('Search failed: $e');
    }
  }

  // Apply filters and sorting
  void _applyFiltersAndSort() {
    List<TaskModel> combinedTasks = [..._tasks, ..._sharedTasks];

    // Apply filters
    switch (_selectedFilter) {
      case 'completed':
        combinedTasks = combinedTasks.where((task) => task.isCompleted).toList();
        break;
      case 'pending':
        combinedTasks = combinedTasks.where((task) => !task.isCompleted).toList();
        break;
      case 'overdue':
        combinedTasks = combinedTasks.where((task) => task.isOverdue).toList();
        break;
      case 'high_priority':
        combinedTasks = combinedTasks.where((task) => task.priority == 'high').toList();
        break;
      default: // 'all'
        break;
    }

    _filteredTasks = combinedTasks;
    _applySortToFiltered();
  }

  // Apply sorting to filtered tasks
  void _applySortToFiltered() {
    _filteredTasks.sort((a, b) {
      int comparison = 0;
      
      switch (_selectedSort) {
        case 'title':
          comparison = a.title.compareTo(b.title);
          break;
        case 'priority':
          const priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
          final aPriority = priorityOrder[a.priority] ?? 0;
          final bPriority = priorityOrder[b.priority] ?? 0;
          comparison = bPriority.compareTo(aPriority); // High priority first
          break;
        case 'dueDate':
          if (a.dueDate == null && b.dueDate == null) comparison = 0;
          else if (a.dueDate == null) comparison = 1;
          else if (b.dueDate == null) comparison = -1;
          else comparison = a.dueDate!.compareTo(b.dueDate!);
          break;
        case 'updatedAt':
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
        default: // 'createdAt'
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    notifyListeners();
  }

  // Set filter
  void setFilter(String filter) {
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      _applyFiltersAndSort();
    }
  }

  // Set sort
  void setSort(String sort, {bool? ascending}) {
    bool shouldUpdate = false;
    
    if (_selectedSort != sort) {
      _selectedSort = sort;
      shouldUpdate = true;
    }
    
    if (ascending != null && _sortAscending != ascending) {
      _sortAscending = ascending;
      shouldUpdate = true;
    }
    
    if (shouldUpdate) {
      _applySortToFiltered();
    }
  }

  // Clear search
  void clearSearch() {
    _searchQuery = '';
    _applyFiltersAndSort();
  }

  // Load analytics
  Future<void> loadAnalytics() async {
    if (_firebaseService.currentUserId == null) return;

    try {
      _analytics = await _firebaseService.getTaskAnalytics(_firebaseService.currentUserId!);
      notifyListeners();
    } catch (e) {
      // Analytics failure shouldn't break the app
      debugPrint('Failed to load analytics: $e');
    }
  }

  // Get task by ID
  TaskModel? getTaskById(String taskId) {
    try {
      return allTasks.firstWhere((task) => task.id == taskId);
    } catch (e) {
      return null;
    }
  }

  // Check if user can edit task
  bool canEditTask(TaskModel task) {
    if (_firebaseService.currentUserId == null) return false;
    return task.canEdit(_firebaseService.currentUserId!);
  }

  // Get tasks by tag
  List<TaskModel> getTasksByTag(String tag) {
    return allTasks.where((task) => task.tags.contains(tag)).toList();
  }

  // Get all unique tags
  List<String> getAllTags() {
    final tags = <String>{};
    for (final task in allTasks) {
      tags.addAll(task.tags);
    }
    return tags.toList()..sort();
  }

  // Refresh tasks
  Future<void> refresh() async {
    _setError(null);
    await initialize();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Dispose
  @override
  void dispose() {
    // Clean up any subscriptions if needed
    super.dispose();
  }
}