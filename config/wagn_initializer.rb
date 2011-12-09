module Wagn
 class Conf
  class << self

    @@config_hash=false

    def config_hash()  @@config_hash ||= wagn_load_config() end
    def [](key)         config_hash[key&&key.to_sym||key]       end
    def []=(key, value) config_hash[key&&key.to_sym||key]=value end
      
    DEFAULT_YML= %{
      base_url: http://localhost:3000/
      max_renders: 8
    }

    # from sample_wagn.rb
#ExceptionNotifier.exception_recipients = ['person1@website.org','person2@website.org']
#ExceptionNotifier.sender_address       = '"Wagn Error" <notifier@wagn.org>'
#ExceptionNotifier.email_prefix         = "[Wagn]"

 # from model/system
 # cattr_accessor :role_tasks, :request, :cache, :main_name,
 #   # Configuration Options     
 #   :base_url, :max_render_time, :max_renders,   # Common; docs in sample_wagn.rb
 #   :enable_ruby_cards, :enable_server_cards,    # Uncommon; Check Security risks before enabling these cardtypes (wagn.org ref url?)
 #   :enable_postgres_fulltext, :postgres_src_dir, :postgres_tsearch_dir, # Optimize PostgreSQL performance
 #   :multihost, :wagn_name, :running
    

    def wagn_load_config(hash={})
      Rails.logger.debug "Load config ...\n"
      hash.merge! YAML.load(DEFAULT_YML)
      config_file = "#{Rails.root}/config/wagn.yml"
      STDERR << "#{config_file} exists? #{File.exists? config_file}\n"
      hash.merge!(
        YAML.load_file config_file ) if File.exists? config_file

      hash.symbolize_keys!

      base_u = hash[:base_url]
      raise "no base url???" unless base_u
      #base_u = 'http://' + request.env['HTTP_HOST'] if !base_u and request and request.env['HTTP_HOST']
      hash[:base_url] = base_u.gsub!(/\/$/,'')
      unless hash[:host]
        hash[:host] = base_u.gsub(/^http:\/\//,'').gsub(/\/.*/,'')
      end
      hash[:root_path] ||= begin
          epath = ENV['RAILS_RELATIVE_URL_ROOT'] 
          epath && epath != '/' ? epath : ''
        end
      hash[:role_tasks] =
        %w{ administrate_users create_accounts assign_user_roles }
      Rails.logger.debug "hash #{hash.inspect}"
      raise "no root path" unless hash[:root_path]
      hash
    end
=begin
    def site_title
      setting('*title') || 'Wagn'
    end
    
    def favicon
      # bit of a kludge. 
      image_setting('*favicon') || image_setting('*logo') || "#{root_path}/images/favicon.ico"
    end
    
    def logo
      image_setting('*logo') || (File.exists?("#{Rails.root}/public/images/logo.gif") ? "#{root_path}/images/logo.gif" : nil)
    end
=end


    def wagn_run
      Rails.logger.debug "wagn_run ..."
      return if Wagn::Conf[:running]
      wagn_setup_multihost
      return unless wagn_database_ready?
      wagn_load_modules
      Wagn::Cache.initialize_on_startup      
      Wagn::Conf[:running] = true
      Rails.logger.info "----------- Wagn Rolling -----------\n\n\n"
    end

    def wagn_database_ready?
      no_mod_msg = "----------Wagn Running without Modules----------"
      if ActiveRecord::Base.connection.table_exists?( 'cards' )    ; true
      else; Rails.logger.info no_mod_msg + '(no cards table)'      ; false
      end
    rescue
      Rails.logger.info no_mod_msg + '(not connected to database)' ; false
    end
  
    def wagn_setup_multihost
      return unless Wagn::Conf[:multihost] and wagn_name=ENV['WAGN']
      Rails.logger.info("------- Multihost.  Wagn Name = #{wagn_name} -------")
      MultihostMapping.map_from_name(wagn_name)
    end

    def wagn_load_modules
      Card
      Cardtype
      #STDERR << "load_modules Pack load #{Wagn.const_defined?(:Pack)}\n\n"
      require_dependency "wagn/pack.rb"
      #had to start requiring renderers once they moved into their own files.  would like to go the other direction...
      %w{lib/wagn/renderer.rb lib/wagn/renderer/*.rb modules/*.rb packs/*/*_pack.rb}.each { |d| Wagn::Pack.dir(File.expand_path( "../../#{d}/",__FILE__)) }
      #%w{modules/*.rb packs/*/*_pack.rb}.each { |d| Wagn::Pack.dir(File.expand_path( "../../#{d}/",__FILE__)) }
      Wagn::Pack.load_all
  
      STDERR << "----------- Wagn MODULES Loaded -----------\n"
    end

  end

 end
end
