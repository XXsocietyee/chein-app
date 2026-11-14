"""RM-02 OWN-25.1 and OWN-READ-全队共享提示-跳过-计时-团队总分 contract tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Rm02TeamSharedPoolContractTests(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text()

    def test_team_pool_supports_hints_skip_timer_and_total_score_sync(self):
        core = self.read("Core/TeamPool.swift")
        for marker in (
            'api/team/pool/hint',
            'api/team/pool/skip',
            'api/team/pool/timer/start',
            'func requestHint()',
            'func requestSkip()',
            'func startTimer()',
            'remainingTimerSeconds',
            'TEAM_FIRST_SOLVE_NODES',
            'onPoolUpdated',
        ):
            self.assertIn(marker, core)

        section = self.read("App/TeamPoolHintSection.swift")
        for marker in (
            'teamPool.useHint',
            'teamPool.useSkip',
            'teamPool.skip.confirm',
            'teamPool.timerStart',
            'teamPool.timerRemaining',
            'TeamPoolRunStatusSection',
            'teamPool.run.section',
            'teamPool.run.score',
            'TimelineView',
        ):
            self.assertIn(marker, section)

        play = self.read("App/PlayExperienceView.swift")
        self.assertIn("TeamPoolRunStatusSection", play)
        self.assertIn("teamPool?.skipResult", play)

    def test_coop_help_shared_endpoint_preserved(self):
        backpack = self.read("Core/PlayTeamBackpack.swift")
        self.assertIn("PlayCoopHelpFlow", backpack)
        self.assertIn("api/play/help/shared", self.read("App/PlayTeamBackpackView.swift"))


if __name__ == "__main__":
    unittest.main()
