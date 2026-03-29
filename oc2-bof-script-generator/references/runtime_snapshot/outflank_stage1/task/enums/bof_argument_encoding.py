from enum import Enum


class BOFArgumentEncoding(Enum):
    UNKNOWN = 0
    WSTR = 10
    STR = 20
    BUFFER = 30
    INT = 40
    SHORT = 50


class BOFType(Enum):
    DEFAULT = 0
    DEFAULT_NON_THREADED = 1
    ASYNC = 2
