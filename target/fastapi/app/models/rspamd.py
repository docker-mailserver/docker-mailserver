from pydantic import BaseModel

# Filenames under `rspamd/override.d/` (e.g. `worker-controller.inc`, `arc.conf`): no path
# separators or leading dot, so a name can't escape the directory or hide as a dotfile.
FILENAME_PATTERN = r"^[A-Za-z0-9][A-Za-z0-9_.-]*$"


class RspamdCustomCommandsRead(BaseModel):
    content: str


class RspamdCustomCommandsWrite(BaseModel):
    content: str


class RspamdOverrideFile(BaseModel):
    name: str


class RspamdOverrideFileRead(BaseModel):
    name: str
    content: str


class RspamdOverrideFileWrite(BaseModel):
    content: str
