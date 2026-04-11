# ShauMsi

App Flutter do ShauMsi ("Shauku ya msimu") para organizar datas importantes, anotacoes e gostos de uma pessoa especial.

## Rodar com 1 atalho no VS Code

Este projeto ja esta configurado com uma task automatica em:

- `.vscode/tasks.json`
- `scripts/run-android.ps1`

### Como executar

1. Abra a pasta `shaumsi` no VS Code.
2. Pressione `Ctrl+Shift+B`.
3. Selecione `ShauMsi: Run Android (auto)` (na primeira vez).

Depois disso, a task faz tudo automaticamente:

1. `flutter pub get`
2. Inicia o emulador configurado do projeto (priorizando `ShauMsi_Lite_API_35`)
3. Aguarda boot do Android
4. Executa `flutter run -d <emulator>`

## Rodar manualmente (opcional)

```powershell
flutter run -d emulator-5554
```
