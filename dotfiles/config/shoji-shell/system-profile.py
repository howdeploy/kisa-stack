"""Current Unix account's display name and local AccountsService portrait."""
import json
import os
from pathlib import Path
import pwd
import sys


def profile(account):
    return {
        "name": account.pw_gecos.split(",", 1)[0].strip() or account.pw_name,
        "avatar": (Path("/var/lib/AccountsService/icons") / account.pw_name).as_uri(),
    }


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-check"]:
        from types import SimpleNamespace

        assert profile(SimpleNamespace(pw_name="user", pw_gecos="Имя,room,phone"))["name"] == "Имя"
        assert profile(SimpleNamespace(pw_name="user", pw_gecos=" ,room"))["name"] == "user"
        assert profile(SimpleNamespace(pw_name="a b", pw_gecos=""))["avatar"].endswith("/a%20b")
        print("Profile: GECOS name, login fallback and local image URL OK")
    else:
        print(json.dumps(profile(pwd.getpwuid(os.getuid())), ensure_ascii=False))
