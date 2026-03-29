from __future__ import annotations

from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from outflank_stage1.task.base_task import BaseTask

from typing import List, Optional
from datetime import datetime

from .enums import ImplantArch, ImplantCommType, ImplantOSType, ImplantPrivilege


class Implant:
    """
    lalala
    """

    # noinspection PyShadowingBuiltins
    def __init__(self, uid: str):
        self._uid: str = uid
        self._parent_uid: Optional[str] = None

        self._version: Optional[str] = None
        self._comm_type: ImplantCommType = ImplantCommType.UNKNOWN
        self._recipe: Optional[str] = None
        self._delay: Optional[int] = None
        self._jitter: Optional[int] = None
        self._kill_date: Optional[datetime] = None
        self._arch: ImplantArch = ImplantArch.UNKNOWN
        self._os: Optional[str] = None
        self._os_type: ImplantOSType = ImplantOSType.UNKNOWN
        self._pid: Optional[int] = None
        self._ppid: Optional[int] = None
        self._privilege: ImplantPrivilege = ImplantPrivilege.UNKNOWN
        self._proc_name: Optional[str] = None
        self._pproc_name: Optional[str] = None
        self._hostname: Optional[str] = None
        self._username: Optional[str] = None
        self._token_impersonated: bool = False
        self._ip: Optional[str] = None
        self._transport_ip: Optional[str] = None
        self._note: Optional[str] = None
        self._first_seen: Optional[datetime] = None
        self._last_seen: Optional[datetime] = None
        self._checkin_count: Optional[int] = None
        self._visible: bool = True
        self._options: int = 0

        self._tasks: List[BaseTask] = []

    def get_uid(self) -> str:
        return self._uid

    def set_uid(self, uid: str) -> Implant:
        self._uid = uid
        return self

    def get_parent_uid(self) -> str:
        return self._parent_uid

    def set_parent_uid(self, parent_uid: str) -> Implant:
        self._parent_uid = parent_uid
        return self

    def get_version(self) -> Optional[str]:
        return self._version

    def set_version(self, version: str) -> Implant:
        self._version = version
        return self

    def get_comm_type(self) -> ImplantCommType:
        return self._comm_type

    def set_comm_type(self, comm_type: ImplantCommType) -> Implant:
        self._comm_type = comm_type
        return self

    def get_recipe(self) -> Optional[str]:
        return self._recipe

    def set_recipe(self, recipe: str) -> Implant:
        self._recipe = recipe
        return self

    def get_delay(self) -> Optional[int]:
        return self._delay

    def set_delay(self, delay: int) -> Implant:
        self._delay = delay
        return self

    def get_jitter(self) -> Optional[int]:
        return self._jitter

    def set_jitter(self, jitter: int) -> Implant:
        self._jitter = jitter
        return self

    def get_kill_date(self) -> Optional[datetime]:
        return self._kill_date

    def set_kill_date(self, kill_date: datetime) -> Implant:
        self._kill_date = kill_date
        return self

    def get_arch(self) -> ImplantArch:
        return self._arch

    def set_arch(self, arch: ImplantArch) -> Implant:
        self._arch = arch
        return self

    def get_os(self) -> Optional[str]:
        return self._os

    def set_os(self, os: str) -> Implant:
        self._os = os
        return self

    def get_os_type(self) -> ImplantOSType:
        return self._os_type

    def set_os_type(self, os_type: ImplantOSType) -> Implant:
        self._os_type = os_type
        return self

    def get_pid(self) -> Optional[int]:
        return self._pid

    def set_pid(self, pid: int) -> Implant:
        self._pid = pid
        return self

    def get_ppid(self) -> Optional[int]:
        return self._ppid

    def set_ppid(self, ppid: int) -> Implant:
        self._ppid = ppid
        return self

    def get_privilege(self) -> ImplantPrivilege:
        return self._privilege

    def set_privilege(self, privilege: ImplantPrivilege) -> Implant:
        self._privilege = privilege
        return self

    def get_proc_name(self) -> Optional[str]:
        return self._proc_name

    def set_proc_name(self, proc_name: str) -> Implant:
        self._proc_name = proc_name
        return self

    def get_pproc_name(self) -> Optional[str]:
        return self._pproc_name

    def set_pproc_name(self, pproc_name: str) -> Implant:
        self._pproc_name = pproc_name
        return self

    def get_hostname(self) -> Optional[str]:
        return self._hostname

    def set_hostname(self, hostname: str) -> Implant:
        self._hostname = hostname
        return self

    def get_username(self) -> Optional[str]:
        return self._username

    def set_username(self, username: str) -> Implant:
        self._username = username
        return self

    def get_token_impersonated(self) -> bool:
        return self._token_impersonated

    def set_token_impersonated(self, token_impersonated: bool) -> Implant:
        self._token_impersonated = token_impersonated
        return self

    def get_ip(self) -> Optional[str]:
        return self._ip

    def set_ip(self, ip: str) -> Implant:
        self._ip = ip
        return self

    def get_transport_ip(self) -> Optional[str]:
        return self._transport_ip

    def set_transport_ip(self, transport_ip: str) -> Implant:
        self._transport_ip = transport_ip
        return self

    def get_note(self) -> Optional[str]:
        return self._note

    def set_note(self, note: str) -> Implant:
        self._note = note
        return self

    def get_first_seen(self) -> Optional[datetime]:
        return self._first_seen

    def set_first_seen(self, first_seen: datetime) -> Implant:
        self._first_seen = first_seen
        return self

    def get_last_seen(self) -> Optional[datetime]:
        return self._last_seen

    def set_last_seen(self, last_seen: datetime) -> Implant:
        self._last_seen = last_seen
        return self

    def get_checkin_count(self) -> Optional[int]:
        return self._checkin_count

    def set_checkin_count(self, checkin_count: int) -> Implant:
        self._checkin_count = checkin_count
        return self

    def get_visible(self) -> bool:
        return self._visible

    def set_visible(self, visible: bool) -> Implant:
        self._visible = visible
        return self

    def get_options(self) -> int:
        return self._options

    def set_options(self, options: int) -> Implant:
        self._options = options
        return self

    def get_tasks(self) -> List[BaseTask]:
        return self._tasks

    def set_tasks(self, tasks: List[BaseTask]):
        self._tasks = tasks
