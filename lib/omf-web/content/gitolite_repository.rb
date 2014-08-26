begin
  require 'rugged'
rescue LoadError => e
  puts <<-ERR
#{e.message}

# To use gitolite support, please install GEM 'rugged'
#
#   gem install rugged
#
# See (https://github.com/libgit2/rugged) for more details
  ERR
  exit(1)
end

require 'find'
require 'omf_base/lobject'
require 'omf_web'
require 'omf-web/content/content_proxy'
require 'omf-web/content/repository'

module OMF::Web

  module GitHelper
    def fetch!(repo, branch = "origin", opts = {})
      repo.fetch(branch, opts)
    end

    def push!(repo, branch = "origin", opts = {})
      repo.push(branch, ["refs/heads/master"], opts)
    end

    def read_blob(repo, path)
    end

    # Write content into a blob object, stage it and commit
    def commit_content_change!(repo, content, opts = {})
      oid = repo.write(content, :blob)

      index = repo.index
      index.read_tree(repo.head.target.tree) unless repo.empty?

      # FIXME What should mode be?
      index.add(path: opts[:path], oid: oid, mode: 0100644)

      # Author &|| committer shall contains :email and :name
      author = opts[:author]
      commiter = opts[:committer] || author
      message = opts[:message] || "New commit via LabWiki"

      Rugged::Commit.create(@repo, {
        tree: index.write_tree(repo),
        author: author.merge(time: Time.now),
        committer: committer.merge(time: Time.now),
        message: message,
        parents: repo.empty? ? [] : [ repo.head.target ].compact,
        update_ref: 'HEAD'
      })
    end
  end

  class GitoliteController < OMF::Base::LObject
    include Singleton
    include GitHelper

    WORKING_DIR = "/tmp/gitolite_admin"

    attr_accessor :repositories
    attr_reader :credentials

    def initialize
      super
    end

    def setup(opts)
      @credentials = Rugged::Credentials::SshKey.new(opts[:credentials])
      @repo = begin
                Rugged::Repository.new(WORKING_DIR)
              rescue Rugged::OSError
                Rugged::Repository.clone_at(opts[:admin_repo], WORKING_DIR, { credentials: @credentials })
              end
    end

    # Adding a new repository for the end user
    #
    # * Allow RW+ for the end user
    # * Allow RW+ for the gitolite admin
    # * Repository name will be identical to the end user id
    def add_repo(id)
      #return if repo_exists?(id)
      # Read gitolite.conf
      # Add keys
      # Append repo setup
      if id =~  /^.+@.+:(.+)\.git$/
        puts "repo #{$1}\n    RW+     =   @all\n"
      else
        raise StandardError, "Malformed repository url '#{id}'"
      end
      push!(@repo, "origin", { credentials: @credentials })
    end

    # Adding a new public key for the user
    def add_key(id, key)
      push!(@repo, "origin", { credentials: @credentials })
    end

    def repo_exists?(id)
      fetch!(@repo, "origin", { credentials: @credentials })
    end
  end
  # This class provides an interface to a GIT repository
  # It retrieves, archives and versions content.
  #
  class GitoliteContentRepository < ContentRepository

    WORKING_DIR_BASE = "/tmp/lw_repositories"

    attr_reader :name, :top_dir

    def self.setup_admin
      @@gitolite_admin = Rugged::Repository.new(@top_dir)
    end

    def initialize(name, opts)
      GitoliteController.instance.setup(opts[:gitolite])

      super

      @repo = Rugged::Repository.clone_at(@top_dir, credentials: GitoliteController.instance.credentials)
    end

    def write(content_descr, content, message, opts = {})
      raise ReadOnlyContentRepositoryException.new if @read_only

      path = _get_path(content_descr)

      commit_content_change(@repo, content, {
        path: path,
        message: message,
        author: opts[:author],
        committer: opts[:committer]
      })
    end

    # Return a URL for a path in this repo
    #
    def get_url_for_path(path)
      @url_prefix + path
    end

    #
    # Return an array of file names which are in the repository and
    # match 'search_pattern'
    #
    def find_files(search_pattern, opts = {})
      search_pattern = Regexp.new(search_pattern)
      res = []

      unless @repo.empty?
        tree = @repo.head.target.tree

        tree.each do |t|
          path = t[:name]
          if path.match(search_pattern)
            mime_type = mime_type_for_file(path)
            res << { path: path, url: get_url_for_path(path), name: name, mime_type: mime_type }
          end
            #:id => Base64.encode64(long_name).gsub("\n", ''),
            #size: e.size, blob: e.id}
        end
      end

      res
      #fs = _find_files(search_pattern, tree, nil, res)
      #fs
    end

    def _find_files(search_pattern, tree, dir_path, res)
      tree.contents.each do |e|
        d = e.name
        long_name = dir_path ? "#{dir_path}/#{d}" : d

        if e.is_a? Grit::Tree
          _find_files(search_pattern, e, long_name, res)
        else
          if long_name.match(search_pattern)
            mt = mime_type_for_file(e.name)
            #path = @url_prefix + long_name
            path = long_name
            res << {
              path: path,
              url: get_url_for_path(path),
              name: e.name,
              mime_type: mt,
              size: e.size,
              blob: e.id
            }
          end
        end
      end
      res
    end

    protected

    def _create_if_not_exists
      unless GitoliteController.instance.repo_exists?(@top_dir)
        GitoliteController.instance.add_repo(@top_dir)
      end
    end
  end # class
end # module
