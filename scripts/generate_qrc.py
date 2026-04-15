from pathlib import Path


def iter_asset_files(asset_path: Path):
    for file_path in asset_path.rglob("*"):
        if not file_path.is_file():
            continue

        relative_path = file_path.relative_to(asset_path.parent)
        if any(part.startswith(".") for part in relative_path.parts):
            continue

        yield relative_path.as_posix()


def generate_qrc(asset_dir, output_file):
    asset_path = Path(asset_dir)

    with open(output_file, "w") as f:
        f.write("<RCC>\n")
        f.write('    <qresource prefix="/">\n')

        for relative_path in iter_asset_files(asset_path):
            f.write(f"        <file>{relative_path}</file>\n")

        f.write("    </qresource>\n")
        f.write("</RCC>\n")

if __name__ == "__main__":
    assert Path("pyproject.toml").exists(), "Must be run from project root"
    generate_qrc('./assets', './resources.qrc')