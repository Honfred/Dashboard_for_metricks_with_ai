// Dashboard.js - Функциональность для дашборда метрик

document.addEventListener('DOMContentLoaded', function() {
  // Инициализация графиков
  initDashboard();
  
  // Настройка обновления данных
  setupAutoRefresh();
  
  // Обработчики для элементов управления
  document.getElementById('time-range').addEventListener('change', updateTimeRange);
  document.getElementById('auto-refresh').addEventListener('change', updateRefreshInterval);
});

// Глобальные переменные для хранения графиков
const charts = {
  servicesStatus: null,
  responseTime: null,
  throughput: null,
  errorRate: null,
  cpuUsage: null,
  memoryUsage: null
};

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

function initDashboard() {
  // Загрузка и отображение данных от Prometheus
  fetchMetricsData();
}

function fetchMetricsData() {
  const timeRange = document.getElementById('time-range').value;
  
  // Fetch data from our backend which queries Prometheus
  fetch(`/dashboard/metrics?time_range=${timeRange}`)
    .then(response => response.json())
    .then(data => {
      renderCharts(data);
    })
    .catch(error => {
      console.error('Error fetching metrics data:', error);
    });
}

function renderCharts(data) {
  renderServicesStatus(data.services_status);
  renderResponseTimeChart(data.response_time);
  renderThroughputChart(data.throughput);
  renderErrorRateChart(data.error_rate);
  renderResourceUsageCharts(data.resource_usage);
}

function renderServicesStatus(statusData) {
  const container = document.getElementById('services-status-chart');
  
  if (!statusData || statusData.length === 0) {
    container.innerHTML = '<div class="no-data">Нет данных о состоянии сервисов</div>';
    return;
  }
  
  // Очищаем контейнер
  container.innerHTML = '';
  
  // Создаем таблицу статусов
  const table = document.createElement('table');
  table.className = 'status-table';
  
  // Заголовок таблицы
  const thead = document.createElement('thead');
  const headerRow = document.createElement('tr');
  ['Сервис', 'Статус'].forEach(text => {
    const th = document.createElement('th');
    th.textContent = text;
    headerRow.appendChild(th);
  });
  thead.appendChild(headerRow);
  table.appendChild(thead);
  
  // Тело таблицы
  const tbody = document.createElement('tbody');
  statusData.forEach(service => {
    const row = document.createElement('tr');
    
    const nameCell = document.createElement('td');
    nameCell.textContent = service.name;
    row.appendChild(nameCell);
    
    const statusCell = document.createElement('td');
    statusCell.className = service.status ? 'status-up' : 'status-down';
    statusCell.textContent = service.status ? 'Работает' : 'Не работает';
    row.appendChild(statusCell);
    
    tbody.appendChild(row);
  });
  table.appendChild(tbody);
  
  container.appendChild(table);
}

function renderResponseTimeChart(responseTimeData) {
  const ctx = getChartContext('response-time-chart', charts.responseTime);
  if (!ctx) return;
  
  const chartData = prepareTimeSeriesData(responseTimeData, 'Время отклика (мс)');
  
  charts.responseTime = new Chart(ctx, {
    type: 'line',
    data: chartData,
    options: getChartOptions('Время отклика', 'Время', 'мс', true)
  });
}

function renderThroughputChart(throughputData) {
  const ctx = getChartContext('throughput-chart', charts.throughput);
  if (!ctx) return;
  
  const chartData = prepareTimeSeriesData(throughputData, 'Запросов в секунду');
  
  charts.throughput = new Chart(ctx, {
    type: 'line',
    data: chartData,
    options: getChartOptions('Пропускная способность', 'Время', 'req/s', false)
  });
}

function renderErrorRateChart(errorRateData) {
  const ctx = getChartContext('error-rate-chart', charts.errorRate);
  if (!ctx) return;
  
  const chartData = prepareTimeSeriesData(errorRateData, 'Процент ошибок');
  
  charts.errorRate = new Chart(ctx, {
    type: 'line',
    data: chartData,
    options: getChartOptions('Уровень ошибок', 'Время', '%', false, {
      y: {
        min: 0,
        max: 1,
        ticks: {
          callback: function(value) {
            return (value * 100).toFixed(1) + '%';
          }
        }
      }
    })
  });
}

function renderResourceUsageCharts(resourceData) {
  // CPU Usage
  const cpuCtx = getChartContext('cpu-usage-chart', charts.cpuUsage);
  if (cpuCtx) {
    const cpuChartData = prepareTimeSeriesData(resourceData.cpu, 'CPU');
    
    charts.cpuUsage = new Chart(cpuCtx, {
      type: 'line',
      data: cpuChartData,
      options: getChartOptions('Использование CPU', 'Время', 'ядра', false)
    });
  }
  
  // Memory Usage
  const memoryCtx = getChartContext('memory-usage-chart', charts.memoryUsage);
  if (memoryCtx) {
    const memoryChartData = prepareTimeSeriesData(resourceData.memory, 'Память');
    
    charts.memoryUsage = new Chart(memoryCtx, {
      type: 'line',
      data: memoryChartData,
      options: getChartOptions('Использование памяти', 'Время', 'МБ', false, {
        y: {
          ticks: {
            callback: function(value) {
              return (value / (1024 * 1024)).toFixed(1) + ' MB';
            }
          }
        }
      })
    });
  }
}

function getChartContext(containerId, existingChart) {
  const container = document.getElementById(containerId);
  
  if (!container) return null;
  
  // Если график уже существует, уничтожаем его
  if (existingChart) {
    existingChart.destroy();
  }
  
  // Очищаем контейнер и добавляем новый canvas
  container.innerHTML = '';
  const canvas = document.createElement('canvas');
  container.appendChild(canvas);
  
  return canvas.getContext('2d');
}

function prepareTimeSeriesData(data, labelPrefix) {
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
  
  // Подготавливаем наборы данных для каждой серии
  const datasets = data.map((series, index) => {
    // Создаем хэш-карту значений для быстрого доступа
    const valueMap = new Map(series.values.map(point => [point[0], point[1]]));
    
    // Для каждой временной метки получаем соответствующее значение
    const dataPoints = timestamps.map(ts => valueMap.get(ts) || null);
    
    // Формируем метку для серии
    let label = labelPrefix;
    if (series.metric) {
      if (series.metric.instance) {
        label += ` (${series.metric.instance})`;
      } else if (series.metric.job) {
        label += ` (${series.metric.job})`;
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

function getChartOptions(title, xAxisLabel, yAxisLabel, logarithmic, scaleOverrides = {}) {
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

function setupAutoRefresh() {
  let refreshInterval;
  
  function startRefresh() {
    const refreshValue = document.getElementById('auto-refresh').value;
    if (refreshValue === 'off') {
      clearInterval(refreshInterval);
      return;
    }
    
    // Преобразование выбранного значения в миллисекунды
    const timeInMs = convertToMs(refreshValue);
    
    clearInterval(refreshInterval);
    refreshInterval = setInterval(fetchMetricsData, timeInMs);
  }
  
  function convertToMs(timeString) {
    const unit = timeString.slice(-1);
    const value = parseInt(timeString.slice(0, -1));
    
    switch(unit) {
      case 's': return value * 1000;
      case 'm': return value * 60 * 1000;
      default: return 30000; // Default to 30 seconds
    }
  }
  
  startRefresh();
}

function updateTimeRange() {
  fetchMetricsData();
}

function updateRefreshInterval() {
  setupAutoRefresh();
} 