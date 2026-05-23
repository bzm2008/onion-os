#!/bin/bash
cd "/mnt/e/llinux os/onion-os/modules"
python3 -c "
import re
with open('03_desktop.sh', 'r') as f:
    lines = f.readlines()
heredocs = []
for i, line in enumerate(lines):
    m = re.search(r'<<\s+[\x27\"]?([A-Z][A-Z0-9_]*)[\x27\"]?', line)
    if m:
        token = m.group(1)
        for j in range(i+1, len(lines)):
            if lines[j].strip() == token and lines[j].strip() == lines[j].rstrip('\n').lstrip():
                actual = repr(lines[j].rstrip('\n'))
                stripped = repr(token)
                if actual != stripped:
                    print(f'FIX line {j+1}: {actual} -> {stripped}')
                else:
                    print(f'OK line {j+1}: {actual}')
                break
" 2>/dev/null
