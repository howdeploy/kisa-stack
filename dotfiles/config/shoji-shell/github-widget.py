#!/usr/bin/env python3
"""Read GitHub through the existing gh login; never mark notifications read."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
from urllib.parse import urlencode


def api(endpoint, *, pages=False, query=None, variables=None):
    command = ["gh", "api", "--hostname", "github.com", endpoint]
    if pages:
        command += ["--paginate", "--slurp"]
    if query:
        command += ["--input", "-"]
    result = subprocess.run(command, input=json.dumps({"query": query, "variables": variables or {}}) if query else None,
                            capture_output=True, text=True, timeout=90)
    if result.returncode:
        # Never forward CLI output: it can contain private response bodies.
        if "401" in result.stderr or "authentication" in result.stderr.lower():
            raise RuntimeError("Нужна авторизация gh")
        if "403" in result.stderr or "429" in result.stderr:
            raise RuntimeError("GitHub: лимит запросов или недостаточно прав")
        raise RuntimeError("GitHub временно недоступен")
    value = json.loads(result.stdout)
    if isinstance(value, dict) and value.get("errors"):
        raise RuntimeError("GitHub не вернул данные обсуждения")
    return [item for page in value for item in page] if pages else value


def graphql(query, variables):
    return api("graphql", query=query, variables=variables)["data"]


def discussion(repo, number):
    owner, name = repo.split("/")
    variables = {"owner": owner, "name": name, "number": number, "cursor": None}
    fields = "id body createdAt author { login }"
    query = """query($owner:String!, $name:String!, $number:Int!, $cursor:String) {
      repository(owner:$owner, name:$name) { discussion(number:$number) {
        author { login } url
        comments(first:100, after:$cursor) {
          pageInfo { hasNextPage endCursor }
          nodes { FIELDS replies(first:100) {
            pageInfo { hasNextPage endCursor } nodes { FIELDS }
          } }
        }
      } }
    }""".replace("FIELDS", fields)
    comments = []
    author = ""
    url = ""
    while True:
        value = graphql(query, variables)["repository"]["discussion"]
        if not value:
            raise RuntimeError("Обсуждение недоступно")
        author = (value.get("author") or {}).get("login", "")
        url = value["url"]
        connection = value["comments"]
        for comment in connection["nodes"]:
            comments.append(comment)
            replies = comment["replies"]
            while True:
                comments.extend(replies["nodes"])
                if not replies["pageInfo"]["hasNextPage"]:
                    break
                replies = graphql("""query($id:ID!, $cursor:String!) {
                  node(id:$id) { ... on DiscussionComment {
                    replies(first:100, after:$cursor) {
                      pageInfo { hasNextPage endCursor } nodes { FIELDS }
                    }
                  } }
                }""".replace("FIELDS", fields), {
                    "id": comment["id"], "cursor": replies["pageInfo"]["endCursor"]
                })["node"]["replies"]
        if not connection["pageInfo"]["hasNextPage"]:
            break
        variables["cursor"] = connection["pageInfo"]["endCursor"]
    return author, url, [{"user": c.get("author"), "created_at": c["createdAt"], "body": c["body"]} for c in comments]


def relevant_comments(author, repo_owner, comments, login):
    if login.lower() in {author.lower(), repo_owner.lower()}:
        return comments
    mention = re.compile(r"(?<![\w@])@" + re.escape(login) + r"(?![\w-])", re.IGNORECASE)
    return [c for c in comments if mention.search(c.get("body") or "")]


def unread_comments(notification, comments, login):
    if not notification["unread"]:
        return []
    last_read = notification.get("last_read_at") or ""
    return [c for c in comments
               if c.get("countable", True)
               and (c.get("user") or {}).get("login", "").lower() != login.lower()
               and (c.get("submitted_at") or c.get("created_at") or "") > last_read]


def unread_count(notification, comments, login):
    return len(unread_comments(notification, comments, login))


def resolve(notification, login):
    subject = notification["subject"]
    repo = notification["repository"]["full_name"]
    match = re.fullmatch(r"https://api\.github\.com/repos/([\w.-]+/[\w.-]+)/(pulls|issues|discussions)/(\d+)", subject.get("url") or "")
    if not match or match[1].lower() != repo.lower():
        raise RuntimeError("Не удалось определить тему уведомления")
    number = int(match[3])
    if subject["type"] == "Discussion":
        author, url, comments = discussion(repo, number)
    else:
        detail = api(f"repos/{repo}/{match[2]}/{number}")
        author = (detail.get("user") or {}).get("login", "")
        url = detail["html_url"]
        comments = api(f"repos/{repo}/issues/{number}/comments?per_page=100", pages=True)
        if subject["type"] == "PullRequest":
            comments += api(f"repos/{repo}/pulls/{number}/comments?per_page=100", pages=True)
            reviews = api(f"repos/{repo}/pulls/{number}/reviews?per_page=100", pages=True)
            comments += [dict(r, countable=bool((r.get("body") or "").strip()))
                         for r in reviews if r.get("submitted_at")]
    comments = relevant_comments(author, notification["repository"]["owner"]["login"], comments, login)
    unread = unread_comments(notification, comments, login)
    comment_at = max((c.get("submitted_at") or c.get("created_at") or "" for c in unread), default="")
    return {"count": len(unread), "commentAt": comment_at, "url": url, "number": number}


def collect():
    cache_path = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "shoji-shell" / "github-widget.json"
    try:
        cache = json.loads(cache_path.read_text())
        if not isinstance(cache, dict):
            cache = {}
    except (OSError, ValueError):
        cache = {}
    snapshot = cache.get("snapshot")
    if isinstance(snapshot, dict) and snapshot.get("login") == cache.get("login"):
        # Replay before any network request; keep the original freshness timestamp.
        print(json.dumps(snapshot, ensure_ascii=False), flush=True)
    login = api("user")["login"]
    if cache.get("login") != login:
        cache = {}
        if isinstance(snapshot, dict):
            print(json.dumps({"login": login, "fetchedAt": 0, "errors": []}), flush=True)
    result = {"login": login, "fetchedAt": int(time.time() * 1000), "errors": []}
    try:
        search = api("search/issues?" + urlencode({"q": f"is:pr is:open user:{login}", "per_page": 1}))
        if search.get("incomplete_results"):
            raise RuntimeError("GitHub вернул неполный список PR")
        result["prCount"] = search["total_count"]
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        result["errors"].append(str(error) if isinstance(error, RuntimeError) else "Не удалось обновить PR")
    try:
        notifications = api("notifications?all=true&per_page=50", pages=True)
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired):
        result["errors"].append("Не удалось обновить уведомления")
        return result
    recent, total, failures, updated = [], 0, 0, {}
    notifications.sort(key=lambda n: n["updated_at"], reverse=True)
    for notification in notifications:
        if notification["subject"]["type"] not in {"PullRequest", "Issue", "Discussion"}:
            continue
        if not notification["unread"]:
            continue
        key = notification["id"]
        fingerprint = [3, notification["updated_at"], notification.get("last_read_at"), notification["unread"], notification["reason"]]
        old = cache.get("threads", {}).get(key, {})
        try:
            cached = old.get("fingerprint") == fingerprint and time.time() - old.get("checkedAt", 0) < 900
            if cached:
                detail = old["detail"]
            else:
                detail = resolve(notification, login)
            updated[key] = {"fingerprint": fingerprint, "detail": detail,
                            "checkedAt": old["checkedAt"] if cached else time.time()}
            show_in_log = True
            if notification["subject"]["type"] in {"PullRequest", "Issue"}:
                # A cached notification does not prove the topic is still open.
                repo = notification["repository"]["full_name"]
                endpoint = "pulls" if notification["subject"]["type"] == "PullRequest" else "issues"
                topic = api(f"repos/{repo}/{endpoint}/{detail['number']}")
                show_in_log = topic["state"] == "open" and not topic.get("merged", False)
        except (RuntimeError, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired):
            failures += 1
            continue
        total += detail["count"]
        if show_in_log and detail["commentAt"]:
            recent.append({"title": notification["subject"]["title"], "repository": notification["repository"]["full_name"],
                           "number": detail["number"], "url": detail["url"], "unread": notification["unread"],
                           "type": notification["subject"]["type"], "updatedAt": detail["commentAt"]})
    if failures:
        result["errors"].append(f"Не удалось обновить тем: {failures}")
    else:
        result.update(commentCount=total, recent=sorted(recent, key=lambda row: row["updatedAt"], reverse=True)[:5])
    snapshot = cache.get("snapshot")
    if not result["errors"]:
        result["fetchedAt"] = int(time.time() * 1000)
        snapshot = result
    try:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = cache_path.with_suffix(".tmp")
        with open(temporary, "w", opener=lambda path, flags: os.open(path, flags, 0o600)) as stream:
            json.dump({"login": login, "threads": updated, "snapshot": snapshot}, stream, ensure_ascii=False)
        temporary.replace(cache_path)
    except OSError:
        pass
    return result


def self_check():
    notification = {"unread": True, "last_read_at": "2026-09-26T12:00:00Z", "reason": "subscribed"}
    comments = [{"user": {"login": "me"}, "created_at": "2026-09-27T12:00:00Z"},
                {"user": {"login": "other"}, "created_at": "2026-09-25T12:00:00Z"},
                {"user": {"login": "other"}, "created_at": "2026-09-27T12:00:00Z"}]
    assert unread_count(notification, comments, "me") == 1
    assert unread_count(notification, comments + [dict(comments[2], countable=False)], "me") == 1
    assert relevant_comments("me", "other", comments, "me") == comments
    assert relevant_comments("other", "me", comments, "me") == comments
    assert relevant_comments("other", "other", comments, "me") == []
    tagged = dict(comments[2], body="Please check, @Me.")
    not_tagged = [dict(comments[2], body=text) for text in ("@me-bot", "@me2", "mail@me", "See #6642")]
    assert relevant_comments("other", "other", comments + not_tagged + [tagged], "me") == [tagged]
    notification["unread"] = False
    assert unread_count(notification, comments, "me") == 0
    notification.update(unread=True, last_read_at=None, reason="mention")
    assert unread_count(notification, comments, "me") == 2
    assert relevant_comments("other", "other", [], "me") == []
    from contextlib import redirect_stdout
    from io import StringIO
    from tempfile import TemporaryDirectory
    from unittest.mock import patch

    with TemporaryDirectory() as directory, patch.dict(os.environ, XDG_CACHE_HOME=directory):
        cache_path = Path(directory) / "shoji-shell" / "github-widget.json"
        responses = {"user": {"login": "me"}, "notifications?all=true&per_page=50": []}
        def fake_api(endpoint, **kwargs):
            return {"total_count": 2} if endpoint.startswith("search/issues?") else responses[endpoint]

        with patch.dict(globals(), api=fake_api), redirect_stdout(StringIO()):
            sample = collect()
        assert json.loads(cache_path.read_text())["snapshot"] == sample
        output = StringIO()
        def offline_api(endpoint, **kwargs):
            assert json.loads(output.getvalue()) == sample  # Emitted before the first request.
            raise RuntimeError("offline")

        with patch.dict(globals(), api=offline_api), redirect_stdout(output):
            try:
                collect()
            except RuntimeError as error:
                assert str(error) == "offline"
        assert json.loads(cache_path.read_text())["snapshot"] == sample
        responses["user"] = {"login": "other"}
        with patch.dict(globals(), api=fake_api), redirect_stdout(StringIO()) as output:
            collect()
        assert json.loads(output.getvalue().splitlines()[1])["login"] == "other"
        assert json.loads(cache_path.read_text())["snapshot"]["login"] == "other"
    print("GitHub comment accounting: OK")


if __name__ == "__main__":
    if "--self-check" not in sys.argv and os.environ.get("SHOJI_ENABLE_GITHUB") != "1":
        sys.exit("GitHub integration is disabled; opt in locally first")
    if "--self-check" in sys.argv:
        self_check()
    else:
        try:
            print(json.dumps(collect(), ensure_ascii=False), flush=True)
        except (RuntimeError, OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
            message = str(error) if isinstance(error, RuntimeError) else "Не удалось собрать данные GitHub"
            print(json.dumps({"errors": [message]}, ensure_ascii=False), flush=True)
