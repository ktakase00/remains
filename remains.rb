require 'optparse'
require 'yaml'
require 'json'

class Remains

  # 開始
  #
  def run
    # コマンドライン引数を解析
    opt = create_option_parser
    opt.parse!

    # 設定ファイル読み込み
    return if !load_config

    # 実行開始前の準備
    return if !prepare

    # 実行開始
    run_main
  end

  private

  # コマンドライン引数のパーサーを生成
  # @todo 設定ファイルの内容をコマンドライン引数で上書きできるようにしたい。
  # @return [OptionParser] コマンドライン引数のパーサー
  #
  def create_option_parser
    opt = OptionParser.new
    # バージョン番号
    opt.version = '1.0.0'

    # 設定ファイル
    opt.on('-c config_path') do |v|
      @config_path = v
    end
  end

  # 設定ファイル読み込み
  # @return [Boolean] 設定ファイルが有効ならtrue
  #
  def load_config
    @config = {}
    res = false

    # パスが指定されていなければデフォルトのパスとする
    @config_path = "#{File.dirname(__FILE__)}/config.yml" if @config_path.nil?

    put_log "config path: #{@config_path}"

    begin
      # 設定ファイルを読み込み
      data = YAML.load_file(@config_path)
      # ハッシュのキーをシンボル化するためいったんJSONに変換してからハッシュに再変換
      json = JSON.generate(data)
      @config = JSON.parse(json, symbolize_names: true)
      res = true
    rescue => e
      put_log "failed to load config: #{e.message}", :error
    end
    res
  end

  # 実行開始前の準備
  # @return [Boolean] 実行可能ならtrue
  #
  def prepare
    res = true

    # 処理対象パスを決定
    @path = ARGV[0]

    # 処理対象パスが有効かどうかを判定
    if @path.nil?
      put_log 'insufficient arguments.', :error
      res = false
    else
      # 末尾が区切り文字なら削除する
      @path = @path.sub(/\/$/, '') if @path =~ /[^\/]+\/$/
    end
    res
  end

  # 実行開始
  #
  def run_main
    # 検索対象ファイルの拡張子
    target = @config.has_key?(:target) ? @config[:target].gsub(/\./, '\.') : ''
    # 検索対象の正規表現の配列
    pattern = @config.has_key?(:pattern) ? @config[:pattern].join('|') : ''
    # 除外するディレクトリの配列
    exclude = @config.has_key?(:exclude) ? @config[:exclude].join('|') : ''

    # 検索対象のパターンが未指定の場合はエラーとする
    if pattern.empty?
      put_log "pattern is not specified.", :error
      return
    end

    # ルートパスを設定
    path_ary = [@path]
    count = 0

    # 検索対象のパスがなくなるまで繰り返し
    while !path_ary.empty?
      # 配列の先頭の要素を取り出してファイルタイプを調べる
      current_path = path_ary.shift
      file_type = File.ftype(current_path)

      case file_type
      when 'directory'
        # ディレクトリとファイルを列挙して検索対象パスに追加する
        path_ary.concat(enumerate(current_path, exclude))
      when 'file'
        # ファイル内からパターンに一致する行を検索する
        count += check(current_path, target, pattern)
      else
        # シンボリックリンクなどは非対応
        put_log "upsupported file type: #{file_type}: #{current_path}"
      end
    end

    # パターンに一致した行数を出力
    put_log "#{count} lines found."
  end

  # ディレクトリとファイルを列挙して検索対象パスに追加する
  # @param [String] path 対象パス(絶対パスで指定)
  # @param [String] exclude 検索対象外とするパスの正規表現
  # @return [Array] 検索対象として追加するパスの配列
  #
  def enumerate(path, exclude)
    # 絶対パスからコマンドライン引数で指定されたパス部分を削除した文字列を準備しておく
    base_path = path.sub(/^#{@path}/, '')
    path_ary = []
    d = nil

    begin
      # すべてのファイルまたはディレクトリについて繰り返し
      d = Dir.open(path)
      d.each do |it|
        # 自分と一つ上のディレクトリは無視
        next if it =~ /^(\.|\.\.)$/
        # 除外するディレクトリのパターンに一致する場合は無視
        next if !exclude.empty? && "#{base_path}/#{it}" =~ /#{exclude}/
        # 検索対象に追加
        path_ary.push("#{path}/#{it}")
      end

    rescue => e
      put_log "enumerae failed: #{e.message}", :error

    ensure
      d.close if !d.nil?
    end

    path_ary
  end

  # ファイル内からパターンに一致する行を検索する
  # @param [String] path ファイルのパス
  # @param [String] target 検索対象ファイルの拡張子
  # @param [String] pattern 検索対象の正規表現
  # @return [Fixnum] 検索対象の正規表現に一致した行の数
  #
  def check(path, target, pattern)
    # 検索対象ファイルの拡張子に一致しない場合は無視
    return 0 if !(path =~ /#{target}$/)

    result_ary = []
    f = nil

    begin
      # ファイルを読み込む
      f = File.open(path, 'r')
      data = f.read

      # 改行文字で分解
      lines = data.split("\n")

      # すべての行について繰り返し
      lines.each_with_index do |line, number|
        # 正規表現に一致するかどうかを判定
        if line =~ /#{pattern}/
          result_ary.push("##{number+1}: #{line}")
        end
      end

    rescue => e
      put_log "failed to read file: #{path}: #{e.message}", :error

    ensure
      f.close if !f.nil?
    end

    # 一致した行があれば画面に出力する
    if !result_ary.empty?
      STDOUT.puts "#{path}:"
      result_ary.each do |line|
        STDOUT.puts line
      end
    end

    # 一致した行数を返す
    result_ary.length
  end

  # ログ出力
  # @param [String] msg ログ内容
  # @param [Symbol] level ログレベル
  #
  def put_log(msg, level: :info)
    prefix = level.to_s.upcase
    STDERR.puts "#{prefix}: #{msg}"
  end
end

app = Remains.new
app.run
