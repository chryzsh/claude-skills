from __future__ import annotations

from typing import TYPE_CHECKING

import argparse
import shlex
import textwrap

from abc import ABC
from datetime import datetime
from typing import Dict, List, Optional

from outflank_stage1.implant.enums import ImplantPrivilege, ImplantArch, ImplantOSType
from outflank_stage1.task.enums import TaskState
from outflank_stage1.task.exceptions import TaskException, TaskInvalidArgumentsException
from outflank_stage1.task.task_file import TaskFile

if TYPE_CHECKING:
    from outflank_stage1.implant import Implant


class BaseTaskArgumentParser(argparse.ArgumentParser):
    """
    An extended argparse.ArgumentParser that does not exit when arguments are invalid.
    """

    def __init__(
        self,
        prog=None,
        usage=None,
        description=None,
        epilog=None,
        parents=[],
        prefix_chars="-",
        fromfile_prefix_chars=None,
        argument_default=None,
        conflict_handler="error",
        allow_abbrev=True,
    ):
        # Override the formatter_class.
        super().__init__(
            prog=prog,
            usage=usage,
            description=description,
            epilog=epilog,
            parents=parents,
            formatter_class=RawHelpFormatter,
            prefix_chars=prefix_chars,
            fromfile_prefix_chars=fromfile_prefix_chars,
            argument_default=argument_default,
            conflict_handler=conflict_handler,
            add_help=False,
            allow_abbrev=allow_abbrev,
            exit_on_error=False,
        )

    def error(self, message: str):
        raise argparse.ArgumentError(None, message)


class RawHelpFormatter(argparse.HelpFormatter):
    def __init__(self, prog, indent_increment=2, max_help_position=48, width=999):
        super().__init__(prog, indent_increment, max_help_position, width)

    def add_argument(self, action):
        if action.help is not argparse.SUPPRESS:
            # find all invocations
            get_invocation = self._format_action_invocation
            invocations = [get_invocation(action)]
            current_indent = self._current_indent

            for subaction in self._iter_indented_subactions(action):
                # compensate for the indent that will be added
                indent_chg = self._current_indent - current_indent
                added_indent = "x" * indent_chg
                invocations.append(added_indent + get_invocation(subaction))

            # update the maximum item length
            invocation_length = max([len(s) for s in invocations])
            action_length = invocation_length + self._current_indent
            self._action_max_length = max(self._action_max_length, action_length)

            # add the item to the list
            self._add_item(self._format_action, [action])

    def _fill_text(self, text, width, indent):
        return "\n".join(
            [textwrap.fill(line, width) for line in textwrap.indent(textwrap.dedent(text), indent).splitlines()]
        )


class BaseTask(ABC):
    # noinspection PyShadowingBuiltins
    def __init__(
        self,
        name: str,
        parser_prefix_chars: str = None,
        min_privilege: Optional[ImplantPrivilege] = None,
        supported_architectures: Optional[List[ImplantArch]] = None,
        supported_os: Optional[List[ImplantOSType]] = None,
    ):
        self._uid: Optional[str] = None

        self._name: str = name
        self._out_name: str = name

        self._arguments: Optional[str] = None
        self._run_arguments: List[str] = []
        self._out_arguments: Optional[str] = None

        self._binary_content: Optional[bytes] = None
        self._binary_content_name: Optional[str] = None

        self._response: Optional[str] = None
        self._response_timestamp: Optional[datetime] = None
        self._response_bytes_total: Optional[int] = None

        self._state: TaskState = TaskState.UNKNOWN
        self._timestamp: Optional[datetime] = None
        self._operator: Optional[str] = None

        self._implant_uid: Optional[str] = None
        self._implant: Optional[Implant] = None

        self.parser: argparse.ArgumentParser = BaseTaskArgumentParser(
            prog=name,
            prefix_chars=(parser_prefix_chars if parser_prefix_chars is not None else "-"),
        )

        self._min_privilege = min_privilege
        self._supported_architectures = supported_architectures
        self._supported_os = supported_os

        self._tasks_before: List[BaseTask] = []
        self._tasks_after: List[BaseTask] = []

        self._files: List[TaskFile] = []

        self._base_path: Optional[str] = None

    def get_base_path(self) -> Optional[str]:
        return self._base_path

    def set_base_path(self, base_path: str):
        self._base_path = base_path

    def get_uid(self) -> str:
        return self._uid

    def set_uid(self, uid: str) -> BaseTask:
        self._uid = uid
        return self

    def get_name(self) -> str:
        return self._name

    def set_name(self, name: str) -> BaseTask:
        if name is None or not isinstance(name, str):
            raise TypeError("name should be of type str.")

        self._name = name
        return self

    def get_out_name(self) -> str:
        return self._out_name

    def set_out_name(self, out_name: str) -> BaseTask:
        if out_name is None or not isinstance(out_name, str):
            raise TypeError("out_name should be of type str.")

        self._out_name = out_name
        return self

    def get_arguments(self) -> Optional[str]:
        return self._arguments

    def set_arguments(self, arguments: Optional[str]) -> BaseTask:
        if arguments is not None and not isinstance(arguments, str):
            raise TypeError("arguments should be of type str.")

        self._arguments = arguments
        return self

    def get_run_arguments(self) -> List[str]:
        return self._run_arguments

    def set_run_arguments(self, run_arguments: List[str]) -> BaseTask:
        if type(run_arguments) != list:
            raise TypeError("run_arguments should be of type list.")
        elif not all((isinstance(run_argument, str)) for run_argument in run_arguments):
            raise ValueError("All run_arguments must be of type str.")

        self._run_arguments = run_arguments
        return self

    def get_out_arguments(self) -> Optional[str]:
        return self._out_arguments

    def set_out_arguments(self, out_arguments: Optional[str]) -> BaseTask:
        if out_arguments is not None and not isinstance(out_arguments, str):
            raise TypeError("out_arguments should be of type str.")

        self._out_arguments = out_arguments
        return self

    def get_binary_content(self) -> Optional[bytes]:
        return self._binary_content

    def set_binary_content(self, content: bytes) -> BaseTask:
        self._binary_content = content
        return self

    def get_binary_content_name(self) -> Optional[str]:
        return self._binary_content_name

    def set_binary_content_name(self, content_name: str) -> BaseTask:
        self._binary_content_name = content_name
        return self

    def get_response_bytes_total(self) -> Optional[int]:
        return self._response_bytes_total

    def set_response_bytes_total(self, bytes_total: int):
        self._response_bytes_total = bytes_total

    def get_response(self) -> Optional[str]:
        return self._response

    def set_response(self, response: str) -> BaseTask:
        self._response = response
        return self

    def append_response(self, response: str) -> BaseTask:
        if self._response is None:
            self._response = ""

        self._response += response
        self.set_response_timestamp(datetime.utcnow())

        return self

    def set_error_response(self, response: str) -> BaseTask:
        self.append_response("[!] " + response)
        self.set_state(TaskState.ERROR)
        self.set_response_timestamp(datetime.utcnow())

        return self

    def get_response_timestamp(self) -> Optional[datetime]:
        return self._response_timestamp

    def set_response_timestamp(self, response_timestamp: datetime) -> BaseTask:
        self._response_timestamp = response_timestamp
        return self

    def get_state(self) -> TaskState:
        return self._state

    def set_state(self, state: TaskState) -> BaseTask:
        self._state = state
        return self

    def get_timestamp(self) -> datetime:
        return self._timestamp

    def set_timestamp(self, timestamp: datetime) -> BaseTask:
        self._timestamp = timestamp
        return self

    def get_operator(self) -> str:
        return self._operator

    def set_operator(self, operator: str) -> BaseTask:
        self._operator = operator
        return self

    def get_implant_uid(self) -> Optional[str]:
        return self._implant_uid

    def set_implant_uid(self, implant_uid: str) -> BaseTask:
        self._implant_uid = implant_uid
        return self

    def get_implant(self) -> Optional[Implant]:
        return self._implant

    def set_implant(self, implant: Implant) -> BaseTask:
        self._implant = implant
        return self

    def validate_arguments(self, arguments: List[str]):
        try:
            _ = self.parser.parse_args(arguments)
        except argparse.ArgumentError as e:
            raise TaskInvalidArgumentsException(e.message)

    def validate_binary_content(self, arguments: List[str]):
        pass

    def validate_files(self, arguments: List[str]):
        pass

    # noinspection PyMethodMayBeStatic
    def rewrite_arguments(self, arguments: List[str]) -> List[str]:
        return arguments

    # noinspection PyMethodMayBeStatic
    def rewrite_response(self, response: Optional[str]) -> Optional[str]:
        return response

    # noinspection PyMethodMayBeStatic
    def _encode_arguments(self, arguments: List[str]) -> List[str]:
        return arguments

    def get_help(self, choice=None) -> str:
        if choice is not None:
            # Retrieve subparsers from parser
            # noinspection PyUnresolvedReferences,PyProtectedMember
            subparsers_actions = [
                action for action in self.parser._actions if isinstance(action, argparse._SubParsersAction)
            ]

            for subparsers_action in subparsers_actions:
                # noinspection PyUnresolvedReferences
                for sub_choice, subparser in subparsers_action.choices.items():
                    if sub_choice == choice:
                        return subparser.format_help()

        return self.parser.format_help()

    def get_description(self) -> str:
        return self.parser.description

    def split_arguments(self, arguments: Optional[str], strip_quotes: bool = False) -> List[str]:
        if arguments is None:
            return []

        try:
            splitted_arguments = shlex.split(arguments, posix=False)
            out_arguments = []

            # Beginning and end quotes from paths if present.
            for argument in splitted_arguments:
                if strip_quotes:
                    out_arguments.append(argument.lstrip('"').rstrip('"'))
                else:
                    out_arguments.append(argument)

            return out_arguments
        except ValueError:
            return []

    # noinspection PyMethodMayBeStatic
    def join_arguments(self, arguments: Optional[List[str]]) -> Optional[str]:
        if arguments is None:
            return None

        if type(arguments) != list:
            raise TypeError("arguments should be of type list.")
        elif not all((isinstance(argument, str)) for argument in arguments):
            raise ValueError("All arguments must be of type str.")
        elif len(arguments) == 0:
            return None

        return " ".join(arguments)

    @staticmethod
    def get_gui_elements() -> Optional[Dict]:
        return None

    def run(self, arguments: List[str]):
        if self._min_privilege is not None and self._min_privilege.value > self._implant.get_privilege().value:
            raise TaskException(f"This task requires at least " + f"{self._min_privilege.value} privileges.")

        if self._supported_architectures is not None and not self._implant.get_arch() in self._supported_architectures:
            raise TaskException(f"This task does not support the {self._implant.get_arch()} architecture.")

        if self._supported_os is not None and not self._implant.get_os_type() in self._supported_os:
            raise TaskException(f"This task does not support {self._implant.get_os()}.")

        self.set_out_arguments(self.join_arguments(self._encode_arguments(arguments)))

    def add_task_before(self, task: BaseTask):
        self._tasks_before.append(task)

    def add_task_after(self, task: BaseTask):
        self._tasks_after.append(task)

    def get_tasks_before(self) -> List[BaseTask]:
        return self._tasks_before

    def get_tasks_after(self) -> List[BaseTask]:
        return self._tasks_after

    def get_files(self) -> List[TaskFile]:
        return self._files

    def set_files(self, files: List[TaskFile]):
        self._files = files

    def get_file_by_name(self, name: str) -> Optional[TaskFile]:
        matching_files = list(filter(lambda file: file.name == name, self.get_files()))

        if len(matching_files) > 1:
            raise TaskInvalidArgumentsException("More than one file with the same name.")
        elif len(matching_files) == 1:
            return matching_files[0]
        else:
            return None

    def get_supported_os(self) -> List[ImplantOSType]:
        return self._supported_os
