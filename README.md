# remains

ソースコードの中から不要な残骸を発掘するツールです。

## 使い方

### 実行

```
ruby remains.rb [options] <target_path>
```

### オプション引数

**-c config_path**

> 設定ファイルのパス(省略時はconfig.ymlが参照される)

**--version**

> バージョン番号を表示する。

## 設定ファイル

YAMLファイルで記述します。

### 項目

|項目|内容|
|---|---|
|target|検索対象ファイルの拡張子(ドット付き)をパイプ記号で連結した文字列を指定する。|
|pattern|発掘する文字列の正規表現を配列で指定する。|
|exclude|除外するディレクトリのパスを配列で指定する。|

### 記述例

```yaml
target: .rb|.sql
pattern:
  - todo|TODO
  - = (null|NULL)
exclude:
  - vendor/bundler
  - node_modules
  - log
  - tmp
```

## 実行結果

実行例：


```
$ ruby remains.rb .
INFO: config path: ./config.yml
./remains.rb:
#27:   # @todo 設定ファイルの内容をコマンドライン引数で上書きできるようにしたい。
INFO: 1 lines found.
```

設定ファイルのpatternに一致する文字列を含む行が見つかった場合、ファイル名と行番号、行の内容が表示されます。

一致した結果は標準出力に出力されます。
その他のプログラムが出力するメッセージは標準エラー出力に出力されます。
