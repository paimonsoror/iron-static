"""Offline self-test for tools/play_publish.py (loaded by `play_publish.py --self-test`). No network, no Google libraries.

Every secret-looking value below is assembled from parts so this file never trips the repo secret scan.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import shutil
import struct
import tempfile
import zipfile
import zlib
from pathlib import Path
from typing import Any, Callable

PEM = "-----" + "BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7FAKEFAKEFAKE\nZZZZyyyyXXXXwwww1111222233334444\n-----" + "END PRIVATE KEY-----\n"
TOKEN = "ya29." + "A0ARrdaM-FAKE_token_VALUE_0123456789"
BEARER = "Bearer " + "FAKEbearerSECRETvalue987"
EMAIL = "robot-fake@fake-proj.iam." + "gserviceaccount.com"
PKID = "0123456789abcdef0123456789abcdef01234567"
PKNAME = "private" + "_key"
SATYPE = "service" + "_account"
PKG = "com.example.fakegame"

MANIFEST = ('<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="{pkg}" '
            'android:versionCode="{code}" android:versionName="{name}"><application/></manifest>')


def png(path: Path, w: int, h: int, ctype: int = 2, extra: bytes = b"") -> None:
    def chunk(t: bytes, d: bytes) -> bytes:
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    bpp = {2: 3, 6: 4}[ctype]
    raw = (b"\x00" + b"\x10" * (w * bpp)) * h
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, ctype, 0, 0, 0))
                     + extra + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def text_chunk() -> bytes:
    d = b"k\x00val"
    return struct.pack(">I", len(d)) + b"tEXt" + d + struct.pack(">I", zlib.crc32(b"tEXt" + d) & 0xFFFFFFFF)


class FakeTools:
    def __init__(self) -> None:
        self.cert = "Owner: CN=Fake Release\nCertificate fingerprints:\n\t SHA256: AA:BB:CC:01"
        self.pkg, self.code, self.name = PKG, 50001, "0.5.0-beta.1"
        self.ver = ("0.5.0-beta.1", 50001)
        self.check_ok = True
        self.check_calls = 0
        self.testfp: list[str] = []

    def signer_text(self, aab: Path) -> str:
        return self.cert

    def testkey_fingerprints(self) -> list[str]:
        return self.testfp

    def manifest_xml(self, aab: Path) -> str:
        return MANIFEST.format(pkg=self.pkg, code=self.code, name=self.name)

    def release_version(self) -> tuple[str, int]:
        return self.ver

    def aab_check(self, aab: Path) -> bool:
        self.check_calls += 1
        return self.check_ok


class FakeApi:
    def __init__(self, fail: dict[str, Exception] | None = None, code: int = 50001) -> None:
        self.calls: list[str] = []
        self.fail = fail or {}
        self.code = code
        self.track_body: dict[str, Any] = {}

    def _c(self, name: str) -> None:
        self.calls.append(name)
        if name in self.fail:
            raise self.fail[name]

    def insert_edit(self, package: str) -> str:
        self._c("insert")
        return "edit1"

    def delete_edit(self, package: str, edit: str) -> None:
        self._c("delete")

    def validate_edit(self, package: str, edit: str) -> None:
        self._c("validate")

    def commit_edit(self, package: str, edit: str) -> None:
        self._c("commit")

    def upload_bundle(self, package: str, edit: str, path: Path) -> int:
        self._c("upload")
        return self.code

    def set_track(self, package: str, edit: str, track: str, release: dict[str, Any]) -> None:
        self._c("track")
        self.track_body = {"track": track, **release}

    def update_listing(self, package: str, edit: str, language: str, body: dict[str, str]) -> None:
        self._c("listing")

    def delete_images(self, package: str, edit: str, language: str, image_type: str) -> None:
        self._c("delete_images")

    def upload_image(self, package: str, edit: str, language: str, image_type: str, path: Path) -> None:
        self._c("upload_image")


def run(pp: Any) -> int:
    results: list[tuple[str, bool]] = []
    tmp = Path(tempfile.mkdtemp(prefix="pp_selftest_"))
    repo, out = tmp / "repo", tmp / "out"
    (repo / "docs" / "release").mkdir(parents=True)
    (repo / "release" / "store").mkdir(parents=True)
    out.mkdir()
    (repo / "export_presets.cfg").write_text(
        f'[preset.0.options]\npackage/unique_name="{PKG}"\n[preset.1.options]\npackage/unique_name="{PKG}"\n', encoding="utf-8")
    notes_text = "First beta. Try both wave modes.\nNo ads, no purchases, no account."
    listing = ("# Listing\n- **App name:** `Fake Game`\n\n## Short description\n\n```\nShort text.\n```\n\n"
               "## Full description\n\n```\nFull text here.\n```\n\n"
               f"## Release notes, first build\n\n```\n{notes_text}\n```\n")
    listing_path = repo / "docs" / "release" / "store_listing.md"
    listing_path.write_text(listing, encoding="utf-8")
    assets = repo / "docs" / "release" / "store_assets.md"
    assets.write_text("# Store graphics\n\n> **Draft: do not upload until cleared.**\n", encoding="utf-8")
    store = repo / "release" / "store"
    png(store / "icon_512.png", 512, 512, 6)
    png(store / "feature_1024x500.png", 1024, 500)
    png(store / "phone_01.png", 360, 640)
    png(store / "phone_02.png", 360, 640)

    def make_aab(name: str = "ironstatic-0.5.0-beta.1-50001.aab", sha_ok: bool = True) -> Path:
        p = out / name
        with zipfile.ZipFile(p, "w") as z:
            z.writestr("base/manifest/AndroidManifest.xml", b"\x00proto")
        h = hashlib.sha256(p.read_bytes()).hexdigest()
        (out / (name + ".sha256")).write_text(("0" * 64 if not sha_ok else h) + "  " + name + "\n", encoding="utf-8")
        return p

    def ns(aab: Path | None = None, **kw: Any) -> argparse.Namespace:
        d: dict[str, Any] = dict(aab=aab, track="internal", status="draft", notes=Path("docs/release/store_listing.md"),
                                 skip_aab_check=False, auth_check=False, validate=False, commit=False, yes=False,
                                 allow_draft_assets=False)
        d.update(kw)
        return argparse.Namespace(**d)

    def capture(fn: Callable[[], int]) -> tuple[int, str]:
        o, e = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(o), contextlib.redirect_stderr(e):
            rc = pp.guarded(fn)
        return rc, o.getvalue() + e.getvalue()

    def check(name: str, ok: bool, detail: str = "") -> None:
        results.append((name, ok))
        print(f"  [{'ok' if ok else 'FAIL'}] {name}" + (f"  {detail}" if detail and not ok else ""))

    def refused(name: str, fn: Callable[[], int], needle: str) -> None:
        rc, text = capture(fn)
        check(name, rc == 1 and "REFUSED" in text and needle in text, f"rc={rc} text={text.strip()[:200]!r}")

    good = make_aab()
    T = FakeTools

    # --- bundle refusals (all before any network call)
    api = FakeApi()
    refused("refuses a TESTKEY file name",
            lambda: pp.cmd_release(ns(make_aab("ironstatic-0.5.0-beta.1-50001-TESTKEY.aab")), repo, T(), lambda: api), "TEST-KEY")
    t = T()
    t.cert = "Owner: CN=IronStatic TEST KEY NOT FOR UPLOAD, O=local test\n SHA256: 11:22"
    refused("refuses a test-key signer certificate", lambda: pp.cmd_release(ns(good), repo, t, lambda: api), "test key")
    t = T()
    t.testfp = ["AA:BB:CC:01"]
    refused("refuses a signer equal to the testkey keystore", lambda: pp.cmd_release(ns(good), repo, t, lambda: api), "throwaway test keystore")
    t = T()
    t.cert = "Owner: CN=Android Debug, O=Android\n SHA256: 11:22"
    refused("refuses the Android debug certificate", lambda: pp.cmd_release(ns(good), repo, t, lambda: api), "debug")
    t = T()
    t.pkg = "com.other.app"
    refused("refuses a wrong manifest package", lambda: pp.cmd_release(ns(good), repo, t, lambda: api), "manifest package")
    t = T()
    t.ver = ("0.5.0-beta.2", 50002)
    refused("refuses a version that differs from version.json", lambda: pp.cmd_release(ns(good), repo, t, lambda: api), "versionCode")
    bad = make_aab("ironstatic-0.5.0-beta.1-50001.aab", sha_ok=False)
    refused("refuses a sha256 mismatch", lambda: pp.cmd_release(ns(bad), repo, T(), lambda: api), "sha256")
    good = make_aab()
    t = T()
    t.check_ok = False
    refused("refuses when aab_check fails", lambda: pp.cmd_release(ns(good), repo, t, lambda: api), "aab_check")
    check("no API call was made by any refusal", api.calls == [])
    t = T()
    rc, text = capture(lambda: pp.cmd_release(ns(good, skip_aab_check=True), repo, t, lambda: api))
    check("--skip-aab-check skips the check and warns", rc == 0 and t.check_calls == 0 and "WARNING" in text)

    # --- key path
    key_repo = repo / "k.json"
    key_repo.write_text("{}", encoding="utf-8")
    try:
        pp.check_key_path(str(key_repo), repo)
        ok = False
    except pp.Refuse as e:
        ok = "inside the repo" in str(e)
    check("refuses a key path inside the repo", ok)
    gitdir = tmp / "wt"
    (gitdir / ".git").mkdir(parents=True)
    (gitdir / "k.json").write_text("{}", encoding="utf-8")
    try:
        pp.check_key_path(str(gitdir / "k.json"), repo)
        ok = False
    except pp.Refuse as e:
        ok = "git working tree" in str(e)
    check("refuses a key path inside any git working tree", ok)
    keys = tmp / "keys"
    keys.mkdir()
    keyfile = keys / "sa.json"
    keyfile.write_text(json.dumps({"type": SATYPE, PKNAME: PEM, PKNAME + "_id": PKID, "client_email": EMAIL,
                                   "client_id": "1234567890123"}), encoding="utf-8")
    try:
        ok = pp.check_key_path(str(keyfile), repo) == keyfile
    except pp.Refuse:
        ok = False
    check("accepts a key outside the repo", ok)
    sec = tmp / "secrets.json"
    sec.write_text(json.dumps({"play_service_account_json": str(keyfile)}), encoding="utf-8")
    check("key path read from the secrets file", pp.read_key_setting(sec, {}) == str(keyfile))
    check("environment variable wins over the secrets file", pp.read_key_setting(sec, {pp.ENV_KEY: "X.json"}) == "X.json")
    sec2 = tmp / "secrets2.json"
    sec2.write_text(json.dumps({"play_service_account_json": str(key_repo)}), encoding="utf-8")
    try:
        pp.check_key_path(pp.read_key_setting(sec2, {}), repo)
        ok = False
    except pp.Refuse:
        ok = True
    check("a secrets file pointing into the repo is refused", ok)

    # --- nothing secret is ever printed
    pp.load_key_secrets(keyfile)
    boom = (f"auth failed. Authorization: {BEARER} token={TOKEN} acct {EMAIL} body "
            + json.dumps({PKNAME: PEM, PKNAME + "_id": PKID}) + "\n" + PEM)

    class LeakyApi(FakeApi):
        def upload_bundle(self, package: str, edit: str, path: Path) -> int:
            print("debug:", PEM, TOKEN)  # a stray print must still be scrubbed
            raise RuntimeError(boom)

    secrets_all = [TOKEN, BEARER.split()[1], EMAIL, PKID, "MIIEvQIBADANBgkqhkiG9w0BAQEFAASC", "ZZZZyyyyXXXXwwww1111222233334444"]
    leaky = LeakyApi()
    rc, text = capture(lambda: pp.cmd_release(ns(good, validate=True), repo, T(), lambda: leaky))
    check("generic error path leaks nothing and still deletes the edit",
          rc == 1 and not any(s in text for s in secrets_all) and "delete" in leaky.calls, text[:300])
    msg = pp.http_error_text(403, json.dumps({"error": {"message": f"denied {TOKEN} for {EMAIL} {BEARER}"}}))
    rc, text = capture(lambda: pp.cmd_release(ns(good, validate=True), repo, T(),
                                              lambda: FakeApi(fail={"insert": pp.ApiError(403, msg, "edits.insert")})))
    check("ApiError path leaks nothing", rc == 1 and not any(s in text for s in secrets_all) and "403" in text, text[:300])
    body = json.dumps({"error": {"message": "x", "errors": [{"reason": "r"}]}, "request": {"headers": {"Authorization": BEARER}}})
    check("http_error_text prints message and reason only", pp.http_error_text(400, body) == "x (reason: r)")
    probe = pp.scrub(f"{PEM} {TOKEN} Authorization: {BEARER} {EMAIL} " + '"' + PKNAME + '": "abc"')
    check("scrub removes PEM, token, header and email even when unregistered",
          not any(s in probe for s in [TOKEN, "MIIEv", EMAIL, "FAKEbearer", '"abc"']), probe)
    cap = io.StringIO()
    with contextlib.redirect_stdout(cap):
        pp.emit("hello " + TOKEN)
    check("emit scrubs", TOKEN not in cap.getvalue())

    # --- modes
    api = FakeApi()
    rc, text = capture(lambda: pp.cmd_release(ns(good), repo, T(), lambda: api))
    check("dry run makes no API calls and says so", rc == 0 and api.calls == [] and "DRY RUN" in text)
    api = FakeApi()
    rc, _ = capture(lambda: pp.cmd_release(ns(good, auth_check=True), repo, T(), lambda: api))
    check("--auth-check is insert then delete only", rc == 0 and api.calls == ["insert", "delete"], str(api.calls))
    api = FakeApi()
    rc, _ = capture(lambda: pp.cmd_release(ns(good, validate=True), repo, T(), lambda: api))
    check("--validate uploads, validates, deletes its edit and never commits",
          rc == 0 and api.calls == ["insert", "upload", "track", "validate", "delete"], str(api.calls))
    api = FakeApi(fail={"validate": pp.ApiError(400, "bad", "edits.validate")})
    rc, _ = capture(lambda: pp.cmd_release(ns(good, validate=True), repo, T(), lambda: api))
    check("a failed validate still deletes the edit", rc == 1 and api.calls[-1] == "delete" and "commit" not in api.calls)
    api = FakeApi()
    rc, text = capture(lambda: pp.cmd_release(ns(good, commit=True, yes=True), repo, T(), lambda: api))
    check("--commit calls commit once and does not delete", rc == 0 and api.calls.count("commit") == 1 and "delete" not in api.calls, str(api.calls))
    check("--commit prints package, track, versionCode, status, notes before the first call",
          all(s in text for s in (PKG, "internal", "50001", "draft", "No ads, no purchases"))
          and text.index("ABOUT TO COMMIT") < text.index("edit edit1 opened"))
    check("release body has draft status, string versionCode and the notes",
          api.track_body.get("status") == "draft" and api.track_body.get("versionCodes") == ["50001"]
          and api.track_body["releaseNotes"][0]["text"] == notes_text)
    api = FakeApi()
    rc, _ = capture(lambda: pp.cmd_release(ns(good, commit=True), repo, T(), lambda: api, ask=lambda _q: "no"))
    check("--commit without confirmation does nothing", rc == 1 and api.calls == [])
    api = FakeApi()
    rc, _ = capture(lambda: pp.cmd_release(ns(good, commit=True), repo, T(), lambda: api, ask=lambda _q: "50001"))
    check("--commit with the typed versionCode proceeds", rc == 0 and "commit" in api.calls)
    api = FakeApi(code=49999)
    rc, _ = capture(lambda: pp.cmd_release(ns(good, commit=True, yes=True), repo, T(), lambda: api))
    check("a versionCode mismatch reported by Play blocks the commit", rc == 1 and "commit" not in api.calls)
    api = FakeApi(fail={"track": pp.ApiError(400, "Only releases with status draft may be created on draft app.", "edits.tracks.update")})
    rc, text = capture(lambda: pp.cmd_release(ns(good, validate=True, status="completed"), repo, T(), lambda: api))
    check("a draft-app rejection prints a clear hint", rc == 1 and "still a draft" in text and "--status draft" in text)
    api = FakeApi(fail={"upload": pp.ApiError(403, "forbidden", "edits.bundles.upload")})
    rc, text = capture(lambda: pp.cmd_release(ns(good, validate=True), repo, T(), lambda: api))
    check("a first-upload error points to a manual Console upload", rc == 1 and "first upload" in text and api.calls[-1] == "delete")
    check("the production track is not selectable", "production" not in pp.TRACKS)

    # --- release notes
    def notes_case(text: str) -> str:
        (repo / "notes.txt").write_text(text, encoding="utf-8")
        return capture(lambda: pp.cmd_release(ns(good, notes=Path("notes.txt")), repo, T(), lambda: FakeApi()))[1]
    check("notes of 500 characters pass", "REFUSED" not in notes_case("a" * 500))
    check("notes of 501 characters are refused", "501 characters" in notes_case("a" * 501))
    check("empty notes are refused", "empty" in notes_case("  \n"))
    check("notes with an email address are refused", "email" in notes_case("write to someone@example.org"))
    check("notes from outside the repo are refused",
          "inside the repo" in capture(lambda: pp.cmd_release(ns(good, notes=tmp / "n.txt"), repo, T(), lambda: FakeApi()))[1])

    # --- listing
    api = FakeApi()
    refused("listing refuses while the draft banner is present", lambda: pp.cmd_listing(ns(validate=True), repo, lambda: api), "Draft: do not upload")
    check("the draft refusal made no API call", api.calls == [])
    rc, text = capture(lambda: pp.cmd_listing(ns(allow_draft_assets=True), repo, lambda: api))
    check("listing dry run (draft allowed) makes no API calls", rc == 0 and api.calls == [] and "DRY RUN" in text and "WARNING" in text)
    api = FakeApi()
    rc, _ = capture(lambda: pp.cmd_listing(ns(allow_draft_assets=True, validate=True), repo, lambda: api))
    check("listing --validate deletes its edit and never commits",
          rc == 0 and api.calls[0] == "insert" and api.calls[-1] == "delete" and "commit" not in api.calls and "upload_image" in api.calls, str(api.calls))
    api = FakeApi()
    rc, _ = capture(lambda: pp.cmd_listing(ns(allow_draft_assets=True, commit=True, yes=True), repo, lambda: api))
    check("listing --commit commits once", rc == 0 and api.calls.count("commit") == 1)
    assets.write_text("# Store graphics\n\nApproved.\n", encoding="utf-8")
    rc, _ = capture(lambda: pp.cmd_listing(ns(validate=True), repo, lambda: FakeApi()))
    check("listing proceeds once the banner is gone", rc == 0)
    listing_path.write_text(listing.replace("Short text.", "s" * 81), encoding="utf-8")
    refused("listing refuses an 81-character short description", lambda: pp.cmd_listing(ns(), repo, lambda: FakeApi()), "81 characters")
    listing_path.write_text(listing, encoding="utf-8")
    png(store / "phone_02.png", 360, 640, 2, extra=text_chunk())
    refused("listing refuses an image with text metadata", lambda: pp.cmd_listing(ns(), repo, lambda: FakeApi()), "metadata")
    png(store / "phone_02.png", 360, 640)
    png(store / "feature_1024x500.png", 1024, 500, 6)
    refused("listing refuses a feature graphic with alpha", lambda: pp.cmd_listing(ns(), repo, lambda: FakeApi()), "alpha")

    shutil.rmtree(tmp, ignore_errors=True)
    failed = [n for n, ok in results if not ok]
    print(f"play_publish self-test: {len(results) - len(failed)}/{len(results)} ok")
    return 1 if failed else 0
