"""Pull the JSON part dump out of a saved Studio tool result (the newest, or the given file) and append it to
out.json (merging chunks). usage: python3 grab.py out.json [--new] [file]"""
import sys, json, glob, os
out = sys.argv[1]
new = "--new" in sys.argv
files = [a for a in sys.argv[2:] if not a.startswith("--")]
f = files[0] if files else max(glob.glob("/root/.claude/projects/-home-claude/*/tool-results/*.txt"), key=os.path.getmtime)
t = open(f).read().strip()
dec = json.JSONDecoder()
try:
    obj, _ = dec.raw_decode(t)
except Exception:
    j = json.loads(t)
    obj, _ = dec.raw_decode(j if isinstance(j, str) else j.get("result", ""))
if isinstance(obj, str): obj, _ = dec.raw_decode(obj)
parts = obj["parts"]
if not new and os.path.exists(out):
    parts = json.load(open(out))["parts"] + parts
json.dump({"parts": parts}, open(out, "w"))
print(len(obj["parts"]), "parts added,", len(parts), "total in", out)
