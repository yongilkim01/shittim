"""Dock preferences for the existing GIO catalogue. Never executes configuration."""
import json
import os
from pathlib import Path
import tempfile


def paths():
    return (Path(__file__).resolve().parents[1] / 'config/dock.json',
            Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config') / 'shittim/dock.json')


def read_settings():
    default, personal = paths()
    source = personal if personal.exists() else default
    try:
        if source.stat().st_size > 65536:
            raise ValueError()
        data = json.loads(source.read_text(encoding='utf-8'))
        favorites = data['favorites']
        mapping = data.get('windowClasses', {})
        if (not isinstance(favorites, list) or len(favorites) > 64 or
                not all(isinstance(item, str) and item.endswith('.desktop') and
                        len(item) <= 256 and '/' not in item and '\\' not in item and
                        not any(ord(c) < 32 for c in item) for item in favorites) or
                not isinstance(mapping, dict)):
            raise ValueError()
        classes = {}
        for app_id, values in mapping.items():
            if (not isinstance(app_id,str) or not app_id.endswith('.desktop') or len(app_id)>256 or '/' in app_id or '\\' in app_id or any(ord(c)<32 for c in app_id) or not isinstance(values, list) or len(values) > 16):
                raise ValueError()
            if not all(isinstance(value, str) and 0 < len(value) <= 256 and
                       not any(ord(c) < 32 for c in value) for value in values):
                raise ValueError()
            classes[app_id] = list(dict.fromkeys(values))
        return {'event': 'dock', 'favorites': list(dict.fromkeys(favorites)), 'windowClasses': classes, 'error': ''}
    except (OSError, ValueError, TypeError, KeyError):
        return {'event': 'dock', 'favorites': [], 'windowClasses': {}, 'error': 'DockConfigInvalid'}


def update_settings(action, app_id, catalogue, index=None):
    current = read_settings()
    if current['error'] or not isinstance(app_id,str) or app_id not in catalogue or not app_id.endswith('.desktop') or len(app_id)>256 or '/' in app_id or '\\' in app_id or any(ord(c)<32 for c in app_id):
        raise ValueError('DockConfigInvalid')
    favorites = current['favorites'][:]
    if action == 'pin':
        if app_id not in favorites:
            if len(favorites) >= 64: raise ValueError('DockLimit')
            favorites.append(app_id)
    elif action == 'unpin':
        favorites = [item for item in favorites if item != app_id]
    elif action == 'reorder':
        if app_id not in favorites or not isinstance(index, int): raise ValueError('InvalidRequest')
        favorites.remove(app_id); favorites.insert(max(0, min(index, len(favorites))), app_id)
    else: raise ValueError('InvalidRequest')
    # Keep class mappings for running applications after they are unpinned.
    source = paths()[1] if paths()[1].exists() else paths()[0]
    data = json.loads(source.read_text(encoding='utf-8'))
    data['favorites'] = favorites
    destination = paths()[1]
    encoded=json.dumps(data,ensure_ascii=False,indent=2)+'\n'
    if len(encoded.encode('utf-8'))>65536: raise ValueError('DockLimit')
    if not destination.is_absolute() or destination.resolve().is_relative_to(Path(__file__).resolve().parents[1]): raise ValueError('StateMustBeOutsideRepository')
    destination.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=destination.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(encoded); stream.flush(); os.fsync(stream.fileno())
            temporary.chmod(0o600); os.replace(temporary, destination)
        finally:
            temporary.unlink(missing_ok=True)
    return read_settings()
