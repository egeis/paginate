require "octopress-hooks"
require "octopress-paginate/version"
require "octopress-paginate/hooks"

module Octopress
  module Paginate
    extend self

    DEFAULT = {
      'collection'   => 'posts',
      'per_page'     => 10,
      'limit'        => 5,
      'permalink'    => '/page:num/',
      'title_suffix' => ' - page :num',
      'page_num'     => 1,
      'reversed'     => false
    }

    LOOP = /(paginate.+\s+in)\s+(site\.(.+?))(.+)%}/

    # Simple Page class override
    class PaginationPage < Jekyll::Page
      attr_accessor :dir, :name

      def relative_asset_path
        site_source = Pathname.new Octopress.site.source
        page_source = Pathname.new @base
        page_source.relative_path_from(site_source).to_s
      end
    end

    def paginate(page)

      defaults = DEFAULT.merge(page.site.config['pagination'] || {})

      if page.data['paginate'].is_a? Hash
        page.data['paginate'] = defaults.merge(page.data['paginate'])
      else
        page.data['paginate'] = defaults
      end

      if tag = page.data['paginate']['tag']
        page.data['paginate']['tags'] = Array(tag)
      end

      if category = page.data['paginate']['category']
        page.data['paginate']['categories'] = Array(category)
      end

      return add_pages(page)
    end

    def add_pages(page)
      config = page.data['paginate']
      pages = (collection(page).size.to_f / config['per_page']).ceil - 1

      if config['limit']
        pages = [pages, config['limit'] - 1].min
      end

      page.data['paginate']['pages'] = pages + 1

      new_pages = []

      pages.times do |i|
        index = i+2

        # If page is generated by an Octopress Ink plugin, use the built in
        # methods for cloning the page
        #
        if page.respond_to?(:asset) && page.asset.to_s.match('Octopress::Ink')
          new_page = page.asset.new_page(page_data(page, index))
        else
          new_page = PaginationPage.new(page.site, page.site.source, File.dirname(page.path), File.basename(page.path))
          new_page.data.merge!(page_data(page, index))
          new_page.process('index.html')
        end

        new_pages << new_page
      end

      all_pages = [page].concat(new_pages)

      all_pages.each_with_index do |p, index|

        if index > 0
          prev_page = all_pages[index - 1]
          p.data['paginate']['previous_page'] = index
          p.data['paginate']['previous_page_path'] = prev_page.url
        end

        if next_page = all_pages[index + 1]
          p.data['paginate']['next_page'] = index + 2
          p.data['paginate']['next_page_path'] = next_page.url
        end
      end

      page.site.pages.concat new_pages
      
      return new_pages
    end

    def page_data(page, index)
      {
        'paginate'  => paginate_data(page, index),
        'permalink' => page_permalink(page, index),
        'title'     => page_title(page, index),
      }
    end

    def page_permalink(page, index)
      subdir = page.data['paginate']['permalink'].clone.sub(':num', index.to_s)
      File.join(page.dir, subdir)
    end

    def paginate_data(page, index)
      paginate_data = page.data['paginate'].clone
      paginate_data['page_num'] = index
      paginate_data
    end

    def page_title(page, index)
      title = if page.data['title']
        page.data['title']
      else
        page.data['paginate']['collection'].capitalize
      end

      title += page.data['paginate']['title_suffix'].sub(/:num/, index.to_s)

      title
    end

    def collection(page)
      collection = if page['paginate']['collection'] == 'posts'
        if defined?(Octopress::Multilingual) && page.lang
          page.site.posts_by_language(page.lang)
        else
          page.site.posts.docs.reverse
        end
      else
        page.site.collections[page['paginate']['collection']].docs
      end
      
      if page['paginate']['reversed'] == true
        collection = collection.reverse
      end

      if categories = page.data['paginate']['categories']
        collection = collection.reject{|p| (p.data['categories'] & categories).empty?}
      end

      if tags = page.data['paginate']['tags']
        collection = collection.reject{|p| (p.data['tags'] & tags).empty?}
      end

      collection
    end

    def page_payload(payload, page)
      config = page.data['paginate']
      collection = collection(page)
      { 'paginator' => {
        "#{config['collection']}"       => items(payload, collection),
        "page"                          => config['page_num'],
        "per_page"                      => config['per_page'],
        "limit"                         => config['limit'],
        "total_#{config['collection']}" => collection.size,
        "total_pages"                   => config['pages'],
        'previous_page'                 => config['previous_page'],
        'previous_page_path'            => config['previous_page_path'],
        'next_page'                     => config['next_page'],
        'next_page_path'                => config['next_page_path']
      }}
    end

    def items(payload, collection)
      config = payload['page']['paginate']

      n = (config['page_num'] - 1) * config['per_page']
      max = n + (config['per_page'] - 1)

      collection[n..max]
    end
  end
end

if defined? Octopress::Docs
  Octopress::Docs.add({
    name:        "Octopress Paginate",
    gem:         "octopress-paginate",
    version:     Octopress::Paginate::VERSION,
    description: "Simple and flexible pagination for Jekyll posts and collections",
    path:        File.expand_path(File.join(File.dirname(__FILE__), "../")),
    source_url:  "https://github.com/octopress/paginate"
  })
end
