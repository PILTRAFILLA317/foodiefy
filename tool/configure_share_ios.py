"""Write only public development signing identifiers to an ignored xcconfig."""
import argparse
import re
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--bundle-id', required=True)
parser.add_argument('--team-id', required=True)
parser.add_argument('--app-group', required=True)
args = parser.parse_args()
if not re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+', args.bundle_id) or not re.fullmatch(r'[A-Z0-9]{10}', args.team_id) or not re.fullmatch(r'group\.[A-Za-z0-9.-]+', args.app_group):
    parser.error('Use actual registered bundle ID, 10-character Team ID and group.* App Group.')
path = Path(__file__).resolve().parents[1] / 'ios/Shared/Share.local.xcconfig'
path.write_text(f'FOODIEFY_APP_BUNDLE_ID = {args.bundle_id}\nFOODIEFY_TEAM_ID = {args.team_id}\nFOODIEFY_APP_GROUP = {args.app_group}\n')
print('Public development signing configuration written. Enable the same registered App Group in both targets; no provisioning performed.')
