#!/usr/bin/env python3
"""Disable signing on a temporary Xcode Cloud checkout. Does not run against the git checkout unless asked."""
import pathlib, sys

MARKERS = ('"buildSettings" = {', 'buildSettings = {')

def inject_build_settings(text):
    pieces = []
    cursor = 0
    while cursor < len(text):
        found = [(text.find(marker, cursor), marker) for marker in MARKERS]
        found = [(at, marker) for at, marker in found if at != -1]
        if not found:
            pieces.append(text[cursor:])
            break
        at, marker = min(found)
        pieces.append(text[cursor:at + len(marker)])
        lines = text[at + len(marker):].splitlines(keepends=True)
        block = []
        for line in lines:
            block.append(line)
            if line.strip() == '};':
                break
        else:
            raise SystemExit('Unclosed buildSettings block')
        body = ''.join(block)
        if 'CODE_SIGNING_ALLOWED' not in body:
            indent = '\t\t\t\t'
            for line in block:
                stripped = line.lstrip('\t')
                if stripped.strip() not in ('', '};'):
                    indent = line[:len(line) - len(stripped)]
                    break
            if marker.startswith('"'):
                inserted = (
                    f'\n{indent}"CODE_SIGNING_ALLOWED" = "NO";\n'
                    f'{indent}"CODE_SIGNING_REQUIRED" = "NO";'
                )
            else:
                inserted = (
                    f'\n{indent}CODE_SIGNING_ALLOWED = NO;\n'
                    f'{indent}CODE_SIGNING_REQUIRED = NO;'
                )
            pieces.append(inserted)
        pieces.append(body)
        cursor = at + len(marker) + len(body)
    return ''.join(pieces)

def append_xcconfig(path):
    text = path.read_text()
    if 'CODE_SIGNING_ALLOWED' in text:
        return
    suffix = '' if text.endswith('\n') else '\n'
    path.write_text(text + suffix + 'CODE_SIGNING_ALLOWED = NO\nCODE_SIGNING_REQUIRED = NO\n')

def disable_signing(root):
    root = pathlib.Path(root)
    for relative in (
        'Questify.xcodeproj/project.pbxproj',
        'Vendor/GLTFKit2/GLTFKit2.xcodeproj/project.pbxproj',
    ):
        path = root / relative
        path.write_text(inject_build_settings(path.read_text()))
    for relative in ('Config/Base.xcconfig', 'Config/AppUnitTests.xcconfig'):
        append_xcconfig(root / relative)

def main(argv):
    if argv != ['--checkout'] and not (len(argv) == 2 and argv[0] == '--checkout'):
        raise SystemExit('usage: python3 tools/xcode_cloud_prepare.py --checkout <temporary-ci-checkout>')
    if len(argv) != 2:
        raise SystemExit('Refusing to edit the working tree without an explicit checkout path')
    disable_signing(argv[1])
    print('CODE_SIGNING_ALLOWED=NO on the temporary checkout. No secrets.')

if __name__ == '__main__':
    main(sys.argv[1:])
