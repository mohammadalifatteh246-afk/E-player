import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Classification of dropped items.
enum DroppedItemType {
  videoAudio,
  subtitle,
  folder,
  unsupported,
}

/// A single dropped file or directory item.
class DroppedItem {
  final String path;
  final String name;
  final String extension;
  final DroppedItemType type;

  const DroppedItem({
    required this.path,
    required this.name,
    required this.extension,
    required this.type,
  });

  static const Set<String> _mediaExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'webm', 'wmv', 'ts', 'm4v', '3gp',
    'mpg', 'mpeg', 'm2ts', 'vob', 'divx', 'rmvb', 'asf',
    'mp3', 'm4a', 'flac', 'wav', 'aac', 'ogg', 'wma', 'opus', 'alac', 'aiff',
  };

  static const Set<String> _subtitleExtensions = {
    'srt', 'vtt', 'ass', 'ssa', 'sub', 'smi', 'txt',
  };

  factory DroppedItem.fromPath(String filePath) {
    final fileName = p.basename(filePath);
    final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();

    // Check directory
    if (FileSystemEntity.isDirectorySync(filePath)) {
      return DroppedItem(
        path: filePath,
        name: fileName,
        extension: '',
        type: DroppedItemType.folder,
      );
    }

    if (_subtitleExtensions.contains(ext)) {
      return DroppedItem(
        path: filePath,
        name: fileName,
        extension: ext,
        type: DroppedItemType.subtitle,
      );
    }

    if (_mediaExtensions.contains(ext)) {
      return DroppedItem(
        path: filePath,
        name: fileName,
        extension: ext,
        type: DroppedItemType.videoAudio,
      );
    }

    return DroppedItem(
      path: filePath,
      name: fileName,
      extension: ext,
      type: DroppedItemType.unsupported,
    );
  }

  @override
  String toString() => 'DroppedItem($name, type: $type)';
}

/// Event emitted when files are dragged and dropped onto the application window.
class DroppedMediaEvent {
  final List<DroppedItem> items;
  final DateTime timestamp;

  DroppedMediaEvent({
    required this.items,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  DroppedItem? get primaryItem => items.isNotEmpty ? items.first : null;

  bool get hasVideoAudio =>
      items.any((item) => item.type == DroppedItemType.videoAudio);

  bool get hasSubtitle =>
      items.any((item) => item.type == DroppedItemType.subtitle);

  List<DroppedItem> get videoAudioItems =>
      items.where((item) => item.type == DroppedItemType.videoAudio).toList();

  List<DroppedItem> get subtitleItems =>
      items.where((item) => item.type == DroppedItemType.subtitle).toList();

  @override
  String toString() =>
      'DroppedMediaEvent(items: ${items.length}, videoAudio: ${videoAudioItems.length}, sub: ${subtitleItems.length})';
}

// Win32 FFI Typedefs
typedef _NativeWndProc = ffi.IntPtr Function(
    ffi.IntPtr hwnd, ffi.Uint32 uMsg, ffi.IntPtr wParam, ffi.IntPtr lParam);

/// Service providing VLC-grade Desktop Drag-and-Drop Ingestion via pure Dart FFI.
///
/// Features:
/// 1. Dragging video/audio files immediately initiates playback.
/// 2. Dragging subtitle files (.srt, .vtt, .ass) onto the video surface dynamically
///    attaches the subtitle track to the active playing stream without interrupting playback.
/// 3. Fully cross-platform architecture with native Win32 `WM_DROPFILES` integration on Windows
///    and simulation support for automated testing and other platforms.
class DesktopDragDropService {
  static DesktopDragDropService? _instance;
  static DesktopDragDropService get instance =>
      _instance ??= DesktopDragDropService();

  @visibleForTesting
  static void setMockInstance(DesktopDragDropService mock) {
    _instance = mock;
  }

  final StreamController<DroppedMediaEvent> _dropStreamController =
      StreamController<DroppedMediaEvent>.broadcast();

  Stream<DroppedMediaEvent> get stream => _dropStreamController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  int _hwnd = 0;
  int _oldWndProc = 0;
  ffi.NativeCallable<_NativeWndProc>? _nativeCallable;

  // DLL references
  ffi.DynamicLibrary? _user32;
  ffi.DynamicLibrary? _shell32;

  /// Initializes the Drag-and-Drop hooks on Desktop Windows.
  void initialize({int? customHwnd, bool isTest = false}) {
    if (_isInitialized) return;
    _isInitialized = true;

    if (isTest || kIsWeb || !Platform.isWindows) {
      debugPrint('[DesktopDragDrop] Initialized in test or non-Windows mode.');
      return;
    }

    try {
      _user32 = ffi.DynamicLibrary.open('user32.dll');
      _shell32 = ffi.DynamicLibrary.open('shell32.dll');

      _hwnd = customHwnd ?? _findFlutterHwnd();
      if (_hwnd == 0) {
        debugPrint(
            '[DesktopDragDrop] Flutter window HWND not found; awaiting window active.');
        return;
      }

      _enableDragDrop(_hwnd);
      debugPrint('[DesktopDragDrop] Native Win32 WM_DROPFILES hooked on HWND: $_hwnd');
    } catch (e, stack) {
      debugPrint('[DesktopDragDrop] Failed to initialize native Win32 FFI: $e\n$stack');
    }
  }

  int _findFlutterHwnd() {
    if (_user32 == null) return 0;

    // 1. Try GetActiveWindow
    try {
      final getActive = _user32!.lookupFunction<ffi.IntPtr Function(), int Function()>(
          'GetActiveWindow');
      final hwnd = getActive();
      if (hwnd != 0) return hwnd;
    } catch (_) {}

    // 2. Try GetForegroundWindow
    try {
      final getForeground =
          _user32!.lookupFunction<ffi.IntPtr Function(), int Function()>(
              'GetForegroundWindow');
      final hwnd = getForeground();
      if (hwnd != 0) return hwnd;
    } catch (_) {}

    // 3. Try FindWindowW with class FLUTTER_RUNNER_WIN32_WINDOW
    try {
      final findWindow = _user32!.lookupFunction<
          ffi.IntPtr Function(ffi.Pointer<Utf16>, ffi.Pointer<Utf16>),
          int Function(ffi.Pointer<Utf16>, ffi.Pointer<Utf16>)>('FindWindowW');
      final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
      final hwnd = findWindow(className, ffi.nullptr);
      calloc.free(className);
      if (hwnd != 0) return hwnd;
    } catch (_) {}

    return 0;
  }

  void _enableDragDrop(int hwnd) {
    if (_shell32 == null || _user32 == null) return;

    // Enable drag acceptance
    final dragAcceptFiles = _shell32!.lookupFunction<
        ffi.Void Function(ffi.IntPtr, ffi.Int32),
        void Function(int, int)>('DragAcceptFiles');
    dragAcceptFiles(hwnd, 1);

    // Create native callback for WndProc
    _nativeCallable = ffi.NativeCallable<_NativeWndProc>.isolateLocal(
      _wndProc,
      exceptionalReturn: 0,
    );

    // Subclass WndProc (GWLP_WNDPROC = -4)
    _oldWndProc = _setWindowLongPtr(hwnd, -4, _nativeCallable!.nativeFunction.address);
  }

  int _setWindowLongPtr(int hwnd, int nIndex, int newLong) {
    if (_user32 == null) return 0;
    try {
      final func = _user32!.lookupFunction<
          ffi.IntPtr Function(ffi.IntPtr, ffi.Int32, ffi.IntPtr),
          int Function(int, int, int)>('SetWindowLongPtrW');
      return func(hwnd, nIndex, newLong);
    } catch (_) {
      final func = _user32!.lookupFunction<
          ffi.Int32 Function(ffi.IntPtr, ffi.Int32, ffi.Int32),
          int Function(int, int, int)>('SetWindowLongW');
      return func(hwnd, nIndex, newLong);
    }
  }

  int _wndProc(int hwnd, int uMsg, int wParam, int lParam) {
    const int wmDropFiles = 0x0233;

    if (uMsg == wmDropFiles) {
      _handleWmDropFiles(wParam);
      return 0; // Handled message
    }

    if (_oldWndProc != 0 && _user32 != null) {
      try {
        final callWindowProc = _user32!.lookupFunction<
            ffi.IntPtr Function(
                ffi.IntPtr, ffi.IntPtr, ffi.Uint32, ffi.IntPtr, ffi.IntPtr),
            int Function(int, int, int, int, int)>('CallWindowProcW');
        return callWindowProc(_oldWndProc, hwnd, uMsg, wParam, lParam);
      } catch (_) {}
    }

    return 0;
  }

  void _handleWmDropFiles(int hDrop) {
    if (_shell32 == null) return;

    try {
      final dragQueryFile = _shell32!.lookupFunction<
          ffi.Uint32 Function(
              ffi.IntPtr, ffi.Uint32, ffi.Pointer<ffi.Void>, ffi.Uint32),
          int Function(int, int, ffi.Pointer<ffi.Void>, int)>('DragQueryFileW');
      final dragFinish = _shell32!.lookupFunction<
          ffi.Void Function(ffi.IntPtr), void Function(int)>('DragFinish');

      final fileCount = dragQueryFile(hDrop, 0xFFFFFFFF, ffi.nullptr, 0);
      final paths = <String>[];

      for (int i = 0; i < fileCount; i++) {
        final length = dragQueryFile(hDrop, i, ffi.nullptr, 0);
        if (length > 0) {
          final buffer = calloc<ffi.Uint16>(length + 1);
          dragQueryFile(hDrop, i, buffer.cast(), length + 1);
          final path = buffer.cast<Utf16>().toDartString();
          calloc.free(buffer);
          paths.add(path);
        }
      }

      dragFinish(hDrop);

      if (paths.isNotEmpty) {
        simulateDrop(paths);
      }
    } catch (e) {
      debugPrint('[DesktopDragDrop] Error processing WM_DROPFILES: $e');
    }
  }

  /// Injects dropped file paths into the service stream.
  /// Used by native Win32 hooks and automated test suites.
  void simulateDrop(List<String> filePaths) {
    final items = filePaths.map((p) => DroppedItem.fromPath(p)).toList();
    if (items.isNotEmpty && !_dropStreamController.isClosed) {
      _dropStreamController.add(DroppedMediaEvent(items: items));
    }
  }

  /// Cleans up native Win32 window subclassing and stream controllers.
  void dispose() {
    if (_oldWndProc != 0 && _hwnd != 0) {
      _setWindowLongPtr(_hwnd, -4, _oldWndProc);
      _oldWndProc = 0;
    }
    _nativeCallable?.close();
    _nativeCallable = null;
    _dropStreamController.close();
    _isInitialized = false;
    _instance = null;
  }
}
