#!/usr/bin/env ruby
#
# Smart BaseURL Configuration Plugin - 修复版本

module Jekyll
  class SmartBaseURL
    def initialize(site)
      @site = site
    end

    def detect_environment
      # 检测GitHub Pages环境
      if ENV['GITHUB_PAGES'] || ENV['JEKYLL_ENV'] == 'production'
        return :github_pages
      end

      # 检测本地开发环境
      if ENV['JEKYLL_ENV'] == 'development' || ENV['RACK_ENV'] == 'development'
        return :development
      end

      # 检测是否在GitHub Actions中运行
      if ENV['GITHUB_ACTIONS']
        return :github_actions
      end

      # 默认认为是本地开发环境
      :development
    end

    def get_repository_name
      # 尝试从git配置获取仓库名
      repo_url = `git config --get remote.origin.url 2>/dev/null`.strip

      if repo_url.empty?
        # 如果没有git配置，尝试从当前目录名获取
        return File.basename(Dir.pwd)
      end

      # 从git URL中提取仓库名
      if repo_url =~ %r{github\.com[:/]([^/]+)/([^/\.]+)(?:\.git)?}
        username = $1
        repo_name = $2
        return repo_name
      end

      # 如果无法提取，使用目录名
      File.basename(Dir.pwd)
    rescue
      # 如果出错，使用默认值
      "zhouhengai"
    end

    def determine_baseurl(environment)
      case environment
      when :github_pages, :github_actions
        repo_name = get_repository_name
        baseurl = "/#{repo_name}"

        # 防止重复的 baseurl
        if @site.config['baseurl'].to_s.include?(baseurl)
          puts "SmartBaseURL: Warning - baseurl may already contain '#{baseurl}'"
          # 如果已经包含，则返回空
          return ""
        end

        baseurl
      when :development
        # 本地开发环境不需要baseurl
        ""
      else
        ""
      end
    end

    def apply!
      environment = detect_environment
      baseurl = determine_baseurl(environment)

      puts "SmartBaseURL: Detected environment: #{environment}"
      puts "SmartBaseURL: Current baseurl: '#{@site.config['baseurl']}'"
      puts "SmartBaseURL: Setting baseurl to: '#{baseurl}'"

      @site.config['baseurl'] = baseurl

      # 如果是GitHub Pages环境，也设置production标志
      if environment == :github_pages || environment == :github_actions
        @site.config['production'] = true
        ENV['JEKYLL_ENV'] = 'production'
      end
    end
  end
end

# 在站点初始化后应用智能baseurl配置
Jekyll::Hooks.register :site, :after_init do |site|
  smart_baseurl = Jekyll::SmartBaseURL.new(site)
  smart_baseurl.apply!
end
