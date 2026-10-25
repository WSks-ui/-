#!/usr/bin/env python3
"""通过 HDC 操作真实 ArkUI 的五城离线演示；只依赖 Python 标准库。"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import re
import shlex
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from typing import Callable, Iterable
import uuid


BUNDLE = "com.yunheji.archive"
ABILITY = "EntryAbility"
TEST_STORE = re.compile(r"yunheji_test_ui_[a-z0-9_]{1,80}\Z")
CITIES = (
    ("roam-smx-earth-home", "三门峡", "黄土里的家"),
    ("roam-ly-spring", "洛阳", "这一城春色，为谁而开"),
    ("roam-zz-zhenwei", "郑州", "溱洧河边，去赴一次相会"),
    ("roam-kf-night", "开封", "点亮汴京的一夜"),
    ("roam-py-dragon-memory", "濮阳", "龙乡的故事，怎样留到今天"),
)
CHAPTER_TITLE = "点亮汴京的一夜"
NOTE_TITLE = "点亮汴京的一夜 · 为这一夜点一盏灯"
LANTERN_GOAL = "读过两种年代的灯事，为原创灯景选择祝愿"
SOURCE_TITLE = "中国非物质文化遗产网·汴京灯笼张"
SOURCE_URL = "https://www.ihchina.cn/project_details/14067.html"
SCENE_SCROLLS = ("roam-chapter-scroll", "roam-chapter-wide-scroll")
WRITING_SCROLLS = ("roam-sheet-scroll", "roam-writing-column", "roam-reading-column")
READING_SCROLLS = ("roam-sheet-scroll", "roam-reading-column")
PAGE_MARKERS = ("roaming-home", "roaming-chapter-page", "roam-personal-scroll", "roam-memory-scroll")
PRIVATE_IDS = ("profile-page", "profile-scroll", "account-panel", "account-username", "account-password")
VERIFIED_IME_BUNDLE = "com.huawei.hmos.inputmethod"


class DemoError(RuntimeError):
    pass


class DemoStopped(DemoError):
    pass


class StopGuard:
    def __init__(self, stop_file: Path):
        self.stop_file = stop_file
        self.interrupted = False

    def handle_signal(self, _number: int, _frame: object) -> None:
        self.interrupted = True

    def check(self) -> None:
        if self.interrupted:
            raise DemoStopped("收到 Ctrl+C；已停止，不再发送设备命令。")
        if self.stop_file.exists():
            raise DemoStopped("检测到停止文件；已停止，不再发送设备命令。")

    def sleep(self, seconds: float) -> None:
        deadline = time.monotonic() + seconds
        while True:
            self.check()
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                return
            time.sleep(min(0.1, remaining))


class Hdc:
    def __init__(self, executable: str, target: str, output: Path, guard: StopGuard):
        self.executable, self.target, self.output, self.guard = executable, target, output, guard
        self.stage = "preflight"
        self.command_count = 0

    def run(self, *arguments: str, timeout: float = 25) -> str:
        # 所有外部命令统一经过这里。停止后只写本机结果，不通过“清理”继续控制设备。
        self.guard.check()
        argv = [self.executable, "-t", self.target, *map(str, arguments)]
        started = time.monotonic()
        self.command_count += 1
        process = None
        stdout, stderr, outcome = "", "", "completed"
        try:
            process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       encoding="utf-8", errors="replace")
            while True:
                self.guard.check()
                if time.monotonic() - started > timeout:
                    raise DemoError("HDC 命令超时；停止本轮，保留当前页面。")
                try:
                    stdout, stderr = process.communicate(timeout=0.1)
                    break
                except subprocess.TimeoutExpired:
                    continue
            self.guard.check()
            if process.returncode != 0 or re.search(r"(?im)^\s*(?:error:|\[fail\])", stdout + "\n" + stderr):
                raise DemoError("HDC 命令报告失败；请查看 commands.jsonl 的原始结果。")
            return stdout
        except (DemoError, OSError):
            outcome = "stopped" if self.guard.interrupted or self.guard.stop_file.exists() else "failed"
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    stdout, stderr = process.communicate(timeout=2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    stdout, stderr = process.communicate()
            raise
        finally:
            # 命令只包含目标设备、固定工具参数和公开的演示文字，不读取账号、token 或密码。
            record = {"number": self.command_count, "stage": self.stage, "argv": argv,
                      "elapsedSeconds": round(time.monotonic() - started, 3), "outcome": outcome,
                      "exitCode": process.returncode if process else None, "stdout": stdout, "stderr": stderr}
            with (self.output / "commands.jsonl").open("a", encoding="utf-8") as stream:
                stream.write(json.dumps(record, ensure_ascii=False) + "\n")

    def shell(self, *arguments: str, timeout: float = 25) -> str:
        # HDC 的 shell 端仍有 POSIX shell；不能用 JSON/Windows 引号代替逐参数 shell 转义。
        return self.run("shell", " ".join(shlex.quote(str(value)) for value in arguments), timeout=timeout)


@dataclass(frozen=True)
class Rect:
    left: int
    top: int
    right: int
    bottom: int

    @classmethod
    def parse(cls, value: str) -> Rect | None:
        numbers = re.findall(r"-?\d+", str(value))
        return cls(*map(int, numbers)) if len(numbers) == 4 else None

    @property
    def width(self) -> int:
        return max(0, self.right - self.left)

    @property
    def height(self) -> int:
        return max(0, self.bottom - self.top)

    @property
    def center(self) -> tuple[int, int]:
        return (self.left + self.right) // 2, (self.top + self.bottom) // 2

    def intersect(self, other: Rect) -> Rect:
        return Rect(max(self.left, other.left), max(self.top, other.top),
                    min(self.right, other.right), min(self.bottom, other.bottom))


@dataclass(eq=False)
class Node:
    attrs: dict
    raw: dict
    parent: Node | None = None
    children: list[Node] = field(default_factory=list)

    @property
    def id(self) -> str:
        return str(self.attrs.get("id", ""))

    @property
    def text(self) -> str:
        return str(self.attrs.get("text", ""))

    @property
    def rect(self) -> Rect | None:
        return Rect.parse(self.attrs.get("bounds", ""))

    def ancestry(self) -> Iterable[Node]:
        current: Node | None = self
        while current is not None:
            yield current
            current = current.parent

    def subtree(self) -> Iterable[Node]:
        yield self
        for child in self.children:
            yield from child.subtree()

    def alive(self) -> bool:
        for item in self.ancestry():
            if str(item.attrs.get("visible", "")).lower() == "false":
                return False
            try:
                if float(item.attrs.get("opacity") or 1) <= 0:
                    return False
            except ValueError:
                return False
        return True

    def visible_rect(self, screen: Rect) -> Rect | None:
        if not self.alive() or not self.rect:
            return None
        visible = self.rect.intersect(screen)
        for parent in list(self.ancestry())[1:]:
            # 只按真实裁切容器计算交集；长 Column 的内容高度不等于可点击的屏幕区域。
            clips = str(parent.attrs.get("clip", "")).lower() == "true"
            if parent.rect and (clips or parent.attrs.get("type") in ("Scroll", "root", "WindowScene")):
                visible = visible.intersect(parent.rect)
        return visible if visible.width > 0 and visible.height > 0 else None

    def usable(self, screen: Rect) -> bool:
        visible = self.visible_rect(screen)
        original = Rect.parse(self.attrs.get("origBounds", "")) or self.rect
        return bool(visible and original and visible.width >= 24 and visible.height >= 24
                    and visible.width >= original.width * 0.65
                    and visible.height >= min(original.height * 0.65, screen.height * 0.45))

    def contains_text(self, value: str) -> bool:
        return any(value in item.text for item in self.subtree())


class Layout:
    def __init__(self, payload: dict):
        self.payload = payload
        self.nodes: list[Node] = []

        def load(raw: dict, parent: Node | None = None) -> Node:
            node = Node(raw.get("attributes", {}), raw, parent)
            self.nodes.append(node)
            node.children = [load(child, node) for child in raw.get("children", []) if isinstance(child, dict)]
            return node

        self.root = load(payload)
        self.screen = self.root.rect
        if not self.screen or not self.screen.width or not self.screen.height:
            raise DemoError("布局没有有效屏幕范围；请核对设备 uitest 版本。")

    def matching(self, predicate: Callable[[Node], bool], scope: Node | None = None) -> list[Node]:
        return [item for item in (scope.subtree() if scope else self.nodes) if item.alive() and predicate(item)]

    def one(self, node_id: str, scope: Node | None = None) -> Node | None:
        found = self.matching(lambda item: item.id == node_id, scope)
        if len(found) > 1:
            raise DemoError(f"控件 ID 不唯一，停止：{node_id}")
        return found[0] if found else None

    def drawn(self, node: Node) -> bool:
        return node.visible_rect(self.screen) is not None

    def keyboard(self) -> bool:
        return any(self.drawn(item) and re.search(r"inputmethod|keyboard", " ".join(
            str(item.attrs.get(key, "")) for key in ("bundleName", "type", "id")), re.I) for item in self.nodes)

    def initialized_keyboard_roots(self) -> list[Node]:
        roots: list[Node] = []
        for node in self.nodes:
            if node.attrs.get("bundleName") != VERIFIED_IME_BUNDLE or node.attrs.get("type") != "root":
                continue
            if not self.drawn(node) or not re.fullmatch(r"\d+", str(node.attrs.get("hostWindowId", ""))):
                continue
            canvas = self.one("KeyboardCanvas", node)
            keys = self.one("KeyCanvasKeyboard", node)
            hide = self.one("KeyHideKbd", node)
            if not canvas or not keys or not hide or not all(self.drawn(item) for item in (canvas, keys, hide)):
                continue
            if canvas.attrs.get("type") != "RelativeContainer" or keys.attrs.get("type") != "Stack":
                continue
            if not any(parent is canvas for parent in keys.ancestry()) or not canvas.rect:
                continue
            # 只认本轮 API 26 真机布局中的已初始化输入法画布，不按任意 bundle 子串放行。
            # 候选画布须在屏幕下部；首次隐私页没有这组结构，仍由隐私/对话框检查阻断。
            if canvas.rect.top < self.screen.top + self.screen.height * 0.5:
                continue
            roots.append(node)
        return roots

    def keyboard_system_panels(self, ime_roots: list[Node]) -> set[Node]:
        field_node = self.one("roam-note-body")
        if not field_node or str(field_node.attrs.get("focused", "")).lower() != "true":
            return set()
        app_root = next((node for node in field_node.ancestry()
                         if node.attrs.get("bundleName") == BUNDLE and node.attrs.get("type") == "root"), None)
        if not app_root or not app_root.rect:
            return set()
        allowed: set[Node] = set()
        for panel in self.nodes:
            host = str(panel.attrs.get("hostWindowId", ""))
            if panel.attrs.get("bundleName") != "com.ohos.sceneboard" or panel.attrs.get("type") != "WindowScene":
                continue
            if not re.fullmatch(r"\d+", host) or panel.id != f"keyboardPanel{host}" or not self.drawn(panel):
                continue
            # M12 实际 keyboardPanel 的 bounds 与键盘避让后的应用窗口相同，并非键盘区域。
            # 不能把“大面积 sceneboard”整体列白名单；窗口编号还须连接到真实 IME 根窗口。
            if panel.rect != app_root.rect or panel.rect.height >= self.screen.height * 0.8:
                continue
            for ime in ime_roots:
                linked_id = f"keyboard{ime.attrs['hostWindowId']}"
                linked = self.one(linked_id, panel)
                controls = self.one("inputMethodPanel", panel)
                left = self.one("keyboardLeftButton", panel)
                right = self.one("keyboardRightButton", panel)
                if not linked or linked.attrs.get("type") != "WindowScene" or not controls or not left or not right:
                    continue
                if controls.attrs.get("type") != "Stack" or left.attrs.get("type") != "Column" or right.attrs.get("type") != "Column":
                    continue
                if not all(any(parent is controls for parent in button.ancestry()) for button in (left, right)):
                    continue
                known_ids = {"", panel.id, linked_id, "inputMethodPanel", "keyboardLeftButton", "keyboardRightButton"}
                known_types = {"WindowScene", "Stack", "Row", "Column", "Image"}
                if any(node.id not in known_ids or node.attrs.get("type") not in known_types or node.text
                       or node.attrs.get("bundleName", "") not in ("", "com.ohos.sceneboard")
                       or str(node.attrs.get("hostWindowId", "")) != host
                       or (node.attrs.get("type") == "WindowScene" and node not in (panel, linked))
                       for node in panel.subtree()):
                    continue
                allowed.add(panel)
        return allowed

    def share_panel(self) -> Node | None:
        card = self.one("share_card")
        if not card or not self.drawn(card):
            return None
        return next((item for item in list(card.ancestry())[1:]
                     if item.attrs.get("type") == "Navigation"), None)

    def guard_page(self, *, blank_login: bool = False, keyboard: bool = False, share: bool = False) -> str:
        login = self.one("login-scroll")
        is_blank_login = bool(login and self.drawn(login))
        if is_blank_login:
            # 登录页永不成为证据。仅空白表单可点击离线入口，任何已有凭据都原样保留并停止。
            if not blank_login:
                raise DemoError("当前是登录页；本轮没有保存该页面，请人工返回离线首页后再运行。")
            for field_id in ("account-username", "account-password"):
                node = self.one(field_id)
                if not node or node.text or node.attrs.get("originalText"):
                    raise DemoError("登录表单非空或结构不符；停止，不读取、记录或提交凭据。")
        if any(item.id in PRIVATE_IDS and self.drawn(item)
               and not (is_blank_login and item.id in ("account-username", "account-password"))
               for item in self.nodes):
            raise DemoError("检测到账号或个人设置页面；已停止且不保存该页面。")
        if any(self.drawn(item) and any(word in item.text for word in
               ("同意基本模式", "同意并继续", "隐私声明", "输入法隐私", "隐私保护指引")) for item in self.nodes):
            raise DemoError("输入法或系统隐私初始化尚未完成；请人工准备后使用新的测试库重跑。")
        panel = self.share_panel()
        if panel and not share:
            raise DemoError("出现非预期分享面板；停止，不选择分享对象。")
        if self.keyboard() and not keyboard:
            raise DemoError("出现非预期软键盘；停止，避免 Back 误退页面。")
        focused_field = self.one("roam-note-body")
        typing_own_note = bool(keyboard and focused_field
                               and str(focused_field.attrs.get("focused", "")).lower() == "true")
        ime_roots = self.initialized_keyboard_roots() if typing_own_note else []
        keyboard_panels = self.keyboard_system_panels(ime_roots) if typing_own_note else set()
        known = [marker for marker in PAGE_MARKERS if (node := self.one(marker)) and self.drawn(node)]
        if not known and not is_blank_login and not (share and panel):
            raise DemoError("当前页面不在原生演示路径中；请手动打开云河纪漫游首页。")
        for node in self.nodes:
            bundle = str(node.attrs.get("bundleName", ""))
            visible = node.visible_rect(self.screen)
            if not bundle or bundle == BUNDLE or not visible:
                continue
            is_keyboard = node in ime_roots
            is_share = bool(share and panel and any(item is node for item in panel.ancestry()))
            host = str(node.attrs.get("hostWindowId", ""))
            at_screen_edge = visible.top <= self.screen.top + self.screen.height * 0.09 or visible.bottom >= self.screen.bottom - self.screen.height * 0.09
            small_system_bar = (bundle == "com.ohos.sceneboard" and node.attrs.get("type") == "WindowScene"
                                and node.id in ("", f"session{host}") and at_screen_edge
                                and visible.height < self.screen.height * 0.09)
            if not (small_system_bar or is_keyboard or node in keyboard_panels or is_share):
                raise DemoError("检测到其他应用或系统遮挡；停止，不猜测弹窗按钮。")
        # 同一窗口中的未知 Dialog 也不能被后台页面的控件吸收点击。
        for node in self.nodes:
            if self.drawn(node) and node.attrs.get("type") in ("Dialog", "AlertDialog", "Menu"):
                if not (share and panel and any(item is node for item in panel.ancestry())):
                    raise DemoError("检测到额外对话框或菜单；停止，等待人工处理。")
        return "blank-login" if is_blank_login else known[-1] if known else "share"

    def safe_payload(self) -> dict:
        # 原始命令日志完整保留；布局证据只保存应用树，排除状态栏、输入法与其他应用。
        # 凭据节点即使在后台树中也不能落到本机证据文件。
        if any(item.id in PRIVATE_IDS or item.id.startswith("login-") for item in self.nodes):
            raise DemoError("布局仍含个人页或登录节点；不保存截图及布局。")
        roots = [item.raw for item in self.nodes if item.attrs.get("bundleName") == BUNDLE
                 and not any(parent.attrs.get("bundleName") == BUNDLE for parent in list(item.ancestry())[1:])]
        if not roots:
            raise DemoError("没有可保存的应用布局证据。")
        return {"attributes": {"bounds": self.root.attrs["bounds"]}, "children": roots}


def parse_bundle_debug(output: str) -> bool:
    """只接受已安装包的明确 Debug 双标记；不根据文件名或本机待安装 HAP 推断。"""
    decoder = json.JSONDecoder()
    candidates: list[dict] = []
    for match in re.finditer(r"\{", output):
        try:
            value, _ = decoder.raw_decode(output[match.start():])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            candidates.append(value)
            break
    if not candidates:
        return False
    flags: list[tuple[object, object]] = []

    def visit(value: object, bundle: str = "") -> None:
        if isinstance(value, dict):
            bundle = str(value.get("bundleName") or bundle)
            # bm dump -n 的当前真实字段为 debug:true 与 appProvisionType:"debug"。
            # 未知、缺失或相互冲突都拒绝隔离启动，防止 Release 静默落回正式库。
            if "debug" in value or "appProvisionType" in value:
                if bundle in ("", BUNDLE):
                    flags.append((value.get("debug"), value.get("appProvisionType")))
            for child in value.values():
                visit(child, bundle)
        elif isinstance(value, list):
            for child in value:
                visit(child, bundle)

    visit(candidates[0])
    debug_values = [debug for debug, _ in flags if debug is not None]
    provision_values = [provision for _, provision in flags if provision is not None]
    return bool(debug_values and provision_values and all(value is True for value in debug_values)
                and all(value == "debug" for value in provision_values))


class NativeUi:
    def __init__(self, hdc: Hdc, guard: StopGuard, pace: float, run_id: str):
        self.hdc, self.guard, self.pace = hdc, guard, pace
        self.remote_base = f"/data/local/tmp/yunheji-roaming-demo-{run_id}"
        self.evidence: list[dict] = []

    def layout(self, **permissions: bool) -> Layout:
        self.guard.check()
        remote = self.remote_base + ".json"
        # 全窗口临时布局用于发现键盘/分享/系统遮挡；先解析并检查，之后才能保存应用证据。
        # 每次读完即删除临时文件；停止发生时不再补发 rm 等设备命令。
        with tempfile.TemporaryDirectory(prefix="yunheji-roaming-layout-") as directory:
            local = Path(directory) / "layout.json"
            self.hdc.shell("uitest", "dumpLayout", "-p", remote)
            self.hdc.run("file", "recv", remote, str(local))
            self.hdc.shell("rm", "-f", remote)
            try:
                payload = json.loads(local.read_text(encoding="utf-8-sig"))
            except (OSError, ValueError) as error:
                raise DemoError("无法解析设备布局；请核对 uitest 支持，原始布局未落入证据目录。") from error
        if not isinstance(payload, dict):
            raise DemoError("设备布局格式不符，停止。")
        result = Layout(payload)
        result.guard_page(**permissions)
        return result

    def wait(self, predicate: Callable[[Layout], bool], description: str, timeout: float = 15,
             **permissions: bool) -> Layout:
        deadline = time.monotonic() + timeout
        while True:
            layout = self.layout(**permissions)
            if predicate(layout):
                return layout
            if time.monotonic() >= deadline:
                raise DemoError(f"等待超时：{description}；停止，不重复点击。")
            self.guard.sleep(0.35)

    def wait_text(self, node_id: str, value: str, **permissions: bool) -> Layout:
        return self.wait(lambda layout: bool((node := layout.one(node_id)) and node.text == value),
                         node_id, **permissions)

    def wait_scrolled_text(self, node_id: str, value: str, scroll_ids: tuple[str, ...],
                           *, search_up: bool = False, **permissions: bool) -> Layout:
        # ArkUI 会从可访问树裁掉屏外节点。先用真实 Scroll 找到目标，再保留原文字断言；
        # 目录/进度位于页首时明确向上找，不能在页中反复等待不存在于当前布局的 header。
        self.locate(lambda item: item.id == node_id, scroll_ids, node_id,
                    search_up=search_up, **permissions)
        return self.wait_text(node_id, value, **permissions)

    @staticmethod
    def scope(layout: Layout, scroll_ids: tuple[str, ...]) -> Node:
        candidates = [node for node_id in scroll_ids if (node := layout.one(node_id)) and layout.drawn(node)]
        if len(candidates) != 1:
            raise DemoError("当前滚动容器缺失或不唯一；停止，避免滚动错误分栏。")
        return candidates[0]

    def locate(self, predicate: Callable[[Node], bool], scroll_ids: tuple[str, ...],
               description: str, *, search_up: bool = False, **permissions: bool) -> tuple[Layout, Node]:
        previous = ""
        for attempt in range(9):
            layout = self.layout(**permissions)
            scope = self.scope(layout, scroll_ids)
            found = layout.matching(predicate, scope)
            if len(found) > 1:
                raise DemoError(f"目标不唯一，停止：{description}")
            node = found[0] if found else None
            if node and node.usable(layout.screen):
                return layout, node
            rect = scope.visible_rect(layout.screen)
            if not rect or rect.width < 100 or rect.height < 160:
                raise DemoError("滚动区域不足，停止。")
            signature = hashlib.sha256(json.dumps([(item.id, item.text, item.attrs.get("bounds"))
                for item in scope.subtree()], ensure_ascii=False).encode("utf-8")).hexdigest()
            if signature == previous or attempt == 8:
                raise DemoError(f"滚动没有找到可见目标，停止：{description}")
            previous = signature
            x = round(rect.right - rect.width * 0.06)
            top, bottom = rect.top + rect.height * 0.18, rect.bottom - rect.height * 0.18
            going_up = bool(node.rect.center[1] < rect.center[1]) if node and node.rect else search_up
            y1, y2 = (top, bottom) if going_up else (bottom, top)
            self.hdc.shell("uitest", "uiInput", "swipe", x, round(y1), x, round(y2), "1000")
            self.guard.sleep(max(0.35, self.pace * 0.4))
        raise DemoError("未能定位控件。")

    def tap(self, node_id: str, scroll_ids: tuple[str, ...] = (), contains: str = "",
            **permissions: bool) -> None:
        if scroll_ids:
            layout, node = self.locate(lambda item: item.id == node_id, scroll_ids, node_id, **permissions)
        else:
            layout = self.layout(**permissions)
            node = layout.one(node_id)
        if not node or not node.usable(layout.screen):
            raise DemoError(f"目标不可见，停止：{node_id}")
        if str(node.attrs.get("enabled", "")).lower() != "true":
            raise DemoError(f"目标尚未启用，停止：{node_id}")
        if contains and not node.contains_text(contains):
            raise DemoError(f"目标正文不符，停止：{node_id}")
        x, y = node.visible_rect(layout.screen).center  # type: ignore[union-attr]
        self.hdc.shell("uitest", "uiInput", "click", x, y)
        self.guard.sleep(self.pace)

    def capture(self, name: str, **permissions: bool) -> None:
        layout = self.layout(**permissions)
        payload = layout.safe_payload()
        self.guard.check()
        remote = self.remote_base + ".png"
        png = self.hdc.output / f"{name}.png"
        self.hdc.shell("uitest", "screenCap", "-p", remote)
        self.hdc.run("file", "recv", remote, str(png))
        self.hdc.shell("rm", "-f", remote)
        self.guard.check()
        if not png.is_file() or png.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
            raise DemoError("截图没有有效 PNG 文件，停止。")
        (self.hdc.output / f"{name}.layout.json").write_text(
            json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        self.evidence.append({"stage": self.hdc.stage, "screenshot": png.name,
                              "layout": f"{name}.layout.json", "sha256": hashlib.sha256(png.read_bytes()).hexdigest()})

    def slider(self, target: int, minimum: int, maximum: int) -> None:
        layout, node = self.locate(lambda item: item.id == "roam-slider", SCENE_SCROLLS, "roam-slider")
        try:
            current = float(node.text)
        except ValueError as error:
            raise DemoError("滑条没有可核对的原生数值；停止，不靠坐标猜测完成。") from error
        if not math.isfinite(current) or not 0 <= current <= 100:
            raise DemoError("滑条数值不符，停止。")
        rect = node.visible_rect(layout.screen)
        if not rect:
            raise DemoError("滑条不在可见区域。")
        padding = min(rect.width * 0.08, max(8, rect.height * 0.32))
        track_left, track_width = rect.left + padding, rect.width - padding * 2
        x1, x2 = round(track_left + track_width * current / 100), round(track_left + track_width * target / 100)
        self.hdc.shell("uitest", "uiInput", "swipe", x1, rect.center[1], x2, rect.center[1], "1000")
        self.guard.sleep(self.pace)
        actual = self.layout().one("roam-slider")
        try:
            value = float(actual.text) if actual else float("nan")
        except ValueError:
            value = float("nan")
        if not minimum <= value <= maximum:
            raise DemoError("滑条实际值没有进入目标区间；停止，不补发盲目拖动。")


class Demo:
    def __init__(self, ui: NativeUi, args: argparse.Namespace, run_id: str):
        self.ui, self.args = ui, args
        self.note = ("沿水线找到街与河的交会，再拨开城市的层次。灯亮起来时，我想记住街巷里温暖的光。"
                     f"（本机演示 {run_id}）")

    def stage(self, name: str, message: str) -> None:
        self.ui.hdc.stage = name
        self.ui.guard.check()
        print(message, flush=True)

    def home(self) -> None:
        self.stage("prepare-home", "检查原生首页与演示数据范围。")
        # 冷启动才能应用测试库 Want；先确认前台没有未保存的编辑页或已输入的登录凭据。
        initial = self.ui.layout(blank_login=True)
        if any((node := initial.one(marker)) and initial.drawn(node)
               for marker in ("roaming-chapter-page", "roam-personal-scroll", "roam-memory-scroll", "roam-edit-body")):
            raise DemoError("当前仍在章节或记忆详情；请人工返回首页，本轮不强停编辑现场。")
        if not initial.one("roaming-home") and not initial.one("login-scroll"):
            raise DemoError("请先手动回到漫游首页或空白登录页；本轮不强停编辑现场。")
        if self.args.isolated:
            info = self.ui.hdc.shell("bm", "dump", "-n", BUNDLE)
            if not parse_bundle_debug(info):
                raise DemoError("安装包未同时确认 debug=true 和 appProvisionType=debug；拒绝隔离启动。")
            self.ui.hdc.shell("aa", "force-stop", BUNDLE)
            self.ui.hdc.shell("aa", "start", "-b", BUNDLE, "-a", ABILITY,
                              "--ps", "yunhejiTestStore", self.args.isolated)
            self.ui.guard.sleep(max(1.2, self.ui.pace))
        layout = self.ui.layout(blank_login=True)
        if layout.one("login-scroll"):
            self.ui.wait(lambda value: bool((node := value.one("login-offline"))
                         and str(node.attrs.get("enabled")).lower() == "true"),
                         "本机档案准备完成", blank_login=True)
            self.ui.tap("login-offline", blank_login=True)
        self.ui.wait(lambda value: value.one("roaming-home") is not None, "漫游首页")
        layout, memory = self.ui.locate(lambda item: item.id == "roam-home-memory", ("roaming-home",), "首页记忆数量")
        if not any(re.fullmatch(r"0\s*页亲笔记录", item.text) for item in memory.subtree()):
            raise DemoError("当前工作区已有亲笔记忆；请换一个新的独立测试库，避免把私人文字拍入演示。")
        # 首张画面从五城题签开始。使用真实 Scroll 的反向滚动回到题签，不发送屏幕固定坐标。
        self.ui.locate(lambda item: item.id == "roam-pick-roam-smx-earth-home", ("roaming-home",), "五城题签", search_up=True)
        self.ui.capture("01-native-home")

    def five_cities(self) -> None:
        self.stage("five-cities", "依次选择原生五城题签，核对篇章标题，再进入开封。")
        for chapter_id, city, title in CITIES:
            self.ui.tap(f"roam-pick-{chapter_id}", ("roaming-home",), contains=city)
            self.ui.wait_text("roam-home-chapter-title", title)
        self.ui.tap("roam-pick-roam-kf-night", ("roaming-home",), contains="开封")
        self.ui.wait_text("roam-home-chapter-title", CHAPTER_TITLE)
        layout = self.ui.layout()
        progress = layout.one("roam-home-progress")
        if not progress or re.sub(r"\s", "", progress.text) != "0/3线索":
            raise DemoError("开封不是 0/3 线索；本轮不清空进度，请使用新的独立测试库。")
        self.ui.capture("02-kaifeng-selected")
        self.ui.tap("roam-start", ("roaming-home",))
        self.ui.wait_text("roam-chapter-title", CHAPTER_TITLE)
        self.ui.wait_text("roam-chapter-progress", "0 / 3")

    def chapter(self) -> None:
        for stage, goal, option_id, option_label, target, interval in (
            (0, "沿水线移动，找到州桥与御街的相接处", "kf-street-river", "记住街河交会", 65, (53, 78)),
            (1, "移动时间观察窗，辨认遗存与今日城市的层次", "kf-bridge-layers", "留住桥的层次", 90, (72, 100)),
        ):
            self.stage(f"kaifeng-{stage + 1}", f"开封第 {stage + 1} 条：真实拖动滑条、选择片段并确认进度。")
            self.ui.wait_text("roam-current-goal", goal)
            self.ui.slider(target, *interval)
            self.ui.tap(f"roam-choice-{option_id}", SCENE_SCROLLS, contains=option_label)
            self.ui.locate(lambda node: node.id == "roam-complete", SCENE_SCROLLS, "确认发现")
            self.ui.capture(f"0{stage + 3}-kaifeng-interaction")
            self.ui.tap("roam-complete", SCENE_SCROLLS, contains="确认发现，继续展开")
            self.ui.wait_scrolled_text("roam-chapter-progress", f"{stage + 1} / 3", SCENE_SCROLLS, search_up=True)
        self.stage("kaifeng-lantern", "读灯事短笺，选择祝愿，亲手点灯并收好这一城。")
        self.ui.wait_text("roam-current-goal", LANTERN_GOAL)
        self.ui.tap("roam-read-story", SCENE_SCROLLS)
        self.ui.locate(lambda node: node.id == "roam-reading-body", READING_SCROLLS, "灯事短笺")
        self.ui.capture("05-lantern-reading")
        layout = self.ui.layout()
        if layout.one("roam-sheet-close"):
            self.ui.tap("roam-sheet-close")
        self.ui.tap("roam-choice-kf-home-warm", SCENE_SCROLLS, contains="愿灯火可亲")
        self.ui.tap("roam-light-lantern", SCENE_SCROLLS, contains="点亮这盏灯")
        self.ui.wait_text("roam-light-lantern", "灯已亮起")
        self.ui.capture("06-lantern-lit")
        self.ui.tap("roam-complete", SCENE_SCROLLS, contains="收好这一城的故事")
        self.ui.wait_scrolled_text("roam-chapter-progress", "3 / 3", SCENE_SCROLLS, search_up=True)

    def write_memory(self) -> None:
        self.stage("blank-personal-thought", "确认个人感想初始为空；资料依据与亲笔文字分别显示。")
        self.ui.tap("roam-write-memory", SCENE_SCROLLS)
        _layout, field_node = self.ui.locate(lambda node: node.id == "roam-note-body", WRITING_SCROLLS, "个人感想")
        if field_node.text or field_node.attrs.get("originalText"):
            raise DemoError("个人感想已有文字；停止，不清空或覆盖现有草稿。")
        self.ui.capture("07-blank-personal-thought")
        self.stage("input-personal-thought", "经原生输入框输入公开演示感想，并逐字回读。")
        self.ui.tap("roam-note-body", WRITING_SCROLLS)
        layout, field_node = self.ui.locate(lambda node: node.id == "roam-note-body", WRITING_SCROLLS,
                                           "个人感想输入框", keyboard=True)
        if field_node.text:
            raise DemoError("输入前文字已变化；停止，不覆盖。")
        x, y = field_node.visible_rect(layout.screen).center  # type: ignore[union-attr]
        self.ui.hdc.shell("uitest", "uiInput", "inputText", x, y, self.note)
        self.ui.guard.sleep(self.ui.pace)
        self.ui.wait_text("roam-note-body", self.note, keyboard=True)
        layout = self.ui.layout(keyboard=True)
        if layout.keyboard():
            self.ui.hdc.shell("uitest", "uiInput", "keyEvent", "Back")
            self.ui.guard.sleep(self.ui.pace)
        self.ui.wait_text("roam-note-body", self.note)
        self.ui.capture("08-personal-thought-input")
        self.stage("confirm-save", "点击明确保存按钮，等待本机保存成功文字。")
        self.ui.tap("roam-save-note", WRITING_SCROLLS, contains="确认，存入我的记忆")
        self.ui.wait_text("roam-save-note", "这一页已保存")
        self.ui.wait_scrolled_text("roam-note-message", "这一页已在本机保存。", WRITING_SCROLLS)
        self.ui.capture("09-saved-on-device")
        self.ui.tap("roam-open-memory", WRITING_SCROLLS)

    def read_recent(self) -> None:
        self.stage("top-recent-note", "从个人长卷顶部“最近留下”打开刚保存的一页。")
        self.ui.wait(lambda layout: layout.one("roam-personal-scroll") is not None, "个人长卷")
        layout = self.ui.layout()
        scope = self.ui.scope(layout, ("roam-personal-scroll",))
        count = layout.one("roam-scroll-count", scope)
        if not count or not re.match(r"1\s*页亲笔记忆", count.text):
            raise DemoError("个人长卷记录数量与本轮不符；停止，避免抓取其他人的文字。")
        recent = layout.matching(lambda node: node.id.startswith("roam-recent-note-"), scope)
        if len(recent) != 1 or not recent[0].contains_text(self.note) or not recent[0].contains_text(NOTE_TITLE):
            raise DemoError("顶部最近记忆不是刚保存的原文；停止，不改点其他城市的记录。")
        self.ui.locate(lambda node: node.id == recent[0].id, ("roam-personal-scroll",), "顶部最近记忆")
        self.ui.capture("10-top-recent-note")
        self.ui.tap(recent[0].id, ("roam-personal-scroll",), contains=self.note)
        self.ui.wait_text("roam-memory-title", NOTE_TITLE)
        self.ui.wait_scrolled_text("roam-memory-body", self.note, ("roam-memory-scroll",))
        self.ui.capture("11-saved-memory-body")
        self.stage("frozen-source", "核对这页随存的文化摘录、来源标题和完整网址。")
        self.ui.locate(lambda node: node.id == "roam-memory-excerpt", ("roam-memory-scroll",), "文化摘录")
        layout = self.ui.layout()
        excerpt = layout.one("roam-memory-excerpt")
        if not excerpt or "北宋灯事" not in excerpt.text or "清末" not in excerpt.text:
            raise DemoError("保存的文化摘录与灯事线索不符，停止。")
        self.ui.locate(lambda node: SOURCE_TITLE in node.text and SOURCE_URL in node.text,
                       ("roam-memory-scroll",), "文化出处")
        self.ui.capture("12-saved-memory-source")

    def share(self) -> None:
        self.stage("native-share-cancel", "打开真实系统分享面板，只展示并取消。")
        self.ui.tap("roam-memory-share", ("roam-memory-scroll",), contains="分享纪行")
        layout = self.ui.wait(lambda item: item.share_panel() is not None, "系统分享面板", share=True)
        panel = layout.share_panel()
        if not panel or not panel.contains_text(NOTE_TITLE) or not panel.contains_text("分享"):
            raise DemoError("系统分享内容不符；停止，不选择任何操作。")
        allowed = {"分享", NOTE_TITLE, "IMAGE", "华为分享", "复制", "保存至图库", "打印", "添加至中转站", "取消", "更多"}
        unknown = any(node.text.strip(" ,，\n\t") not in allowed for node in panel.subtree() if node.text.strip(" ,，\n\t"))
        # 真实设备可能展示常用联系人。遇到未知分享项只取消，不把收件人或账号拍入证据。
        if not unknown:
            self.ui.capture("13-native-share-sheet", share=True)
        fresh = self.ui.layout(share=True)
        if not fresh.share_panel():
            raise DemoError("取消前分享面板已改变；停止，不发送 Back 到未知页面。")
        self.ui.hdc.shell("uitest", "uiInput", "keyEvent", "Back")
        self.ui.guard.sleep(self.ui.pace)
        self.ui.wait_scrolled_text("roam-memory-body", self.note, ("roam-memory-scroll",), search_up=True)
        self.ui.wait_scrolled_text("roam-memory-title", NOTE_TITLE, ("roam-memory-scroll",), search_up=True)
        if unknown:
            raise DemoError("分享面板出现未识别项目；已取消并跳过截图，请人工核对设备分享界面。")
        self.ui.wait_scrolled_text("roam-memory-body", self.note, ("roam-memory-scroll",))
        self.ui.capture("14-share-cancelled")

    def run(self) -> None:
        self.home()
        self.five_cities()
        self.chapter()
        self.write_memory()
        self.read_recent()
        if self.args.share:
            self.share()


def check_keyboard_fixture(path: Path) -> dict:
    """对显式提供的已脱敏完整布局做离线回归；不构造 HDC，不读设备或账号文件。"""
    payload = json.loads(path.read_text(encoding="utf-8-sig"))
    layout = Layout(payload)
    layout.guard_page(keyboard=True)
    roots = layout.initialized_keyboard_roots()
    panels = layout.keyboard_system_panels(roots)
    if not roots or not panels:
        raise DemoError("夹具没有已核实的输入法画布和关联系统键盘栏。")
    checks = ["实际完整布局允许聚焦感想输入", "识别已初始化输入法画布", "系统键盘栏关联真实输入法窗口"]

    def reject(name: str, change: Callable[[Layout], None], *, expected_keyboard: bool = True) -> None:
        changed = copy.deepcopy(payload)
        change(Layout(changed))
        try:
            Layout(changed).guard_page(keyboard=expected_keyboard)
        except DemoError:
            checks.append(name)
            return
        raise DemoError(f"离线反例未被阻断：{name}")

    def field(item: Layout) -> Node:
        node = item.one("roam-note-body")
        if not node:
            raise DemoError("夹具缺少感想框。")
        return node

    def insert(item: Layout, node_id: str, node_type: str, text: str = "", *, foreign: bool = False) -> None:
        attributes = {"id": node_id, "type": node_type, "text": text, "visible": "true", "enabled": "true",
                      "bounds": field(item).attrs["bounds"], "opacity": "1"}
        if foreign:
            attributes["bundleName"] = "fixture.unknown.app"
            parent = item.payload
        else:
            parent = next(node.raw for node in field(item).ancestry() if node.attrs.get("bundleName") == BUNDLE)
        parent.setdefault("children", []).append({"attributes": attributes, "children": []})

    reject("未授权的键盘阶段仍阻断", lambda item: None, expected_keyboard=False)
    reject("任意输入法名称应用仍阻断", lambda item: item.initialized_keyboard_roots()[0].attrs.update(bundleName="fixture.inputmethod"))
    reject("未知大面积系统窗仍阻断", lambda item: next(iter(item.keyboard_system_panels(item.initialized_keyboard_roots()))).attrs.update(id="unknownPanel"))
    reject("全屏系统窗不能冒充键盘栏", lambda item: next(iter(item.keyboard_system_panels(item.initialized_keyboard_roots()))).attrs.update(bounds=item.root.attrs["bounds"]))
    reject("系统栏与输入法窗口编号不符仍阻断", lambda item: item.one(f"keyboard{item.initialized_keyboard_roots()[0].attrs['hostWindowId']}").attrs.update(id="keyboard999999"))
    reject("失去感想焦点仍阻断", lambda item: field(item).attrs.update(focused="false"))
    reject("隐私同意仍阻断", lambda item: insert(item, "fixture-privacy", "Text", "同意基本模式"))
    reject("未知对话框仍阻断", lambda item: insert(item, "fixture-dialog", "Dialog"))
    reject("未知应用仍阻断", lambda item: insert(item, "fixture-window", "root", foreign=True))
    reject("账号输入仍阻断", lambda item: insert(item, "account-username", "TextInput"))
    reject("个人设置页仍阻断", lambda item: insert(item, "profile-page", "NavDestination"))
    return {"status": "passed", "offlineChecks": len(checks), "checks": checks, "deviceCommandsSent": 0}


def arguments(argv: list[str] | None = None) -> argparse.Namespace:
    requested = sys.argv[1:] if argv is None else argv
    if "--check-layout" in requested:
        offline = argparse.ArgumentParser(description="离线核对已初始化键盘布局及阻断反例，不需要或调用 HDC。")
        offline.add_argument("--check-layout", required=True, type=Path, help="显式提供已脱敏的完整 uitest 布局 JSON")
        return offline.parse_args(requested)
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="先在手机打开云河纪漫游首页或空白登录页。--tablet 只写入人工接续说明，不向平板发送命令。\n"
               "推荐使用新的 --isolated yunheji_test_ui_roaming_<编号>。停止：Ctrl+C 或创建停止文件。\n"
               "离线键盘回归：--check-layout <已脱敏的完整布局.json>；该模式不接受设备参数，不调用 HDC。")
    parser.add_argument("--hdc", required=True, help="HDC 可执行文件路径，或 PATH 中的名称")
    parser.add_argument("--phone", required=True, help="主演示设备的 HDC target ID")
    parser.add_argument("--tablet", help="可选人工接续设备 ID；本脚本不会控制该设备")
    parser.add_argument("--isolated", required=True, metavar="STORE", help="必填，只用于已确认 Debug 包的独立测试库名")
    parser.add_argument("--pace", type=float, default=1.5, help="每次交互后的停留秒数，默认 1.5，范围 0—30")
    parser.add_argument("--share", action="store_true", help="最后打开真实系统分享面板并取消，不发送给任何人")
    parser.add_argument("--output", type=Path, help="新建证据目录，默认仓库 .local/roaming-demo/<本轮编号>")
    parser.add_argument("--stop-file", type=Path, help="检测到该文件即停止；默认本轮证据目录/STOP")
    args = parser.parse_args(argv)
    if not math.isfinite(args.pace) or not 0 <= args.pace <= 30:
        parser.error("--pace 必须是 0—30 之间的有限数字")
    if args.isolated and not TEST_STORE.fullmatch(args.isolated):
        parser.error("--isolated 必须符合 yunheji_test_ui_[a-z0-9_]{1,80}")
    if args.tablet == args.phone:
        parser.error("--tablet 与 --phone 不能指向同一设备")
    executable = shutil.which(args.hdc)
    if not executable:
        parser.error("找不到 --hdc；请传入已安装 SDK 中的 HDC 可执行文件路径")
    args.hdc = executable
    return args


def main(argv: list[str] | None = None) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    args = arguments(argv)
    if hasattr(args, "check_layout"):
        try:
            print(json.dumps(check_keyboard_fixture(args.check_layout), ensure_ascii=False, indent=2))
            return 0
        except (DemoError, OSError, ValueError) as error:
            print(f"离线布局检查失败：{error}", file=sys.stderr)
            return 1
    run_id = time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6]
    output = (args.output or Path(__file__).resolve().parents[1] / ".local" / "roaming-demo" / run_id).resolve()
    stop_file = (args.stop_file or output / "STOP").resolve()
    guard = StopGuard(stop_file)
    for name in ("SIGINT", "SIGTERM"):
        if hasattr(signal, name):
            signal.signal(getattr(signal, name), guard.handle_signal)
    try:
        guard.check()
        output.mkdir(parents=True, exist_ok=False)
    except (OSError, DemoStopped) as error:
        print(f"未开始：{error}", file=sys.stderr)
        return 130 if isinstance(error, DemoStopped) else 1
    hdc = Hdc(args.hdc, args.phone, output, guard)
    ui = NativeUi(hdc, guard, args.pace, run_id)
    demo = Demo(ui, args, run_id)
    status, detail, code = "failed", "", 1
    print(f"证据目录：{output}\n停止文件：{stop_file}", flush=True)
    print("本轮将经原生 UI 确认三条开封线索并新增一页公开演示感想，数据保留在设备上。", flush=True)
    try:
        demo.run()
        status, detail, code = "completed", "单端原生操作、保存与原文/出处回读已完成。", 0
    except DemoStopped as error:
        status, detail, code = "stopped", str(error), 130
    except (DemoError, OSError) as error:
        detail = str(error)
    finally:
        summary = {"status": status, "detail": detail, "stage": hdc.stage, "runId": run_id,
                   "phone": args.phone, "tabletManualOnly": args.tablet,
                   "isolatedStore": args.isolated, "shareRequested": args.share,
                   "commandCount": hdc.command_count, "evidence": ui.evidence,
                   "testNoteText": demo.note, "twoDeviceSyncVerified": False,
                   "remoteTemporaryBase": ui.remote_base}
        (output / "result.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(detail, flush=True)
    if code == 0:
        print("没有执行双端同步。人工接续请按 docs/ROAMING_DEMO.md 使用真实登录与同步界面。", flush=True)
    print(f"本轮结果：{output / 'result.json'}", flush=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
