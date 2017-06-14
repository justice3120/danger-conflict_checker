require 'shellwords'
require 'tempfile'
require "open3"
require 'securerandom'

module Danger
  # ToDo
  #
  # @example Ensure people are well warned about merging on Mondays
  #
  #          conflict_checker.check_conflict
  #
  # @see  justice3120/danger-conflict_checker
  # @tags conflict
  #
  class DangerConflictChecker < Plugin
    # Allows you to disable a collection of linters from running. Doesn't work yet.
    # You can get a list of [them here](https://github.com/amperser/proselint#checks)
    # defaults to `["misc.scare_quotes", "typography.symbols"]` when it's nil.
    #
    # @return   [Array<String>]
    attr_accessor :check_results

    def initialize(dangerfile)
      super(dangerfile)
    end

    # A method that you can call from your Dangerfile
    # @return   [Array<Hash>]
    #
    def check_conflict()
      puts "aaa"
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
          patch = `git format-patch #{base}..#{branch2} --stdout`.chomp
          f.sync = true
          f.puts patch
          out, s = Open3.capture2e("git apply --check #{f.path}")

          out.each_line do |line|

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
