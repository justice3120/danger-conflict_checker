require 'shellwords'
require 'tempfile'
require 'securerandom'

module Danger
  # This is your plugin class. Any attributes or methods you expose here will
  # be available from within your Dangerfile.
  #
  # To be published on the Danger plugins site, you will need to have
  # the public interface documented. Danger uses [YARD](http://yardoc.org/)
  # for generating documentation from your plugin source, and you can verify
  # by running `danger plugins lint` or `bundle exec rake spec`.
  #
  # You should replace these comments with a public description of your library.
  #
  # @example Ensure people are well warned about merging on Mondays
  #
  #          conflict_checker.check_conflict
  #
  # @see  Masayoshi Sakamoto/danger-conflict_checker
  # @tags conflict
  #
  class DangerConflictChecker < Plugin
    # Allows you to disable a collection of linters from running. Doesn't work yet.
    # You can get a list of [them here](https://github.com/amperser/proselint#checks)
    # defaults to `["misc.scare_quotes", "typography.symbols"]` when it's nil.
    #
    # @return   [Array<String>]
    attr_accessor :check_results

    # A method that you can call from your Dangerfile
    # @return   [Array<String>]
    #
    def check_conflict(dummy=nil)
      @check_results = []

      repo_name = github.pr_json[:base][:repo][:full_name]

      pull_requests = github.api.pull_requests(repo_name).select do |pr|
        pr[:id] != github.pr_json[:id] && pr[:base][:label] == github.pr_json[:base][:label]
      end

      return if pull_requests.empty?

      g = Git.open(Dir.pwd)

      pull_requests.each do |pr|
        result = {
          pull_request: pr,
          mergeable: true,
          conflicts: []
        }

        uuid = SecureRandom.uuid

        r = g.add_remote(uuid, pr[:head][:repo][:ssh_url])
        r.fetch()

        branch1 = github.pr_json[:head][:ref]
        branch2 = "#{uuid}/#{pr[:head][:ref]}"

        base = `git merge-base #{branch1} #{branch2}`.chomp

        Tempfile.open('tmp') do |f|
          puts "aaaa"
          patch = `git format-patch #{base}..#{branch2} --stdout`.chomp
          f.sync = true
          f.puts patch
          output = `git apply --check #{f.path}`

          p output

          output.each_line do |line|
            puts "bbb"
            p line
            p line.split(':')[1].chomp

            if 'patch failed' == line.split(':')[1].chomp
              conflict = {
                file: line.split(':')[2].chomp,
                line: line.split(':')[3].chomp
              }
              result[:conflicts] << conflict
            end
          end

          result[:mergeable] = result[:conflicts].empty?
        end

        g.remove_remote(uuid)

        @check_results << result
      end

      @check_results
    end
  end
end
