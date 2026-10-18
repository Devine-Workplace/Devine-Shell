from importlib.metadata import PackageNotFoundError, version


def print_version() -> None:
    try:
        current = version("devine")
    except PackageNotFoundError:
        current = "0.1.0"
    print(f"Devine {current}")
