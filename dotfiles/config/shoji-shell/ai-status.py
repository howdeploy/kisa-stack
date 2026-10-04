#!/usr/bin/env python3
"""Public provider status only; no credentials or inference requests."""
import concurrent.futures
import html
import json
import re
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

SOURCES = {
    "openai": "https://status.openai.com/api/v2/summary.json",
    "claude": "https://status.claude.com/api/v2/summary.json",
    "deepseek": "https://status.deepseek.com/",
    "kimi": "https://status.moonshot.cn/api/v2/summary.json",
    "grok": "https://status.x.ai/feed.xml",
}
LEVELS = {
    "operational": 0, "none": 0, "maintenance": 1, "under_maintenance": 1,
    "minor": 2, "degraded": 2, "degraded_performance": 2,
    "major": 3, "partial_outage": 3, "critical": 4, "major_outage": 4, "full_outage": 4,
}
LABELS = ["Сбоев не объявлено", "Наблюдение / обслуживание", "Повышенное число ошибок",
          "Частичная недоступность", "Крупный сбой"]


def level(value):
    if value not in LEVELS:
        raise ValueError("Unknown status")
    return LEVELS[value]


def statuspage(data):
    severity = level(data["status"]["indicator"])
    for component in data["components"]:
        severity = max(severity, level(component["status"]))
    titles = []
    for incident in data["incidents"]:
        state = incident["status"]
        if state in ("resolved", "completed"):
            continue
        if state not in ("monitoring", "investigating", "identified"):
            raise ValueError("Unknown incident state")
        impact = 1 if state == "monitoring" else max(2, level(incident["impact"]))
        severity = max(severity, impact)
        titles.append(incident["name"])
    return severity, titles


def deepseek(document):
    # ponytail: parse the official page's embedded data until Flashduty exposes a public stable API.
    chunks = re.findall(r'self\.__next_f\.push\(\[1,("(?:[^"\\]|\\.)*")\]\)', document)
    for chunk in chunks:
        for line in json.loads(chunk).splitlines():
            try:
                node = json.loads(line.split(":", 1)[1])
            except (ValueError, IndexError):
                continue
            if not isinstance(node, list) or len(node) < 4 or not isinstance(node[3], dict):
                continue
            data = node[3].get("initialData", {})
            if not isinstance(data, dict) or "active_changes" not in data:
                continue
            if data.get("page", {}).get("name") != "DeepSeek" or not isinstance(data["active_changes"], list):
                raise ValueError("Unexpected DeepSeek page")
            severity, titles = 0, []
            for change in data["active_changes"]:
                state = change["status"]
                if state in ("resolved", "completed", "cancelled", "scheduled"):
                    continue
                if state not in ("monitoring", "investigating", "identified", "in_progress"):
                    raise ValueError("Unknown DeepSeek incident state")
                impact = 1 if state in ("monitoring", "in_progress") else 2
                for component in change.get("affected_components", []):
                    impact = max(impact, level(component["status"]))
                severity = max(severity, impact)
                titles.append(change["title"])
            return severity, titles
    raise ValueError("DeepSeek status data missing")


def grok(document):
    feed = ET.fromstring(document)
    if feed.tag == "rss" and feed.find("channel") is not None:
        entries = feed.findall("./channel/item")
    elif feed.tag == "{http://www.w3.org/2005/Atom}feed":
        entries = feed.findall("{http://www.w3.org/2005/Atom}entry")
    else:
        raise ValueError("Unexpected xAI feed")
    severity, titles = 0, []
    for entry in entries:
        fields = {child.tag.rsplit("}", 1)[-1]: "".join(child.itertext()) for child in entry}
        title = fields.get("title", "")
        text = html.unescape(re.sub(r"<[^>]+>", " ", title + " " + fields.get("description", fields.get("content", fields.get("summary", "")))))
        # Only a recognized newest update is evidence; never interpret an unparsed feed as healthy.
        state = re.search(r"\b(resolved|monitoring|investigating|identified)\b", text, re.I)
        if not state:
            raise ValueError("xAI feed has no explicit incident state")
        if state[1].lower() == "resolved":
            continue
        impact = 1 if state[1].lower() == "monitoring" else 2
        current = text[:500].lower()
        if re.search(r"major outage|full outage|complete outage", current):
            impact = max(impact, 4)
        elif re.search(r"partial outage|partially unavailable", current):
            impact = max(impact, 3)
        severity = max(severity, impact)
        titles.append(title)
    return severity, titles


def collect(provider, url):
    result = {"id": provider, "source": url, "checkedAt": int(time.time() * 1000)}
    try:
        request = urllib.request.Request(url, headers={"User-Agent": "ShojiStatus/1.0", "Accept": "application/json, application/xml, text/html"})
        with urllib.request.urlopen(request, timeout=12) as response:
            body = response.read(2 * 1024 * 1024 + 1)
        if len(body) > 2 * 1024 * 1024:
            raise ValueError("Response too large")
        document = body.decode("utf-8")
        severity, titles = (deepseek(document) if provider == "deepseek" else
                            grok(document) if provider == "grok" else statuspage(json.loads(document)))
        return {**result, "state": "available", "severity": severity, "fetchedAt": int(time.time() * 1000),
                "detail": LABELS[severity] + (" · " + "; ".join(titles[:2])[:300] if titles else "")}
    except urllib.error.HTTPError as error:
        detail = f"Источник недоступен: HTTP {error.code}"
    except (OSError, ValueError, KeyError, TypeError, ET.ParseError):
        detail = "Нет достоверных данных от источника"
    return {**result, "state": "unavailable", "severity": None, "detail": detail}


def self_check():
    assert statuspage({"status": {"indicator": "none"}, "components": [], "incidents": []})[0] == 0
    assert statuspage({"status": {"indicator": "none"}, "components": [{"status": "major_outage"}], "incidents": []})[0] == 4
    data = {"page": {"name": "DeepSeek"}, "active_changes": [{"status": "investigating", "title": "Errors", "affected_components": [{"status": "degraded"}]}]}
    chunk = '1:["$","$L",null,' + json.dumps({"initialData": data}) + ']\n'
    assert deepseek('<script>self.__next_f.push([1,' + json.dumps(chunk) + '])</script>')[0] == 2
    assert grok('<rss><channel><item><title>Errors</title><description>Resolved. Previously investigating.</description></item></channel></rss>')[0] == 0
    assert grok('<rss><channel><item><title>Errors</title><description>Investigating a major outage</description></item></channel></rss>')[0] == 4
    for parser, payload in [(grok, '<html/>'), (deepseek, '<html>All Systems Operational</html>'), (statuspage, {})]:
        try:
            parser(payload)
        except (ValueError, KeyError):
            pass
        else:
            raise AssertionError("Malformed source must not be green")
    print("Provider status parsing: OK")


if __name__ == "__main__":
    if "--self-check" in sys.argv:
        self_check()
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as pool:
            pending = [pool.submit(collect, provider, url) for provider, url in SOURCES.items()]
            for future in concurrent.futures.as_completed(pending):
                print(json.dumps(future.result(), ensure_ascii=False), flush=True)
