import 'package:flutter/foundation.dart';
import 'importers/five_tools_importer_service.dart';
import 'logging_service.dart';
import 'minion_session_service.dart';
import 'persistence/app_backup_service.dart';
import 'persistence/campaign_profile_service.dart';
import 'persistence/debounced_storage_service.dart';
import 'persistence/dm_backup_service.dart';
import 'persistence/dpr_persistence_service.dart';
import 'persistence/homebrew_persistence_service.dart';
import 'persistence/storage_migration_service.dart';
import 'preset_service.dart';

/// Centralized application service locator and dependency injection container.
///
/// Provides decoupled access to core singletons and persistence services,
/// supporting dependency overrides and clean state resets for isolated testing.
class AppServices {
  static AppServices _instance = AppServices._();

  static AppServices get instance => _instance;

  // Internal service instances
  final LoggingService _logger;
  final DebouncedStorageService _debouncedStorage;
  final StorageMigrationService _migrationService;
  final AppBackupService _backupService;
  final DprPersistenceService _dprPersistence;
  final PresetService _presetService;
  final MinionSessionService _minionSession;
  final CampaignProfileService _campaignProfileService;
  final DmBackupService _dmBackupService;
  final HomebrewPersistenceService _homebrewPersistence;
  final FiveToolsImporterService _fiveToolsImporter;

  AppServices._({
    LoggingService? logger,
    DebouncedStorageService? debouncedStorage,
    StorageMigrationService? migrationService,
    AppBackupService? backupService,
    DprPersistenceService? dprPersistence,
    PresetService? presetService,
    MinionSessionService? minionSession,
    CampaignProfileService? campaignProfileService,
    DmBackupService? dmBackupService,
    HomebrewPersistenceService? homebrewPersistence,
    FiveToolsImporterService? fiveToolsImporter,
  })  : _logger = logger ?? LoggingService(),
        _debouncedStorage = debouncedStorage ?? DebouncedStorageService(),
        _migrationService = migrationService ?? StorageMigrationService(),
        _backupService = backupService ?? AppBackupService(),
        _dprPersistence = dprPersistence ?? DprPersistenceService(),
        _presetService = presetService ?? PresetService(),
        _minionSession = minionSession ?? MinionSessionService(),
        _campaignProfileService = campaignProfileService ?? CampaignProfileService(),
        _dmBackupService = dmBackupService ?? DmBackupService(),
        _homebrewPersistence = homebrewPersistence ?? HomebrewPersistenceService(),
        _fiveToolsImporter = fiveToolsImporter ?? FiveToolsImporterService();

  /// Core logging and crash reporting service
  LoggingService get logger => _logger;

  /// Debounced asynchronous persistence coordinator
  DebouncedStorageService get debouncedStorage => _debouncedStorage;

  /// Storage schema migration engine
  StorageMigrationService get migrationService => _migrationService;

  /// Full application backup and restore coordinator
  AppBackupService get backupService => _backupService;

  /// DPR custom builds and active draft persistence service
  DprPersistenceService get dprPersistence => _dprPersistence;

  /// Custom dice preset persistence service
  PresetService get presetService => _presetService;

  /// Minion session state coordinator
  MinionSessionService get minionSession => _minionSession;

  /// Campaign profile persistence service
  CampaignProfileService get campaignProfileService => _campaignProfileService;

  /// DM snapshot import/export service
  DmBackupService get dmBackupService => _dmBackupService;

  /// Homebrew and custom compendium persistence service
  HomebrewPersistenceService get homebrewPersistence => _homebrewPersistence;

  /// 5eTools community compendium ingestion service
  FiveToolsImporterService get fiveToolsImporter => _fiveToolsImporter;

  /// Registers service overrides for unit or widget testing.
  @visibleForTesting
  static void registerOverrides({
    LoggingService? logger,
    DebouncedStorageService? debouncedStorage,
    StorageMigrationService? migrationService,
    AppBackupService? backupService,
    DprPersistenceService? dprPersistence,
    PresetService? presetService,
    MinionSessionService? minionSession,
    CampaignProfileService? campaignProfileService,
    DmBackupService? dmBackupService,
    HomebrewPersistenceService? homebrewPersistence,
    FiveToolsImporterService? fiveToolsImporter,
  }) {
    _instance = AppServices._(
      logger: logger ?? _instance._logger,
      debouncedStorage: debouncedStorage ?? _instance._debouncedStorage,
      migrationService: migrationService ?? _instance._migrationService,
      backupService: backupService ?? _instance._backupService,
      dprPersistence: dprPersistence ?? _instance._dprPersistence,
      presetService: presetService ?? _instance._presetService,
      minionSession: minionSession ?? _instance._minionSession,
      campaignProfileService: campaignProfileService ?? _instance._campaignProfileService,
      dmBackupService: dmBackupService ?? _instance._dmBackupService,
      homebrewPersistence: homebrewPersistence ?? _instance._homebrewPersistence,
      fiveToolsImporter: fiveToolsImporter ?? _instance._fiveToolsImporter,
    );
  }

  /// Resets the service container to fresh default instances.
  @visibleForTesting
  static void reset() {
    // ignore: invalid_use_of_visible_for_testing_member
    _instance.debouncedStorage.cancelAllForTesting();
    _instance.presetService.clearCacheForTesting();
    _instance.minionSession.clearCacheForTesting();
    _instance.campaignProfileService.clearCacheForTesting();
    _instance = AppServices._();
  }
}
