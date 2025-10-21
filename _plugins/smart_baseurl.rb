#!/usr/bin/env ruby
#
# Smart BaseURL Configuration Plugin - 修复版本

module Jekyll
  class SmartBaseURL
    # ... 其他代码保持不变 ...

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

Jekyll::Hooks.register :site, :after_init do |site|
  smart_baseurl = Jekyll::SmartBaseURL.new(site)
  smart_baseurl.apply!
end
