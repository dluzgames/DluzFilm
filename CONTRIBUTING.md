# Contributing to Dluz Film

Thanks for taking the time to help improve **Dluz Film**.

## Before you start

- For anything larger than a bug fix, open an issue first on [GitHub Issues](https://github.com/dluzgames/DluzFilm/issues) so the approach can be agreed on before you write code.
- Blank issues are disabled. Use one of the issue templates; for bugs, include the output of the in-app debug info popup.
- One logical change per pull request. Unrelated fixes belong in their own PR.

## Building and testing

Setup, dependencies, and platform notes live in [docs/BUILDING.md](docs/BUILDING.md) and [project.md](project.md).

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
```

## Code style

- **Commenting is highly encouraged.** Explain why the code does what it does, especially where workarounds exist for platform quirks, Qt/FFmpeg behaviors, or AI integrations.
- C++20, Qt 6, QML. Keep UI logic in QML and heavy work off the GUI thread.
- User-visible strings must be translatable: `qsTr()` in QML, `tr()` or `QCoreApplication::translate()` in C++.

## Licence

Dluz Film is licensed under the **GNU General Public License v3.0 (GPL-3.0)**. By contributing, you agree that your contributions are licensed under the same terms.
