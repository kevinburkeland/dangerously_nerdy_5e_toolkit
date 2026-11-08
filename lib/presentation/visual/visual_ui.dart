import 'package:flutter/material.dart';

import '../../models/visual/app_icon.dart';
import '../../models/visual/argb.dart';

export 'minion_stat_block_ui.dart';
export 'monster_codex_ui.dart';

extension ArgbUi on Argb {
  Color toColor() => Color(value);
}

extension AppIconUi on AppIcon {
  IconData get iconData => switch (this) {
        AppIcon.albumOutlined => Icons.album_outlined,
        AppIcon.articleOutlined => Icons.article_outlined,
        AppIcon.autoAwesome => Icons.auto_awesome,
        AppIcon.autoFixHigh => Icons.auto_fix_high,
        AppIcon.autoFixNormalOutlined => Icons.auto_fix_normal_outlined,
        AppIcon.autoStories => Icons.auto_stories,
        AppIcon.backpackOutlined => Icons.backpack_outlined,
        AppIcon.brushOutlined => Icons.brush_outlined,
        AppIcon.categoryOutlined => Icons.category_outlined,
        AppIcon.changeCircleOutlined => Icons.change_circle_outlined,
        AppIcon.coronavirusOutlined => Icons.coronavirus_outlined,
        AppIcon.darkModeOutlined => Icons.dark_mode_outlined,
        AppIcon.diamondOutlined => Icons.diamond_outlined,
        AppIcon.directionsWalk => Icons.directions_walk,
        AppIcon.ecoOutlined => Icons.eco_outlined,
        AppIcon.explore => Icons.explore,
        AppIcon.favoriteBorder => Icons.favorite_border,
        AppIcon.fitnessCenter => Icons.fitness_center,
        AppIcon.flashOn => Icons.flash_on,
        AppIcon.grid4x4 => Icons.grid_4x4,
        AppIcon.groupsOutlined => Icons.groups_outlined,
        AppIcon.healing => Icons.healing,
        AppIcon.healthAndSafetyOutlined => Icons.health_and_safety_outlined,
        AppIcon.hub => Icons.hub,
        AppIcon.localFireDepartment => Icons.local_fire_department,
        AppIcon.localFireDepartmentOutlined =>
          Icons.local_fire_department_outlined,
        AppIcon.memory => Icons.memory,
        AppIcon.menuBook => Icons.menu_book,
        AppIcon.monetizationOn => Icons.monetization_on,
        AppIcon.monetizationOnOutlined => Icons.monetization_on_outlined,
        AppIcon.musicNote => Icons.music_note,
        AppIcon.paletteOutlined => Icons.palette_outlined,
        AppIcon.park => Icons.park,
        AppIcon.pets => Icons.pets,
        AppIcon.psychologyOutlined => Icons.psychology_outlined,
        AppIcon.scienceOutlined => Icons.science_outlined,
        AppIcon.shield => Icons.shield,
        AppIcon.shieldOutlined => Icons.shield_outlined,
        AppIcon.sort => Icons.sort,
        AppIcon.sortByAlpha => Icons.sort_by_alpha,
        AppIcon.sportsKabaddi => Icons.sports_kabaddi,
        AppIcon.sportsMma => Icons.sports_mma,
        AppIcon.stadiumOutlined => Icons.stadium_outlined,
        AppIcon.starsOutlined => Icons.stars_outlined,
        AppIcon.straightenOutlined => Icons.straighten_outlined,
        AppIcon.trackChanges => Icons.track_changes,
        AppIcon.visibilityOff => Icons.visibility_off,
        AppIcon.visibilityOutlined => Icons.visibility_outlined,
        AppIcon.water => Icons.water,
        AppIcon.wbTwilight => Icons.wb_twilight,
        AppIcon.widgetsOutlined => Icons.widgets_outlined,
      };
}

