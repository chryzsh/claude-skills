from __future__ import annotations

from typing import Tuple, TYPE_CHECKING

from outflank_stage1.implant.enums import ImplantArch, ImplantPrivilege, ImplantOSType
from outflank_stage1.task.base_task import BaseTask

if TYPE_CHECKING:
    from outflank_stage1.implant import Implant

import base64
import datetime
import os
from typing import List, Optional

from .enums import BOFArgumentEncoding, BOFType
from .exceptions import TaskException, TaskInvalidArgumentsException


class BaseBOFTask(BaseTask):
    _BINARY_MIN_SIZE = 100
    _BINARY_MAX_SIZE = 5000000

    def __init__(
        self,
        name: str,
        base_binary_name: str = None,
        base_binary_path: str = None,
        parser_prefix_chars: str = None,
        min_privilege: Optional[ImplantPrivilege] = None,
        supported_architectures: Optional[List[ImplantArch]] = None,
        supported_os: Optional[List[ImplantOSType]] = [ImplantOSType.WINDOWS],
        bof_type: BOFType = BOFType.DEFAULT,
        # Deprecated: non_threaded. Use BOFType.DEFAULT_NON_THREADED
        non_threaded: bool = False,
    ):
        super().__init__(
            name=name,
            parser_prefix_chars=parser_prefix_chars,
            min_privilege=min_privilege,
            supported_architectures=supported_architectures,
            supported_os=supported_os,
        )

        if non_threaded and bof_type == BOFType.DEFAULT:
            bof_type = BOFType.DEFAULT_NON_THREADED
        self._bof_type = bof_type

        self._base_binary_name = base_binary_name if base_binary_name is not None else name
        self._base_binary_path = base_binary_path if base_binary_path is not None else ""

        self._implant: Optional[Implant] = None
        self._task: Optional[BaseTask] = None

    # noinspection PyUnusedLocal
    def _get_base_binary_name(self, arguments: List[str]) -> str:
        return self._base_binary_name

    def _set_base_binary_name(self, name: str):
        self._base_binary_name = name

    # noinspection PyUnusedLocal
    def _get_base_binary_path(self, arguments: List[str]) -> str:
        return self._base_binary_path

    # noinspection PyUnusedLocal, PyMethodMayBeStatic
    def _get_base_binary_suffix(self, implant: Implant, arguments: List[str]) -> str:
        match implant.get_arch():
            case ImplantArch.INTEL_X64:
                path_suffix = "x64"
            case ImplantArch.INTEL_X86:
                path_suffix = "x86"
            case ImplantArch.ARM64:
                path_suffix = "arm64"
            case _:
                path_suffix = "unknown"

        return f".{path_suffix}.o"

    def _get_bof_binary_filename(self, implant: Implant, arguments: List[str]) -> str:
        return f"{self._get_base_binary_name(arguments)}{self._get_base_binary_suffix(implant, arguments)}"

    def _get_bof_binary_content(self, implant: Implant, arguments: List[str]) -> bytes:
        binary_path = os.path.join(
            self.get_base_path(),
            self._get_base_binary_path(arguments),
            self._get_bof_binary_filename(implant, arguments),
        )

        if not os.path.exists(binary_path):
            raise TaskException(f'The path to the BOF file does not exist: "{binary_path}".')

        if not os.path.isfile(binary_path):
            raise TaskException(f'The path to the BOF file is not pointing to a valid file: "' + f'{binary_path}".')

        f = open(binary_path, "rb")
        binary_content = f.read()
        f.close()

        return binary_content

    # noinspection PyMethodMayBeStatic
    def _get_license_expired(self) -> bool:
        license_time_path = os.path.join(self.get_base_path(), "license_time")

        if not os.path.exists(license_time_path) or not os.path.isfile(license_time_path):
            # If thie license expiry time file does not exist, or is not a valid file,
            # then return False (license not expired).
            return False

        try:
            # Read the license_time file.
            f = open(license_time_path, "r")
            license_content = f.read()
            f.close()

            # Calculate the remaining license time.
            license_remaining = int(license_content) - int(datetime.datetime.utcnow().timestamp())
        except ValueError:
            # Can't parse the license expiry time. Return True (license expired).
            return True

        # If the license_remaining is smaller than 0, the license is expired.
        return license_remaining < 0

    # noinspection PyMethodMayBeStatic
    def _encode_arguments_bof(self, arguments: List[str]) -> List[Tuple[BOFArgumentEncoding, str | bytes | int]]:
        return []

    def _encode_arguments(self, arguments: List[str]) -> List[str]:
        try:
            return [self._bof_arguments_to_base64(self._encode_arguments_bof(arguments))]
        except ValueError as e:
            raise TaskException(e)

    # noinspection PyMethodMayBeStatic
    def _bof_arguments_to_base64(
        self, arguments_with_encoding: List[Tuple[BOFArgumentEncoding, str | bytes | int]]
    ) -> str:
        output = bytes()

        for argument_with_encoding in arguments_with_encoding:
            encoding = argument_with_encoding[0]
            argument = argument_with_encoding[1]

            match encoding:
                case BOFArgumentEncoding.WSTR:
                    encoded_str = bytes()
                    for c in argument + "\0":
                        encoded_str += ord(c).to_bytes(2, "little")
                    output += len(encoded_str).to_bytes(4, "little") + encoded_str
                case BOFArgumentEncoding.STR:
                    encoded_str = argument.encode("utf-8") + bytes([0])
                    output += len(encoded_str).to_bytes(4, "little") + encoded_str
                case BOFArgumentEncoding.BUFFER:
                    encoded_buffer = argument
                    output += len(encoded_buffer).to_bytes(4, "little") + encoded_buffer
                case BOFArgumentEncoding.INT:
                    output += int(argument).to_bytes(4, "little", signed=True)
                case BOFArgumentEncoding.SHORT:
                    output += int(argument).to_bytes(2, "little", signed=True)
                case _:
                    raise ValueError(f"Unknown BOFArgumentEncoding type {encoding}.")

        # Prepend with the length.
        output = (len(output) + 4).to_bytes(4, "little") + output

        return base64.b64encode(output).decode("utf-8")

    def validate_binary_content(self, arguments: List[str]):
        binary_content = self._get_bof_binary_content(self._implant, arguments)

        if len(binary_content) < self._BINARY_MIN_SIZE:
            raise TaskInvalidArgumentsException(f"The BOF binary is too small (< {self._BINARY_MIN_SIZE} bytes).")

        if len(binary_content) > self._BINARY_MAX_SIZE:
            raise TaskInvalidArgumentsException(f"The BOF binary is too large (< {self._BINARY_MAX_SIZE} bytes).")

        if binary_content[:2] == bytes([0x64, 0x86]):
            if self._implant.get_arch() == ImplantArch.INTEL_X86:
                raise TaskInvalidArgumentsException(f"Incorrect BOF binary header (x64) where the implant is x86.")
        elif binary_content[:2] == bytes([0x4C, 0x01]):
            if self._implant.get_arch() == ImplantArch.INTEL_X64:
                raise TaskInvalidArgumentsException(f"Incorrect BOF binary header (x86) where the implant is x64.")
        elif binary_content[:2] == bytes([0x4D, 0x5A]):
            # MZ header - DLL
            pass
        else:
            raise TaskInvalidArgumentsException(f"BOF binary does not contain a x64 or x86 binary header.")

    def run(self, arguments: List[str]):
        super().run(arguments)

        if self._get_license_expired():
            raise TaskException("License expired! Please download a fresh copy from the OST portal.")

        match self._bof_type:
            case BOFType.DEFAULT:
                self.set_out_name("exec_bof")
            case BOFType.DEFAULT_NON_THREADED:
                self.set_out_name("exec_bof_non_threaded")
            case BOFType.ASYNC:
                self.set_out_name("exec_bof_async")
            case _:
                raise ValueError(f"Unknown Bof type.")

        self.set_binary_content(self._get_bof_binary_content(self._implant, arguments))
