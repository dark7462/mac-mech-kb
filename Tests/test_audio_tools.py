import hashlib
import json
import math
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Scripts"))
from prepare_recorded_sounds import bass_shelf, encode_wave, prepare
from verify_sounds import verify


class AudioPreparationTests(unittest.TestCase):
    def test_bass_boost_preserves_high_frequencies(self):
        # Measure steady-state response with tones, independently of coefficients.
        for frequency, expected_db in ((50, 5), (300, 2.5), (3000, 0)):
            tone = [math.sin(2 * math.pi * frequency * i / 48000) for i in range(24000)]
            boosted = bass_shelf(tone)
            gain_db = 10 * math.log10(sum(x * x for x in boosted[4800:]) / sum(x * x for x in tone[4800:]))
            self.assertAlmostEqual(gain_db, expected_db, delta=0.05)

    def test_invalid_excerpts_are_rejected(self):
        for raw in ([], [1], [0] * 4800):
            with self.assertRaises(ValueError):
                prepare(raw)

    def test_nonfinite_and_clipped_outputs_are_rejected(self):
        for values in ([], [float("nan")], [float("inf")], [1.1], [-1.1]):
            with self.assertRaises(ValueError):
                encode_wave(values)


class AudioVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        shutil.copytree(ROOT / "AudioSources", self.root / "AudioSources", ignore=shutil.ignore_patterns("*.html"))
        shutil.copytree(ROOT / "Sources/MechanicalKeyboard/Resources/Sounds",
                        self.root / "Sources/MechanicalKeyboard/Resources/Sounds")
        self.sample = self.root / "Sources/MechanicalKeyboard/Resources/Sounds/Blue/normal-01.wav"
        self.report = self.root / "AudioSources/processing-report.json"

    def test_changed_audio_is_rejected(self):
        self.sample.write_bytes(b"not a wave")
        with self.assertRaisesRegex(ValueError, "Changed audio"):
            verify(self.root)

    def test_truncated_pcm_cannot_pass_with_updated_hash(self):
        self.sample.write_bytes(self.sample.read_bytes()[:-100])
        report = json.loads(self.report.read_text())
        report["samples"][0]["sha256"] = hashlib.sha256(self.sample.read_bytes()).hexdigest()
        self.report.write_text(json.dumps(report))
        with self.assertRaisesRegex(ValueError, "Truncated PCM"):
            verify(self.root)

    def test_manifest_cannot_redefine_an_incomplete_pack_as_complete(self):
        path = self.root / "AudioSources/manifest.json"
        manifest = json.loads(path.read_text())
        del manifest["presets"]["Blue"]["cuts"]["normal-06"]
        path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "Incomplete preset"):
            verify(self.root)

    def test_duplicate_report_entries_are_rejected(self):
        report = json.loads(self.report.read_text())
        report["samples"].append(report["samples"][0])
        self.report.write_text(json.dumps(report))
        with self.assertRaisesRegex(ValueError, "duplicate sample report"):
            verify(self.root)

    def test_stale_extra_audio_in_app_is_rejected(self):
        app = self.root / "Stale.app"
        resources = app / "Contents/Resources"
        resources.mkdir(parents=True)
        shutil.copytree(self.root / "Sources/MechanicalKeyboard/Resources/Sounds", resources / "Sounds")
        shutil.copyfile(self.sample, resources / "unexpected.wav")
        with self.assertRaisesRegex(ValueError, "exactly 27 WAVs"):
            verify(self.root, bundle=app)


if __name__ == "__main__":
    unittest.main()
