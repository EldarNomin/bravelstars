"""Export the checked-in Godot balance/maps to Unity without changing their values."""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'unity/Assets/Resources/Data'


def defaults(relative):
    values = {}
    for line in (ROOT / relative).read_text(encoding='utf-8').splitlines():
        if not line.startswith('@export'):
            continue
        match = re.search(r'\bvar\s+(\w+)\s*:\s*[\w.]+\s*=\s*(.+)', line)
        if not match:
            continue
        value = match[2].removeprefix('&')
        values[match[1]] = 0 if value == 'Kind.STRAIGHT' else json.loads(value)
    return values


def sections(path):
    result, current = {}, None
    for line in path.read_text(encoding='utf-8').splitlines():
        if line.startswith('['):
            current = 'resource' if line == '[resource]' else None
            match = re.match(r'\[sub_resource .*id="([^"]+)"', line)
            if match:
                current = match[1]
            if current:
                result[current] = {}
        elif current and ' = ' in line:
            key, value = line.split(' = ', 1)
            if key == 'script':
                continue
            if value.startswith('SubResource('):
                result[current][key] = ('ref', re.search(r'"([^"]+)"', value)[1])
            elif value.startswith('ExtResource('):
                result[current][key] = 'dash'
            else:
                result[current][key] = json.loads(value.removeprefix('&'))
    return result


def outputs():
    files = {}
    hero_defaults = defaults('src/sim/data/brawler_data.gd')
    attack_defaults = defaults('src/sim/data/attack_data.gd')
    bot_defaults = defaults('src/ai/bot_profile.gd')
    for hero_id in ('lynx', 'anvil', 'shishka'):
        s = sections(ROOT / f'data/brawlers/{hero_id}.tres')
        hero = hero_defaults | s['resource']
        for key in ('attack', 'super_attack'):
            hero[key] = attack_defaults | s[hero[key][1]]
        hero['bot'] = bot_defaults | sections(ROOT / f'src/ai/roles/{hero_id}.tres')['resource']
        files[f'Heroes/{hero_id}.json'] = hero
    files['balance.json'] = defaults('src/sim/data/global_balance.gd') | sections(ROOT / 'data/balance/global.tres')['resource']
    for path in sorted((ROOT / 'data/maps').glob('*.json')):
        data = json.loads(path.read_text(encoding='utf-8'))
        data['development'] = path.name.startswith('_')
        files[f'Maps/{path.name}'] = data
    return {name: json.dumps(data, ensure_ascii=False, indent=2) + '\n' for name, data in files.items()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    files = outputs()
    for name, content in files.items():
        path = OUT / name
        if args.check:
            if not path.is_file() or path.read_text(encoding='utf-8') != content:
                raise SystemExit(f'Stale Unity data: {path}')
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding='utf-8', newline='\n')
    digest = hashlib.sha256(''.join(files.values()).encode()).hexdigest()
    print(f'{len(files)} data files match Godot sources; SHA256 {digest}')


if __name__ == '__main__':
    main()
