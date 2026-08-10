// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $KeyValueEntriesTable extends KeyValueEntries
    with TableInfo<$KeyValueEntriesTable, KeyValueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_value_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<KeyValueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValueEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $KeyValueEntriesTable createAlias(String alias) {
    return $KeyValueEntriesTable(attachedDatabase, alias);
  }
}

class KeyValueEntry extends DataClass implements Insertable<KeyValueEntry> {
  final String key;
  final String value;
  const KeyValueEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValueEntriesCompanion toCompanion(bool nullToAbsent) {
    return KeyValueEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValueEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  KeyValueEntry copyWith({String? key, String? value}) =>
      KeyValueEntry(key: key ?? this.key, value: value ?? this.value);
  KeyValueEntry copyWithCompanion(KeyValueEntriesCompanion data) {
    return KeyValueEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KeyValueEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class KeyValueEntriesCompanion extends UpdateCompanion<KeyValueEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValueEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValueEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<KeyValueEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValueEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return KeyValueEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValueEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadedItemsTable extends DownloadedItems
    with TableInfo<$DownloadedItemsTable, DownloadedItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadedItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUrlMeta = const VerificationMeta(
    'serverUrl',
  );
  @override
  late final GeneratedColumn<String> serverUrl = GeneratedColumn<String>(
    'server_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorNamesMeta = const VerificationMeta(
    'authorNames',
  );
  @override
  late final GeneratedColumn<String> authorNames = GeneratedColumn<String>(
    'author_names',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _totalDurationMeta = const VerificationMeta(
    'totalDuration',
  );
  @override
  late final GeneratedColumn<double> totalDuration = GeneratedColumn<double>(
    'total_duration',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chaptersJsonMeta = const VerificationMeta(
    'chaptersJson',
  );
  @override
  late final GeneratedColumn<String> chaptersJson = GeneratedColumn<String>(
    'chapters_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverLocalPathMeta = const VerificationMeta(
    'coverLocalPath',
  );
  @override
  late final GeneratedColumn<String> coverLocalPath = GeneratedColumn<String>(
    'cover_local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('downloading'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _progressCurrentTimeMeta =
      const VerificationMeta('progressCurrentTime');
  @override
  late final GeneratedColumn<double> progressCurrentTime =
      GeneratedColumn<double>(
        'progress_current_time',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _progressIsFinishedMeta =
      const VerificationMeta('progressIsFinished');
  @override
  late final GeneratedColumn<bool> progressIsFinished = GeneratedColumn<bool>(
    'progress_is_finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("progress_is_finished" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    serverUrl,
    title,
    authorNames,
    totalDuration,
    chaptersJson,
    coverLocalPath,
    status,
    createdAt,
    progressCurrentTime,
    progressIsFinished,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloaded_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadedItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('server_url')) {
      context.handle(
        _serverUrlMeta,
        serverUrl.isAcceptableOrUnknown(data['server_url']!, _serverUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_serverUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author_names')) {
      context.handle(
        _authorNamesMeta,
        authorNames.isAcceptableOrUnknown(
          data['author_names']!,
          _authorNamesMeta,
        ),
      );
    }
    if (data.containsKey('total_duration')) {
      context.handle(
        _totalDurationMeta,
        totalDuration.isAcceptableOrUnknown(
          data['total_duration']!,
          _totalDurationMeta,
        ),
      );
    }
    if (data.containsKey('chapters_json')) {
      context.handle(
        _chaptersJsonMeta,
        chaptersJson.isAcceptableOrUnknown(
          data['chapters_json']!,
          _chaptersJsonMeta,
        ),
      );
    }
    if (data.containsKey('cover_local_path')) {
      context.handle(
        _coverLocalPathMeta,
        coverLocalPath.isAcceptableOrUnknown(
          data['cover_local_path']!,
          _coverLocalPathMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('progress_current_time')) {
      context.handle(
        _progressCurrentTimeMeta,
        progressCurrentTime.isAcceptableOrUnknown(
          data['progress_current_time']!,
          _progressCurrentTimeMeta,
        ),
      );
    }
    if (data.containsKey('progress_is_finished')) {
      context.handle(
        _progressIsFinishedMeta,
        progressIsFinished.isAcceptableOrUnknown(
          data['progress_is_finished']!,
          _progressIsFinishedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  DownloadedItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadedItem(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      serverUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      authorNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author_names'],
      )!,
      totalDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_duration'],
      ),
      chaptersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chapters_json'],
      ),
      coverLocalPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_local_path'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      progressCurrentTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_current_time'],
      ),
      progressIsFinished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}progress_is_finished'],
      )!,
    );
  }

  @override
  $DownloadedItemsTable createAlias(String alias) {
    return $DownloadedItemsTable(attachedDatabase, alias);
  }
}

class DownloadedItem extends DataClass implements Insertable<DownloadedItem> {
  final String itemId;
  final String serverUrl;
  final String title;
  final String authorNames;
  final double? totalDuration;
  final String? chaptersJson;
  final String? coverLocalPath;
  final String status;
  final DateTime createdAt;
  final double? progressCurrentTime;
  final bool progressIsFinished;
  const DownloadedItem({
    required this.itemId,
    required this.serverUrl,
    required this.title,
    required this.authorNames,
    this.totalDuration,
    this.chaptersJson,
    this.coverLocalPath,
    required this.status,
    required this.createdAt,
    this.progressCurrentTime,
    required this.progressIsFinished,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['server_url'] = Variable<String>(serverUrl);
    map['title'] = Variable<String>(title);
    map['author_names'] = Variable<String>(authorNames);
    if (!nullToAbsent || totalDuration != null) {
      map['total_duration'] = Variable<double>(totalDuration);
    }
    if (!nullToAbsent || chaptersJson != null) {
      map['chapters_json'] = Variable<String>(chaptersJson);
    }
    if (!nullToAbsent || coverLocalPath != null) {
      map['cover_local_path'] = Variable<String>(coverLocalPath);
    }
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || progressCurrentTime != null) {
      map['progress_current_time'] = Variable<double>(progressCurrentTime);
    }
    map['progress_is_finished'] = Variable<bool>(progressIsFinished);
    return map;
  }

  DownloadedItemsCompanion toCompanion(bool nullToAbsent) {
    return DownloadedItemsCompanion(
      itemId: Value(itemId),
      serverUrl: Value(serverUrl),
      title: Value(title),
      authorNames: Value(authorNames),
      totalDuration: totalDuration == null && nullToAbsent
          ? const Value.absent()
          : Value(totalDuration),
      chaptersJson: chaptersJson == null && nullToAbsent
          ? const Value.absent()
          : Value(chaptersJson),
      coverLocalPath: coverLocalPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverLocalPath),
      status: Value(status),
      createdAt: Value(createdAt),
      progressCurrentTime: progressCurrentTime == null && nullToAbsent
          ? const Value.absent()
          : Value(progressCurrentTime),
      progressIsFinished: Value(progressIsFinished),
    );
  }

  factory DownloadedItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadedItem(
      itemId: serializer.fromJson<String>(json['itemId']),
      serverUrl: serializer.fromJson<String>(json['serverUrl']),
      title: serializer.fromJson<String>(json['title']),
      authorNames: serializer.fromJson<String>(json['authorNames']),
      totalDuration: serializer.fromJson<double?>(json['totalDuration']),
      chaptersJson: serializer.fromJson<String?>(json['chaptersJson']),
      coverLocalPath: serializer.fromJson<String?>(json['coverLocalPath']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      progressCurrentTime: serializer.fromJson<double?>(
        json['progressCurrentTime'],
      ),
      progressIsFinished: serializer.fromJson<bool>(json['progressIsFinished']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'serverUrl': serializer.toJson<String>(serverUrl),
      'title': serializer.toJson<String>(title),
      'authorNames': serializer.toJson<String>(authorNames),
      'totalDuration': serializer.toJson<double?>(totalDuration),
      'chaptersJson': serializer.toJson<String?>(chaptersJson),
      'coverLocalPath': serializer.toJson<String?>(coverLocalPath),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'progressCurrentTime': serializer.toJson<double?>(progressCurrentTime),
      'progressIsFinished': serializer.toJson<bool>(progressIsFinished),
    };
  }

  DownloadedItem copyWith({
    String? itemId,
    String? serverUrl,
    String? title,
    String? authorNames,
    Value<double?> totalDuration = const Value.absent(),
    Value<String?> chaptersJson = const Value.absent(),
    Value<String?> coverLocalPath = const Value.absent(),
    String? status,
    DateTime? createdAt,
    Value<double?> progressCurrentTime = const Value.absent(),
    bool? progressIsFinished,
  }) => DownloadedItem(
    itemId: itemId ?? this.itemId,
    serverUrl: serverUrl ?? this.serverUrl,
    title: title ?? this.title,
    authorNames: authorNames ?? this.authorNames,
    totalDuration: totalDuration.present
        ? totalDuration.value
        : this.totalDuration,
    chaptersJson: chaptersJson.present ? chaptersJson.value : this.chaptersJson,
    coverLocalPath: coverLocalPath.present
        ? coverLocalPath.value
        : this.coverLocalPath,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    progressCurrentTime: progressCurrentTime.present
        ? progressCurrentTime.value
        : this.progressCurrentTime,
    progressIsFinished: progressIsFinished ?? this.progressIsFinished,
  );
  DownloadedItem copyWithCompanion(DownloadedItemsCompanion data) {
    return DownloadedItem(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      serverUrl: data.serverUrl.present ? data.serverUrl.value : this.serverUrl,
      title: data.title.present ? data.title.value : this.title,
      authorNames: data.authorNames.present
          ? data.authorNames.value
          : this.authorNames,
      totalDuration: data.totalDuration.present
          ? data.totalDuration.value
          : this.totalDuration,
      chaptersJson: data.chaptersJson.present
          ? data.chaptersJson.value
          : this.chaptersJson,
      coverLocalPath: data.coverLocalPath.present
          ? data.coverLocalPath.value
          : this.coverLocalPath,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      progressCurrentTime: data.progressCurrentTime.present
          ? data.progressCurrentTime.value
          : this.progressCurrentTime,
      progressIsFinished: data.progressIsFinished.present
          ? data.progressIsFinished.value
          : this.progressIsFinished,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedItem(')
          ..write('itemId: $itemId, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('title: $title, ')
          ..write('authorNames: $authorNames, ')
          ..write('totalDuration: $totalDuration, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('coverLocalPath: $coverLocalPath, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('progressCurrentTime: $progressCurrentTime, ')
          ..write('progressIsFinished: $progressIsFinished')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    itemId,
    serverUrl,
    title,
    authorNames,
    totalDuration,
    chaptersJson,
    coverLocalPath,
    status,
    createdAt,
    progressCurrentTime,
    progressIsFinished,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadedItem &&
          other.itemId == this.itemId &&
          other.serverUrl == this.serverUrl &&
          other.title == this.title &&
          other.authorNames == this.authorNames &&
          other.totalDuration == this.totalDuration &&
          other.chaptersJson == this.chaptersJson &&
          other.coverLocalPath == this.coverLocalPath &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.progressCurrentTime == this.progressCurrentTime &&
          other.progressIsFinished == this.progressIsFinished);
}

class DownloadedItemsCompanion extends UpdateCompanion<DownloadedItem> {
  final Value<String> itemId;
  final Value<String> serverUrl;
  final Value<String> title;
  final Value<String> authorNames;
  final Value<double?> totalDuration;
  final Value<String?> chaptersJson;
  final Value<String?> coverLocalPath;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<double?> progressCurrentTime;
  final Value<bool> progressIsFinished;
  final Value<int> rowid;
  const DownloadedItemsCompanion({
    this.itemId = const Value.absent(),
    this.serverUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.authorNames = const Value.absent(),
    this.totalDuration = const Value.absent(),
    this.chaptersJson = const Value.absent(),
    this.coverLocalPath = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.progressCurrentTime = const Value.absent(),
    this.progressIsFinished = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadedItemsCompanion.insert({
    required String itemId,
    required String serverUrl,
    required String title,
    this.authorNames = const Value.absent(),
    this.totalDuration = const Value.absent(),
    this.chaptersJson = const Value.absent(),
    this.coverLocalPath = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.progressCurrentTime = const Value.absent(),
    this.progressIsFinished = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       serverUrl = Value(serverUrl),
       title = Value(title);
  static Insertable<DownloadedItem> custom({
    Expression<String>? itemId,
    Expression<String>? serverUrl,
    Expression<String>? title,
    Expression<String>? authorNames,
    Expression<double>? totalDuration,
    Expression<String>? chaptersJson,
    Expression<String>? coverLocalPath,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<double>? progressCurrentTime,
    Expression<bool>? progressIsFinished,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (serverUrl != null) 'server_url': serverUrl,
      if (title != null) 'title': title,
      if (authorNames != null) 'author_names': authorNames,
      if (totalDuration != null) 'total_duration': totalDuration,
      if (chaptersJson != null) 'chapters_json': chaptersJson,
      if (coverLocalPath != null) 'cover_local_path': coverLocalPath,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (progressCurrentTime != null)
        'progress_current_time': progressCurrentTime,
      if (progressIsFinished != null)
        'progress_is_finished': progressIsFinished,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadedItemsCompanion copyWith({
    Value<String>? itemId,
    Value<String>? serverUrl,
    Value<String>? title,
    Value<String>? authorNames,
    Value<double?>? totalDuration,
    Value<String?>? chaptersJson,
    Value<String?>? coverLocalPath,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<double?>? progressCurrentTime,
    Value<bool>? progressIsFinished,
    Value<int>? rowid,
  }) {
    return DownloadedItemsCompanion(
      itemId: itemId ?? this.itemId,
      serverUrl: serverUrl ?? this.serverUrl,
      title: title ?? this.title,
      authorNames: authorNames ?? this.authorNames,
      totalDuration: totalDuration ?? this.totalDuration,
      chaptersJson: chaptersJson ?? this.chaptersJson,
      coverLocalPath: coverLocalPath ?? this.coverLocalPath,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      progressCurrentTime: progressCurrentTime ?? this.progressCurrentTime,
      progressIsFinished: progressIsFinished ?? this.progressIsFinished,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (serverUrl.present) {
      map['server_url'] = Variable<String>(serverUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (authorNames.present) {
      map['author_names'] = Variable<String>(authorNames.value);
    }
    if (totalDuration.present) {
      map['total_duration'] = Variable<double>(totalDuration.value);
    }
    if (chaptersJson.present) {
      map['chapters_json'] = Variable<String>(chaptersJson.value);
    }
    if (coverLocalPath.present) {
      map['cover_local_path'] = Variable<String>(coverLocalPath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (progressCurrentTime.present) {
      map['progress_current_time'] = Variable<double>(
        progressCurrentTime.value,
      );
    }
    if (progressIsFinished.present) {
      map['progress_is_finished'] = Variable<bool>(progressIsFinished.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedItemsCompanion(')
          ..write('itemId: $itemId, ')
          ..write('serverUrl: $serverUrl, ')
          ..write('title: $title, ')
          ..write('authorNames: $authorNames, ')
          ..write('totalDuration: $totalDuration, ')
          ..write('chaptersJson: $chaptersJson, ')
          ..write('coverLocalPath: $coverLocalPath, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('progressCurrentTime: $progressCurrentTime, ')
          ..write('progressIsFinished: $progressIsFinished, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadedTracksTable extends DownloadedTracks
    with TableInfo<$DownloadedTracksTable, DownloadedTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadedTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES downloaded_items (item_id)',
    ),
  );
  static const VerificationMeta _trackIndexMeta = const VerificationMeta(
    'trackIndex',
  );
  @override
  late final GeneratedColumn<int> trackIndex = GeneratedColumn<int>(
    'track_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startOffsetMeta = const VerificationMeta(
    'startOffset',
  );
  @override
  late final GeneratedColumn<double> startOffset = GeneratedColumn<double>(
    'start_offset',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<double> duration = GeneratedColumn<double>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    trackIndex,
    startOffset,
    duration,
    localPath,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloaded_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadedTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('track_index')) {
      context.handle(
        _trackIndexMeta,
        trackIndex.isAcceptableOrUnknown(data['track_index']!, _trackIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIndexMeta);
    }
    if (data.containsKey('start_offset')) {
      context.handle(
        _startOffsetMeta,
        startOffset.isAcceptableOrUnknown(
          data['start_offset']!,
          _startOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadedTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadedTrack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      trackIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_index'],
      )!,
      startOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}start_offset'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $DownloadedTracksTable createAlias(String alias) {
    return $DownloadedTracksTable(attachedDatabase, alias);
  }
}

class DownloadedTrack extends DataClass implements Insertable<DownloadedTrack> {
  final int id;
  final String itemId;
  final int trackIndex;
  final double startOffset;
  final double duration;
  final String? localPath;
  final String status;
  const DownloadedTrack({
    required this.id,
    required this.itemId,
    required this.trackIndex,
    required this.startOffset,
    required this.duration,
    this.localPath,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['item_id'] = Variable<String>(itemId);
    map['track_index'] = Variable<int>(trackIndex);
    map['start_offset'] = Variable<double>(startOffset);
    map['duration'] = Variable<double>(duration);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  DownloadedTracksCompanion toCompanion(bool nullToAbsent) {
    return DownloadedTracksCompanion(
      id: Value(id),
      itemId: Value(itemId),
      trackIndex: Value(trackIndex),
      startOffset: Value(startOffset),
      duration: Value(duration),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      status: Value(status),
    );
  }

  factory DownloadedTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadedTrack(
      id: serializer.fromJson<int>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      trackIndex: serializer.fromJson<int>(json['trackIndex']),
      startOffset: serializer.fromJson<double>(json['startOffset']),
      duration: serializer.fromJson<double>(json['duration']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemId': serializer.toJson<String>(itemId),
      'trackIndex': serializer.toJson<int>(trackIndex),
      'startOffset': serializer.toJson<double>(startOffset),
      'duration': serializer.toJson<double>(duration),
      'localPath': serializer.toJson<String?>(localPath),
      'status': serializer.toJson<String>(status),
    };
  }

  DownloadedTrack copyWith({
    int? id,
    String? itemId,
    int? trackIndex,
    double? startOffset,
    double? duration,
    Value<String?> localPath = const Value.absent(),
    String? status,
  }) => DownloadedTrack(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    trackIndex: trackIndex ?? this.trackIndex,
    startOffset: startOffset ?? this.startOffset,
    duration: duration ?? this.duration,
    localPath: localPath.present ? localPath.value : this.localPath,
    status: status ?? this.status,
  );
  DownloadedTrack copyWithCompanion(DownloadedTracksCompanion data) {
    return DownloadedTrack(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      trackIndex: data.trackIndex.present
          ? data.trackIndex.value
          : this.trackIndex,
      startOffset: data.startOffset.present
          ? data.startOffset.value
          : this.startOffset,
      duration: data.duration.present ? data.duration.value : this.duration,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedTrack(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('trackIndex: $trackIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('duration: $duration, ')
          ..write('localPath: $localPath, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    itemId,
    trackIndex,
    startOffset,
    duration,
    localPath,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadedTrack &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.trackIndex == this.trackIndex &&
          other.startOffset == this.startOffset &&
          other.duration == this.duration &&
          other.localPath == this.localPath &&
          other.status == this.status);
}

class DownloadedTracksCompanion extends UpdateCompanion<DownloadedTrack> {
  final Value<int> id;
  final Value<String> itemId;
  final Value<int> trackIndex;
  final Value<double> startOffset;
  final Value<double> duration;
  final Value<String?> localPath;
  final Value<String> status;
  const DownloadedTracksCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.trackIndex = const Value.absent(),
    this.startOffset = const Value.absent(),
    this.duration = const Value.absent(),
    this.localPath = const Value.absent(),
    this.status = const Value.absent(),
  });
  DownloadedTracksCompanion.insert({
    this.id = const Value.absent(),
    required String itemId,
    required int trackIndex,
    required double startOffset,
    required double duration,
    this.localPath = const Value.absent(),
    this.status = const Value.absent(),
  }) : itemId = Value(itemId),
       trackIndex = Value(trackIndex),
       startOffset = Value(startOffset),
       duration = Value(duration);
  static Insertable<DownloadedTrack> custom({
    Expression<int>? id,
    Expression<String>? itemId,
    Expression<int>? trackIndex,
    Expression<double>? startOffset,
    Expression<double>? duration,
    Expression<String>? localPath,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (trackIndex != null) 'track_index': trackIndex,
      if (startOffset != null) 'start_offset': startOffset,
      if (duration != null) 'duration': duration,
      if (localPath != null) 'local_path': localPath,
      if (status != null) 'status': status,
    });
  }

  DownloadedTracksCompanion copyWith({
    Value<int>? id,
    Value<String>? itemId,
    Value<int>? trackIndex,
    Value<double>? startOffset,
    Value<double>? duration,
    Value<String?>? localPath,
    Value<String>? status,
  }) {
    return DownloadedTracksCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      trackIndex: trackIndex ?? this.trackIndex,
      startOffset: startOffset ?? this.startOffset,
      duration: duration ?? this.duration,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (trackIndex.present) {
      map['track_index'] = Variable<int>(trackIndex.value);
    }
    if (startOffset.present) {
      map['start_offset'] = Variable<double>(startOffset.value);
    }
    if (duration.present) {
      map['duration'] = Variable<double>(duration.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadedTracksCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('trackIndex: $trackIndex, ')
          ..write('startOffset: $startOffset, ')
          ..write('duration: $duration, ')
          ..write('localPath: $localPath, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $LogEntriesTable extends LogEntries
    with TableInfo<$LogEntriesTable, LogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<String> level = GeneratedColumn<String>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageMeta = const VerificationMeta(
    'message',
  );
  @override
  late final GeneratedColumn<String> message = GeneratedColumn<String>(
    'message',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, timestamp, level, tag, message];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'log_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('message')) {
      context.handle(
        _messageMeta,
        message.isAcceptableOrUnknown(data['message']!, _messageMeta),
      );
    } else if (isInserting) {
      context.missing(_messageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}level'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      message: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message'],
      )!,
    );
  }

  @override
  $LogEntriesTable createAlias(String alias) {
    return $LogEntriesTable(attachedDatabase, alias);
  }
}

class LogEntry extends DataClass implements Insertable<LogEntry> {
  final int id;
  final DateTime timestamp;
  final String level;
  final String tag;
  final String message;
  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['level'] = Variable<String>(level);
    map['tag'] = Variable<String>(tag);
    map['message'] = Variable<String>(message);
    return map;
  }

  LogEntriesCompanion toCompanion(bool nullToAbsent) {
    return LogEntriesCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      level: Value(level),
      tag: Value(tag),
      message: Value(message),
    );
  }

  factory LogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LogEntry(
      id: serializer.fromJson<int>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      level: serializer.fromJson<String>(json['level']),
      tag: serializer.fromJson<String>(json['tag']),
      message: serializer.fromJson<String>(json['message']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'level': serializer.toJson<String>(level),
      'tag': serializer.toJson<String>(tag),
      'message': serializer.toJson<String>(message),
    };
  }

  LogEntry copyWith({
    int? id,
    DateTime? timestamp,
    String? level,
    String? tag,
    String? message,
  }) => LogEntry(
    id: id ?? this.id,
    timestamp: timestamp ?? this.timestamp,
    level: level ?? this.level,
    tag: tag ?? this.tag,
    message: message ?? this.message,
  );
  LogEntry copyWithCompanion(LogEntriesCompanion data) {
    return LogEntry(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      level: data.level.present ? data.level.value : this.level,
      tag: data.tag.present ? data.tag.value : this.tag,
      message: data.message.present ? data.message.value : this.message,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LogEntry(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('level: $level, ')
          ..write('tag: $tag, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timestamp, level, tag, message);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LogEntry &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.level == this.level &&
          other.tag == this.tag &&
          other.message == this.message);
}

class LogEntriesCompanion extends UpdateCompanion<LogEntry> {
  final Value<int> id;
  final Value<DateTime> timestamp;
  final Value<String> level;
  final Value<String> tag;
  final Value<String> message;
  const LogEntriesCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.level = const Value.absent(),
    this.tag = const Value.absent(),
    this.message = const Value.absent(),
  });
  LogEntriesCompanion.insert({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    required String level,
    required String tag,
    required String message,
  }) : level = Value(level),
       tag = Value(tag),
       message = Value(message);
  static Insertable<LogEntry> custom({
    Expression<int>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? level,
    Expression<String>? tag,
    Expression<String>? message,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (level != null) 'level': level,
      if (tag != null) 'tag': tag,
      if (message != null) 'message': message,
    });
  }

  LogEntriesCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? timestamp,
    Value<String>? level,
    Value<String>? tag,
    Value<String>? message,
  }) {
    return LogEntriesCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      level: level ?? this.level,
      tag: tag ?? this.tag,
      message: message ?? this.message,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (level.present) {
      map['level'] = Variable<String>(level.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (message.present) {
      map['message'] = Variable<String>(message.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('level: $level, ')
          ..write('tag: $tag, ')
          ..write('message: $message')
          ..write(')'))
        .toString();
  }
}

class $PendingProgressSyncsTable extends PendingProgressSyncs
    with TableInfo<$PendingProgressSyncsTable, PendingProgressSync> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingProgressSyncsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _syncKeyMeta = const VerificationMeta(
    'syncKey',
  );
  @override
  late final GeneratedColumn<String> syncKey = GeneratedColumn<String>(
    'sync_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryItemIdMeta = const VerificationMeta(
    'libraryItemId',
  );
  @override
  late final GeneratedColumn<String> libraryItemId = GeneratedColumn<String>(
    'library_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _episodeIdMeta = const VerificationMeta(
    'episodeId',
  );
  @override
  late final GeneratedColumn<String> episodeId = GeneratedColumn<String>(
    'episode_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentTimeMeta = const VerificationMeta(
    'currentTime',
  );
  @override
  late final GeneratedColumn<double> currentTime = GeneratedColumn<double>(
    'current_time',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMeta = const VerificationMeta(
    'duration',
  );
  @override
  late final GeneratedColumn<double> duration = GeneratedColumn<double>(
    'duration',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFinishedMeta = const VerificationMeta(
    'isFinished',
  );
  @override
  late final GeneratedColumn<bool> isFinished = GeneratedColumn<bool>(
    'is_finished',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_finished" IN (0, 1))',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    syncKey,
    libraryItemId,
    episodeId,
    currentTime,
    duration,
    isFinished,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_progress_syncs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingProgressSync> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sync_key')) {
      context.handle(
        _syncKeyMeta,
        syncKey.isAcceptableOrUnknown(data['sync_key']!, _syncKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_syncKeyMeta);
    }
    if (data.containsKey('library_item_id')) {
      context.handle(
        _libraryItemIdMeta,
        libraryItemId.isAcceptableOrUnknown(
          data['library_item_id']!,
          _libraryItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_libraryItemIdMeta);
    }
    if (data.containsKey('episode_id')) {
      context.handle(
        _episodeIdMeta,
        episodeId.isAcceptableOrUnknown(data['episode_id']!, _episodeIdMeta),
      );
    }
    if (data.containsKey('current_time')) {
      context.handle(
        _currentTimeMeta,
        currentTime.isAcceptableOrUnknown(
          data['current_time']!,
          _currentTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentTimeMeta);
    }
    if (data.containsKey('duration')) {
      context.handle(
        _durationMeta,
        duration.isAcceptableOrUnknown(data['duration']!, _durationMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMeta);
    }
    if (data.containsKey('is_finished')) {
      context.handle(
        _isFinishedMeta,
        isFinished.isAcceptableOrUnknown(data['is_finished']!, _isFinishedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {syncKey};
  @override
  PendingProgressSync map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingProgressSync(
      syncKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_key'],
      )!,
      libraryItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_item_id'],
      )!,
      episodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}episode_id'],
      ),
      currentTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_time'],
      )!,
      duration: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration'],
      )!,
      isFinished: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_finished'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PendingProgressSyncsTable createAlias(String alias) {
    return $PendingProgressSyncsTable(attachedDatabase, alias);
  }
}

class PendingProgressSync extends DataClass
    implements Insertable<PendingProgressSync> {
  final String syncKey;
  final String libraryItemId;
  final String? episodeId;
  final double currentTime;
  final double duration;
  final bool? isFinished;
  final DateTime updatedAt;
  const PendingProgressSync({
    required this.syncKey,
    required this.libraryItemId,
    this.episodeId,
    required this.currentTime,
    required this.duration,
    this.isFinished,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sync_key'] = Variable<String>(syncKey);
    map['library_item_id'] = Variable<String>(libraryItemId);
    if (!nullToAbsent || episodeId != null) {
      map['episode_id'] = Variable<String>(episodeId);
    }
    map['current_time'] = Variable<double>(currentTime);
    map['duration'] = Variable<double>(duration);
    if (!nullToAbsent || isFinished != null) {
      map['is_finished'] = Variable<bool>(isFinished);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PendingProgressSyncsCompanion toCompanion(bool nullToAbsent) {
    return PendingProgressSyncsCompanion(
      syncKey: Value(syncKey),
      libraryItemId: Value(libraryItemId),
      episodeId: episodeId == null && nullToAbsent
          ? const Value.absent()
          : Value(episodeId),
      currentTime: Value(currentTime),
      duration: Value(duration),
      isFinished: isFinished == null && nullToAbsent
          ? const Value.absent()
          : Value(isFinished),
      updatedAt: Value(updatedAt),
    );
  }

  factory PendingProgressSync.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingProgressSync(
      syncKey: serializer.fromJson<String>(json['syncKey']),
      libraryItemId: serializer.fromJson<String>(json['libraryItemId']),
      episodeId: serializer.fromJson<String?>(json['episodeId']),
      currentTime: serializer.fromJson<double>(json['currentTime']),
      duration: serializer.fromJson<double>(json['duration']),
      isFinished: serializer.fromJson<bool?>(json['isFinished']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'syncKey': serializer.toJson<String>(syncKey),
      'libraryItemId': serializer.toJson<String>(libraryItemId),
      'episodeId': serializer.toJson<String?>(episodeId),
      'currentTime': serializer.toJson<double>(currentTime),
      'duration': serializer.toJson<double>(duration),
      'isFinished': serializer.toJson<bool?>(isFinished),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PendingProgressSync copyWith({
    String? syncKey,
    String? libraryItemId,
    Value<String?> episodeId = const Value.absent(),
    double? currentTime,
    double? duration,
    Value<bool?> isFinished = const Value.absent(),
    DateTime? updatedAt,
  }) => PendingProgressSync(
    syncKey: syncKey ?? this.syncKey,
    libraryItemId: libraryItemId ?? this.libraryItemId,
    episodeId: episodeId.present ? episodeId.value : this.episodeId,
    currentTime: currentTime ?? this.currentTime,
    duration: duration ?? this.duration,
    isFinished: isFinished.present ? isFinished.value : this.isFinished,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PendingProgressSync copyWithCompanion(PendingProgressSyncsCompanion data) {
    return PendingProgressSync(
      syncKey: data.syncKey.present ? data.syncKey.value : this.syncKey,
      libraryItemId: data.libraryItemId.present
          ? data.libraryItemId.value
          : this.libraryItemId,
      episodeId: data.episodeId.present ? data.episodeId.value : this.episodeId,
      currentTime: data.currentTime.present
          ? data.currentTime.value
          : this.currentTime,
      duration: data.duration.present ? data.duration.value : this.duration,
      isFinished: data.isFinished.present
          ? data.isFinished.value
          : this.isFinished,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingProgressSync(')
          ..write('syncKey: $syncKey, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('episodeId: $episodeId, ')
          ..write('currentTime: $currentTime, ')
          ..write('duration: $duration, ')
          ..write('isFinished: $isFinished, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    syncKey,
    libraryItemId,
    episodeId,
    currentTime,
    duration,
    isFinished,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingProgressSync &&
          other.syncKey == this.syncKey &&
          other.libraryItemId == this.libraryItemId &&
          other.episodeId == this.episodeId &&
          other.currentTime == this.currentTime &&
          other.duration == this.duration &&
          other.isFinished == this.isFinished &&
          other.updatedAt == this.updatedAt);
}

class PendingProgressSyncsCompanion
    extends UpdateCompanion<PendingProgressSync> {
  final Value<String> syncKey;
  final Value<String> libraryItemId;
  final Value<String?> episodeId;
  final Value<double> currentTime;
  final Value<double> duration;
  final Value<bool?> isFinished;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PendingProgressSyncsCompanion({
    this.syncKey = const Value.absent(),
    this.libraryItemId = const Value.absent(),
    this.episodeId = const Value.absent(),
    this.currentTime = const Value.absent(),
    this.duration = const Value.absent(),
    this.isFinished = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingProgressSyncsCompanion.insert({
    required String syncKey,
    required String libraryItemId,
    this.episodeId = const Value.absent(),
    required double currentTime,
    required double duration,
    this.isFinished = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : syncKey = Value(syncKey),
       libraryItemId = Value(libraryItemId),
       currentTime = Value(currentTime),
       duration = Value(duration);
  static Insertable<PendingProgressSync> custom({
    Expression<String>? syncKey,
    Expression<String>? libraryItemId,
    Expression<String>? episodeId,
    Expression<double>? currentTime,
    Expression<double>? duration,
    Expression<bool>? isFinished,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (syncKey != null) 'sync_key': syncKey,
      if (libraryItemId != null) 'library_item_id': libraryItemId,
      if (episodeId != null) 'episode_id': episodeId,
      if (currentTime != null) 'current_time': currentTime,
      if (duration != null) 'duration': duration,
      if (isFinished != null) 'is_finished': isFinished,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingProgressSyncsCompanion copyWith({
    Value<String>? syncKey,
    Value<String>? libraryItemId,
    Value<String?>? episodeId,
    Value<double>? currentTime,
    Value<double>? duration,
    Value<bool?>? isFinished,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PendingProgressSyncsCompanion(
      syncKey: syncKey ?? this.syncKey,
      libraryItemId: libraryItemId ?? this.libraryItemId,
      episodeId: episodeId ?? this.episodeId,
      currentTime: currentTime ?? this.currentTime,
      duration: duration ?? this.duration,
      isFinished: isFinished ?? this.isFinished,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (syncKey.present) {
      map['sync_key'] = Variable<String>(syncKey.value);
    }
    if (libraryItemId.present) {
      map['library_item_id'] = Variable<String>(libraryItemId.value);
    }
    if (episodeId.present) {
      map['episode_id'] = Variable<String>(episodeId.value);
    }
    if (currentTime.present) {
      map['current_time'] = Variable<double>(currentTime.value);
    }
    if (duration.present) {
      map['duration'] = Variable<double>(duration.value);
    }
    if (isFinished.present) {
      map['is_finished'] = Variable<bool>(isFinished.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingProgressSyncsCompanion(')
          ..write('syncKey: $syncKey, ')
          ..write('libraryItemId: $libraryItemId, ')
          ..write('episodeId: $episodeId, ')
          ..write('currentTime: $currentTime, ')
          ..write('duration: $duration, ')
          ..write('isFinished: $isFinished, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMediaItemsTable extends LocalMediaItems
    with TableInfo<$LocalMediaItemsTable, LocalMediaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressCurrentTimeMeta =
      const VerificationMeta('progressCurrentTime');
  @override
  late final GeneratedColumn<double> progressCurrentTime =
      GeneratedColumn<double>(
        'progress_current_time',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    localPath,
    durationSeconds,
    progressCurrentTime,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_media_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMediaItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('progress_current_time')) {
      context.handle(
        _progressCurrentTimeMeta,
        progressCurrentTime.isAcceptableOrUnknown(
          data['progress_current_time']!,
          _progressCurrentTimeMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMediaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMediaItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_seconds'],
      ),
      progressCurrentTime: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress_current_time'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $LocalMediaItemsTable createAlias(String alias) {
    return $LocalMediaItemsTable(attachedDatabase, alias);
  }
}

class LocalMediaItem extends DataClass implements Insertable<LocalMediaItem> {
  final String id;
  final String title;
  final String localPath;
  final double? durationSeconds;
  final double? progressCurrentTime;
  final DateTime addedAt;
  const LocalMediaItem({
    required this.id,
    required this.title,
    required this.localPath,
    this.durationSeconds,
    this.progressCurrentTime,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['local_path'] = Variable<String>(localPath);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<double>(durationSeconds);
    }
    if (!nullToAbsent || progressCurrentTime != null) {
      map['progress_current_time'] = Variable<double>(progressCurrentTime);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  LocalMediaItemsCompanion toCompanion(bool nullToAbsent) {
    return LocalMediaItemsCompanion(
      id: Value(id),
      title: Value(title),
      localPath: Value(localPath),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      progressCurrentTime: progressCurrentTime == null && nullToAbsent
          ? const Value.absent()
          : Value(progressCurrentTime),
      addedAt: Value(addedAt),
    );
  }

  factory LocalMediaItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMediaItem(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      localPath: serializer.fromJson<String>(json['localPath']),
      durationSeconds: serializer.fromJson<double?>(json['durationSeconds']),
      progressCurrentTime: serializer.fromJson<double?>(
        json['progressCurrentTime'],
      ),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'localPath': serializer.toJson<String>(localPath),
      'durationSeconds': serializer.toJson<double?>(durationSeconds),
      'progressCurrentTime': serializer.toJson<double?>(progressCurrentTime),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  LocalMediaItem copyWith({
    String? id,
    String? title,
    String? localPath,
    Value<double?> durationSeconds = const Value.absent(),
    Value<double?> progressCurrentTime = const Value.absent(),
    DateTime? addedAt,
  }) => LocalMediaItem(
    id: id ?? this.id,
    title: title ?? this.title,
    localPath: localPath ?? this.localPath,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    progressCurrentTime: progressCurrentTime.present
        ? progressCurrentTime.value
        : this.progressCurrentTime,
    addedAt: addedAt ?? this.addedAt,
  );
  LocalMediaItem copyWithCompanion(LocalMediaItemsCompanion data) {
    return LocalMediaItem(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      progressCurrentTime: data.progressCurrentTime.present
          ? data.progressCurrentTime.value
          : this.progressCurrentTime,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMediaItem(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('localPath: $localPath, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('progressCurrentTime: $progressCurrentTime, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    localPath,
    durationSeconds,
    progressCurrentTime,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMediaItem &&
          other.id == this.id &&
          other.title == this.title &&
          other.localPath == this.localPath &&
          other.durationSeconds == this.durationSeconds &&
          other.progressCurrentTime == this.progressCurrentTime &&
          other.addedAt == this.addedAt);
}

class LocalMediaItemsCompanion extends UpdateCompanion<LocalMediaItem> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> localPath;
  final Value<double?> durationSeconds;
  final Value<double?> progressCurrentTime;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const LocalMediaItemsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.localPath = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.progressCurrentTime = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMediaItemsCompanion.insert({
    required String id,
    required String title,
    required String localPath,
    this.durationSeconds = const Value.absent(),
    this.progressCurrentTime = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       localPath = Value(localPath);
  static Insertable<LocalMediaItem> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? localPath,
    Expression<double>? durationSeconds,
    Expression<double>? progressCurrentTime,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (localPath != null) 'local_path': localPath,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (progressCurrentTime != null)
        'progress_current_time': progressCurrentTime,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMediaItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? localPath,
    Value<double?>? durationSeconds,
    Value<double?>? progressCurrentTime,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return LocalMediaItemsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      localPath: localPath ?? this.localPath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      progressCurrentTime: progressCurrentTime ?? this.progressCurrentTime,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (progressCurrentTime.present) {
      map['progress_current_time'] = Variable<double>(
        progressCurrentTime.value,
      );
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMediaItemsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('localPath: $localPath, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('progressCurrentTime: $progressCurrentTime, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $KeyValueEntriesTable keyValueEntries = $KeyValueEntriesTable(
    this,
  );
  late final $DownloadedItemsTable downloadedItems = $DownloadedItemsTable(
    this,
  );
  late final $DownloadedTracksTable downloadedTracks = $DownloadedTracksTable(
    this,
  );
  late final $LogEntriesTable logEntries = $LogEntriesTable(this);
  late final $PendingProgressSyncsTable pendingProgressSyncs =
      $PendingProgressSyncsTable(this);
  late final $LocalMediaItemsTable localMediaItems = $LocalMediaItemsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    keyValueEntries,
    downloadedItems,
    downloadedTracks,
    logEntries,
    pendingProgressSyncs,
    localMediaItems,
  ];
}

typedef $$KeyValueEntriesTableCreateCompanionBuilder =
    KeyValueEntriesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$KeyValueEntriesTableUpdateCompanionBuilder =
    KeyValueEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$KeyValueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $KeyValueEntriesTable> {
  $$KeyValueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KeyValueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $KeyValueEntriesTable> {
  $$KeyValueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KeyValueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KeyValueEntriesTable> {
  $$KeyValueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValueEntriesTable,
          KeyValueEntry,
          $$KeyValueEntriesTableFilterComposer,
          $$KeyValueEntriesTableOrderingComposer,
          $$KeyValueEntriesTableAnnotationComposer,
          $$KeyValueEntriesTableCreateCompanionBuilder,
          $$KeyValueEntriesTableUpdateCompanionBuilder,
          (
            KeyValueEntry,
            BaseReferences<_$AppDatabase, $KeyValueEntriesTable, KeyValueEntry>,
          ),
          KeyValueEntry,
          PrefetchHooks Function()
        > {
  $$KeyValueEntriesTableTableManager(
    _$AppDatabase db,
    $KeyValueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KeyValueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KeyValueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KeyValueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyValueEntriesCompanion(
                key: key,
                value: value,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => KeyValueEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValueEntriesTable,
      KeyValueEntry,
      $$KeyValueEntriesTableFilterComposer,
      $$KeyValueEntriesTableOrderingComposer,
      $$KeyValueEntriesTableAnnotationComposer,
      $$KeyValueEntriesTableCreateCompanionBuilder,
      $$KeyValueEntriesTableUpdateCompanionBuilder,
      (
        KeyValueEntry,
        BaseReferences<_$AppDatabase, $KeyValueEntriesTable, KeyValueEntry>,
      ),
      KeyValueEntry,
      PrefetchHooks Function()
    >;
typedef $$DownloadedItemsTableCreateCompanionBuilder =
    DownloadedItemsCompanion Function({
      required String itemId,
      required String serverUrl,
      required String title,
      Value<String> authorNames,
      Value<double?> totalDuration,
      Value<String?> chaptersJson,
      Value<String?> coverLocalPath,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<double?> progressCurrentTime,
      Value<bool> progressIsFinished,
      Value<int> rowid,
    });
typedef $$DownloadedItemsTableUpdateCompanionBuilder =
    DownloadedItemsCompanion Function({
      Value<String> itemId,
      Value<String> serverUrl,
      Value<String> title,
      Value<String> authorNames,
      Value<double?> totalDuration,
      Value<String?> chaptersJson,
      Value<String?> coverLocalPath,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<double?> progressCurrentTime,
      Value<bool> progressIsFinished,
      Value<int> rowid,
    });

final class $$DownloadedItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $DownloadedItemsTable, DownloadedItem> {
  $$DownloadedItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DownloadedTracksTable, List<DownloadedTrack>>
  _downloadedTracksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloadedTracks,
    aliasName: 'downloaded_items__item_id__downloaded_tracks__item_id',
  );

  $$DownloadedTracksTableProcessedTableManager get downloadedTracksRefs {
    final manager =
        $$DownloadedTracksTableTableManager($_db, $_db.downloadedTracks).filter(
          (f) => f.itemId.itemId.sqlEquals($_itemColumn<String>('item_id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _downloadedTracksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DownloadedItemsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadedItemsTable> {
  $$DownloadedItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverUrl => $composableBuilder(
    column: $table.serverUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get authorNames => $composableBuilder(
    column: $table.authorNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progressCurrentTime => $composableBuilder(
    column: $table.progressCurrentTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get progressIsFinished => $composableBuilder(
    column: $table.progressIsFinished,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> downloadedTracksRefs(
    Expression<bool> Function($$DownloadedTracksTableFilterComposer f) f,
  ) {
    final $$DownloadedTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.downloadedTracks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadedTracksTableFilterComposer(
            $db: $db,
            $table: $db.downloadedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadedItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadedItemsTable> {
  $$DownloadedItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverUrl => $composableBuilder(
    column: $table.serverUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get authorNames => $composableBuilder(
    column: $table.authorNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressCurrentTime => $composableBuilder(
    column: $table.progressCurrentTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get progressIsFinished => $composableBuilder(
    column: $table.progressIsFinished,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadedItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadedItemsTable> {
  $$DownloadedItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get serverUrl =>
      $composableBuilder(column: $table.serverUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get authorNames => $composableBuilder(
    column: $table.authorNames,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalDuration => $composableBuilder(
    column: $table.totalDuration,
    builder: (column) => column,
  );

  GeneratedColumn<String> get chaptersJson => $composableBuilder(
    column: $table.chaptersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverLocalPath => $composableBuilder(
    column: $table.coverLocalPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<double> get progressCurrentTime => $composableBuilder(
    column: $table.progressCurrentTime,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get progressIsFinished => $composableBuilder(
    column: $table.progressIsFinished,
    builder: (column) => column,
  );

  Expression<T> downloadedTracksRefs<T extends Object>(
    Expression<T> Function($$DownloadedTracksTableAnnotationComposer a) f,
  ) {
    final $$DownloadedTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.downloadedTracks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadedTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadedTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadedItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadedItemsTable,
          DownloadedItem,
          $$DownloadedItemsTableFilterComposer,
          $$DownloadedItemsTableOrderingComposer,
          $$DownloadedItemsTableAnnotationComposer,
          $$DownloadedItemsTableCreateCompanionBuilder,
          $$DownloadedItemsTableUpdateCompanionBuilder,
          (DownloadedItem, $$DownloadedItemsTableReferences),
          DownloadedItem,
          PrefetchHooks Function({bool downloadedTracksRefs})
        > {
  $$DownloadedItemsTableTableManager(
    _$AppDatabase db,
    $DownloadedItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadedItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadedItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadedItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<String> serverUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> authorNames = const Value.absent(),
                Value<double?> totalDuration = const Value.absent(),
                Value<String?> chaptersJson = const Value.absent(),
                Value<String?> coverLocalPath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<double?> progressCurrentTime = const Value.absent(),
                Value<bool> progressIsFinished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadedItemsCompanion(
                itemId: itemId,
                serverUrl: serverUrl,
                title: title,
                authorNames: authorNames,
                totalDuration: totalDuration,
                chaptersJson: chaptersJson,
                coverLocalPath: coverLocalPath,
                status: status,
                createdAt: createdAt,
                progressCurrentTime: progressCurrentTime,
                progressIsFinished: progressIsFinished,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                required String serverUrl,
                required String title,
                Value<String> authorNames = const Value.absent(),
                Value<double?> totalDuration = const Value.absent(),
                Value<String?> chaptersJson = const Value.absent(),
                Value<String?> coverLocalPath = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<double?> progressCurrentTime = const Value.absent(),
                Value<bool> progressIsFinished = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadedItemsCompanion.insert(
                itemId: itemId,
                serverUrl: serverUrl,
                title: title,
                authorNames: authorNames,
                totalDuration: totalDuration,
                chaptersJson: chaptersJson,
                coverLocalPath: coverLocalPath,
                status: status,
                createdAt: createdAt,
                progressCurrentTime: progressCurrentTime,
                progressIsFinished: progressIsFinished,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadedItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({downloadedTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (downloadedTracksRefs) db.downloadedTracks,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (downloadedTracksRefs)
                    await $_getPrefetchedData<
                      DownloadedItem,
                      $DownloadedItemsTable,
                      DownloadedTrack
                    >(
                      currentTable: table,
                      referencedTable: $$DownloadedItemsTableReferences
                          ._downloadedTracksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DownloadedItemsTableReferences(
                            db,
                            table,
                            p0,
                          ).downloadedTracksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.itemId == item.itemId),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DownloadedItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadedItemsTable,
      DownloadedItem,
      $$DownloadedItemsTableFilterComposer,
      $$DownloadedItemsTableOrderingComposer,
      $$DownloadedItemsTableAnnotationComposer,
      $$DownloadedItemsTableCreateCompanionBuilder,
      $$DownloadedItemsTableUpdateCompanionBuilder,
      (DownloadedItem, $$DownloadedItemsTableReferences),
      DownloadedItem,
      PrefetchHooks Function({bool downloadedTracksRefs})
    >;
typedef $$DownloadedTracksTableCreateCompanionBuilder =
    DownloadedTracksCompanion Function({
      Value<int> id,
      required String itemId,
      required int trackIndex,
      required double startOffset,
      required double duration,
      Value<String?> localPath,
      Value<String> status,
    });
typedef $$DownloadedTracksTableUpdateCompanionBuilder =
    DownloadedTracksCompanion Function({
      Value<int> id,
      Value<String> itemId,
      Value<int> trackIndex,
      Value<double> startOffset,
      Value<double> duration,
      Value<String?> localPath,
      Value<String> status,
    });

final class $$DownloadedTracksTableReferences
    extends
        BaseReferences<_$AppDatabase, $DownloadedTracksTable, DownloadedTrack> {
  $$DownloadedTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DownloadedItemsTable _itemIdTable(_$AppDatabase db) => db
      .downloadedItems
      .createAlias('downloaded_tracks__item_id__downloaded_items__item_id');

  $$DownloadedItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$DownloadedItemsTableTableManager(
      $_db,
      $_db.downloadedItems,
    ).filter((f) => f.itemId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadedTracksTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadedTracksTable> {
  $$DownloadedTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackIndex => $composableBuilder(
    column: $table.trackIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$DownloadedItemsTableFilterComposer get itemId {
    final $$DownloadedItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.downloadedItems,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadedItemsTableFilterComposer(
            $db: $db,
            $table: $db.downloadedItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadedTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadedTracksTable> {
  $$DownloadedTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackIndex => $composableBuilder(
    column: $table.trackIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$DownloadedItemsTableOrderingComposer get itemId {
    final $$DownloadedItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.downloadedItems,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadedItemsTableOrderingComposer(
            $db: $db,
            $table: $db.downloadedItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadedTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadedTracksTable> {
  $$DownloadedTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get trackIndex => $composableBuilder(
    column: $table.trackIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get startOffset => $composableBuilder(
    column: $table.startOffset,
    builder: (column) => column,
  );

  GeneratedColumn<double> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$DownloadedItemsTableAnnotationComposer get itemId {
    final $$DownloadedItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.downloadedItems,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadedItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadedItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadedTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadedTracksTable,
          DownloadedTrack,
          $$DownloadedTracksTableFilterComposer,
          $$DownloadedTracksTableOrderingComposer,
          $$DownloadedTracksTableAnnotationComposer,
          $$DownloadedTracksTableCreateCompanionBuilder,
          $$DownloadedTracksTableUpdateCompanionBuilder,
          (DownloadedTrack, $$DownloadedTracksTableReferences),
          DownloadedTrack,
          PrefetchHooks Function({bool itemId})
        > {
  $$DownloadedTracksTableTableManager(
    _$AppDatabase db,
    $DownloadedTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadedTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadedTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadedTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> trackIndex = const Value.absent(),
                Value<double> startOffset = const Value.absent(),
                Value<double> duration = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => DownloadedTracksCompanion(
                id: id,
                itemId: itemId,
                trackIndex: trackIndex,
                startOffset: startOffset,
                duration: duration,
                localPath: localPath,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String itemId,
                required int trackIndex,
                required double startOffset,
                required double duration,
                Value<String?> localPath = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => DownloadedTracksCompanion.insert(
                id: id,
                itemId: itemId,
                trackIndex: trackIndex,
                startOffset: startOffset,
                duration: duration,
                localPath: localPath,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadedTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$DownloadedTracksTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$DownloadedTracksTableReferences
                                        ._itemIdTable(db)
                                        .itemId,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DownloadedTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadedTracksTable,
      DownloadedTrack,
      $$DownloadedTracksTableFilterComposer,
      $$DownloadedTracksTableOrderingComposer,
      $$DownloadedTracksTableAnnotationComposer,
      $$DownloadedTracksTableCreateCompanionBuilder,
      $$DownloadedTracksTableUpdateCompanionBuilder,
      (DownloadedTrack, $$DownloadedTracksTableReferences),
      DownloadedTrack,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$LogEntriesTableCreateCompanionBuilder =
    LogEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      required String level,
      required String tag,
      required String message,
    });
typedef $$LogEntriesTableUpdateCompanionBuilder =
    LogEntriesCompanion Function({
      Value<int> id,
      Value<DateTime> timestamp,
      Value<String> level,
      Value<String> tag,
      Value<String> message,
    });

class $$LogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get message => $composableBuilder(
    column: $table.message,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LogEntriesTable> {
  $$LogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get message =>
      $composableBuilder(column: $table.message, builder: (column) => column);
}

class $$LogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LogEntriesTable,
          LogEntry,
          $$LogEntriesTableFilterComposer,
          $$LogEntriesTableOrderingComposer,
          $$LogEntriesTableAnnotationComposer,
          $$LogEntriesTableCreateCompanionBuilder,
          $$LogEntriesTableUpdateCompanionBuilder,
          (LogEntry, BaseReferences<_$AppDatabase, $LogEntriesTable, LogEntry>),
          LogEntry,
          PrefetchHooks Function()
        > {
  $$LogEntriesTableTableManager(_$AppDatabase db, $LogEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LogEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LogEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LogEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<String> level = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String> message = const Value.absent(),
              }) => LogEntriesCompanion(
                id: id,
                timestamp: timestamp,
                level: level,
                tag: tag,
                message: message,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                required String level,
                required String tag,
                required String message,
              }) => LogEntriesCompanion.insert(
                id: id,
                timestamp: timestamp,
                level: level,
                tag: tag,
                message: message,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LogEntriesTable,
      LogEntry,
      $$LogEntriesTableFilterComposer,
      $$LogEntriesTableOrderingComposer,
      $$LogEntriesTableAnnotationComposer,
      $$LogEntriesTableCreateCompanionBuilder,
      $$LogEntriesTableUpdateCompanionBuilder,
      (LogEntry, BaseReferences<_$AppDatabase, $LogEntriesTable, LogEntry>),
      LogEntry,
      PrefetchHooks Function()
    >;
typedef $$PendingProgressSyncsTableCreateCompanionBuilder =
    PendingProgressSyncsCompanion Function({
      required String syncKey,
      required String libraryItemId,
      Value<String?> episodeId,
      required double currentTime,
      required double duration,
      Value<bool?> isFinished,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PendingProgressSyncsTableUpdateCompanionBuilder =
    PendingProgressSyncsCompanion Function({
      Value<String> syncKey,
      Value<String> libraryItemId,
      Value<String?> episodeId,
      Value<double> currentTime,
      Value<double> duration,
      Value<bool?> isFinished,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PendingProgressSyncsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingProgressSyncsTable> {
  $$PendingProgressSyncsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get syncKey => $composableBuilder(
    column: $table.syncKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentTime => $composableBuilder(
    column: $table.currentTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingProgressSyncsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingProgressSyncsTable> {
  $$PendingProgressSyncsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get syncKey => $composableBuilder(
    column: $table.syncKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get episodeId => $composableBuilder(
    column: $table.episodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentTime => $composableBuilder(
    column: $table.currentTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get duration => $composableBuilder(
    column: $table.duration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingProgressSyncsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingProgressSyncsTable> {
  $$PendingProgressSyncsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get syncKey =>
      $composableBuilder(column: $table.syncKey, builder: (column) => column);

  GeneratedColumn<String> get libraryItemId => $composableBuilder(
    column: $table.libraryItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get episodeId =>
      $composableBuilder(column: $table.episodeId, builder: (column) => column);

  GeneratedColumn<double> get currentTime => $composableBuilder(
    column: $table.currentTime,
    builder: (column) => column,
  );

  GeneratedColumn<double> get duration =>
      $composableBuilder(column: $table.duration, builder: (column) => column);

  GeneratedColumn<bool> get isFinished => $composableBuilder(
    column: $table.isFinished,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PendingProgressSyncsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingProgressSyncsTable,
          PendingProgressSync,
          $$PendingProgressSyncsTableFilterComposer,
          $$PendingProgressSyncsTableOrderingComposer,
          $$PendingProgressSyncsTableAnnotationComposer,
          $$PendingProgressSyncsTableCreateCompanionBuilder,
          $$PendingProgressSyncsTableUpdateCompanionBuilder,
          (
            PendingProgressSync,
            BaseReferences<
              _$AppDatabase,
              $PendingProgressSyncsTable,
              PendingProgressSync
            >,
          ),
          PendingProgressSync,
          PrefetchHooks Function()
        > {
  $$PendingProgressSyncsTableTableManager(
    _$AppDatabase db,
    $PendingProgressSyncsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingProgressSyncsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingProgressSyncsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingProgressSyncsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> syncKey = const Value.absent(),
                Value<String> libraryItemId = const Value.absent(),
                Value<String?> episodeId = const Value.absent(),
                Value<double> currentTime = const Value.absent(),
                Value<double> duration = const Value.absent(),
                Value<bool?> isFinished = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingProgressSyncsCompanion(
                syncKey: syncKey,
                libraryItemId: libraryItemId,
                episodeId: episodeId,
                currentTime: currentTime,
                duration: duration,
                isFinished: isFinished,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String syncKey,
                required String libraryItemId,
                Value<String?> episodeId = const Value.absent(),
                required double currentTime,
                required double duration,
                Value<bool?> isFinished = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingProgressSyncsCompanion.insert(
                syncKey: syncKey,
                libraryItemId: libraryItemId,
                episodeId: episodeId,
                currentTime: currentTime,
                duration: duration,
                isFinished: isFinished,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingProgressSyncsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingProgressSyncsTable,
      PendingProgressSync,
      $$PendingProgressSyncsTableFilterComposer,
      $$PendingProgressSyncsTableOrderingComposer,
      $$PendingProgressSyncsTableAnnotationComposer,
      $$PendingProgressSyncsTableCreateCompanionBuilder,
      $$PendingProgressSyncsTableUpdateCompanionBuilder,
      (
        PendingProgressSync,
        BaseReferences<
          _$AppDatabase,
          $PendingProgressSyncsTable,
          PendingProgressSync
        >,
      ),
      PendingProgressSync,
      PrefetchHooks Function()
    >;
typedef $$LocalMediaItemsTableCreateCompanionBuilder =
    LocalMediaItemsCompanion Function({
      required String id,
      required String title,
      required String localPath,
      Value<double?> durationSeconds,
      Value<double?> progressCurrentTime,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });
typedef $$LocalMediaItemsTableUpdateCompanionBuilder =
    LocalMediaItemsCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> localPath,
      Value<double?> durationSeconds,
      Value<double?> progressCurrentTime,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$LocalMediaItemsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMediaItemsTable> {
  $$LocalMediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progressCurrentTime => $composableBuilder(
    column: $table.progressCurrentTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMediaItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMediaItemsTable> {
  $$LocalMediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progressCurrentTime => $composableBuilder(
    column: $table.progressCurrentTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMediaItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMediaItemsTable> {
  $$LocalMediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get progressCurrentTime => $composableBuilder(
    column: $table.progressCurrentTime,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$LocalMediaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMediaItemsTable,
          LocalMediaItem,
          $$LocalMediaItemsTableFilterComposer,
          $$LocalMediaItemsTableOrderingComposer,
          $$LocalMediaItemsTableAnnotationComposer,
          $$LocalMediaItemsTableCreateCompanionBuilder,
          $$LocalMediaItemsTableUpdateCompanionBuilder,
          (
            LocalMediaItem,
            BaseReferences<
              _$AppDatabase,
              $LocalMediaItemsTable,
              LocalMediaItem
            >,
          ),
          LocalMediaItem,
          PrefetchHooks Function()
        > {
  $$LocalMediaItemsTableTableManager(
    _$AppDatabase db,
    $LocalMediaItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<double?> durationSeconds = const Value.absent(),
                Value<double?> progressCurrentTime = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMediaItemsCompanion(
                id: id,
                title: title,
                localPath: localPath,
                durationSeconds: durationSeconds,
                progressCurrentTime: progressCurrentTime,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String localPath,
                Value<double?> durationSeconds = const Value.absent(),
                Value<double?> progressCurrentTime = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMediaItemsCompanion.insert(
                id: id,
                title: title,
                localPath: localPath,
                durationSeconds: durationSeconds,
                progressCurrentTime: progressCurrentTime,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMediaItemsTable,
      LocalMediaItem,
      $$LocalMediaItemsTableFilterComposer,
      $$LocalMediaItemsTableOrderingComposer,
      $$LocalMediaItemsTableAnnotationComposer,
      $$LocalMediaItemsTableCreateCompanionBuilder,
      $$LocalMediaItemsTableUpdateCompanionBuilder,
      (
        LocalMediaItem,
        BaseReferences<_$AppDatabase, $LocalMediaItemsTable, LocalMediaItem>,
      ),
      LocalMediaItem,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$KeyValueEntriesTableTableManager get keyValueEntries =>
      $$KeyValueEntriesTableTableManager(_db, _db.keyValueEntries);
  $$DownloadedItemsTableTableManager get downloadedItems =>
      $$DownloadedItemsTableTableManager(_db, _db.downloadedItems);
  $$DownloadedTracksTableTableManager get downloadedTracks =>
      $$DownloadedTracksTableTableManager(_db, _db.downloadedTracks);
  $$LogEntriesTableTableManager get logEntries =>
      $$LogEntriesTableTableManager(_db, _db.logEntries);
  $$PendingProgressSyncsTableTableManager get pendingProgressSyncs =>
      $$PendingProgressSyncsTableTableManager(_db, _db.pendingProgressSyncs);
  $$LocalMediaItemsTableTableManager get localMediaItems =>
      $$LocalMediaItemsTableTableManager(_db, _db.localMediaItems);
}
