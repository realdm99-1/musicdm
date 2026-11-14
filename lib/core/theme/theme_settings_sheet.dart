import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'el_theme.dart';
import 'theme_provider.dart';

class ThemeSettingsSheet extends ConsumerWidget {
  const ThemeSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => const ThemeSettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final el = context.el;
    final settings = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '테마 및 포인트 컬러',
                style: TextStyle(
                  color: el.textColorPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: el.textColorRegular),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '화면 모드',
            style: TextStyle(
              color: el.textColorRegular,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('라이트'),
                icon: Icon(Icons.light_mode_outlined, size: 18),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('다크'),
                icon: Icon(Icons.dark_mode_outlined, size: 18),
              ),
            ],
            selected: {
              settings.themeMode == ThemeMode.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
            },
            onSelectionChanged: (selection) {
              controller.setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 20),
          Text(
            '포인트 컬러',
            style: TextStyle(
              color: el.textColorRegular,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: ElThemeTokens.accentPresets.map((preset) {
              final isSelected =
                  settings.accentColor.toARGB32() == preset.color.toARGB32();
              return Tooltip(
                message: preset.name,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => controller.setAccentColor(preset.color),
                  child: Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? preset.color : el.borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: preset.color,
                        shape: BoxShape.circle,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
