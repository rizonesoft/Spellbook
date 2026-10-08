"""Validate Codex's independent workflow files, including untracked new skills."""
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = {'add-feature', 'add-migration', 'add-todo', 'build-and-test', 'create-todo',
            'fix-bug', 'groom-plan', 'process-phase', 'process-plan', 'process-todo-file',
            'process-todo-section', 'release', 'review-todo-section', 'win32-ui-patterns'}


def check(root: Path) -> list[str]:
    errors = []
    skills = root / '.agents/skills'
    actual = {p.parent.name for p in skills.glob('*/SKILL.md')}
    if actual != EXPECTED:
        errors.append(f'skill set differs: missing={sorted(EXPECTED - actual)}, extra={sorted(actual - EXPECTED)}')
    for folder in (root / '.agents', root / '.codex'):
        for path in folder.rglob('*'):
            if path.is_symlink() or (hasattr(path, 'is_junction') and path.is_junction()):
                errors.append(f'{path.relative_to(root)}: links across workflow boundaries are forbidden')
    for path in skills.rglob('*.md'):
        text = path.read_text(encoding='utf-8')
        if re.search(r'\.claude[/\\]|Cron(Create|List|Delete)|CLAUDE_[A-Z_]+|claude-campaign', text):
            errors.append(f'{path.relative_to(root)}: Claude runtime dependency')
        if path.name == 'SKILL.md':
            match = re.match(r'---\nname: ([a-z0-9-]+)\ndescription: (.+)\n---\n', text)
            if not match or match[1] != path.parent.name or len(match[1]) > 64:
                errors.append(f'{path.relative_to(root)}: invalid skill metadata')
    if '@AGENTS.md' in (root / 'CLAUDE.md').read_text(encoding='utf-8'):
        errors.append('CLAUDE.md still imports Codex instructions')
    hooks = json.loads((root / '.codex/hooks.json').read_text(encoding='utf-8'))
    if set(hooks['hooks']) != {'Stop', 'Interrupt'}:
        errors.append('Codex lifecycle hook set differs')
    for groups in hooks['hooks'].values():
        for group in groups:
            for handler in group['hooks']:
                if '.codex/hooks/campaign.py' not in handler['command'] or '.claude' in handler['command']:
                    errors.append('Codex hook targets the wrong handler')
    for name in ('pre-commit', 'commit-msg'):
        data = (root / '.codex/githooks' / name).read_bytes()
        if not data.startswith(b'#!/bin/sh\n') or b'\r' in data:
            errors.append(f'Codex Git hook {name} must be LF with a shell shebang')
    # Agent-neutral docs checker, explicitly applied to new/untracked workflow docs too.
    spec = importlib.util.spec_from_file_location('spellbook_docs', root / 'scripts/check-docs.py')
    docs = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(docs)
    files = [*skills.rglob('*.md'), * (root / 'docs/codex-runs').glob('*.md'),
             root / 'docs/dev/codex.md', root / 'AGENTS.md', root / 'CLAUDE.md']
    errors.extend(docs.check_links(root, files))
    return errors


if __name__ == '__main__':
    findings = check(ROOT)
    for finding in findings:
        print(finding)
    print(f'codex workflow: {len(EXPECTED)} skills, {len(findings)} findings')
    sys.exit(bool(findings))
