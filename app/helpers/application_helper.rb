module ApplicationHelper
  def display_service_name(service_name)
    ServiceNameMapper.display_name(service_name)
  end

  # Хелпер для переключения языков
  def locale_switcher
    links = I18n.available_locales.map do |locale|
      if locale == I18n.locale
        content_tag(:span, t("locale.#{locale}"), class: 'locale-link active')
      else
        link_to(t("locale.#{locale}"), url_for(locale: locale), class: 'locale-link')
      end
    end
    
    content_tag(:div, links.join(' | ').html_safe, class: 'locale-switcher')
  end

  # Хелпер для получения названия локали
  def locale_name(locale)
    t("locale.#{locale}")
  end

  # Хелпер для форматирования дат с локализацией
  def l_date(date, format = :default)
    return '-' if date.blank?
    l(date.to_date, format: format)
  end

  # Хелпер для форматирования времени с локализацией
  def l_time(time, format = :default)
    return '-' if time.blank?
    l(time, format: format)
  end
end
