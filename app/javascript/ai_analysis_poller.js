// Скрипт для автоматического обновления страницы анализа и проверки статуса ML-сервиса

document.addEventListener('DOMContentLoaded', function() {
  // Автоматическое обновление страницы при выполнении анализа
  const refreshStatus = document.querySelector('[data-refresh-status="true"]');
  if (refreshStatus) {
    setTimeout(function() {
      location.reload();
    }, 5000);
  }

  // Обработчик для кнопки проверки статуса ML-сервиса
  const checkMlServiceButton = document.getElementById('check-ml-service');
  if (checkMlServiceButton) {
    checkMlServiceButton.addEventListener('click', function(e) {
      e.preventDefault();
      fetch('/check_ml_service', { method: 'GET' })
        .then(response => response.json())
        .then(data => {
          if (data.status === 'ok') {
            alert('ML-сервис работает нормально. Анализ должен завершиться в ближайшее время.');
          } else {
            alert('Проблема с подключением к ML-сервису. Пожалуйста, проверьте, что сервис запущен и доступен.');
          }
        })
        .catch(error => {
          console.error('Ошибка проверки статуса ML-сервиса:', error);
          alert('Ошибка при проверке статуса ML-сервиса.');
        });
    });
  }
});