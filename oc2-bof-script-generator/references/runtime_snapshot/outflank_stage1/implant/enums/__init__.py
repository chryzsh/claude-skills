from enum import Enum


class ImplantArch(Enum):
    UNKNOWN = 0
    INTEL_X86 = 100
    INTEL_X64 = 200
    ARM64 = 300


class ImplantCommType(Enum):
    UNKNOWN = 0
    HTTP_HTTPS = 100
    TCP = 200
    NAMEDPIPE = 300
    FILE_DISK = 400


class ImplantOSType(Enum):
    UNKNOWN = 0
    WINDOWS = 100
    MAC_OS = 200
    LINUX = 300
    FREEBSD = 400


class ImplantPrivilege(Enum):
    UNKNOWN = 0
    UNTRUSTED = 50
    LOW = 100
    MEDIUM = 200
    HIGH = 300
    SYSTEM = 400
    PROTECTED_PROCESS = 500
