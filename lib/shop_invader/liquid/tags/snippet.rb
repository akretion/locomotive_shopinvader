module Locomotive
  module Steam
    module Liquid
      module Tags

        class EsiSnippet < Snippet

          def render(context)
            @context = context
            @template_name = evaluate_snippet_name(context)
            # TODO support live editing
            if true
              "<esi:include src=\"#{snippet_path}\"/>"
            else
              super
            end
          end

          private

          def snippet_path
            default_locale = site.default_locale.to_sym
            same_locale = locale == default_locale

            if site.prefix_default_locale || !same_locale
              "/#{locale}/snippet/#{@template_name}"
            else
              "/snippet/#{@template_name}"
            end
          end

          def locale
            @locale ||= @context.registers[:locale]
          end

          def site
            @site ||= @context.registers[:site]
          end

          ::Liquid::Template.register_tag('esi_include'.freeze, EsiSnippet)
        end

      end
    end
  end
end
