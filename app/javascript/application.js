// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Импортируем dashboard.js напрямую через элемент скрипта вместо importmap
document.addEventListener('DOMContentLoaded', function() {
  if (document.body.classList.contains('metrics') && document.body.classList.contains('show')) {
    // Только для страницы с метриками
    const script = document.createElement('script');
    script.src = '/assets/dashboard.js';
    script.type = 'module';
    document.head.appendChild(script);
  }
});
