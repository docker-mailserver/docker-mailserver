from typing import Annotated, Literal

from pydantic import BaseModel, Field, ValidationError

# Filenames under `rspamd/override.d/` (e.g. `worker-controller.inc`, `arc.conf`): no path
# separators or leading dot, so a name can't escape the directory or hide as a dotfile.
FILENAME_PATTERN = r"^[A-Za-z0-9][A-Za-z0-9_.-]*$"

# Module/option identifiers (e.g. `classifier-bayes`, `secure_ip`): a single whitespace-free
# token, matching how `_rspamd_handle_user_modules_adjustments` in
# `target/scripts/helpers/rspamd.sh` splits a line on whitespace via `read`. Also keeps
# `module` safe to use as `{module}.conf` and `option` safe to embed in the `sed` pattern
# built by that script's `__add_or_replace`.
_IDENTIFIER_PATTERN = r"^[A-Za-z0-9_-]+$"

# `value` / `line`: the remainder of a directive line, so anything is allowed except a
# newline, which would let a single field smuggle in an extra (unvalidated) directive line.
_LINE_PATTERN = r"^[^\r\n]+$"

# The 7 directives understood by `_rspamd_handle_user_modules_adjustments`. See:
# https://docker-mailserver.github.io/docker-mailserver/latest/config/security/rspamd/#with-the-help-of-a-custom-file


class EnableModuleCommand(BaseModel):
    """Enable an Rspamd module: `enable-module <module>`."""

    command: Literal["enable-module"] = "enable-module"
    module: str = Field(pattern=_IDENTIFIER_PATTERN, examples=["dkim"])


class DisableModuleCommand(BaseModel):
    """Disable an Rspamd module: `disable-module <module>`."""

    command: Literal["disable-module"] = "disable-module"
    module: str = Field(pattern=_IDENTIFIER_PATTERN, examples=["chartable"])


class SetOptionForModuleCommand(BaseModel):
    """Set/overwrite an option in `override.d/<module>.conf`."""

    command: Literal["set-option-for-module"] = "set-option-for-module"
    module: str = Field(pattern=_IDENTIFIER_PATTERN, examples=["classifier-bayes"])
    option: str = Field(pattern=_IDENTIFIER_PATTERN, examples=["autolearn"])
    value: str = Field(pattern=_LINE_PATTERN, examples=["true"])


class SetOptionForControllerCommand(BaseModel):
    """Set/overwrite an option in `override.d/worker-controller.inc`."""

    command: Literal["set-option-for-controller"] = "set-option-for-controller"
    option: str = Field(pattern=_IDENTIFIER_PATTERN, examples=["secure_ip"])
    value: str = Field(pattern=_LINE_PATTERN, examples=['"0.0.0.0/0"'])


class SetOptionForProxyCommand(BaseModel):
    """Set/overwrite an option in `override.d/worker-proxy.inc`."""

    command: Literal["set-option-for-proxy"] = "set-option-for-proxy"
    option: str = Field(pattern=_IDENTIFIER_PATTERN, examples=["reject_message"])
    value: str = Field(pattern=_LINE_PATTERN, examples=['"Rejected - Detected as spam"'])


class SetCommonOptionCommand(BaseModel):
    """Set/overwrite an option in `override.d/options.inc`."""

    command: Literal["set-common-option"] = "set-common-option"
    option: str = Field(pattern=_IDENTIFIER_PATTERN, examples=["local_addrs"])
    value: str = Field(pattern=_LINE_PATTERN, examples=['"192.168.0.0/16"'])


class AddLineCommand(BaseModel):
    """Append a raw config line to `override.d/<filename>`."""

    command: Literal["add-line"] = "add-line"
    filename: str = Field(pattern=FILENAME_PATTERN, examples=["worker-proxy.inc"])
    line: str = Field(pattern=_LINE_PATTERN, examples=['reject_message = "Rejected as spam"'])


RspamdCustomCommand = Annotated[
    EnableModuleCommand
    | DisableModuleCommand
    | SetOptionForModuleCommand
    | SetOptionForControllerCommand
    | SetOptionForProxyCommand
    | SetCommonOptionCommand
    | AddLineCommand,
    Field(discriminator="command"),
]

# directive -> (positional field names, model type). The last field always takes the
# remainder of the line (mirrors the bash `read`/`maxsplit` behaviour it must round-trip).
_DIRECTIVE_FIELDS: dict[str, tuple[list[str], type[BaseModel]]] = {
    "enable-module": (["module"], EnableModuleCommand),
    "disable-module": (["module"], DisableModuleCommand),
    "set-option-for-module": (["module", "option", "value"], SetOptionForModuleCommand),
    "set-option-for-controller": (["option", "value"], SetOptionForControllerCommand),
    "set-option-for-proxy": (["option", "value"], SetOptionForProxyCommand),
    "set-common-option": (["option", "value"], SetCommonOptionCommand),
    "add-line": (["filename", "line"], AddLineCommand),
}


def serialize_custom_commands(commands: list[RspamdCustomCommand]) -> str:
    """Render typed commands back into `custom-commands.conf` directive lines."""
    lines: list[str] = []
    for entry in commands:
        field_names, _ = _DIRECTIVE_FIELDS[entry.command]
        values = [str(getattr(entry, field_name)) for field_name in field_names]
        lines.append(" ".join([entry.command, *values]))
    return "".join(f"{line}\n" for line in lines)


def parse_custom_commands(content: str) -> list[RspamdCustomCommand]:
    """Parse `custom-commands.conf` content into typed commands.

    Raises ValueError (with a 1-indexed line number) on the first invalid line.
    """
    commands: list[RspamdCustomCommand] = []
    for line_number, raw_line in enumerate(content.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        commands.append(_parse_command_line(line, line_number))
    return commands


def _parse_command_line(line: str, line_number: int) -> RspamdCustomCommand:
    verb, _, rest = line.partition(" ")
    fields = _DIRECTIVE_FIELDS.get(verb)
    if fields is None:
        raise ValueError(
            f"line {line_number}: unknown directive {verb!r} "
            f"(expected one of {', '.join(_DIRECTIVE_FIELDS)})"
        )

    field_names, model = fields
    parts = rest.split(maxsplit=len(field_names) - 1)
    if len(parts) < len(field_names):
        raise ValueError(f"line {line_number}: {verb!r} requires {len(field_names)} argument(s)")

    try:
        return model(command=verb, **dict(zip(field_names, parts, strict=True)))
    except ValidationError as error:
        raise ValueError(f"line {line_number}: {error}") from error


class RspamdCustomCommandsRead(BaseModel):
    commands: list[RspamdCustomCommand]


class RspamdCustomCommandsWrite(BaseModel):
    commands: list[RspamdCustomCommand]


class RspamdOverrideFile(BaseModel):
    name: str


class RspamdOverrideFileRead(BaseModel):
    name: str
    content: str


class RspamdOverrideFileWrite(BaseModel):
    content: str
