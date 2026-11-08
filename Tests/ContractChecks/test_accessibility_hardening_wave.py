"""Static guards for the accessibility and hardening wave (FP-A1..A6, FP-M5..M7, FP-M12, FP-X1)."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def src(path):
    return (ROOT / path).read_text()


class FPA1IconOnlyButtons(unittest.TestCase):
    def test_h5_close_is_labelled_and_44pt(self):
        s = src('App/H5PlatformShellView.swift')
        self.assertIn('Label("action.close", systemImage: "xmark").labelStyle(.iconOnly)', s)
        self.assertIn('minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget', s)
        self.assertNotIn('Button(action: onClose) { Image(systemName: "xmark") }', s)

    def test_story_rule_move_up_is_labelled_and_44pt(self):
        s = src('App/StoryRuleEditorView.swift')
        self.assertIn('Label(ChannelCopy.text("上移", "Move up", locale: locale), systemImage: "arrow.up")', s)
        self.assertIn('.labelStyle(.iconOnly)', s)
        self.assertIn('minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget', s)
        self.assertNotIn('Image(systemName: "arrow.up")', s)


class FPA2HomeSearchAndPublish(unittest.TestCase):
    def test_publish_button_uses_tokens_and_44pt(self):
        s = src('App/HomeSearchTabParityViews.swift')
        body = s[s.index('struct PublishTabFloatingButton'):s.index('struct PublishTabFloatingSheetView')]
        self.assertIn('.foregroundStyle(CYColor.textOnAccent)', body)
        self.assertNotIn('.foregroundStyle(.white)', body)
        self.assertIn('.frame(minHeight: CYSpacing.minTouchTarget)', body)
        self.assertNotIn('.padding(.vertical, 10)', body)

    def test_search_entry_has_search_trait_and_wraps(self):
        s = src('App/HomeSearchTabParityViews.swift')
        entry = s[s.index('GlobalSearchParityPresentation.placeholderCopy'):s.index('"homeIndex.hero.searchEntry"')]
        self.assertIn('.lineLimit(2)', entry)
        self.assertNotIn('.lineLimit(1)', entry)
        self.assertIn('.accessibilityAddTraits(.isSearchField)', entry)


class FPA3ClubChannelMessaging(unittest.TestCase):
    def test_reduce_motion_gates_animations(self):
        s = src('App/ClubChannelMessagingView.swift')
        self.assertIn('@Environment(\\.accessibilityReduceMotion) private var reduceMotion', s)
        self.assertNotIn('withAnimation(.easeInOut', s)
        self.assertNotIn('withAnimation(.easeOut', s)
        self.assertEqual(s.count('withAnimation(reduceMotion ? nil :'), 2)

    def test_jump_pill_uses_tokens(self):
        s = src('App/ClubChannelMessagingView.swift')
        pill = s[s.index('showNewMessageJumpBanner {'):s.index('channelComposerBar: some View')]
        self.assertIn('CYColor.accent', pill)
        self.assertIn('CYColor.textOnAccent', pill)
        self.assertNotIn('Color.accentColor', pill)
        self.assertNotIn('.foregroundStyle(.white)', pill)

    def test_channel_names_not_cut_to_one_line(self):
        s = src('App/ClubChannelMessagingView.swift')
        top = s[s.index('private var channelTopBar'):s.index('Image(systemName: "bell.slash.fill")')]
        self.assertNotIn('.lineLimit(1)', top)
        self.assertIn('.fixedSize(horizontal: false, vertical: true)', top)


class FPA4ActivityDetail(unittest.TestCase):
    def test_map_is_static_and_has_value(self):
        s = src('App/ActivityDetailView.swift')
        self.assertIn('interactionModes:[]', s)
        self.assertIn('.accessibilityValue(Text(verbatim:ActivityLocationAccessibility.value(', s)

    def test_sheets_have_detent_and_indicator_and_labelled_close(self):
        s = src('App/ActivityDetailView.swift')
        self.assertGreaterEqual(s.count('.presentationDragIndicator(.visible)'), 2)
        self.assertIn('Button("action.close"', src('App/RegistrationSheetView.swift'))
        self.assertIn('Button("action.close", action: onClose)', src('App/TicketWalletView.swift'))


class FPA5WalletAndGrowth(unittest.TestCase):
    def test_no_fixed_system_size_fonts(self):
        for path in ('App/WalletCommerceViews.swift', 'App/GrowthCenterView.swift'):
            self.assertNotIn('.system(size:', src(path), path)
        self.assertIn('CYTypography.data2XL', src('App/GrowthCenterView.swift'))

    def test_wallet_posts_announcement_when_loaded(self):
        s = src('App/WalletCommerceViews.swift')
        self.assertEqual(s.count('AccessibilityNotification.Announcement(WalletLoadAnnouncement.text(locale: locale)).post()'), 2)


class FPA6SeriesDateRemoval(unittest.TestCase):
    def test_remove_requires_confirmation_and_row_label(self):
        s = src('App/ClubSeriesScheduleEditor.swift')
        self.assertNotIn('Button(role: .destructive) { schedule.removeDate(id: item.id) }', s)
        self.assertIn('pendingRemoval = item', s)
        self.assertIn('.confirmationDialog(', s)
        self.assertIn('ClubSeriesScheduleRemovalCopy.rowLabel(position: index + 1', s)
        self.assertEqual(s.count('schedule.removeDate(id:'), 1)


class FPM5Pasteboard(unittest.TestCase):
    def test_no_plain_pasteboard_string_assignment_in_app(self):
        offenders = []
        for path in (ROOT / 'App').rglob('*.swift'):
            if 'UIPasteboard.general.string' in path.read_text():
                offenders.append(path.name)
        self.assertEqual(offenders, [])

    def test_helper_is_local_only_with_expiry(self):
        s = src('App/LocalPasteboard.swift')
        self.assertIn('.localOnly: true', s)
        self.assertIn('.expirationDate:', s)

    def test_listed_sites_use_helper(self):
        for path in ('App/NativeCopyTextButton.swift', 'App/NativePlatformAdapters.swift',
                     'App/SettingsSupportSections.swift', 'App/SettingsAboutView.swift'):
            self.assertIn('LocalPasteboard.copy(', src(path), path)


class FPM6NoForcedOperations(unittest.TestCase):
    def test_listed_production_sites_have_no_force_try_or_cast(self):
        for path in ('Core/ChannelDiscordMessaging.swift', 'Core/SearchRoutePreview.swift', 'Core/InvoiceLaunchService.swift',
                     'App/ReformWorldHostWorkbenchView.swift', 'Core/OrientSessionRecovery.swift'):
            s = src(path)
            self.assertNotIn('try!', s, path)
            self.assertNotIn(' as! ', s, path)
        self.assertNotIn('sessionID!', src('Core/OrientSessionRecovery.swift'))
        self.assertNotIn('instance!', src('Core/OrientSessionRecovery.swift'))


def _is_debug_wrapped(text):
    lines = text.split('\n')
    i = 0
    while i < len(lines):
        t = lines[i].strip()
        if t == '' or t.startswith('import ') or t.startswith('//'):
            i += 1
        elif t.startswith('#if canImport'):
            while not lines[i].strip().startswith('#endif'):
                i += 1
            i += 1
        else:
            break
    return i < len(lines) and lines[i].strip() == '#if DEBUG' and text.rstrip().endswith('#endif')


class FPM7FixturesAreDebugOnly(unittest.TestCase):
    def test_files_with_synthetic_token_are_debug_only(self):
        offenders = []
        for folder in ('App', 'Core'):
            for path in (ROOT / folder).glob('*.swift'):
                text = path.read_text()
                if 'synthetic-token' in text and not _is_debug_wrapped(text):
                    offenders.append(path.name)
        self.assertEqual(offenders, [])

    def test_named_fixture_files_are_debug_only(self):
        offenders = []
        for folder in ('App', 'Core'):
            for path in sorted((ROOT / folder).glob('*Fixture*.swift')):
                if path.name.endswith('FixtureView.swift') or 'Audit' in path.name or 'SectionView' in path.name:
                    continue
                if not _is_debug_wrapped(path.read_text()):
                    offenders.append(path.name)
        self.assertEqual(offenders, [])

    def test_roam_fixture_reader_is_debug_only_and_clock_is_not(self):
        s = src('Core/RoamPassportTools.swift')
        self.assertLess(s.index('public enum RoamPassportToolsOfflineClock'), s.index('#if DEBUG'))
        self.assertGreater(s.index('RoamPassportToolsFixtureReader'), s.index('#if DEBUG'))
        self.assertNotIn('RoamPassportToolsFixtureReader', src('Core/RoamMonthlyRecapCoordinator.swift'))


class FPX1NoReleasePrint(unittest.TestCase):
    @staticmethod
    def _lint():
        import importlib.util
        spec = importlib.util.spec_from_file_location('lint_no_release_print', ROOT / 'tools/lint_no_release_print.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_repository_has_no_release_print(self):
        import subprocess
        import sys
        result = subprocess.run([sys.executable, str(ROOT / 'tools/lint_no_release_print.py')], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_lint_flags_release_print_and_allows_debug(self):
        lint = self._lint()
        self.assertEqual([n for n, _ in lint.findings_for('func f() {\n    print("x")\n}')], [2])
        self.assertEqual(lint.findings_for('#if DEBUG\nprint("x")\n#endif'), [])
        self.assertEqual([n for n, _ in lint.findings_for('#if DEBUG\nlet a = 1\n#else\nprint("x")\n#endif')], [4])
        self.assertEqual(lint.findings_for('// print("x")\nlet s = "print(1)"\nlet blueprint = 1\nobj.print(2)'), [])
        self.assertEqual([n for n, _ in lint.findings_for('#if os(iOS)\nNSLog("x")\n#endif')], [2])
        self.assertEqual(lint.findings_for('#if DEBUG\n#if os(iOS)\nprint("x")\n#endif\n#endif'), [])


if __name__ == '__main__':
    unittest.main()
