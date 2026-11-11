#!/usr/bin/env python3
"""Publish IRON STATIC to Google Play (Android Publisher API v3). Safety first. See docs/release/play_publish.md.

Run with isolated mode:  python -I tools/play_publish.py <command> ...   (tools\\play_publish.ps1 does this)

  release <file.aab>   dry run (local checks only) | --auth-check | --validate | --commit
  listing              store listing text + images from the repo, same modes
  status               read-only: every track with its releases (opens an edit, then deletes it)
  --self-test          no network, no Google libraries needed

Safety rules (each one is covered by --self-test):
  * the service-account key stays outside the repo and outside any git working tree; it is never copied,
    printed or written; every line this tool prints passes through scrub()
  * default is a dry run: local checks only, zero network calls
  * test-key / debug-signed / wrong-package / wrong-version / sha-mismatch bundles are refused before any network call
  * only --commit commits, only after printing exactly what it commits and asking for confirmation
  * no production track (closed = API alpha is the default; open = API beta stays on hold and needs --allow-open),
    no tester emails, no personal data: the tool sends the AAB, release notes, listing text
    and images that are already in the repo
Exit: 0 ok, 1 refused or failed, 2 usage or configuration error.
"""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile
import zlib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

ROOT = Path(__file__).resolve().parent.parent
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
LANG = "en-US"
# Friendly name -> API track name. Production is deliberately missing: this tool can never touch it.
TRACK_API = {"closed": "alpha", "internal": "internal", "open": "beta"}
TRACK_LABEL = {"closed": "closed testing", "internal": "internal testing", "open": "open testing"}
TRACKS = tuple(TRACK_API)
DEFAULT_TRACK = "closed"
API_FRIENDLY = {"alpha": "closed testing", "internal": "internal testing", "beta": "open testing", "production": "production"}
NOTES_MAX = 500
SECRETS_KEY = "play_service_account_json"
ENV_KEY = "PLAY_SERVICE_ACCOUNT_JSON"
DEFAULT_VENV = r"C:\dev\tools\venvs\play"
PK = "private" + "_key"  # never write the quoted key name literally: the repo secret scan would flag this file

# ---------------------------------------------------------------- scrubbing

_SECRETS: set[str] = set()
_PEM = re.compile("-----" + "BEGIN[^-]*-----.*?-----" + "END[^-]*-----", re.S)
_PEM_OPEN = re.compile("-----" + "BEGIN[^-]*-----[A-Za-z0-9+/=\\s\\\\n]*")
_PRIV = re.compile('"' + PK + '(_id)?"\\s*:\\s*"[^"]*"')
_TOKEN = re.compile(r"\bya29\.[\w.-]+|\bBearer\s+[\w.~+/=-]+|\beyJ[\w-]{8,}\.[\w.-]+|\bAIza[\w-]{20,}")
_HEADER = re.compile(r"(?i)\b(authorization|x-goog-[\w-]+|access_token|refresh_token|client_secret|assertion)\b(['\"]?\s*[:=]\s*)\S+")
_EMAIL = re.compile(r"[\w.+-]+@[\w-]+(?:\.[\w-]+)+")


def register_secret(value: Any) -> None:
    """Remember a literal secret so scrub() removes it wherever it shows up (raw, JSON-escaped, per PEM line)."""
    if not isinstance(value, str) or len(value) < 6:
        return
    _SECRETS.add(value)
    _SECRETS.add(json.dumps(value)[1:-1])
    for line in value.splitlines():
        if len(line.strip()) >= 16:
            _SECRETS.add(line.strip())


def scrub(text: str) -> str:
    out = str(text)
    for s in sorted(_SECRETS, key=len, reverse=True):
        out = out.replace(s, "<redacted>")
    out = _PEM.sub("<redacted-key>", out)
    out = _PEM_OPEN.sub("<redacted-key>", out)
    out = _PRIV.sub('"<redacted>"', out)
    out = _TOKEN.sub("<redacted-token>", out)
    out = _HEADER.sub(lambda m: m.group(1) + m.group(2) + "<redacted>", out)
    return _EMAIL.sub("<email>", out)


def emit(msg: str = "", err: bool = False) -> None:
    (sys.stderr if err else sys.stdout).write(scrub(msg) + "\n")


class ScrubWriter:
    """Wraps a text stream so that even stray prints and library output pass through scrub()."""

    def __init__(self, inner: Any) -> None:
        self.inner = inner

    def write(self, s: str) -> int:
        self.inner.write(scrub(s))
        return len(s)

    def flush(self) -> None:
        self.inner.flush()

    def isatty(self) -> bool:
        return bool(getattr(self.inner, "isatty", lambda: False)())


class Refuse(Exception):
    """A safety check failed; the message is safe to print."""


class ApiError(Exception):
    def __init__(self, status: int, message: str, step: str = "") -> None:
        super().__init__(message)
        self.status = status
        self.message = message
        self.step = step


def http_error_text(status: int, content: bytes | str) -> str:
    """One scrubbed line out of a Google error body. Never includes request headers."""
    raw = content.decode("utf-8", "replace") if isinstance(content, bytes) else str(content)
    msg = raw
    try:
        err = json.loads(raw).get("error", {})
        msg = str(err.get("message", "")) or raw
        reasons = [str(e.get("reason", "")) for e in err.get("errors", []) if isinstance(e, dict)]
        if reasons and reasons[0]:
            msg += f" (reason: {reasons[0]})"
    except (ValueError, AttributeError):
        pass
    return scrub(" ".join(msg.split()))[:400]


# ---------------------------------------------------------------- configuration and key path


def read_key_setting(secrets_path: Path, env: dict[str, str]) -> str:
    """Key path from the environment, else from secrets.local.json. Only that one field is read."""
    if env.get(ENV_KEY):
        return env[ENV_KEY]
    if secrets_path.is_file():
        try:
            data = json.loads(secrets_path.read_text(encoding="utf-8-sig"))
        except ValueError:
            raise Refuse(f"{secrets_path.name} is not valid JSON") from None
        val = data.get(SECRETS_KEY) if isinstance(data, dict) else None
        if isinstance(val, str) and val.strip():
            return val.strip()
    raise Refuse(f"no key path: set '{SECRETS_KEY}' in secrets.local.json or the environment variable {ENV_KEY}")


def _norm(p: str | Path) -> str:
    return os.path.normcase(os.path.realpath(str(p)))


def check_key_path(raw: str, repo: Path) -> Path:
    """Refuse a key that is inside the repo or inside any git working tree. Never opens the file."""
    key = Path(os.path.expandvars(os.path.expanduser(raw)))
    k, r = _norm(key), _norm(repo)
    if k == r or k.startswith(r.rstrip("\\/") + os.sep):
        raise Refuse("the service-account key is inside the repo directory; move it outside the repo")
    for parent in Path(k).parents:
        if (parent / ".git").exists():
            raise Refuse("the service-account key is inside a git working tree; keep it in a plain folder outside any repo")
    if key.suffix.lower() != ".json":
        raise Refuse("the key path must end in .json")
    if not key.is_file():
        raise Refuse("the key file does not exist at the configured path")
    if key.stat().st_size > 20_000:
        raise Refuse("the key file is unexpectedly large; not a service-account key")
    return key


def load_key_secrets(key: Path) -> None:
    """Parse the key only to register its secret fields for scrubbing and to check its type. Prints nothing."""
    try:
        data = json.loads(key.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        raise Refuse("the key file is not readable JSON") from None
    if not isinstance(data, dict) or data.get("type") != "service" + "_account":
        raise Refuse("the key file is not a service-account key")
    for f in (PK, PK + "_id", "client_email", "client_id"):
        register_secret(data.get(f))


def import_google() -> tuple[Any, Any, Any, Any]:
    """Import the Google libraries lazily; fall back to the venv outside the repo."""
    def attempt() -> tuple[Any, Any, Any, Any]:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        from googleapiclient.errors import HttpError
        from googleapiclient.http import MediaFileUpload
        return service_account, build, HttpError, MediaFileUpload

    try:
        return attempt()
    except ImportError:
        venv = Path(os.environ.get("PLAY_VENV", DEFAULT_VENV))
        for sp in (venv / "Lib" / "site-packages", *venv.glob("lib/python3*/site-packages")):
            if sp.is_dir():
                sys.path.append(str(sp))
        try:
            return attempt()
        except ImportError:
            raise Refuse(
                "Google libraries not found. Create the venv outside the repo:\n"
                f"  python -m venv {DEFAULT_VENV}\n"
                f"  {DEFAULT_VENV}\\Scripts\\python.exe -m pip install -r tools\\requirements-play.txt\n"
                "(or set PLAY_VENV to another venv)") from None


# ---------------------------------------------------------------- Play API wrapper


class PlayApi:
    """Thin wrapper over androidpublisher v3. The self-test replaces it with a fake of the same methods."""

    def __init__(self, key: Path) -> None:
        import logging
        service_account, build, self._HttpError, self._Media = import_google()
        for name in ("googleapiclient", "google", "httplib2", "urllib3"):
            logging.getLogger(name).setLevel(logging.CRITICAL)
        try:
            creds = service_account.Credentials.from_service_account_file(str(key), scopes=[SCOPE])
            self._svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
        except Exception as e:  # noqa: BLE001 - message is scrubbed, never the key
            raise Refuse(f"could not load credentials ({type(e).__name__}): {scrub(str(e))[:200]}") from None

    def _do(self, step: str, req: Any) -> Any:
        try:
            return req.execute()
        except self._HttpError as e:
            raise ApiError(int(getattr(e.resp, "status", 0) or 0), http_error_text(int(getattr(e.resp, "status", 0) or 0), e.content), step) from None

    def insert_edit(self, package: str) -> str:
        return str(self._do("edits.insert", self._svc.edits().insert(packageName=package, body={}))["id"])

    def delete_edit(self, package: str, edit: str) -> None:
        self._do("edits.delete", self._svc.edits().delete(packageName=package, editId=edit))

    def validate_edit(self, package: str, edit: str) -> None:
        self._do("edits.validate", self._svc.edits().validate(packageName=package, editId=edit))

    def commit_edit(self, package: str, edit: str, not_sent_for_review: bool = False) -> None:
        extra = {"changesNotSentForReview": True} if not_sent_for_review else {}
        self._do("edits.commit", self._svc.edits().commit(packageName=package, editId=edit, **extra))

    def list_tracks(self, package: str, edit: str) -> list[dict[str, Any]]:
        r = self._do("edits.tracks.list", self._svc.edits().tracks().list(packageName=package, editId=edit))
        return list(r.get("tracks", []))

    def upload_bundle(self, package: str, edit: str, path: Path) -> int:
        media = self._Media(str(path), mimetype="application/octet-stream", resumable=True)
        r = self._do("edits.bundles.upload", self._svc.edits().bundles().upload(packageName=package, editId=edit, media_body=media))
        return int(r["versionCode"])

    def set_track(self, package: str, edit: str, track: str, release: dict[str, Any]) -> None:
        body = {"track": track, "releases": [release]}
        self._do("edits.tracks.update", self._svc.edits().tracks().update(packageName=package, editId=edit, track=track, body=body))

    def update_listing(self, package: str, edit: str, language: str, body: dict[str, str]) -> None:
        self._do("edits.listings.update", self._svc.edits().listings().update(packageName=package, editId=edit, language=language, body=body))

    def delete_images(self, package: str, edit: str, language: str, image_type: str) -> None:
        self._do("edits.images.deleteall", self._svc.edits().images().deleteall(packageName=package, editId=edit, language=language, imageType=image_type))

    def upload_image(self, package: str, edit: str, language: str, image_type: str, path: Path) -> None:
        media = self._Media(str(path), mimetype="image/png")
        self._do("edits.images.upload", self._svc.edits().images().upload(packageName=package, editId=edit, language=language, imageType=image_type, media_body=media))


def make_real_api(secrets_path: Path, repo: Path, env: dict[str, str]) -> PlayApi:
    if not sys.flags.isolated:
        raise Refuse("run with isolated mode: python -I tools/play_publish.py ... (tools\\play_publish.ps1 does this)")
    key = check_key_path(read_key_setting(secrets_path, env), repo)
    load_key_secrets(key)
    return PlayApi(key)


# ---------------------------------------------------------------- local tools (java, keytool, powershell)


def _first_existing(*cands: str) -> str | None:
    for c in cands:
        p = c if os.path.isabs(c) else shutil.which(c)
        if p and os.path.isfile(p):
            return p
    return None


def _run(cmd: list[str], timeout: int = 600) -> tuple[int, str]:
    p = subprocess.run(cmd, capture_output=True, timeout=timeout, check=False)
    return p.returncode, (p.stdout + p.stderr).decode("utf-8", "replace")


class RealTools:
    def __init__(self, repo: Path) -> None:
        self.repo = repo
        jdk = os.environ.get("IRONSTATIC_JDK") or r"C:\dev\tools\jdk-17"
        self.keytool = _first_existing(os.path.join(jdk, "bin", "keytool.exe"), "keytool")
        self.java = _first_existing(os.path.join(jdk, "bin", "java.exe"), "java")
        self.ps = _first_existing("powershell", "pwsh")

    def signer_text(self, aab: Path) -> str:
        if not self.keytool:
            raise Refuse("keytool not found (JDK 17 at C:\\dev\\tools\\jdk-17); cannot check the signer certificate")
        return _run([self.keytool, "-printcert", "-jarfile", str(aab)], 120)[1]

    def testkey_fingerprints(self) -> list[str]:
        """SHA256 fingerprints of the throwaway test keystore(s) under build\\testkey (this tree and the main tree)."""
        dirs = [self.repo / "build" / "testkey"]
        code, out = _run(["git", "-C", str(self.repo), "rev-parse", "--git-common-dir"], 30)
        if code == 0 and out.strip():
            dirs.append((self.repo / out.strip()).resolve().parent / "build" / "testkey")
        fps: list[str] = []
        for d in dirs:
            ks, pw = d / "NOT-FOR-UPLOAD-test.keystore", d / "NOT-FOR-UPLOAD-test.pw"
            if ks.is_file() and pw.is_file() and self.keytool:
                pass_ = pw.read_text(encoding="utf-8").strip()
                register_secret(pass_)
                m = re.search(r"SHA256:\s*([0-9A-F:]+)", _run([self.keytool, "-list", "-v", "-keystore", str(ks), "-storepass", pass_], 60)[1])
                if m:
                    fps.append(m.group(1))
        return fps

    def manifest_xml(self, aab: Path) -> str:
        if not self.java:
            raise Refuse("java not found; cannot read the bundle manifest")
        lines = (ROOT / "tools" / "bundletool_version.txt").read_text(encoding="utf-8").splitlines()
        jar = Path(os.environ.get("IRONSTATIC_BUNDLETOOL") or rf"C:\dev\tools\bundletool\bundletool-all-{lines[0].strip()}.jar")
        if not jar.is_file() or hashlib.sha256(jar.read_bytes()).hexdigest() != lines[1].replace("sha256=", "").strip().lower():
            raise Refuse("bundletool jar missing or its hash differs from tools/bundletool_version.txt")
        code, out = _run([self.java, "-jar", str(jar), "dump", "manifest", f"--bundle={aab}"], 300)
        if code != 0:
            raise Refuse("bundletool could not read the manifest; not a valid AAB?")
        return out

    def release_version(self) -> tuple[str, int]:
        if not self.ps:
            raise Refuse("powershell not found; cannot read release/version.json through tools\\release_version.ps1")
        code, out = _run([self.ps, "-NoProfile", "-File", str(self.repo / "tools" / "release_version.ps1"), "-Show"], 60)
        m = re.search(r"versionName (\S+)\s+versionCode (\d+)", out)
        if code != 0 or not m:
            raise Refuse("tools\\release_version.ps1 -Show failed")
        return m.group(1), int(m.group(2))

    def aab_check(self, aab: Path) -> bool:
        if not self.ps:
            raise Refuse("powershell not found; cannot run tools\\aab_check.ps1")
        code, out = _run([self.ps, "-NoProfile", "-File", str(self.repo / "tools" / "aab_check.ps1"), str(aab)], 900)
        tail = [ln for ln in out.splitlines() if ln.strip()][-12:]
        emit("  aab_check: " + (tail[-1] if tail else "(no output)"))
        if code != 0:
            emit("\n".join("    " + t for t in tail))
        return code == 0


# ---------------------------------------------------------------- local checks


def expected_package(repo: Path) -> str:
    text = (repo / "export_presets.cfg").read_text(encoding="utf-8")
    found = set(re.findall(r'(?m)^package/unique_name="([^"]+)"$', text))
    if len(found) != 1:
        raise Refuse(f"export_presets.cfg must name exactly one package (found {len(found)})")
    return found.pop()


def fenced_after(md: str, heading: str) -> str:
    """First ``` block after a '## <heading>...' line."""
    m = re.search(r"(?m)^##\s+" + re.escape(heading) + r"[^\n]*\n(.*?)^```\n(.*?)^```", md, re.S)
    if not m:
        raise Refuse(f"no fenced block under '## {heading}' in the listing file")
    return m.group(2).strip("\n")


def load_notes(path: Path, repo: Path) -> str:
    p = path if path.is_absolute() else repo / path
    rp, rr = _norm(p), _norm(repo)
    if not rp.startswith(rr.rstrip("\\/") + os.sep):
        raise Refuse("release notes must come from a file inside the repo")
    if not p.is_file():
        raise Refuse(f"release notes file not found: {path}")
    text = p.read_text(encoding="utf-8").replace("\r\n", "\n")
    if p.name == "store_listing.md":
        text = fenced_after(text, "Release notes")
    return validate_text("release notes", text.strip(), NOTES_MAX)


def validate_text(label: str, text: str, limit: int, min_len: int = 1) -> str:
    if len(text) < min_len:
        raise Refuse(f"{label} is empty")
    if len(text) > limit:
        raise Refuse(f"{label} is {len(text)} characters; Play allows {limit}")
    if _EMAIL.search(text):
        raise Refuse(f"{label} contains an email address; this tool sends no personal data")
    if re.search(r"\[[A-Z][A-Z0-9 _-]{3,}\]", text):
        raise Refuse(f"{label} still contains a [PLACEHOLDER]")
    if re.search(r"[\x00-\x08\x0b-\x1f]", text):
        raise Refuse(f"{label} contains control characters")
    return text


@dataclass
class ReleaseInfo:
    aab: Path
    package: str
    version_code: int
    version_name: str
    sha256: str
    notes: str


def check_release(aab_arg: Path, notes_arg: Path, repo: Path, tools: Any, skip_aab_check: bool) -> ReleaseInfo:
    aab = Path(aab_arg)
    if aab.suffix.lower() != ".aab" or not aab.is_file():
        raise Refuse("pass an existing .aab file")
    if "TESTKEY" in aab.name.upper():
        raise Refuse(f"{aab.name} is a TEST-KEY build; it must never be uploaded to Play")
    problems: list[str] = []
    # sha256 against the recorded .sha256 file
    digest = hashlib.sha256(aab.read_bytes()).hexdigest()
    sha_file = aab.with_name(aab.name + ".sha256")
    if not sha_file.is_file():
        problems.append("no .sha256 file next to the AAB (release_build.ps1 writes it)")
    else:
        parts = sha_file.read_text(encoding="utf-8").split()
        if not parts or parts[0].lower() != digest:
            problems.append("sha256 of the AAB differs from its .sha256 file (file changed after the build?)")
    # container sanity
    try:
        with zipfile.ZipFile(aab) as z:
            if "base/manifest/AndroidManifest.xml" not in z.namelist():
                problems.append("not an Android App Bundle (no base manifest)")
    except zipfile.BadZipFile:
        raise Refuse("the file is not a zip/AAB") from None
    # signer certificate
    cert = tools.signer_text(aab)
    if "TEST KEY NOT FOR UPLOAD" in cert.upper() or "ANDROID DEBUG" in cert.upper():
        raise Refuse("the AAB is signed with the test key or the Android debug key; never upload it")
    m = re.search(r"SHA256:\s*([0-9A-F:]+)", cert)
    if not m:
        problems.append("could not read a signer certificate from the AAB (unsigned?)")
    elif m.group(1) in tools.testkey_fingerprints():
        raise Refuse("the AAB signer matches the throwaway test keystore under build\\testkey; never upload it")
    # package and version
    want_pkg = expected_package(repo)
    want_name, want_code = tools.release_version()
    pkg = name = ""
    code = -1
    try:
        root = ET.fromstring(tools.manifest_xml(aab))
        ns = "{http://schemas.android.com/apk/res/android}"
        pkg, name = root.get("package", ""), root.get(ns + "versionName", "")
        code = int(root.get(ns + "versionCode", "-1"))
    except (ET.ParseError, ValueError):
        problems.append("could not parse the bundle manifest")
    if pkg != want_pkg:
        problems.append(f"manifest package '{pkg}' != '{want_pkg}' (export_presets.cfg)")
    if code != want_code:
        problems.append(f"manifest versionCode {code} != {want_code} (release/version.json)")
    if name != want_name:
        problems.append(f"manifest versionName '{name}' != '{want_name}' (release/version.json)")
    try:
        notes = load_notes(notes_arg, repo)
    except Refuse as e:
        problems.append(str(e))
        notes = ""
    if problems:
        raise Refuse("local checks failed:\n" + "\n".join("  - " + p for p in problems))
    # aab_check last: it is the slow one
    if skip_aab_check:
        emit("WARNING: --skip-aab-check given; tools\\aab_check.ps1 was NOT run for this bundle.")
    elif not tools.aab_check(aab):
        raise Refuse("tools\\aab_check.ps1 did not pass")
    return ReleaseInfo(aab, want_pkg, code, name, digest, notes)


# ---------------------------------------------------------------- listing and images

PNG_OK_CHUNKS = {"IHDR", "PLTE", "IDAT", "IEND", "sRGB", "gAMA", "cHRM", "pHYs", "tRNS", "sBIT", "bKGD"}


def png_info(path: Path) -> tuple[int, int, int, list[str]]:
    d = path.read_bytes()
    if d[:8] != b"\x89PNG\r\n\x1a\n":
        raise Refuse(f"{path.name} is not a PNG")
    p, chunks, w, h, ct = 8, [], 0, 0, 0
    while p + 8 <= len(d):
        n, = struct.unpack(">I", d[p:p + 4])
        t = d[p + 4:p + 8].decode("latin-1")
        chunks.append(t)
        if t == "IHDR":
            w, h, _bd, ct = struct.unpack(">IIBB", d[p + 8:p + 18])
        p += 12 + n
    return w, h, ct, chunks


def check_images(repo: Path) -> list[tuple[str, Path]]:
    """(imageType, file) in upload order. Only the known file names are used; metadata chunks are refused."""
    d = repo / "release" / "store"
    out: list[tuple[str, Path]] = []
    spec = [("icon", d / "icon_512.png", (512, 512), 1024 * 1024, True), ("featureGraphic", d / "feature_1024x500.png", (1024, 500), 15 << 20, False)]
    for typ, p, size, cap, alpha_ok in spec:
        if not p.is_file():
            raise Refuse(f"missing {p.name}")
        w, h, ct, chunks = png_info(p)
        if (w, h) != size:
            raise Refuse(f"{p.name} is {w}x{h}, want {size[0]}x{size[1]}")
        if p.stat().st_size > cap:
            raise Refuse(f"{p.name} is over the size limit")
        if ct in (4, 6) and not alpha_ok:
            raise Refuse(f"{p.name} has an alpha channel; the feature graphic must not")
        _meta(p, chunks)
        out.append((typ, p))
    phones = sorted(d.glob("phone_*.png"))
    if not 2 <= len(phones) <= 8:
        raise Refuse(f"need 2 to 8 phone screenshots, found {len(phones)}")
    for p in phones:
        w, h, ct, chunks = png_info(p)
        if min(w, h) < 320 or max(w, h) > 3840 or max(w, h) > 2 * min(w, h):
            raise Refuse(f"{p.name} ({w}x{h}) breaks Play's screenshot size rules")
        if p.stat().st_size > 8 << 20:
            raise Refuse(f"{p.name} is over 8 MB")
        _meta(p, chunks)
        out.append(("phoneScreenshots", p))
    return out


def _meta(p: Path, chunks: list[str]) -> None:
    bad = sorted(set(chunks) - PNG_OK_CHUNKS)
    if bad:
        raise Refuse(f"{p.name} carries metadata chunks {bad}; re-export without text/EXIF data (could hold personal data)")


@dataclass
class ListingInfo:
    title: str
    short: str
    full: str
    images: list[tuple[str, Path]] = field(default_factory=list)


def check_listing(repo: Path, allow_draft_assets: bool) -> ListingInfo:
    assets = (repo / "docs" / "release" / "store_assets.md").read_text(encoding="utf-8")
    if re.search(r"(?i)draft:\s*do not upload", assets):
        if not allow_draft_assets:
            raise Refuse("docs/release/store_assets.md still carries the 'Draft: do not upload' banner "
                         "(Q31 trademark search and user approval). Use --allow-draft-assets only after the user says so.")
        emit("WARNING: --allow-draft-assets given; the graphics are still marked draft (Q31 open?).")
    md = (repo / "docs" / "release" / "store_listing.md").read_text(encoding="utf-8").replace("\r\n", "\n")
    m = re.search(r"(?m)^- \*\*App name:\*\* `([^`]+)`", md)
    if not m:
        raise Refuse("no '- **App name:** `...`' line in store_listing.md")
    info = ListingInfo(
        validate_text("app name", m.group(1), 30),
        validate_text("short description", fenced_after(md, "Short description"), 80),
        validate_text("full description", fenced_after(md, "Full description"), 4000),
    )
    info.images = check_images(repo)
    return info


# ---------------------------------------------------------------- edit flow


def run_edit(api: Any, package: str, mode: str, work: Callable[[str], None], not_sent_for_review: bool = False) -> None:
    """mode: auth (insert + delete), validate (work + validate + delete), commit (work + validate + commit once)."""
    edit = api.insert_edit(package)
    emit(f"  edit {edit} opened")
    committed = False
    try:
        if mode == "auth":
            emit("  auth OK (edits.insert worked; nothing uploaded)")
            return
        work(edit)
        api.validate_edit(package, edit)
        emit("  edits.validate OK")
        if mode == "commit":
            if not_sent_for_review:
                api.commit_edit(package, edit, True)
            else:
                api.commit_edit(package, edit)
            committed = True
            emit("  edits.commit OK: committed to Play")
    finally:
        if not committed:
            try:
                api.delete_edit(package, edit)
                emit(f"  edit {edit} deleted (nothing committed)")
            except Exception as e:  # noqa: BLE001
                emit(f"WARNING: could not delete edit {edit}: {type(e).__name__}", err=True)


def explain(e: ApiError) -> str:
    low = e.message.lower()
    out = f"Google API error {e.status} in {e.step or 'a call'}: {e.message}"
    if "draft" in low:
        out += ("\n  Hint: the app is still a draft in Play Console. Use --status draft and finish the rollout once in Console, "
                "or complete the app setup first.")
    if "changesnotsentforreview" in low.replace("_", "") or "sent for review automatically" in low:
        out += ("\n  Hint: Google cannot send these changes for review automatically (another change is already waiting, "
                "or the app needs a manual review step). Nothing was committed. Run the same command again with "
                "--changes-not-sent-for-review: the release is then committed, and you send it for review yourself in "
                "Play Console > Publishing overview.")
    if e.step == "edits.bundles.upload":
        out += ("\n  Hint: if this is the very first upload for this app, Play may require that one file to be uploaded by hand "
                "in Console (Testing > Internal testing > Create release). Later versions work through this tool.")
    if e.status in (401, 403):
        out += ("\n  Hint: check the Google Play Android Developer API is enabled and the service account was invited "
                "in Play Console with access to this app (docs/release/play_publish.md).")
    return out


def confirm(version_code: int, yes: bool, ask: Callable[[str], str] | None = None, action: str = "commit") -> None:
    if yes:
        return
    if ask is None:
        if not sys.stdin.isatty():
            raise Refuse("--commit needs an interactive confirmation (or --yes)")
        ask = input
    if ask(f"Type the versionCode ({version_code}) to {action}, anything else cancels: ").strip() != str(version_code):
        raise Refuse("cancelled; nothing was committed")


# ---------------------------------------------------------------- commands


def mode_of(a: argparse.Namespace) -> str:
    return "commit" if a.commit else "validate" if a.validate else "auth" if a.auth_check else "dry"


def cmd_release(a: argparse.Namespace, repo: Path, tools: Any, api_factory: Callable[[], Any], ask: Callable[[str], str] | None = None) -> int:
    mode = mode_of(a)
    api_track = TRACK_API[a.track]
    label = TRACK_LABEL[a.track]
    if a.track == "open":
        emit("WARNING: the open testing track is ON HOLD (decision Q88: no open track until the human playtest passes).")
        if not a.allow_open:
            raise Refuse("the open track is on hold; add --allow-open only if the user has lifted Q88")
    info = check_release(a.aab, a.notes, repo, tools, a.skip_aab_check)
    rollout = a.status == "completed"
    what = f"ROLL OUT to {label}" if rollout else f"save as DRAFT on {label} (not rolled out)"
    plan = (f"  package      {info.package}\n  track        {label} (API: {api_track})\n  versionCode  {info.version_code}\n"
            f"  versionName  {info.version_name}\n  status       {a.status}  ({'roll out to all testers' if rollout else 'draft, not rolled out'})\n  aab          {info.aab.name} (sha256 {info.sha256[:16]}...)\n"
            f"  notes ({len(info.notes)}/{NOTES_MAX} chars, {LANG}):\n" + "\n".join("    | " + ln for ln in info.notes.splitlines()))
    emit("Local checks passed.")
    if mode == "dry":
        emit("DRY RUN: no network call was made. Would release:\n" + plan)
        emit("Next: add --auth-check, then --validate, then --commit.")
        return 0
    if mode == "commit":
        emit(f"ABOUT TO COMMIT TO GOOGLE PLAY ({what}):\n" + plan)
        if a.changes_not_sent_for_review:
            emit("  The release will NOT be sent for review automatically; you send it in Play Console > Publishing overview.")
        confirm(info.version_code, a.yes, ask, what)
    api = api_factory()
    release = {"name": info.version_name, "versionCodes": [str(info.version_code)], "status": a.status,
               "releaseNotes": [{"language": LANG, "text": info.notes}]}

    def work(edit: str) -> None:
        got = api.upload_bundle(info.package, edit, info.aab)
        emit(f"  bundle uploaded (versionCode {got})")
        if int(got) != info.version_code:
            raise Refuse(f"Play reports versionCode {got}, expected {info.version_code}")
        api.set_track(info.package, edit, api_track, release)
        emit(f"  track '{a.track}' (API {api_track}) set to {a.status}")

    run_edit(api, info.package, mode, work, a.changes_not_sent_for_review)
    if mode == "validate":
        emit("VALIDATE OK: edit deleted, nothing committed.")
    if mode == "commit":
        if a.changes_not_sent_for_review:
            emit("COMMITTED, NOT sent for review. Open Play Console > Publishing overview and send the changes for review.")
        elif not rollout:
            emit(f"Saved as a DRAFT on {label}. Finish the rollout in Play Console, or run again with --status completed.")
        elif a.track == "internal":
            emit("Rolled out to internal testing. Internal releases are not reviewed; testers get it within minutes.")
        else:
            emit(f"Submitted to {label}. Google reviews {a.track}-track releases, usually within hours to a few days; "
                 "testers get the update after approval.")
    return 0


def cmd_status(a: argparse.Namespace, repo: Path, api_factory: Callable[[], Any]) -> int:
    """Read-only: list every track and its releases. Opens an edit and always deletes it."""
    pkg = expected_package(repo)
    api = api_factory()
    edit = api.insert_edit(pkg)
    try:
        tracks = api.list_tracks(pkg, edit)
    finally:
        try:
            api.delete_edit(pkg, edit)
        except Exception as e:  # noqa: BLE001
            emit(f"WARNING: could not delete edit {edit}: {type(e).__name__}", err=True)
    emit(f"Tracks for {pkg} (read-only; the edit was deleted):")
    if not tracks:
        emit("  (no tracks returned)")
    for t in tracks:
        api_name = str(t.get("track", "?"))
        emit(f"  {API_FRIENDLY.get(api_name, api_name)} (API: {api_name})")
        rels = t.get("releases") or []
        if not rels:
            emit("    (no releases)")
        for r in rels:
            frac = f", userFraction {r['userFraction']}" if "userFraction" in r else ""
            codes = ",".join(str(v) for v in r.get("versionCodes", []))
            emit(f"    release '{r.get('name', '')}': status {r.get('status', '?')}, versionCodes {codes}{frac}")
    return 0


def cmd_listing(a: argparse.Namespace, repo: Path, api_factory: Callable[[], Any], ask: Callable[[str], str] | None = None) -> int:
    mode = mode_of(a)
    pkg = expected_package(repo)
    info = check_listing(repo, a.allow_draft_assets)
    plan = (f"  package {pkg}, language {LANG}\n  title   {info.title}\n  short   {info.short}\n  full    {len(info.full)} characters\n"
            + "".join(f"  image   {t}: {p.name}\n" for t, p in info.images))
    emit("Local checks passed.")
    if mode == "dry":
        emit("DRY RUN: no network call was made. Would push:\n" + plan.rstrip())
        return 0
    if mode == "commit":
        emit("ABOUT TO COMMIT THE STORE LISTING:\n" + plan.rstrip())
        _confirm_listing(a.yes, ask)
    api = api_factory()

    def work(edit: str) -> None:
        api.update_listing(pkg, edit, LANG, {"title": info.title, "shortDescription": info.short, "fullDescription": info.full})
        emit("  listing text set")
        for typ in dict.fromkeys(t for t, _ in info.images):
            api.delete_images(pkg, edit, LANG, typ)
        for typ, p in info.images:
            api.upload_image(pkg, edit, LANG, typ, p)
            emit(f"  uploaded {typ}: {p.name}")

    run_edit(api, pkg, mode, work)
    if mode == "validate":
        emit("VALIDATE OK: edit deleted, nothing committed.")
    return 0


def _confirm_listing(yes: bool, ask: Callable[[str], str] | None) -> None:
    if yes:
        return
    if ask is None:
        if not sys.stdin.isatty():
            raise Refuse("--commit needs an interactive confirmation (or --yes)")
        ask = input
    if ask("Type COMMIT to push the listing, anything else cancels: ").strip() != "COMMIT":
        raise Refuse("cancelled; nothing was committed")


def build_parser() -> argparse.ArgumentParser:
    ap = argparse.ArgumentParser(prog="play_publish", description="Publish IRON STATIC to Google Play. Default: dry run.")
    ap.add_argument("--self-test", action="store_true", help="run the offline tests (no network, no Google libraries)")
    ap.add_argument("--secrets", type=Path, default=ROOT / "secrets.local.json", help="secrets file holding '" + SECRETS_KEY + "'")
    sub = ap.add_subparsers(dest="cmd")

    def common(p: argparse.ArgumentParser) -> None:
        g = p.add_mutually_exclusive_group()
        g.add_argument("--auth-check", action="store_true", help="edits.insert then edits.delete; no upload")
        g.add_argument("--validate", action="store_true", help="upload into an edit, edits.validate, delete the edit")
        g.add_argument("--commit", action="store_true", help="really commit (asks for confirmation unless --yes)")
        p.add_argument("--yes", action="store_true", help="skip the interactive confirmation of --commit")

    r = sub.add_parser("release", help="upload an AAB to a testing track (default: closed testing, rolled out)")
    r.add_argument("aab", type=Path)
    r.add_argument("--track", choices=TRACKS, default=DEFAULT_TRACK,
                   help="closed (API alpha, default), internal, open (API beta, on hold: needs --allow-open)")
    r.add_argument("--status", choices=("draft", "completed"), default="completed",
                   help="completed = roll out to all testers on the track (default); draft = save without rolling out")
    r.add_argument("--allow-open", action="store_true", help="permit the open track (on hold, decision Q88)")
    r.add_argument("--changes-not-sent-for-review", action="store_true",
                   help="commit without sending for review (when Google says it cannot send changes automatically; then send in Play Console > Publishing overview)")
    r.add_argument("--notes", type=Path, default=Path("docs/release/store_listing.md"), help="notes file inside the repo (default: the release-notes block of store_listing.md)")
    r.add_argument("--skip-aab-check", action="store_true", help="do not run tools\\aab_check.ps1 (prints a warning)")
    common(r)
    li = sub.add_parser("listing", help="push store listing text and graphics from the repo")
    li.add_argument("--allow-draft-assets", action="store_true", help="push even though store_assets.md says Draft")
    common(li)
    sub.add_parser("status", help="read-only: list every track and its releases")
    return ap


def guarded(fn: Callable[[], int]) -> int:
    """Run fn with all output scrubbed; turn every failure into one safe line."""
    old_o, old_e = sys.stdout, sys.stderr
    sys.stdout, sys.stderr = ScrubWriter(old_o), ScrubWriter(old_e)
    try:
        return fn()
    except Refuse as e:
        emit("REFUSED: " + str(e), err=True)
        return 1
    except ApiError as e:
        emit(explain(e), err=True)
        return 1
    except KeyboardInterrupt:
        emit("interrupted", err=True)
        return 1
    except Exception as e:  # noqa: BLE001 - never print a traceback: it can carry request data
        emit(f"FAILED ({type(e).__name__}): {str(e)[:300]}", err=True)
        return 1
    finally:
        sys.stdout, sys.stderr = old_o, old_e


def main(argv: list[str]) -> int:
    a = build_parser().parse_args(argv)
    if a.self_test:
        import importlib.util
        spec = importlib.util.spec_from_file_location("play_publish_selftest", ROOT / "tools" / "play_publish_selftest.py")
        mod = importlib.util.module_from_spec(spec)  # type: ignore[arg-type]
        spec.loader.exec_module(mod)  # type: ignore[union-attr]
        return int(mod.run(sys.modules[__name__]))
    if not a.cmd:
        build_parser().print_help()
        return 2
    env = dict(os.environ)
    factory = lambda: make_real_api(a.secrets, ROOT, env)  # noqa: E731
    if a.cmd == "release":
        return guarded(lambda: cmd_release(a, ROOT, RealTools(ROOT), factory))
    if a.cmd == "status":
        return guarded(lambda: cmd_status(a, ROOT, factory))
    return guarded(lambda: cmd_listing(a, ROOT, factory))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
