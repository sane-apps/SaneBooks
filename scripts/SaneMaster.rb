#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'

project_root = File.expand_path('..', __dir__)
manifest_path = File.join(project_root, '.saneprocess')
manifest = YAML.safe_load(File.read(manifest_path), aliases: false) || {}
command = ARGV.first

if command == 'release' && manifest.dig('release', 'enabled') != true
  warn 'SaneBooks release is disabled by .saneprocess (release.enabled: false).'
  exit 78
end

if command == 'appstore_preflight' && manifest.dig('appstore', 'enabled') != true
  warn 'SaneBooks App Store lane is disabled by .saneprocess (appstore.enabled: false).'
  exit 78
end

master = nil
dir = project_root
loop do
  candidate = File.join(dir, 'infra', 'SaneProcess', 'scripts', 'SaneMaster.rb')
  if File.exist?(candidate)
    master = candidate
    break
  end

  parent = File.dirname(dir)
  break if parent == dir

  dir = parent
end

home_candidate = File.expand_path('~/SaneApps/infra/SaneProcess/scripts/SaneMaster.rb')
master ||= home_candidate if File.exist?(home_candidate)

unless master && File.exist?(master)
  warn 'SaneMaster is unavailable. Clone SaneBooks inside the SaneApps monorepo for canonical verification.'
  exit 1
end

Dir.chdir(project_root)
exec('ruby', master, *ARGV)
