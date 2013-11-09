require 'digest/md5'
require 'nanogenmo/utils'
require 'nokogiri'
require 'open-uri'
require 'set'

module NaNoGenMo

  class FanficitonNetClient

    # Fake a user agent to avoid getting 403 errors
    USER_AGENT = 'Mozilla/5.0 (X11; Ubuntu; Linux armv7l; rv:24.0) Gecko/20100101 Firefox/24.0'

    # Delay between requesting pages from fanfiction.net, to be nice. Seconds.
    # The default 5 seconds makes data collection take a LONG TIME. Smaller values are
    # fine right up until fanfiction.net IP-bans you :(
    PAGE_DELAY = 5

    STORY_LINK_CLASS = 'stitle'
    CHAPTER_SELECT_ID = 'chap_select'

    # Given a page of story links return a list of URLs for each page.
    # search_page_url - Pick a Fanfiction.net page that has links to stories. This can be a category, user or search page, e.g.
    #   http://www.fanfiction.net/tv/Doctor-Who/
    #   http://www.fanfiction.net/Sonic-the-Hedgehog-and-My-Little-Pony-Crossovers/253/621/
    #   http://www.fanfiction.net/search.php?keywords=cupcakes&ready=1&type=story
    #   http://www.fanfiction.net/u/1234567/UserName
    def self.search_page_to_page_urls(search_page_url, max_pages = 100)
      uri = URI.parse(search_page_url)
      baseURL = "#{uri.scheme}://#{uri.host}"
      story_urls = Nokogiri::HTML(fetch_page(search_page_url)).css("a.#{STORY_LINK_CLASS}").map{|tag| baseURL + tag['href']}

      # Now you have a link to the "Chapter 1" page of each story. For each "Chapter 1" page,
      # look for a SELECT box that will provide links to any other chapters.
      page_urls = []
      story_urls.each do |chapterOneURL|
        page_urls << chapterOneURL
        begin
          page_urls += Nokogiri::HTML(fetch_page(chapterOneURL)).css("select\##{CHAPTER_SELECT_ID} option").map do |option|
            chapterOneURL.sub(/\/1\//, "\/#{option['value']}\/")
          end
        rescue
          puts "Failed to load and parse a page '#{chapterOneURL}' (ignored)."
        end
      end
      Set.new(page_urls).to_a
    end

    private

    def self.fetch_page(url)
      cache_file = "#{cache_dir()}/#{Digest::MD5.hexdigest(url)}.html"
      if !File.exists?(cache_file)
        sleep PAGE_DELAY if Time.now.to_i - @last_fetch.to_i < PAGE_DELAY
        puts "fetching #{url}..."
        open(url, 'User-Agent' => USER_AGENT){|f| IO.write(cache_file, f.read)} 
        @last_fetch = Time.now
      end
      IO.read(cache_file)
    end

    def self.cache_dir()
      dir = "#{NaNoGenMo::Utils.config_dir()}/fanfiction"
      FileUtils.mkdir_p dir if !Dir.exists?(dir)
      dir
    end

  end

end
