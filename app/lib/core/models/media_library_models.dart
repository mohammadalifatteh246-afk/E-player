import 'dart:convert';

/// Media entity type: unknown, video, or audio.
enum MediaType {
  unknown,
  video,
  audio,
}

/// File role: main media, multi-part fragment, soundtrack, or subtitle.
enum FileType {
  main,
  part,
  soundtrack,
  subtitle,
}

/// Processing step for asynchronous task queue ingestion.
enum TaskStep {
  discovered,
  metadataExtraction,
  complete,
  failed,
}

/// Type of file system entity displayed in browser navigation.
enum FileNodeType {
  drive,
  directory,
  videoFile,
  audioFile,
  subtitleFile,
  otherFile,
}

/// Alias for FileNodeType to satisfy polymorphic naming conventions.
typedef FileSystemNodeType = FileNodeType;

/// Type of filesystem watcher notification.
enum WatcherChangeType {
  created,
  modified,
  deleted,
  moved,
  overflowCatch,
}

/// Alias for WatcherChangeType to satisfy polymorphic naming conventions.
typedef WatcherEventType = WatcherChangeType;

/// Storage device or volume tracking record.
class DeviceRecord {
  final int? idDevice;
  final String uuid;
  final String scheme;
  final bool isRemovable;
  final bool isPresent;
  final DateTime lastSeen;

  const DeviceRecord({
    this.idDevice,
    required this.uuid,
    required this.scheme,
    this.isRemovable = false,
    this.isPresent = true,
    required this.lastSeen,
  });

  DeviceRecord copyWith({
    int? idDevice,
    String? uuid,
    String? scheme,
    bool? isRemovable,
    bool? isPresent,
    DateTime? lastSeen,
  }) {
    return DeviceRecord(
      idDevice: idDevice ?? this.idDevice,
      uuid: uuid ?? this.uuid,
      scheme: scheme ?? this.scheme,
      isRemovable: isRemovable ?? this.isRemovable,
      isPresent: isPresent ?? this.isPresent,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  Map<String, Object?> toMap() => {
    if (idDevice != null) 'id_device': idDevice,
    'uuid': uuid,
    'scheme': scheme,
    'is_removable': isRemovable ? 1 : 0,
    'is_present': isPresent ? 1 : 0,
    'last_seen': lastSeen.millisecondsSinceEpoch,
  };

  factory DeviceRecord.fromMap(Map<String, Object?> map) => DeviceRecord(
    idDevice: map['id_device'] as int?,
    uuid: map['uuid'] as String,
    scheme: map['scheme'] as String,
    isRemovable: (map['is_removable'] as int? ?? 0) == 1,
    isPresent: (map['is_present'] as int? ?? 1) == 1,
    lastSeen: DateTime.fromMillisecondsSinceEpoch(map['last_seen'] as int? ?? 0),
  );

  String toJson() => json.encode(toMap());

  factory DeviceRecord.fromJson(String source) =>
      DeviceRecord.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceRecord &&
          runtimeType == other.runtimeType &&
          idDevice == other.idDevice &&
          uuid == other.uuid &&
          scheme == other.scheme &&
          isRemovable == other.isRemovable &&
          isPresent == other.isPresent &&
          lastSeen.millisecondsSinceEpoch == other.lastSeen.millisecondsSinceEpoch;

  @override
  int get hashCode => Object.hash(
    idDevice,
    uuid,
    scheme,
    isRemovable,
    isPresent,
    lastSeen.millisecondsSinceEpoch,
  );

  @override
  String toString() =>
      'DeviceRecord(id: $idDevice, uuid: $uuid, scheme: $scheme, removable: $isRemovable, present: $isPresent, lastSeen: $lastSeen)';
}

/// Tracked directory or folder within a device.
class FolderRecord {
  final int? idFolder;
  final String path;
  final String name;
  final int? parentId;
  final int deviceId;
  final int mtime;
  final bool isPresent;
  final bool isBanned;
  final int nbMedia;

  const FolderRecord({
    this.idFolder,
    required this.path,
    required this.name,
    this.parentId,
    required this.deviceId,
    required this.mtime,
    this.isPresent = true,
    this.isBanned = false,
    this.nbMedia = 0,
  });

  FolderRecord copyWith({
    int? idFolder,
    String? path,
    String? name,
    int? parentId,
    int? deviceId,
    int? mtime,
    bool? isPresent,
    bool? isBanned,
    int? nbMedia,
  }) {
    return FolderRecord(
      idFolder: idFolder ?? this.idFolder,
      path: path ?? this.path,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      deviceId: deviceId ?? this.deviceId,
      mtime: mtime ?? this.mtime,
      isPresent: isPresent ?? this.isPresent,
      isBanned: isBanned ?? this.isBanned,
      nbMedia: nbMedia ?? this.nbMedia,
    );
  }

  Map<String, Object?> toMap() => {
    if (idFolder != null) 'id_folder': idFolder,
    'path': path,
    'name': name,
    'parent_id': parentId,
    'device_id': deviceId,
    'mtime': mtime,
    'is_present': isPresent ? 1 : 0,
    'is_banned': isBanned ? 1 : 0,
    'nb_media': nbMedia,
  };

  factory FolderRecord.fromMap(Map<String, Object?> map) => FolderRecord(
    idFolder: map['id_folder'] as int?,
    path: map['path'] as String,
    name: map['name'] as String,
    parentId: map['parent_id'] as int?,
    deviceId: map['device_id'] as int,
    mtime: map['mtime'] as int? ?? 0,
    isPresent: (map['is_present'] as int? ?? 1) == 1,
    isBanned: (map['is_banned'] as int? ?? 0) == 1,
    nbMedia: map['nb_media'] as int? ?? 0,
  );

  String toJson() => json.encode(toMap());

  factory FolderRecord.fromJson(String source) =>
      FolderRecord.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FolderRecord &&
          runtimeType == other.runtimeType &&
          idFolder == other.idFolder &&
          path == other.path &&
          name == other.name &&
          parentId == other.parentId &&
          deviceId == other.deviceId &&
          mtime == other.mtime &&
          isPresent == other.isPresent &&
          isBanned == other.isBanned &&
          nbMedia == other.nbMedia;

  @override
  int get hashCode => Object.hash(
    idFolder,
    path,
    name,
    parentId,
    deviceId,
    mtime,
    isPresent,
    isBanned,
    nbMedia,
  );

  @override
  String toString() =>
      'FolderRecord(id: $idFolder, path: $path, name: $name, parentId: $parentId, deviceId: $deviceId, mediaCount: $nbMedia, present: $isPresent, banned: $isBanned)';
}

/// Core media entity representing a logical video or audio title.
class MediaRecord {
  final int? idMedia;
  final MediaType type;
  final int subtype;
  final String title;
  final int duration;
  final int playCount;
  final int lastPosition;
  final DateTime? lastPlayedDate;
  final DateTime insertionDate;
  final DateTime? releaseDate;
  final String? thumbnail;
  final bool isFavorite;
  final bool isPresent;

  const MediaRecord({
    this.idMedia,
    required this.type,
    this.subtype = 0,
    required this.title,
    this.duration = -1,
    this.playCount = 0,
    this.lastPosition = 0,
    this.lastPlayedDate,
    required this.insertionDate,
    this.releaseDate,
    this.thumbnail,
    this.isFavorite = false,
    this.isPresent = true,
  });

  MediaRecord copyWith({
    int? idMedia,
    MediaType? type,
    int? subtype,
    String? title,
    int? duration,
    int? playCount,
    int? lastPosition,
    DateTime? lastPlayedDate,
    DateTime? insertionDate,
    DateTime? releaseDate,
    String? thumbnail,
    bool? isFavorite,
    bool? isPresent,
  }) {
    return MediaRecord(
      idMedia: idMedia ?? this.idMedia,
      type: type ?? this.type,
      subtype: subtype ?? this.subtype,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      playCount: playCount ?? this.playCount,
      lastPosition: lastPosition ?? this.lastPosition,
      lastPlayedDate: lastPlayedDate ?? this.lastPlayedDate,
      insertionDate: insertionDate ?? this.insertionDate,
      releaseDate: releaseDate ?? this.releaseDate,
      thumbnail: thumbnail ?? this.thumbnail,
      isFavorite: isFavorite ?? this.isFavorite,
      isPresent: isPresent ?? this.isPresent,
    );
  }

  Map<String, Object?> toMap() => {
    if (idMedia != null) 'id_media': idMedia,
    'type': type.index,
    'subtype': subtype,
    'title': title,
    'duration': duration,
    'play_count': playCount,
    'last_position': lastPosition,
    'last_played_date': lastPlayedDate?.millisecondsSinceEpoch,
    'insertion_date': insertionDate.millisecondsSinceEpoch,
    'release_date': releaseDate?.millisecondsSinceEpoch,
    'thumbnail': thumbnail,
    'is_favorite': isFavorite ? 1 : 0,
    'is_present': isPresent ? 1 : 0,
  };

  factory MediaRecord.fromMap(Map<String, Object?> map) => MediaRecord(
    idMedia: map['id_media'] as int?,
    type: MediaType.values[(map['type'] as int? ?? 0).clamp(0, 2)],
    subtype: map['subtype'] as int? ?? 0,
    title: map['title'] as String,
    duration: map['duration'] as int? ?? -1,
    playCount: map['play_count'] as int? ?? 0,
    lastPosition: map['last_position'] as int? ?? 0,
    lastPlayedDate: map['last_played_date'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['last_played_date'] as int)
        : null,
    insertionDate: DateTime.fromMillisecondsSinceEpoch(map['insertion_date'] as int? ?? 0),
    releaseDate: map['release_date'] != null
        ? DateTime.fromMillisecondsSinceEpoch(map['release_date'] as int)
        : null,
    thumbnail: map['thumbnail'] as String?,
    isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
    isPresent: (map['is_present'] as int? ?? 1) == 1,
  );

  String toJson() => json.encode(toMap());

  factory MediaRecord.fromJson(String source) =>
      MediaRecord.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaRecord &&
          runtimeType == other.runtimeType &&
          idMedia == other.idMedia &&
          type == other.type &&
          subtype == other.subtype &&
          title == other.title &&
          duration == other.duration &&
          playCount == other.playCount &&
          lastPosition == other.lastPosition &&
          lastPlayedDate?.millisecondsSinceEpoch == other.lastPlayedDate?.millisecondsSinceEpoch &&
          insertionDate.millisecondsSinceEpoch == other.insertionDate.millisecondsSinceEpoch &&
          releaseDate?.millisecondsSinceEpoch == other.releaseDate?.millisecondsSinceEpoch &&
          thumbnail == other.thumbnail &&
          isFavorite == other.isFavorite &&
          isPresent == other.isPresent;

  @override
  int get hashCode => Object.hash(
    idMedia,
    type,
    subtype,
    title,
    duration,
    playCount,
    lastPosition,
    lastPlayedDate?.millisecondsSinceEpoch,
    insertionDate.millisecondsSinceEpoch,
    releaseDate?.millisecondsSinceEpoch,
    thumbnail,
    isFavorite,
    isPresent,
  );

  @override
  String toString() =>
      'MediaRecord(id: $idMedia, title: $title, type: $type, duration: $duration, fav: $isFavorite, present: $isPresent)';
}

/// Physical file storage instance of a media item on disk.
class FileRecord {
  final int? idFile;
  final int mediaId;
  final int? folderId;
  final String mrl;
  final FileType type;
  final int mtime;
  final int size;
  final bool isPresent;
  final bool isRemovable;

  const FileRecord({
    this.idFile,
    required this.mediaId,
    this.folderId,
    required this.mrl,
    this.type = FileType.main,
    required this.mtime,
    required this.size,
    this.isPresent = true,
    this.isRemovable = false,
  });

  FileRecord copyWith({
    int? idFile,
    int? mediaId,
    int? folderId,
    String? mrl,
    FileType? type,
    int? mtime,
    int? size,
    bool? isPresent,
    bool? isRemovable,
  }) {
    return FileRecord(
      idFile: idFile ?? this.idFile,
      mediaId: mediaId ?? this.mediaId,
      folderId: folderId ?? this.folderId,
      mrl: mrl ?? this.mrl,
      type: type ?? this.type,
      mtime: mtime ?? this.mtime,
      size: size ?? this.size,
      isPresent: isPresent ?? this.isPresent,
      isRemovable: isRemovable ?? this.isRemovable,
    );
  }

  Map<String, Object?> toMap() => {
    if (idFile != null) 'id_file': idFile,
    'media_id': mediaId,
    'folder_id': folderId,
    'mrl': mrl,
    'type': type.index + 1,
    'mtime': mtime,
    'size': size,
    'is_present': isPresent ? 1 : 0,
    'is_removable': isRemovable ? 1 : 0,
  };

  factory FileRecord.fromMap(Map<String, Object?> map) => FileRecord(
    idFile: map['id_file'] as int?,
    mediaId: map['media_id'] as int,
    folderId: map['folder_id'] as int?,
    mrl: map['mrl'] as String,
    type: FileType.values[((map['type'] as int? ?? 1) - 1).clamp(0, 3)],
    mtime: map['mtime'] as int? ?? 0,
    size: map['size'] as int? ?? 0,
    isPresent: (map['is_present'] as int? ?? 1) == 1,
    isRemovable: (map['is_removable'] as int? ?? 0) == 1,
  );

  String toJson() => json.encode(toMap());

  factory FileRecord.fromJson(String source) =>
      FileRecord.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileRecord &&
          runtimeType == other.runtimeType &&
          idFile == other.idFile &&
          mediaId == other.mediaId &&
          folderId == other.folderId &&
          mrl == other.mrl &&
          type == other.type &&
          mtime == other.mtime &&
          size == other.size &&
          isPresent == other.isPresent &&
          isRemovable == other.isRemovable;

  @override
  int get hashCode => Object.hash(
    idFile,
    mediaId,
    folderId,
    mrl,
    type,
    mtime,
    size,
    isPresent,
    isRemovable,
  );

  @override
  String toString() =>
      'FileRecord(id: $idFile, mediaId: $mediaId, mrl: $mrl, size: $size, present: $isPresent)';
}

/// Technical video stream metadata record.
class VideoTrackRecord {
  final int? idTrack;
  final int mediaId;
  final String? codec;
  final int width;
  final int height;
  final int? fpsNum;
  final int? fpsDen;
  final int? bitrate;

  const VideoTrackRecord({
    this.idTrack,
    required this.mediaId,
    this.codec,
    required this.width,
    required this.height,
    this.fpsNum,
    this.fpsDen,
    this.bitrate,
  });

  VideoTrackRecord copyWith({
    int? idTrack,
    int? mediaId,
    String? codec,
    int? width,
    int? height,
    int? fpsNum,
    int? fpsDen,
    int? bitrate,
  }) {
    return VideoTrackRecord(
      idTrack: idTrack ?? this.idTrack,
      mediaId: mediaId ?? this.mediaId,
      codec: codec ?? this.codec,
      width: width ?? this.width,
      height: height ?? this.height,
      fpsNum: fpsNum ?? this.fpsNum,
      fpsDen: fpsDen ?? this.fpsDen,
      bitrate: bitrate ?? this.bitrate,
    );
  }

  Map<String, Object?> toMap() => {
    if (idTrack != null) 'id_track': idTrack,
    'media_id': mediaId,
    'codec': codec,
    'width': width,
    'height': height,
    'fps_num': fpsNum,
    'fps_den': fpsDen,
    'bitrate': bitrate,
  };

  factory VideoTrackRecord.fromMap(Map<String, Object?> map) => VideoTrackRecord(
    idTrack: map['id_track'] as int?,
    mediaId: map['media_id'] as int,
    codec: map['codec'] as String?,
    width: map['width'] as int? ?? 0,
    height: map['height'] as int? ?? 0,
    fpsNum: map['fps_num'] as int?,
    fpsDen: map['fps_den'] as int?,
    bitrate: map['bitrate'] as int?,
  );

  String toJson() => json.encode(toMap());

  factory VideoTrackRecord.fromJson(String source) =>
      VideoTrackRecord.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoTrackRecord &&
          runtimeType == other.runtimeType &&
          idTrack == other.idTrack &&
          mediaId == other.mediaId &&
          codec == other.codec &&
          width == other.width &&
          height == other.height &&
          fpsNum == other.fpsNum &&
          fpsDen == other.fpsDen &&
          bitrate == other.bitrate;

  @override
  int get hashCode => Object.hash(
    idTrack,
    mediaId,
    codec,
    width,
    height,
    fpsNum,
    fpsDen,
    bitrate,
  );

  @override
  String toString() =>
      'VideoTrackRecord(id: $idTrack, mediaId: $mediaId, codec: $codec, resolution: ${width}x$height, bitrate: $bitrate)';
}

/// Technical audio stream metadata record.
class AudioTrackRecord {
  final int? idTrack;
  final int mediaId;
  final String? codec;
  final int? bitrate;
  final int? samplerate;
  final int? nbChannels;
  final String? language;

  const AudioTrackRecord({
    this.idTrack,
    required this.mediaId,
    this.codec,
    this.bitrate,
    this.samplerate,
    this.nbChannels,
    this.language,
  });

  AudioTrackRecord copyWith({
    int? idTrack,
    int? mediaId,
    String? codec,
    int? bitrate,
    int? samplerate,
    int? nbChannels,
    String? language,
  }) {
    return AudioTrackRecord(
      idTrack: idTrack ?? this.idTrack,
      mediaId: mediaId ?? this.mediaId,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      samplerate: samplerate ?? this.samplerate,
      nbChannels: nbChannels ?? this.nbChannels,
      language: language ?? this.language,
    );
  }

  Map<String, Object?> toMap() => {
    if (idTrack != null) 'id_track': idTrack,
    'media_id': mediaId,
    'codec': codec,
    'bitrate': bitrate,
    'samplerate': samplerate,
    'nb_channels': nbChannels,
    'language': language,
  };

  factory AudioTrackRecord.fromMap(Map<String, Object?> map) => AudioTrackRecord(
    idTrack: map['id_track'] as int?,
    mediaId: map['media_id'] as int,
    codec: map['codec'] as String?,
    bitrate: map['bitrate'] as int?,
    samplerate: map['samplerate'] as int?,
    nbChannels: map['nb_channels'] as int?,
    language: map['language'] as String?,
  );

  String toJson() => json.encode(toMap());

  factory AudioTrackRecord.fromJson(String source) =>
      AudioTrackRecord.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrackRecord &&
          runtimeType == other.runtimeType &&
          idTrack == other.idTrack &&
          mediaId == other.mediaId &&
          codec == other.codec &&
          bitrate == other.bitrate &&
          samplerate == other.samplerate &&
          nbChannels == other.nbChannels &&
          language == other.language;

  @override
  int get hashCode => Object.hash(
    idTrack,
    mediaId,
    codec,
    bitrate,
    samplerate,
    nbChannels,
    language,
  );

  @override
  String toString() =>
      'AudioTrackRecord(id: $idTrack, mediaId: $mediaId, codec: $codec, channels: $nbChannels, rate: $samplerate)';
}

/// Ingestion queue task record.
class TaskRecord {
  final int? idTask;
  final TaskStep step;
  final int retryCount;
  final int fileId;

  const TaskRecord({
    this.idTask,
    this.step = TaskStep.discovered,
    this.retryCount = 0,
    required this.fileId,
  });

  TaskRecord copyWith({
    int? idTask,
    TaskStep? step,
    int? retryCount,
    int? fileId,
  }) {
    return TaskRecord(
      idTask: idTask ?? this.idTask,
      step: step ?? this.step,
      retryCount: retryCount ?? this.retryCount,
      fileId: fileId ?? this.fileId,
    );
  }

  Map<String, Object?> toMap() => {
    if (idTask != null) 'id_task': idTask,
    'step': step.index,
    'retry_count': retryCount,
    'file_id': fileId,
  };

  factory TaskRecord.fromMap(Map<String, Object?> map) => TaskRecord(
    idTask: map['id_task'] as int?,
    step: TaskStep.values[(map['step'] as int? ?? 0).clamp(0, 3)],
    retryCount: map['retry_count'] as int? ?? 0,
    fileId: map['file_id'] as int,
  );

  String toJson() => json.encode(toMap());

  factory TaskRecord.fromJson(String source) =>
      TaskRecord.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskRecord &&
          runtimeType == other.runtimeType &&
          idTask == other.idTask &&
          step == other.step &&
          retryCount == other.retryCount &&
          fileId == other.fileId;

  @override
  int get hashCode => Object.hash(idTask, step, retryCount, fileId);

  @override
  String toString() =>
      'TaskRecord(id: $idTask, fileId: $fileId, step: $step, retry: $retryCount)';
}

/// In-memory node representation for the interactive file browser navigation tree.
class FileSystemNode {
  final String path;
  final String name;
  final FileNodeType type;
  final int sizeBytes;
  final DateTime modifiedDate;
  final bool isHidden;
  final bool hasChildren;
  final int childMediaCount;

  const FileSystemNode({
    required this.path,
    required this.name,
    required this.type,
    this.sizeBytes = 0,
    required this.modifiedDate,
    this.isHidden = false,
    this.hasChildren = false,
    this.childMediaCount = 0,
  });

  bool get isDirectory => type == FileNodeType.directory || type == FileNodeType.drive;
  bool get isMedia => type == FileNodeType.videoFile || type == FileNodeType.audioFile;

  FileSystemNode copyWith({
    String? path,
    String? name,
    FileNodeType? type,
    int? sizeBytes,
    DateTime? modifiedDate,
    bool? isHidden,
    bool? hasChildren,
    int? childMediaCount,
  }) {
    return FileSystemNode(
      path: path ?? this.path,
      name: name ?? this.name,
      type: type ?? this.type,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      isHidden: isHidden ?? this.isHidden,
      hasChildren: hasChildren ?? this.hasChildren,
      childMediaCount: childMediaCount ?? this.childMediaCount,
    );
  }

  Map<String, Object?> toMap() => {
    'path': path,
    'name': name,
    'type': type.index,
    'size_bytes': sizeBytes,
    'modified_date': modifiedDate.millisecondsSinceEpoch,
    'is_hidden': isHidden ? 1 : 0,
    'has_children': hasChildren ? 1 : 0,
    'child_media_count': childMediaCount,
  };

  factory FileSystemNode.fromMap(Map<String, Object?> map) => FileSystemNode(
    path: map['path'] as String,
    name: map['name'] as String,
    type: FileNodeType.values[(map['type'] as int? ?? 0).clamp(0, 5)],
    sizeBytes: map['size_bytes'] as int? ?? 0,
    modifiedDate: DateTime.fromMillisecondsSinceEpoch(map['modified_date'] as int? ?? 0),
    isHidden: (map['is_hidden'] as int? ?? 0) == 1,
    hasChildren: (map['has_children'] as int? ?? 0) == 1,
    childMediaCount: map['child_media_count'] as int? ?? 0,
  );

  String toJson() => json.encode(toMap());

  factory FileSystemNode.fromJson(String source) =>
      FileSystemNode.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileSystemNode &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          name == other.name &&
          type == other.type &&
          sizeBytes == other.sizeBytes &&
          modifiedDate.millisecondsSinceEpoch == other.modifiedDate.millisecondsSinceEpoch &&
          isHidden == other.isHidden &&
          hasChildren == other.hasChildren &&
          childMediaCount == other.childMediaCount;

  @override
  int get hashCode => Object.hash(
    path,
    name,
    type,
    sizeBytes,
    modifiedDate.millisecondsSinceEpoch,
    isHidden,
    hasChildren,
    childMediaCount,
  );

  @override
  String toString() =>
      'FileSystemNode(path: $path, name: $name, type: $type, size: $sizeBytes, modified: $modifiedDate)';
}

/// Directory watcher event payload.
class WatcherEvent {
  final String path;
  final WatcherChangeType type;
  final String? destinationPath;
  final DateTime timestamp;
  final bool isDirectory;

  const WatcherEvent({
    required this.path,
    required this.type,
    this.destinationPath,
    required this.timestamp,
    this.isDirectory = false,
  });

  WatcherEvent copyWith({
    String? path,
    WatcherChangeType? type,
    String? destinationPath,
    DateTime? timestamp,
    bool? isDirectory,
  }) {
    return WatcherEvent(
      path: path ?? this.path,
      type: type ?? this.type,
      destinationPath: destinationPath ?? this.destinationPath,
      timestamp: timestamp ?? this.timestamp,
      isDirectory: isDirectory ?? this.isDirectory,
    );
  }

  Map<String, Object?> toMap() => {
    'path': path,
    'type': type.index,
    'destination_path': destinationPath,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'is_directory': isDirectory ? 1 : 0,
  };

  factory WatcherEvent.fromMap(Map<String, Object?> map) => WatcherEvent(
    path: map['path'] as String,
    type: WatcherChangeType.values[(map['type'] as int? ?? 0).clamp(0, 4)],
    destinationPath: map['destination_path'] as String?,
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? 0),
    isDirectory: (map['is_directory'] as int? ?? 0) == 1,
  );

  String toJson() => json.encode(toMap());

  factory WatcherEvent.fromJson(String source) =>
      WatcherEvent.fromMap(json.decode(source) as Map<String, Object?>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatcherEvent &&
          runtimeType == other.runtimeType &&
          path == other.path &&
          type == other.type &&
          destinationPath == other.destinationPath &&
          timestamp.millisecondsSinceEpoch == other.timestamp.millisecondsSinceEpoch &&
          isDirectory == other.isDirectory;

  @override
  int get hashCode => Object.hash(
    path,
    type,
    destinationPath,
    timestamp.millisecondsSinceEpoch,
    isDirectory,
  );

  @override
  String toString() =>
      'WatcherEvent($type, path: $path, dest: $destinationPath, dir: $isDirectory, time: $timestamp)';
}
