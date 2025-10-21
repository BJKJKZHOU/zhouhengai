def determine_baseurl(environment)
  case environment
  when :github_pages, :github_actions
    repo_name = get_repository_name
    expected_baseurl = "/#{repo_name}".gsub(/\/+/, '/').chomp('/')

    current_baseurl = @site.config['baseurl'].to_s

    # 如果当前baseurl为空或者是默认值，则设置新的baseurl
    if current_baseurl.empty? || current_baseurl == "/" || current_baseurl == ""
      puts "SmartBaseURL: Setting baseurl to: '#{expected_baseurl}'"
      expected_baseurl
    else
      puts "SmartBaseURL: Using existing baseurl: '#{current_baseurl}'"
      current_baseurl
    end
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

  # 只在必要时更新baseurl
  if baseurl != @site.config['baseurl']
    puts "SmartBaseURL: Updating baseurl to: '#{baseurl}'"
    @site.config['baseurl'] = baseurl
  else
    puts "SmartBaseURL: Baseurl unchanged"
  end

  # 如果是GitHub Pages环境，也设置production标志
  if environment == :github_pages || environment == :github_actions
    @site.config['production'] = true
    ENV['JEKYLL_ENV'] = 'production'
  end
end
