class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Заглушка для current_user, чтобы избежать ошибок в шаблонах
  def current_user
    nil
  end
  
  # Сделаем current_user доступным в шаблонах
  helper_method :current_user
end
