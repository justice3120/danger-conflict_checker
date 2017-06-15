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

    def initialize(dangerfile)
      super(dangerfile)
    end

    # A method that you can call from your Dangerfile
    # @return   [Array<Hash>]
    #
    def check_conflict()
      check_results = []

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

            if 'patch failed' == line.split(':')[1].strip
              conflict = {
                file: line.split(':')[2].strip,
                line: line.split(':')[3].strip.to_i
              }
              result[:conflicts] << conflict
            end
          end

          result[:mergeable] = result[:conflicts].empty?
        end

        g.remove_remote(uuid)

        check_results << result
      end

      check_results
    end

    def check_conflict_and_comment()
      results = check_conflict()

      results.each do |result|
        message = "<p>This PR conflicts with <a href=\"#{result[:pull_request][:html_url]}\">##{result[:pull_request][:number]}</a>.</p>"
        table = '<table><thead><tr><th width="100%">File</th><th>Line</th></tr></thead><tbody>' + result[:conflicts].map do |conflict|
          file = conflict[:file]
          line = conflict[:line]
          line_link = "#{result[:pull_request][:head][:repo][:html_url]}/blob/#{result[:pull_request][:head][:ref]}/#{file}#L#{line}"
          "<tr><td>#{file}</td><td><a href=\"#{line_link}\">#L#{line}</a></td></tr>"
        end.join('') + '</tbody></table>'
        puts (message + table)
        warn("<div>" + message + table + "</div>")
      end

      results
    end
  end
end
