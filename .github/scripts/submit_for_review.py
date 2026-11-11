"""Submit the Xcode Cloud build of the current commit to App Review.

Flow: find the Xcode Cloud run for $GITHUB_SHA -> wait for it to finish and
its build to finish processing -> get-or-create the App Store version for that
build -> set "What's New" -> attach the build -> submit for review.

Env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_PRIVATE_KEY (.p8 contents), ASC_APP_ID,
GITHUB_SHA; optional RELEASE_NOTES, WAIT_MINUTES (default 90).
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"
APP_ID = os.environ["ASC_APP_ID"]
SHA = os.environ["GITHUB_SHA"]
DEADLINE = time.time() + int(os.environ.get("WAIT_MINUTES", "90")) * 60
EDITABLE = {
    "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
    "METADATA_REJECTED", "INVALID_BINARY",
}
IN_FLIGHT = {
    "WAITING_FOR_REVIEW", "IN_REVIEW", "PENDING_APPLE_RELEASE",
    "PENDING_DEVELOPER_RELEASE", "PROCESSING_FOR_APP_STORE", "READY_FOR_REVIEW",
}


def token():
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1200,
         "aud": "appstoreconnect-v1"},
        os.environ["ASC_PRIVATE_KEY"], algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"]},
    )


def call(method, path, body=None, params=None):
    url = API + path + ("?" + urllib.parse.urlencode(params) if params else "")
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        sys.exit(f"{method} {path} -> {e.code}: {e.read().decode()}")


def wait_for(what, fn):
    while True:
        result = fn()
        if result is not None:
            return result
        if time.time() > DEADLINE:
            sys.exit(f"Timed out waiting for {what}")
        time.sleep(30)


def find_build_run():
    product = call("GET", f"/v1/apps/{APP_ID}/ciProduct")["data"]["id"]
    runs = call("GET", f"/v1/ciProducts/{product}/buildRuns",
                params={"limit": 50, "sort": "-number"})["data"]
    for run in runs:
        if (run["attributes"].get("sourceCommit") or {}).get("commitSha") == SHA:
            return run["id"]
    return None  # Xcode Cloud has not picked up the push yet


def run_build(run_id):
    run = call("GET", f"/v1/ciBuildRuns/{run_id}")["data"]["attributes"]
    if run["executionProgress"] != "COMPLETE":
        return None
    if run["completionStatus"] != "SUCCEEDED":
        sys.exit(f"Xcode Cloud run finished {run['completionStatus']}; not submitting")
    builds = call("GET", f"/v1/ciBuildRuns/{run_id}/builds")["data"]
    return builds[0]["id"] if builds else None


def processed_build(build_id):
    b = call("GET", f"/v1/builds/{build_id}",
             params={"include": "preReleaseVersion"})
    state = b["data"]["attributes"]["processingState"]
    if state in ("FAILED", "INVALID"):
        sys.exit(f"Build processing {state}")
    if state != "VALID":
        return None
    version = next(i for i in b["included"] if i["type"] == "preReleaseVersions")
    return version["attributes"]["version"]


def get_or_create_version(version):
    existing = call("GET", f"/v1/apps/{APP_ID}/appStoreVersions",
                    params={"filter[platform]": "IOS", "limit": 10})["data"]
    for v in existing:
        a = v["attributes"]
        if a["versionString"] == version:
            if a["appStoreState"] in EDITABLE:
                return v["id"]
            sys.exit(f"Version {version} is already {a['appStoreState']}; "
                     "bump `version:` in pubspec.yaml to ship a new one")
    for v in existing:
        if v["attributes"]["appStoreState"] in IN_FLIGHT:
            sys.exit(f"Version {v['attributes']['versionString']} is still "
                     f"{v['attributes']['appStoreState']}; skipping this push")
    return call("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": version,
                       "releaseType": "AFTER_APPROVAL"},
        "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
    }})["data"]["id"]


def set_whats_new(version_id, notes):
    locs = call("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    for loc in locs:
        call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {
            "type": "appStoreVersionLocalizations", "id": loc["id"],
            "attributes": {"whatsNew": notes}}})


def submit(version_id):
    subs = call("GET", f"/v1/apps/{APP_ID}/reviewSubmissions",
                params={"filter[platform]": "IOS", "filter[state]": "READY_FOR_REVIEW"})["data"]
    if subs:
        sub_id = subs[0]["id"]
    else:
        sub_id = call("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": APP_ID}}},
        }})["data"]["id"]
        call("POST", "/v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems", "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
            }}})
    call("PATCH", f"/v1/reviewSubmissions/{sub_id}", {"data": {
        "type": "reviewSubmissions", "id": sub_id, "attributes": {"submitted": True}}})


def main():
    run_id = wait_for("Xcode Cloud to start a run for this commit", find_build_run)
    print(f"Xcode Cloud run {run_id}")
    build_id = wait_for("the Xcode Cloud run to finish", lambda: run_build(run_id))
    version = wait_for("build processing", lambda: processed_build(build_id))
    print(f"Build {build_id} is version {version}")

    version_id = get_or_create_version(version)
    notes = os.environ.get("RELEASE_NOTES", "").strip()
    if notes:
        try:
            set_whats_new(version_id, notes)
        except SystemExit as e:  # a first release has no What's New field
            print(f"Skipping What's New: {e}")
    call("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build",
         {"data": {"type": "builds", "id": build_id}})
    submit(version_id)
    print(f"Submitted {version} for App Review")


main()
