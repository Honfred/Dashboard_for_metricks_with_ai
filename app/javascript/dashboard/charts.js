// Функциональность для создания и управления графиками

// Цвета для графиков
const chartColors = [
  'rgba(52, 152, 219, 0.8)',
  'rgba(46, 204, 113, 0.8)',
  'rgba(155, 89, 182, 0.8)',
  'rgba(231, 76, 60, 0.8)',
  'rgba(241, 196, 15, 0.8)',
  'rgba(230, 126, 34, 0.8)',
  'rgba(52, 73, 94, 0.8)',
  'rgba(149, 165, 166, 0.8)'
];

// Глобальные переменные для хранения графиков
export const charts = {
  servicesStatus: null,
  responseTime: null,
  throughput: null,
  errorRate: null,
  cpuUsage: null,
  memoryUsage: null,
  resourceOverview: null
};

export function renderCharts(data) {
  console.log('Начинаем рендеринг графиков...');
  
  // Проверяем наличие объекта Chart
  if (typeof Chart === 'undefined') {
    console.warn('Объект Chart не найден. Пробуем отложить рендеринг...');
    // Откладываем рендеринг на небольшое время, чтобы дать библиотеке Chart.js загрузиться
    setTimeout(() => {
      if (typeof Chart === 'undefined') {
        console.error('Библиотека Chart.js не загружена. Графики не будут отображены.');
        const msg = window.dashboardTranslations?.messages?.chartLoadingError || 'Ошибка загрузки библиотеки Chart.js. Пожалуйста, обновите страницу.';
        showChartError(msg);
        return;
      }
      // Повторяем попытку рендеринга
      renderCharts(data);
    }, 500);
    return;
  }
  
  // Если данные не переданы, используем имеющиеся или генерируем новые
  if (!data) {
    console.log('Данные для графиков не переданы, генерируем новые');
    return;
  }
  
  // Уничтожаем предыдущие графики
  Object.values(charts).forEach(chart => {
    if (chart && typeof chart.destroy === 'function') {
      chart.destroy();
    }
  });
  
  console.log('Рендеринг графиков с данными:', data);
  
  // Получаем переводы из глобального объекта
  const t = window.dashboardTranslations?.charts || {
    responseTime: 'Время отклика (мс)',
    throughput: 'Пропускная способность (запросов/сек)',
    errorRate: 'Уровень ошибок (%)',
    resourceUsage: 'Общее использование ресурсов (%)',
    cpuUsage: 'Использование CPU (%)',
    memoryUsage: 'Использование памяти (%)'
  };
  
  try {
    // Отрисовываем время отклика
    if (data.response_time) {
      const container = document.getElementById('response-time-chart');
      if (container) {
        charts.responseTime = createLineChart(
          'response-time-chart',
          t.responseTime,
          data.response_time
        );
      }
    }
    
    // Отрисовываем пропускную способность
    if (data.throughput) {
      const container = document.getElementById('throughput-chart');
      if (container) {
        charts.throughput = createLineChart(
          'throughput-chart',
          t.throughput,
          data.throughput
        );
      }
    }
    
    // Отрисовываем уровень ошибок
    if (data.error_rate) {
      const container = document.getElementById('error-rate-chart');
      if (container) {
        charts.errorRate = createLineChart(
          'error-rate-chart',
          t.errorRate,
          data.error_rate
        );
      }
    }
    
    // Отрисовываем использование ресурсов (общий график, CPU и память)
    if (data.resource_usage) {
      console.log('Рендеринг графиков ресурсов:', data.resource_usage);
      
      // Отрисовываем общий график ресурсов
      if (data.resource_usage.overview) {
        const container = document.getElementById('resource-usage-chart');
        if (container) {
          charts.resourceOverview = createLineChart(
            'resource-usage-chart',
            t.resourceUsage,
            data.resource_usage.overview
          );
        }
      }
      
      if (data.resource_usage.cpu) {
        const container = document.getElementById('cpu-usage-chart');
        if (container) {
          charts.cpuUsage = createLineChart(
            'cpu-usage-chart',
            t.cpuUsage,
            data.resource_usage.cpu
          );
        }
      }
      
      if (data.resource_usage.memory) {
        const container = document.getElementById('memory-usage-chart');
        if (container) {
          charts.memoryUsage = createLineChart(
            'memory-usage-chart',
            t.memoryUsage,
            data.resource_usage.memory
          );
        }
      }
    }
    
    // Отрисовываем состояние сервисов
    if (data.service_health) {
      const container = document.getElementById('service-health-chart');
      if (container) {
        renderServiceHealthTable('service-health-chart', data.service_health);
      }
    }
    
    console.log('Рендеринг графиков завершен успешно');
  } catch (error) {
    console.error('Ошибка при рендеринге графиков:', error);
    const msgBase = window.dashboardTranslations?.messages?.chartCreationError || 'Ошибка при создании графиков';
    showChartError(`${msgBase}: ${error.message}`);
  }
}

export function createLineChart(elementId, title, datasets) {
  console.log('Создаем график для', elementId);
  
  const container = document.getElementById(elementId);
  if (!container) {
    console.error('Не найден контейнер для графика:', elementId);
    return null;
  }
  
  // Находим canvas внутри контейнера
  const canvasId = elementId.replace('-chart', '-canvas');
  const canvas = document.getElementById(canvasId);
  
  if (!canvas) {
    console.error('Не найден canvas с ID:', canvasId);
    const msg = window.dashboardTranslations?.messages?.canvasNotFound || 'Ошибка: не найден canvas для графика';
    container.innerHTML = `<div style="color: red; padding: 20px;">${msg}</div>`;
    return null;
  }
  
  try {
    // Очищаем существующий график, если он есть
    if (charts[elementId]) {
      charts[elementId].destroy();
    }
    
    // Получаем контекст canvas для отрисовки
    const ctx = canvas.getContext('2d');
    
    if (!ctx) {
      console.error('Не удалось получить 2D контекст для canvas:', canvasId);
      return null;
    }
    
    // Преобразуем данные в формат, понятный Chart.js
    const formattedData = {
      datasets: datasets.map(dataset => {
        return {
          label: dataset.label,
          data: dataset.data,
          borderColor: dataset.borderColor,
          backgroundColor: dataset.backgroundColor,
          borderDash: dataset.borderDash || [],
          tension: dataset.tension || 0.4
        };
      })
    };
    
    // Создаем график при помощи Chart.js
    const chart = new Chart(ctx, {
      type: 'line',
      data: formattedData,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          title: {
            display: true,
            text: title
          },
          legend: {
            position: 'top',
          }
        },
        scales: {
          x: {
            type: 'time',
            time: {
              unit: getTimeUnitForChart()
            },
            title: {
              display: true,
              text: window.dashboardTranslations?.timeAxis || 'Время'
            }
          },
          y: {
            beginAtZero: true,
            title: {
              display: true,
              text: title
            }
          }
        }
      }
    });
    
    console.log('График успешно создан для', elementId);
    return chart;
  } catch (error) {
    console.error('Ошибка при создании графика для', elementId, ':', error);
    // Отображаем сообщение об ошибке прямо в контейнере
    const chartErrorMsg = window.dashboardTranslations?.messages?.chartError || 'Ошибка при создании графика';
    container.innerHTML = `
      <div style="padding: 20px; text-align: center; color: #dc3545;">
        <p>${chartErrorMsg}:</p>
        <p>${error.message}</p>
      </div>
    `;
    return null;
  }
}

function getTimeUnitForChart() {
  const timeRange = document.getElementById('time-range').value;
  switch(timeRange) {
    case '15m':
    case '1h': return 'minute';
    case '3h':
    case '6h': return 'minute';
    case '12h':
    case '24h': return 'hour';
    case '7d': return 'day';
    default: return 'minute';
  }
}

export function renderServiceHealthTable(elementId, services) {
  const container = document.getElementById(elementId);
  if (!container) return;
  
  // Очищаем контейнер
  container.innerHTML = '';
  
  // Получаем переводы
  const t = window.dashboardTranslations?.serviceHealth || {};
  const serviceLabel = t.service || 'Сервис';
  const statusLabel = t.status || 'Статус';
  const uptimeLabel = t.uptime || 'Время работы';
  
  // Создаем таблицу
  const table = document.createElement('table');
  table.className = 'status-table';
  
  // Заголовок таблицы
  const thead = document.createElement('thead');
  thead.innerHTML = `
    <tr>
      <th>${serviceLabel}</th>
      <th>${statusLabel}</th>
      <th>${uptimeLabel}</th>
    </tr>
  `;
  table.appendChild(thead);
  
  // Получаем текущий список выбранных сервисов
  const selectedServices = window.dashboardSelectedServices || [];
  
  // Тело таблицы
  const tbody = document.createElement('tbody');
  services.forEach(service => {
    const tr = document.createElement('tr');
    
    // Добавляем класс service-row для стилизации и data-service для выбора сервиса
    tr.className = 'service-row';
    tr.dataset.service = service.name;
    
    // Проверяем, выбран ли этот сервис (находится в массиве выбранных)
    if (selectedServices.includes(service.name)) {
      tr.classList.add('selected');
    }
    
    tr.innerHTML = `
      <td>${service.name}</td>
      <td><span class="status-${service.status}">${service.status === 'up' ? (t.statusUp || 'Работает') : (t.statusDown || 'Не работает')}</span></td>
      <td>${service.uptime}</td>
    `;
    
    // Добавляем обработчик клика для выбора сервиса с учетом клавиши Ctrl/Cmd для множественного выбора
    tr.addEventListener('click', function(event) {
      const serviceName = this.dataset.service;
      if (serviceName) {
        console.log('Клик по сервису:', serviceName, 'с Ctrl/Cmd:', event.ctrlKey || event.metaKey);
        
        // Публикуем событие выбора сервиса
        document.dispatchEvent(new CustomEvent('dashboard:toggle-service', { 
          detail: { 
            service: serviceName,
            ctrlKey: event.ctrlKey || event.metaKey // Учитываем клавиши Ctrl/Cmd для множественного выбора
          } 
        }));
      }
    });
    
    tbody.appendChild(tr);
  });
  table.appendChild(tbody);
  
  container.appendChild(table);
}

export function prepareTimeSeriesData(data, labelPrefix) {
  if (!data || data.length === 0) {
    return {
      labels: [],
      datasets: [{
        label: labelPrefix,
        data: [],
        borderColor: chartColors[0],
        backgroundColor: 'transparent'
      }]
    };
  }
  
  // Собираем все временные метки из всех серий данных
  const allTimestamps = new Set();
  data.forEach(series => {
    series.values.forEach(point => {
      allTimestamps.add(point[0]);
    });
  });
  
  // Сортируем метки времени
  const timestamps = Array.from(allTimestamps).sort((a, b) => a - b);
  
  // Форматируем временные метки для отображения
  const labels = timestamps.map(ts => new Date(ts).toLocaleTimeString());
  
  // Определяем, связан ли этот график с использованием ресурсов
  const isResourcesRelated = (prefix) => {
    // Поддерживаем как русские, так и английские названия
    const resourceKeywords = [
      'Использование', 'CPU', 'ресурсов', 'памяти',
      'Usage', 'Resource', 'Memory'
    ];
    return resourceKeywords.some(keyword => prefix.indexOf(keyword) !== -1);
  };
  
  // Подготавливаем наборы данных для каждой серии
  const datasets = data.map((series, index) => {
    // Создаем хэш-карту значений для быстрого доступа
    const valueMap = new Map(series.values.map(point => [point[0], point[1]]));
    
    // Для каждой временной метки получаем соответствующее значение
    const dataPoints = timestamps.map(ts => valueMap.get(ts) || null);
    
    // Формируем метку для серии
    let label = "";
    if (series.metric) {
      // Определяем отображаемую метку в зависимости от типа графика
      if (series.metric.instance) {
        // Для графиков ресурсов сохраняем полное название с метрикой
        if (isResourcesRelated(labelPrefix)) {
          label = `${series.metric.instance} - ${labelPrefix}`;
        } else {
          // Для других графиков указываем только имя сервиса без метрики
          label = series.metric.instance;
        }
      } else if (series.metric.job) {
        // Аналогично для job
        if (isResourcesRelated(labelPrefix)) {
          label = `${series.metric.job} - ${labelPrefix}`;
        } else {
          label = series.metric.job;
        }
      }
    }
    
    return {
      label: label,
      data: dataPoints,
      borderColor: chartColors[index % chartColors.length],
      backgroundColor: 'transparent',
      pointRadius: 2,
      borderWidth: 2,
      tension: 0.1
    };
  });
  
  return { labels, datasets };
}

export function getChartOptions(title, xAxisLabel, yAxisLabel, logarithmic, scaleOverrides = {}) {
  const options = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      title: {
        display: false,
        text: title
      },
      tooltip: {
        mode: 'index',
        intersect: false
      },
      legend: {
        position: 'top',
        labels: {
          boxWidth: 12,
          font: {
            size: 11
          }
        }
      }
    },
    scales: {
      x: {
        title: {
          display: true,
          text: xAxisLabel
        },
        grid: {
          display: false
        }
      },
      y: {
        title: {
          display: true,
          text: yAxisLabel
        },
        type: logarithmic ? 'logarithmic' : 'linear',
        grid: {
          color: 'rgba(0, 0, 0, 0.05)'
        }
      }
    },
    animation: {
      duration: 300
    }
  };
  
  // Применяем переопределения для осей
  if (scaleOverrides.x) {
    options.scales.x = { ...options.scales.x, ...scaleOverrides.x };
  }
  
  if (scaleOverrides.y) {
    options.scales.y = { ...options.scales.y, ...scaleOverrides.y };
  }
  
  return options;
}

export function showChartError(message) {
  const refreshText = window.dashboardTranslations?.messages?.refreshPage || 'Обновить страницу';
  // Отображаем сообщение об ошибке во всех контейнерах графиков
  document.querySelectorAll('.chart-container').forEach(container => {
    container.innerHTML = `
      <div style="text-align: center; color: #dc3545; padding: 20px;">
        <i class="fa fa-exclamation-triangle" style="font-size: 24px; margin-bottom: 10px;"></i>
        <p>${message}</p>
        <button onclick="window.location.reload()" class="btn btn-outline-primary" style="margin-top: 10px;">
          ${refreshText}
        </button>
      </div>
    `;
  });
}

export function getChartContext(containerId, existingChart) {
  const container = document.getElementById(containerId);
  
  if (!container) {
    console.error(`Контейнер с id "${containerId}" не найден`);
    return null;
  }
  
  // Если график уже существует, уничтожаем его
  if (existingChart) {
    try {
      existingChart.destroy();
    } catch (e) {
      console.error(`Ошибка при уничтожении существующего графика: ${e.message}`);
    }
  }
  
  // Очищаем контейнер и добавляем новый canvas
  container.innerHTML = '';
  const canvas = document.createElement('canvas');
  container.appendChild(canvas);
  
  // Проверяем, что canvas был создан корректно
  if (!canvas || !canvas.getContext) {
    console.error(`Не удалось создать canvas в контейнере ${containerId}`);
    return null;
  }
  
  return canvas.getContext('2d');
}