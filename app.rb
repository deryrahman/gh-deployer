# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'digest'

ACCESS_TOKEN = ENV['ACCESS_TOKEN']
SECRET_TOKEN = ENV['SECRET_TOKEN']
EMAIL = ENV['EMAIL']

puts `git config --global user.email "#{EMAIL}"`
puts `git config --global user.name "Bot"`

get '/' do
  'ok'
end

post '/deploy' do
  request.body.rewind
  payload_body = request.body.read
  verify_signature(payload_body)
  payload = JSON.parse(payload_body)

  if request.env['HTTP_X_GITHUB_EVENT'] == 'pull_request' && payload['action'] == 'closed' && payload['pull_request']['merged']
    run_deployment(payload['repository']['full_name'])
  end
end

helpers do
  def verify_signature(payload_body)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['SECRET_TOKEN'], payload_body)
    unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
      halt 500, "Signatures didn't match!"
    end
  end

  def run_deployment(source_repo)
    user = JSON.parse(`curl -sH "Authorization: token #{ACCESS_TOKEN}" https://api.github.com/user`)
    username = user['login']
    tmp = '/tmp/gh-deployer'

    target_repo = "#{username}/#{username}.github.io"
    target_repo_name = target_repo.split('/')[-1]
    target_repo_path = File.join(tmp, target_repo_name)

    source_repo_name = source_repo.split('/')[-1]
    source_repo_path = File.join(tmp, source_repo_name)

    puts `mkdir -p #{tmp}`
    Dir.chdir(tmp) do
      puts `
        git clone https://#{username}:#{ACCESS_TOKEN}@github.com/#{target_repo}.git
        git clone https://#{username}:#{ACCESS_TOKEN}@github.com/#{source_repo}.git
        git remote set-url origin https://#{username}:#{ACCESS_TOKEN}@github.com/#{target_repo}.git
        git remote get-url origin
      `
    end

    format_source_files(source_repo_path)
    targeted_files = get_targeted_files(target_repo_path)
    source_files = get_source_files(source_repo_path)
    updated_files = targeted_files.select { |k, v| source_files[k] && v[1] != source_files[k][1] }
    new_files = source_files.reject { |k| targeted_files[k] }
    new_files = new_files.each { |_k, v| v[0] = give_date(v[0]) }

    files = updated_files.merge(new_files)

    post_path = File.join(target_repo_path, '_posts')
    Dir.chdir(source_repo_path) do
      files.each { |k, v| `cp #{k} #{post_path}/#{v[0]}` }
    end

    puts "Update: #{updated_files.keys}"
    puts "Add: #{new_files.keys}"
    Dir.chdir(target_repo_path) do
      puts `
        git status
        git add -u && git commit -m "Update #{updated_files.keys}"
        git add -A && git commit -m "Add #{new_files.keys}"
        git push origin master
      `
    end

    puts `rm -rf #{tmp}`
  end

  def get_targeted_files(target_repo_path)
    files = []
    post_path = File.join(target_repo_path, '_posts')
    Dir.chdir(post_path) do
      files = Dir.glob '*.md'
      files.map! { |f| [sanitize_filename(f), [f, Digest::SHA256.hexdigest(File.read(f))]] }
    end
    files.to_h
  end

  def get_source_files(source_repo_path)
    Dir.chdir(source_repo_path) do
      files = Dir.glob '*.md'
      files -= Dir.glob 'README.md'
      files.map! { |f| [f, [f, Digest::SHA256.hexdigest(File.read(f))]] }
      files.to_h
    end
  end

  def format_source_files(source_repo_path)
    Dir.chdir(source_repo_path) do
      files = Dir.glob '*.md'
      files -= Dir.glob 'README.md'
      files.each { |f| jekyll_formatter(f) }
    end
  end

  def jekyll_formatter(f)
    content = File.readlines(f).map(&:chomp)
    title = content.shift.match(/# (.+)/)[-1]
    header = ['---', 'layout: post', "title: #{title}", '---', '']
    content = header + content
    File.open(f, 'w') do |fn|
      content.each { |l| fn.puts(l) }
    end
  end

  def sanitize_filename(fn)
    matcher = fn.match(/(\d+-){3}(.*)/)
    (matcher[-1]).to_s
  end

  def give_date(fn)
    "#{Time.now.strftime('%Y-%m-%d')}-#{fn}"
  end
end
