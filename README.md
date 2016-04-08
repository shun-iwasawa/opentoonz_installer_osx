# MacOSX 用 Installer (pkg) 作成スクリプト

## 依存パッケージ・モジュール

- Xcode (`pkgbuild, productbuild`)
- Qt
- gsed

## スクリプト実行

`./app.rb [BUNDLE_PATH] [STUFF_DIR] [VERSION(floatnum)] [MACDEPLOYQT_PATH] [DELETE_RPATH]`

上記のように実行時引数で

- ビルド済バンドルへのパス
- 本体リポジトリの stuff ディレクトリへのパス
- pkg のバージョン
- `macdeployqt` コマンドのパス
- 削除しておくrpath(ユーザーに依存しているもの)

を与えて下さい。スクリプト内の途中で外部コマンドの実行に失敗すると途中で止まります。

実際の実行例

```
./app.rb ~/Workspaces/github/kogaki/toonz/opentoonz/toonz/build/toonz/OpenToonz_1.0.app ~/Workspaces/github/kogaki/toonz/opentoonz/stuff 0.0.1 ~/Qt5.5.1/5.5/clang_64/bin/macdeployqt ~/Qt5.5.1/5.5/clang_64/lib
```
