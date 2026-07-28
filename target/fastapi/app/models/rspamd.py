from pydantic import BaseModel, field_validator

# Filenames under `rspamd/override.d/` (e.g. `worker-controller.inc`, `arc.conf`): no path
# separators or leading dot, so a name can't escape the directory or hide as a dotfile.
FILENAME_PATTERN = r"^[A-Za-z0-9][A-Za-z0-9_.-]*$"

# Directives understood by `_rspamd_handle_user_modules_adjustments` in
# `target/scripts/helpers/rspamd.sh`, mapped to how many whitespace-delimited arguments they
# require (the last argument consumes the rest of the line). See:
# https://docker-mailserver.github.io/docker-mailserver/latest/config/security/rspamd/#with-the-help-of-a-custom-file
_DIRECTIVE_ARG_COUNTS = {
    "set-common-option": 2,
    "set-option-for-controller": 2,
    "set-option-for-proxy": 2,
    "enable-module": 1,
    "disable-module": 1,
    "set-option-for-module": 3,
    "add-line": 2,
}


def _validate_custom_commands(content: str) -> str:
    for line_number, raw_line in enumerate(content.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        verb, _, rest = line.partition(" ")
        arg_count = _DIRECTIVE_ARG_COUNTS.get(verb)
        if arg_count is None:
            raise ValueError(
                f"line {line_number}: unknown directive {verb!r} "
                f"(expected one of {', '.join(_DIRECTIVE_ARG_COUNTS)})"
            )

        if len(rest.split(maxsplit=arg_count - 1)) < arg_count:
            raise ValueError(f"line {line_number}: {verb!r} requires {arg_count} argument(s)")

    return content


class RspamdCustomCommandsRead(BaseModel):
    content: str


class RspamdCustomCommandsWrite(BaseModel):
    content: str

    @field_validator("content")
    @classmethod
    def _valid_directives(cls, content: str) -> str:
        return _validate_custom_commands(content)


class RspamdOverrideFile(BaseModel):
    name: str


class RspamdOverrideFileRead(BaseModel):
    name: str
    content: str


class RspamdOverrideFileWrite(BaseModel):
    content: str
