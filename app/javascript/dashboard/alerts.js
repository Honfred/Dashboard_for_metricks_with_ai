// Функциональность для работы с системой оповещений

// Массив для хранения текущих оповещений
let currentAlerts = [];

export function initAlerts() {
  // Проверка наличия оповещений каждую минуту
  setInterval(checkAlerts, 60000);
  
  // Настройка модального окна оповещений
  const modal = document.getElementById('alerts-modal');
  if (!modal) return;
  
  const closeBtn = modal.querySelector('.close');
  if (closeBtn) {
    closeBtn.onclick = function() {
      modal.style.display = 'none';
    };
  }
  
  window.addEventListener('click', function(event) {
    if (event.target == modal) {
      modal.style.display = 'none';
    }
  });
}

export function checkAlerts() {
  // Запрашиваем активные оповещения с сервера
  fetch('/alerts/active.json')
    .then(response => response.json())
    .then(data => {
      updateAlerts(data);
    })
    .catch(error => {
      console.error('Error fetching alerts:', error);
    });
}

// Последнее значение серии: поддерживаем формат датасетов Chart.js
// (data: [{x, y}]) и «сырой» формат Prometheus (values: [[ts, value]])
function getLastSeriesValue(series) {
  const points = series.data || series.values;
  if (!points || points.length === 0) return null;

  const last = points[points.length - 1];
  if (Array.isArray(last)) return last[1];
  if (last && typeof last === 'object') return last.y;
  return last;
}

// Имя сервиса, к которому относится серия
function getSeriesService(series) {
  return series.service ||
         (series.metric && (series.metric.instance || series.metric.job)) ||
         series.label ||
         'unknown';
}

export function checkAnomalies(data) {
  // Проверяем данные на аномалии и генерируем оповещения при необходимости
  if (!data) return;

  // Проверка превышения порогов для времени отклика
  if (data.response_time && data.response_time.length > 0) {
    data.response_time.forEach(series => {
      const service = getSeriesService(series);
      if (service === 'threshold') return; // Служебная серия порога

      const lastValue = getLastSeriesValue(series);
      const threshold = 500; // Пороговое значение в миллисекундах

      if (lastValue !== null && lastValue > threshold) {
        // Создаем оповещение на сервере
        createAlert({
          service: service,
          metric: 'response_time',
          value: lastValue,
          threshold: threshold,
          severity: lastValue > threshold * 1.5 ? 'critical' : 'warning'
        });
      }
    });
  }

  // Проверка превышения порогов для уровня ошибок
  if (data.error_rate && data.error_rate.length > 0) {
    data.error_rate.forEach(series => {
      const service = getSeriesService(series);
      if (service === 'threshold') return; // Служебная серия порога

      const lastValue = getLastSeriesValue(series);
      const threshold = 0.05; // Пороговое значение 5% ошибок

      if (lastValue !== null && lastValue > threshold) {
        // Создаем оповещение на сервере
        createAlert({
          service: service,
          metric: 'error_rate',
          value: lastValue,
          threshold: threshold,
          severity: lastValue > threshold * 2 ? 'critical' : 'warning'
        });
      }
    });
  }
}

export function createAlert(alertData) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
  if (!csrfToken) {
    console.error('CSRF token not found, cannot create alert');
    return Promise.reject(new Error('CSRF token not found'));
  }
  
  return fetch('/alerts', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken
    },
    body: JSON.stringify(alertData)
  })
  .then(response => {
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  })
  .catch(error => {
    console.error('Error creating alert:', error);
    throw error;
  });
}

export function updateAlerts(alerts) {
  currentAlerts = alerts;
  
  // Обновляем список оповещений в модальном окне
  const alertsList = document.getElementById('alerts-list');
  if (!alertsList) return;
  
  alertsList.innerHTML = '';
  
  if (alerts.length === 0) {
    const t = window.dashboardTranslations?.alertsWidget || {};
    alertsList.innerHTML = `<p>${t.noActiveAlerts || 'Нет активных оповещений'}</p>`;
    return;
  }
  
  const t = window.dashboardTranslations?.alertsWidget || {};
  const metricLabel = t.metricLabel || 'Метрика';
  const valueLabel = t.valueLabel || 'Значение';
  const thresholdLabel = t.thresholdLabel || 'порог';
  const timeLabel = t.timeLabel || 'Время';
  
  alerts.forEach(alert => {
    const alertEl = document.createElement('div');
    alertEl.className = `alert alert-${alert.severity}`;
    alertEl.innerHTML = `
      <h3>${alert.service}</h3>
      <p>${metricLabel}: ${alert.metric}</p>
      <p>${valueLabel}: ${alert.value} (${thresholdLabel}: ${alert.threshold})</p>
      <p>${timeLabel}: ${new Date(alert.triggered_at).toLocaleString()}</p>
    `;
    alertsList.appendChild(alertEl);
  });
  
  // Показываем модальное окно, если есть новые оповещения
  if (alerts.length > 0) {
    const modal = document.getElementById('alerts-modal');
    if (modal) {
      modal.style.display = 'block';
    }
  }
}

export function resolveAlert(alertId) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
  if (!csrfToken) {
    console.error('CSRF token not found, cannot resolve alert');
    return Promise.reject(new Error('CSRF token not found'));
  }
  
  return fetch(`/alerts/${alertId}/resolve`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken
    }
  })
  .then(response => {
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  })
  .then(data => {
    // После успешного разрешения оповещения обновляем список
    checkAlerts();
    return data;
  })
  .catch(error => {
    console.error('Error resolving alert:', error);
    throw error;
  });
}

export function acknowledgeAlert(alertId) {
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
  if (!csrfToken) {
    console.error('CSRF token not found, cannot acknowledge alert');
    return Promise.reject(new Error('CSRF token not found'));
  }
  
  return fetch(`/alerts/${alertId}/acknowledge`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': csrfToken
    }
  })
  .then(response => {
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return response.json();
  })
  .then(data => {
    // После успешного подтверждения оповещения обновляем список
    checkAlerts();
    return data;
  })
  .catch(error => {
    console.error('Error acknowledging alert:', error);
    throw error;
  });
}