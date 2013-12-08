require 'redis'
require 'redis-namespace'
require 'json'
require 'sinatra'
require 'nokogiri'
require 'open-uri'
require 'benchmark'
require 'pry'
require 'coffee-script'

def benchmark
  start = Time.now.to_f
  yield
  puts Time.now.to_f - start
end

module MyLWT


  class Text
    attr_accessor :text

    def initialize(url)
      source = open(url).read
      @text = Text.filter_script(Nokogiri::HTML(source))
      @text.xpath('//link').each do |elem|
        elem['href'] = URI.join(url, elem['href']).to_s
      end
      @text.xpath('//img').each do |elem|
        elem['src'] = URI.join(url, elem['src']).to_s
      end
      @text.xpath('//a').each do |elem|
        begin
          elem['href'] = '/?uri=' + URI.join(url, elem['href']).to_s
        end rescue nil
      end
      @redis = MyLWT::Config.redis
    end

    def self.filter_script(text)
      text.xpath('//body/script').remove
      text.xpath("//@*[starts-with(name(),'on')]").remove 
      text
    end

    def words
      @text.text.split(/\W+/).uniq.map{|w| w.downcase}.select{|w| not w =~ /^[0-9]+$/}
    end

    def known_words
      key = "action:#{rand.to_s[2..8]}"
      @redis.sadd key, self.words
      known = MyLWT::Config.redis.sinter 'known', key
      @redis.del key
      known
    end

    def unknown_words
      self.words - self.known_words - self.translated_words.keys
    end

    def translated_words
      tr = Hash[self.words.zip @redis.hmget('translated', self.words)]
      tr = tr.delete_if { |k, v| v == nil }
      tr
    end
  end

  class Config
    def self.redis
      r = Redis.new(db: 2)
      @redis ||= Redis::Namespace.new(:mylwt, redis: r)
    end
  end

  class Word
    def self.known?(word)
      Config.redis.sismember('known', word.downcase) 
    end
    def self.translation(word)
      Config.redis.hget('translated', word.downcase)
    end
    def self.remember(word, translation='')
      if translation == ''
        Config.redis.sadd('known', word.downcase)
      else
        Config.redis.hset('translated', word.downcase, translation)
      end
    end
    def self.forget(word)
      Config.redis.srem('known', word.downcase)
      Config.redis.hdel('translated', word.downcase)
    end
  end

  class App
    def initialize
      @redis = Config.redis
    end 
  
    def run
    end
  end

end

include MyLWT
$app = App.new
$text = nil
Encoding.default_external = "utf-8"

#use Rack::Auth::Basic do |username, password|
#  username == 'user' && password == 'pass'
#end

get '/words/known' do
  JSON.generate($text.known_words)
end

get '/words/unknown' do
  JSON.generate($text.unknown_words)
end

get '/words/translated' do
  JSON.generate($text.translated_words)
end

get '/' do
  if params[:uri]
    $text = Text.new params[:uri]
  end

  erb 'index.html'.to_sym
end

get '/remember/:word' do
  w = params[:word]
  Word.remember(w)
  highlight_js w, :known
end

get '/forget/:word' do
  w = params[:word]
  Word.forget(w)
  highlight_js w, :unknown
end

post '/translate' do
  Word.remember(params[:word], params[:translation])
  coffee erb(:'translate.coffee', locals: { word: params[:word], translation: params[:translation] })
end


def highlight_js(word, classname)
  "$(\"body\").highlight(\"#{word}\", {  className: '#{classname}', wordsOnly: true });"
end
