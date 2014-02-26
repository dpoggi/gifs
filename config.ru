require 'erb'

require 'bundler/setup'
require 'rack'
require 'fog'
require 'dotenv'
Dotenv.load

class Gifs
  def initialize
    s3 = Fog::Storage.new({
      provider: 'AWS',
      aws_access_key_id: ENV['S3_KEY'],
      aws_secret_access_key: ENV['S3_SECRET'],
    })
    s3_bucket = s3.directories.get(ENV['S3_BUCKET'])
    @gifs = s3_bucket.files.map do |gif|
      {
        name: gif.key,
        url: "https://#{ENV['S3_BUCKET']}.s3.amazonaws.com/#{gif.key}",
        size: format_size(gif.content_length),
        mtime: gif.last_modified,
      }
    end

    dir = File.expand_path(File.join(__FILE__, '..'))
    @index_page = eval_template(File.join(dir, 'index.html.erb'))
    @not_found_page = File.read(File.join(dir, '404.html'))
    @response_headers = {
      'Content-Type' => 'text/html',
    }
  end

  def call(env)
    dup._call(env)
  end

  def _call(env)
    case env['PATH_INFO']
    when '/' then
      [200, @response_headers, [@index_page]]
    else
      [404, @response_headers, [@not_found_page]]
    end
  end

  private
  def eval_template(template)
    ERB.new(File.read(template)).result(binding)
  end

  def format_size(bytes)
    [
      ['%.1fT', 1 << 40],
      ['%.1fG', 1 << 30],
      ['%.1fM', 1 << 20],
      ['%.1fK', 1 << 10],
    ].each do |format, size|
      return format % (bytes.to_f / size) if bytes >= size
    end

    bytes.to_s + 'B'
  end
end

run Gifs.new
