#!/usr/bin/env ruby

require 'octokit'
require 'time'
require 'open-uri'

def env_var var
  ENV[var] or raise "Environment variable #{var} isn't set"
end

def token
  env_var 'GITHUB_TOKEN'
end

def revision
  env_var 'GO_REVISION_DIEGO_WINDOWS_MSI'
end

def release
  label = env_var 'GO_PIPELINE_LABEL'
  "v0.#{label}"
end

def github
  @github ||= Octokit::Client.new :login => 'jvshahid', :access_token => token
end

def repo
  'pivotal-cf/diego-windows-msi'
end

def short_sha
  revision[0..6]
end

def msi_url
  "https://s3.amazonaws.com/diego-windows-msi/output/DiegoWindowsMSI-#{short_sha}.msi"
end

def install_instructions_url
  "https://s3.amazonaws.com/diego-windows-msi/output/INSTALL-#{short_sha}.md"
end

def setup_url
  "https://s3.amazonaws.com/diego-windows-msi/output/setup-#{short_sha}.ps1"
end

def bosh_target
  env_var 'BOSH_TARGET'
end

def bosh_user
  env_var 'BOSH_USER'
end

def bosh_password
  env_var 'BOSH_PASSWORD'
end

def create_github_tag
  puts "Creating release #{release} with sha #{revision}"
  github.create_tag repo,
                    release,
                    "Release #{release}",
                    revision,
                    "commit",
                    "Greenhouse", # tagger name isn't being used by the api
                    "greenhouse@pivotal.io", # tagger email isn't being used by the api
                    Time.now.utc.iso8601

  github.create_release repo,
                        release,
                        name: release,
                        body: "Diego windows MSI Release #{release}"
end

def download_from_s3 url, destination
  File.open(destination, "wb+") do |f|
    open(url, "rb") do |read_file|
      f.write(read_file.read)
    end
  end
  destination
end

def grab_cf_diego_release_sha
  puts "Grabbing cf/diego release shas from #{bosh_target}"
  releases = "/tmp/cf_diego_release_sha.md"
  File.open(releases, "wb+") do |f|
    output = `bosh -t #{bosh_target} -u #{bosh_user} -p #{bosh_password} releases`
    puts output
    f.write output
  end

  puts "Grabbing cf/diego deployments from #{bosh_target}"
  deployments = "/tmp/cf_diego_deployments_sha.md"
  File.open(deployments, "wb+") do |f|
    output = `bosh -t #{bosh_target} -u #{bosh_user} -p #{bosh_password} deployments`
    puts output
    f.write output
  end
  [releases, deployments]
end

def content_type filename
  if File.extname(filename) == ".md"
    "text/plain"
  else
    "application/octet-stream"
  end
end

def upload_release_assets filepath, release
  filename = File.basename filepath
  github.upload_asset release[:url],
                      filepath,
                      content_type: content_type(filename),
                      name: filename
end

puts "Creating github release"
res = create_github_tag
puts "Created github release"

puts "Downloading msi from s3"
file = download_from_s3 msi_url, "/tmp/DiegoWindowsMSI.msi"
puts "Downloaded msi from s3"

puts "Uploading msi to github release"
upload_release_assets file, res
puts "Uploaded msi to github release"

puts "Downloading installation instructions from s3"
file = download_from_s3 install_instructions_url, "/tmp/INSTALL.md"
puts "Downloaded installation instructions from s3"

puts "Uploading installation instructions to github release"
upload_release_assets file, res
puts "Uploaded installation instructions to github release"

puts "Downloading setup script from s3"
file = download_from_s3 setup_url, "/tmp/setup.ps1"
puts "Downloaded setup script from s3"

puts "Uploading setup script to github release"
upload_release_assets file, res
puts "Uploaded setup script to github release"

puts "Grabbing cf/diego release sha"
files = grab_cf_diego_release_sha
files.each { |f| upload_release_assets f, res }
puts "Grabbed and uploaded cf/diego release sha"
