"""Exercise retention decisions without deleting any Docker objects."""
import importlib.util
import json
import os
import sys
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("retention", ROOT / "deploy/image_retention.py")
retention = importlib.util.module_from_spec(spec)
spec.loader.exec_module(retention)


def image(letter, **extra):
    return {"Id": letter, "RepoTags": [retention.REPOSITORY + ":sha-" + letter * 7], **extra}


def container(letter, running=True):
    return {"Image": letter, "Config": {"Image": retention.REPOSITORY + ":sha-" + letter * 7}, "State": {"Running": running}}


class RetentionTests(unittest.TestCase):
    def test_before_pull_preserves_current_rollback_target_feeds_and_containers(self):
        images = [image(c) for c in 'abcdef']
        state, remove = retention.retention_plan(images, [container('a'), container('e', False)],
            {'sha-ccccccc', 'sha-ddddddd'}, {'current': 'sha-aaaaaaa', 'rollback': 'sha-bbbbbbb'}, 'before')
        self.assertEqual(remove, [retention.REPOSITORY + ':sha-fffffff'])
        self.assertEqual(state['rollback'], 'sha-bbbbbbb')

    def test_success_tracks_rollback_and_same_release_retry_preserves_it(self):
        images = [image(c) for c in 'abc']
        state, _ = retention.retention_plan(images, [container('b')], {'sha-bbbbbbb'}, {'current': 'sha-aaaaaaa'}, 'after')
        self.assertEqual(state, {'current': 'sha-bbbbbbb', 'rollback': 'sha-aaaaaaa'})
        again, remove = retention.retention_plan(images, [container('b')], {'sha-bbbbbbb'}, state, 'after')
        self.assertEqual(again, state)
        self.assertEqual(remove, [retention.REPOSITORY + ':sha-ccccccc'])

    def test_first_run_seeds_running_release_before_pull(self):
        state, remove = retention.retention_plan([image('a'), image('b')], [container('a')], {'sha-bbbbbbb'}, {}, 'before')
        self.assertEqual(state['current'], 'sha-aaaaaaa')
        self.assertEqual(remove, [])

    def test_failed_pull_does_not_promote_requested_target(self):
        state, _ = retention.retention_plan([image('a'), image('b')], [container('a')], {'sha-bbbbbbb'}, {'current': 'sha-aaaaaaa'}, 'before')
        self.assertEqual(state['current'], 'sha-aaaaaaa')

    def test_mixed_running_releases_fail_closed(self):
        with self.assertRaises(ValueError):
            retention.retention_plan([], [container('a'), container('b')], set(), {}, 'after')

    def test_unrelated_images_tags_and_aliases_are_not_deleted(self):
        images = [image('a', RepoTags=['caddy:2.11.4-alpine']), image('b', RepoTags=['other:sha-bbbbbbb']), image('c', RepoTags=[retention.REPOSITORY + ':latest']), image('d', RepoTags=None)]
        _, remove = retention.retention_plan(images, [], set(), {}, 'before')
        self.assertEqual(remove, [])

    def test_deployment_inputs_are_data_not_shell(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / '.env').write_text('STARFALL_TAG=sha-aaaaaaa\nUNRELATED=$(touch should-not-exist)\n')
            (root / '.last-tag').write_text('sha-bbbbbbb\n')
            (root / 'downloads/linux').mkdir(parents=True)
            (root / 'downloads/linux/manifest.json').write_text(json.dumps({'server_tag': 'sha-ccccccc'}))
            self.assertEqual(retention.read_deployment_tags(root), {'sha-aaaaaaa', 'sha-bbbbbbb', 'sha-ccccccc'})
            (root / '.last-tag').write_text('../escape')
            with self.assertRaises(ValueError): retention.read_deployment_tags(root)

    def test_invalid_state_cannot_delete_images(self):
        with self.assertRaises(ValueError):
            retention.retention_plan([image('a')], [], set(), {'rollback': 'latest'}, 'before')

    @unittest.skipUnless(os.name == "posix", "Linux deploy wrapper installation")
    def test_existing_wrapper_install_is_idempotent_and_backed_up(self):
        installer = (ROOT / 'deploy/install-retention.sh').read_text().split("python3 - <<'PY'\n", 1)[1].split('\nPY\n', 1)[0]
        with tempfile.TemporaryDirectory() as temp:
            wrapper = Path(temp) / 'starfall-deploy'
            original = '#!/bin/bash\necho "--- pulling ---"\ndocker compose pull\n        docker image prune -f --filter "until=168h" >/dev/null || true\n'
            wrapper.write_text(original)
            code = installer.replace("Path('/usr/local/bin/starfall-deploy')", 'Path(' + repr(str(wrapper)) + ')')
            for _ in range(2): subprocess.run([sys.executable, '-c', code], check=True, capture_output=True)
            self.assertEqual(wrapper.read_text().count('starfall-image-retention before'), 1)
            self.assertEqual(wrapper.read_text().count('starfall-image-retention after'), 1)
            self.assertEqual(wrapper.with_name('starfall-deploy.before-retention').read_text(), original)
            wrapper.write_text('#!/bin/bash\necho custom wrapper\n')
            result = subprocess.run([sys.executable, '-c', code], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(wrapper.read_text(), '#!/bin/bash\necho custom wrapper\n')
