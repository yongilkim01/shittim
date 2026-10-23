"""Dock preferences for the existing GIO catalogue. Never executes configuration."""
import json
import os
from pathlib import Path


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
            if app_id not in favorites or not isinstance(values, list) or len(values) > 16:
                raise ValueError()
            if not all(isinstance(value, str) and 0 < len(value) <= 256 and
                       not any(ord(c) < 32 for c in value) for value in values):
                raise ValueError()
            classes[app_id] = list(dict.fromkeys(values))
        return {'event': 'dock', 'favorites': list(dict.fromkeys(favorites)), 'windowClasses': classes, 'error': ''}
    except (OSError, ValueError, TypeError, KeyError):
        return {'event': 'dock', 'favorites': [], 'windowClasses': {}, 'error': 'DockConfigInvalid'}
