require 'rugged'
require 'fileutils'

class GitRepo

  attr_accessor :path

  def initialize(path)
    @path = path
  end

  def exists?
    File.exists?(path)
  end

  def destroy
    FileUtils.rm_rf path
  end

  def checkout_all_files
    run "cd #{path} && git checkout ."
  end

  def was_pushed?
    has_file? "package.json"
  end

  def clone_from(source)
    run "git clone #{source.path} #{path}"
    set_app_owner
  end

  def set_app_owner
    run "chown -R app:app #{path}" if !Rails.env.development?
  end

  def commit_all_changes(message)
    run "git config --global user.name \"React Native Playground\" && git config --global user.email \"info@rnplay.org\"" unless Rails.env.development?
    run "cd #{path} && git add . && git commit --author \"React Native Playground <info@rnplay.org>\" -a -m \"#{message}\" && git push origin master"
    set_app_owner
  end

  def install_hooks
    run "cp #{Rails.root}/config/git-post-receive #{path}/hooks/post-receive"
    run "chmod 755 #{path}/hooks/post-receive"
  end

  def create_as_bare
    Rugged::Repository.init_at(path, :bare)
    install_hooks
    set_app_owner
  end

  def npm_install
    # TODO: background this job
    if has_file?('package.json')
      run "cd #{path} && npm install"
    end
  end

  def bare?
    Rugged::Repository.new(path).bare?
  end

  def files_with_contents
    file_list.inject({}) do |hash, path|
      base = path.gsub("#{@path}/", "")
      hash[base] = File.read(path)
      hash
    end
  end

  def contents_of_file(filename)
    File.read("#{@path}/#{filename}")
  end

  def file_list
    Dir.glob("#{path}/**/*.{js,json}").reject {|f| f['node_modules'] || f['iOS']}
  end

  def has_file?(filename)
    File.exists?("#{path}/#{filename}")
  end

  # TODO: refactor to File model
  def update_file(name, content)

    content = content.gsub(/@providesModule.*$/, "")
    File.open("#{path}/#{name}", "w") do |file|
      file.write(content)
      set_app_owner
    end
  end

  def fork_to(target_repo)
    Rails.logger.info(path)
    Rails.logger.info(target_repo.path)

    run "cp -pr #{path} #{target_repo.path}"
    target_repo.set_app_owner
  end

  private

  def run(cmd)
    Rails.logger.info "Running #{cmd}"
    Rails.logger.info `#{cmd}`
  end

end
