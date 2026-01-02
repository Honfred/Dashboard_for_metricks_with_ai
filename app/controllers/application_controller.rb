class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :set_locale

  def current_user
    nil
  end
  
  helper_method :current_user

  # Действие для смены локали
  def set_locale_action
    locale = params[:locale].to_s.strip.to_sym
    if I18n.available_locales.include?(locale)
      session[:locale] = locale
      I18n.locale = locale
    end
    
    # Редирект на предыдущую страницу, но без параметра locale в URL
    # чтобы локаль бралась из сессии
    fallback = root_path
    referer = request.referer
    
    if referer.present?
      uri = URI.parse(referer)
      # Удаляем параметр locale из query string
      if uri.query.present?
        params_hash = Rack::Utils.parse_query(uri.query)
        params_hash.delete('locale')
        uri.query = params_hash.empty? ? nil : Rack::Utils.build_query(params_hash)
      end
      redirect_to uri.to_s, allow_other_host: false
    else
      redirect_to fallback
    end
  end

  private

  def set_locale
    I18n.locale = extract_locale || I18n.default_locale
  end

  def extract_locale
    parsed_locale = params[:locale] || session[:locale] || extract_locale_from_accept_language_header
    I18n.available_locales.map(&:to_s).include?(parsed_locale.to_s) ? parsed_locale : nil
  end

  def extract_locale_from_accept_language_header
    return nil unless request.env['HTTP_ACCEPT_LANGUAGE']
    
    request.env['HTTP_ACCEPT_LANGUAGE'].scan(/^[a-z]{2}/).first
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
