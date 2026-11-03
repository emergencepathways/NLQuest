#!/usr/bin/env python3
"""
Speurtocht.NL - the batch merge queue (run by .github/workflows/batch-automerge.yml).

Usage (from the repo root, on a full clone with an "origin" remote):
    python3 tools/automerge.py              process every batch-NN branch that isn't on main yet
    python3 tools/automerge.py --local      same, but no GitHub calls (no pull requests / comments);
                                            for testing against a local copy

For each waiting batch-NN branch, lowest number first:
  1. make sure it has a pull request (title and notes from the batch commit)
  2. merge main into it; take main's copy of the shared files (SpeurtochtNL.toc,
     Data/Namen.lua, CHANGELOG.md) and rebuild them with tools/sync_batch.py NN
  3. run the offline test harness
  4. push the synced branch, then merge it into main with a normal merge commit and
     push main. GitHub marks the pull request as merged by itself when its last
     commit lands on main, so there is no "merge" API call that can be refused
     while GitHub is still checking a commit that was pushed a second earlier.
If a step fails, the branch is left alone, the pull request gets one comment with
the actual error (once per commit, so the scheduled retries don't spam), and the
queue moves on to the next batch. Exit code 1 if a batch couldn't be merged for a reason
not reported before.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = ["SpeurtochtNL.toc", "Data/Namen.lua", "CHANGELOG.md"]
LOCAL = "--local" in sys.argv
LUA = os.environ.get("LUA", "lua5.1")
RUN_URL = ""
if os.environ.get("GITHUB_RUN_ID"):
    RUN_URL = "%s/%s/actions/runs/%s" % (os.environ.get("GITHUB_SERVER_URL", "https://github.com"),
                                         os.environ.get("GITHUB_REPOSITORY", ""), os.environ["GITHUB_RUN_ID"])


class Fail(Exception):
    pass


def sh(*cmd, check=True):
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    if check and p.returncode:
        raise Fail("$ %s\n%s%s" % (" ".join(cmd), p.stdout[-3000:], p.stderr[-3000:]))
    return p


def git(*args, check=True):
    return sh("git", *args, check=check).stdout.strip()


def gh(*args, check=True):
    if LOCAL:
        return ""
    return sh("gh", *args, check=check).stdout.strip()


def waiting_branches():
    git("fetch", "-q", "--prune", "origin", "+refs/heads/*:refs/remotes/origin/*")
    out = []
    for ref in git("for-each-ref", "--format=%(refname:short)", "refs/remotes/origin/").split("\n"):
        m = re.fullmatch(r"origin/batch-(\d+)", ref.strip())
        if m and git("rev-list", "--count", "origin/main.." + ref) != "0":
            out.append((int(m.group(1)), "batch-" + m.group(1)))
    return sorted(out)


def pr_notes(branch):
    commits = git("rev-list", "--reverse", "--no-merges", "origin/main..origin/" + branch).split()
    title = git("log", "-1", "--format=%s", commits[0])
    body = [git("log", "-1", "--format=%b", commits[0])]
    for c in commits[1:]:
        subject = git("log", "-1", "--format=%s", c)
        if re.search(r": (rebuild shared files|sync with main)$", subject):
            continue
        body += ["", "**Follow-up:** " + subject, git("log", "-1", "--format=%b", c)]
    body += ["", "---", "Checked and merged automatically by the *Batch auto-merge* workflow "
                         "(importer READY, test harness 0 failures)."]
    return title, "\n".join(body).strip() + "\n"


def ensure_pr(branch):
    if LOCAL:
        return None
    found = gh("pr", "list", "--head", branch, "--state", "open", "--json", "number", "--jq", ".[0].number")
    if found:
        return found
    title, body = pr_notes(branch)
    gh("pr", "create", "--base", "main", "--head", branch, "--title", title, "--body", body)
    return gh("pr", "list", "--head", branch, "--state", "open", "--json", "number", "--jq", ".[0].number")


def comment_once(pr, head, text):
    """Comment on the pull request unless this commit was already reported. True = a new problem."""
    if LOCAL or not pr:
        return True
    marker = "<!-- automerge:%s -->" % head
    existing = gh("api", "repos/{owner}/{repo}/issues/%s/comments" % pr, "--paginate", "--jq", ".[].body", check=False)
    if marker in existing:
        return False
    gh("pr", "comment", pr, "--body", text + "\n\n" + marker, check=False)
    return True


def clean_tree():
    git("merge", "--abort", check=False)
    git("reset", "-q", "--hard")
    git("clean", "-qfd", "-e", "work/")


def process(n, branch):
    clean_tree()
    git("checkout", "-q", "-B", branch, "origin/" + branch)
    merged = sh("git", "merge", "--no-ff", "--no-commit", "origin/main", check=False)
    for f in SHARED:
        git("checkout", "origin/main", "--", f)
    left = git("diff", "--name-only", "--diff-filter=U")
    if left:
        raise Fail("These files conflict with main and need a person:\n" + left)
    sync = sh(sys.executable, "tools/sync_batch.py", str(n), check=False)
    if sync.returncode:
        raise Fail("tools/sync_batch.py %d failed:\n%s%s" % (n, sync.stdout[-3000:], sync.stderr[-1500:]))
    git("add", "-A")
    if os.path.exists(os.path.join(ROOT, ".git", "MERGE_HEAD")):
        git("commit", "-q", "-m", "Batch %d: sync with main" % n)
    elif git("diff", "--cached", "--name-only"):
        git("commit", "-q", "-m", "Batch %d: rebuild shared files" % n)
    tests = sh(LUA, "tools/test_harness.lua", check=False)
    if tests.returncode:
        fails = [l for l in tests.stdout.split("\n") if l.startswith("FAIL")][:30]
        raise Fail("Test harness failed:\n" + "\n".join(fails + tests.stdout.strip().split("\n")[-1:]))
    git("push", "-q", "origin", "HEAD:refs/heads/" + branch)
    synced = git("rev-parse", "HEAD")
    return synced, merged.returncode


def merge_into_main(n, branch, pr, synced):
    title = git("log", "-1", "--format=%s", git("rev-list", "--reverse", "--no-merges",
                                                "origin/main.." + synced).split()[0])
    head = "Merge pull request #%s from %s" % (pr, branch) if pr else "Merge %s" % branch
    git("checkout", "-q", "-B", "main", "origin/main")
    git("merge", "-q", "--no-ff", synced, "-m", head, "-m", title)
    push = sh("git", "push", "-q", "origin", "HEAD:refs/heads/main", check=False)
    return push.returncode == 0


def main():
    for k, v in (("user.name", "github-actions[bot]"),
                 ("user.email", "41898282+github-actions[bot]@users.noreply.github.com")):
        if not git("config", k, check=False):
            git("config", k, v)
    queue = waiting_branches()
    if not queue:
        print("Nothing waiting.")
        return 0
    print("Waiting: " + ", ".join(b for _, b in queue))
    stuck, new_problem = [], False
    for n, branch in queue:
        pr = None
        head = git("rev-parse", "origin/" + branch)
        try:
            pr = ensure_pr(branch)
            for attempt in (1, 2, 3):          # main can move under us only if someone pushes to it by hand
                synced, _ = process(n, branch)
                if merge_into_main(n, branch, pr, synced):
                    break
                print("  main moved during batch %d, retrying (%d)" % (n, attempt))
                git("fetch", "-q", "origin", "+refs/heads/main:refs/remotes/origin/main")
            else:
                raise Fail("Couldn't push to main three times in a row.")
            print("MERGED %s%s" % (branch, " (#%s)" % pr if pr else ""))
            if pr:
                gh("pr", "comment", pr, "--body", "Merged automatically." + (" Run: " + RUN_URL if RUN_URL else ""),
                   check=False)
            git("fetch", "-q", "origin", "+refs/heads/main:refs/remotes/origin/main")
        except Fail as e:
            stuck.append(branch)
            msg = str(e).strip()
            print("NOT MERGED %s:\n%s" % (branch, msg))
            new_problem |= comment_once(pr, head, "**Not merged automatically.** The branch stays open until this is fixed.\n\n"
                         "```\n%s\n```\n%s\nTo fix: in a new chat, say \"Fix batch %d\". Pushing the fix to %s "
                         "retries automatically; the queue also retries every 30 minutes."
                         % (msg[-3500:], ("Run: " + RUN_URL + "\n") if RUN_URL else "", n, branch))
    clean_tree()
    if stuck:
        print("Still waiting: " + ", ".join(stuck))
        # fail the run (GitHub emails the owner) only for a problem not reported before,
        # so the 30-minute retries of an already-reported batch stay quiet
        return 1 if new_problem else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
