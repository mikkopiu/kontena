require 'uri'
module Kontena
  class DebugInstrumentor
    def self.instrument(name, params = {}, &block)
      result = []
      params = params.dup

      direction = name.split('.').last.capitalize

      if direction == 'Request'
        uri = URI.parse("#{params[:scheme]}://#{params[:host]}:#{params[:port]}")
        uri.path = params[:path].nil? ? '/' : params[:path].split('?', 2).first
        uri.query = URI.encode_www_form(params[:query]) if params[:query] && !params[:query].empty?
        str = "#{params[:method].to_s.upcase} #{uri}"
        str << " (ssl_verify: #{params[:ssl_verify_peer]}) " if params[:scheme] == 'https'
        result << str
      end

      if params[:headers]
        str = "Headers: {"
        heads = []
        heads << "Accept: #{params[:headers]['Accept']}" if params[:headers]['Accept']
        heads << "Content-Type: #{params[:headers]['Content-Type']}" if params[:headers]['Content-Type']
        heads << "Authorization: #{params[:headers]['Authorization'].split(' ', 2).first}" if params[:headers]['Authorization']
        heads << "X-Kontena-Version: #{params[:headers]['X-Kontena-Version']}" if params[:headers]['X-Kontena-Version']
        str << heads.join(', ')
        str << "} "
        result << str
      end

      if params[:status]
        str = "Status: "
        if params[:status] < 299
          str << Kontena.pastel.green(params[:status])
        else
          str << Kontena.pastel.red(params[:status])
        end
        result << str
      end

      if params[:body] && !params[:body].empty?
        str = "Body: "
        if ENV["DEBUG"] == "api"
          str << "\n"
          str << params[:body]
        else
          body = params[:body].inspect.strip
          str << body[0,80]
          if body.length > 80
            str << "...\""
          end
        end
        result << str
      elsif params[:error]
        result << params[:error]
      end

      color = case direction
              when 'Request' then :blue
              when 'Response' then :magenta
              else :red
              end

      Kontena.logger.debug("CLIENT") { Kontena.pastel.send(color, "[#{direction}]: #{result.join(" | ")}") }

      if block_given?
        yield
      end
    end
  end
end
