#!/usr/bin/env python
"""APK 빌드 버전 카운터 — 빌드 전에 실행하면 그날 빌드 번호를 +1 하고
bible_app/lib/constants/build_info.dart 의 kBuildVersion 을 갱신한다.

형식: (YYYYMMDD.vN)
카운터는 이 파일 옆의 apk_build_counter.txt 에 {'date': ..., 'count': ...} 로 저장.
"""
import datetime
import io
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
COUNTER = os.path.join(ROOT, 'apk_build_counter.txt')
BUILD_INFO = os.path.join(
    ROOT, 'bible_app', 'lib', 'constants', 'build_info.dart')

today = datetime.datetime.now().strftime('%Y%m%d')

state = {'date': today, 'count': 0}
if os.path.exists(COUNTER):
    try:
        state = json.loads(io.open(COUNTER, encoding='utf-8').read())
    except Exception:
        pass
if state.get('date') != today:
    state = {'date': today, 'count': 0}
state['count'] = int(state.get('count', 0)) + 1
io.open(COUNTER, 'w', encoding='utf-8', newline='\n').write(json.dumps(state))

label = '(%s.v%d)' % (today, state['count'])
src = io.open(BUILD_INFO, encoding='utf-8').read()
import re
src = re.sub(r"const String kBuildVersion = '[^']*';",
             "const String kBuildVersion = '%s';" % label, src)
io.open(BUILD_INFO, 'w', encoding='utf-8', newline='\n').write(src)
print('kBuildVersion =', label)
