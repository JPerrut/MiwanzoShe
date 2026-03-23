# Miwanzo

App Flutter para organizar datas importantes, anotações e gostos de uma pessoa especial.

## Rodar com 1 atalho no VS Code

Este projeto já está configurado com uma task automática em:

- `.vscode/tasks.json`
- `scripts/run-android.ps1`

### Como executar

1. Abra a pasta `miwanzo` no VS Code.
2. Pressione `Ctrl+Shift+B`.
3. Selecione `Miwanzo: Run Android (auto)` (na primeira vez).

Depois disso, a task faz tudo automaticamente:

1. `flutter pub get`
2. Inicia o emulador `Miwanzo_API_35` (se não estiver aberto)
3. Aguarda boot do Android
4. Executa `flutter run -d <emulator>`

## Rodar manualmente (opcional)

```powershell
flutter run -d emulator-5554
```
