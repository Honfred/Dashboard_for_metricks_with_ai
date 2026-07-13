// Функциональность для генерации демо-данных для дашборда

// Массив для хранения выбранных сервисов
let selectedServices = [];

// Функция для установки выбранных сервисов
export function setSelectedServices(services) {
  if (!Array.isArray(services)) {
    services = [services]; // Преобразуем одиночное значение в массив
  }
  selectedServices = services;
  return selectedServices;
}

// Функция для добавления сервиса в список выбранных
export function addSelectedService(service) {
  if (!selectedServices.includes(service)) {
    selectedServices.push(service);
  }
  return selectedServices;
}

// Функция для удаления сервиса из списка выбранных
export function removeSelectedService(service) {
  selectedServices = selectedServices.filter(s => s !== service);
  return selectedServices;
}

// Функция для переключения состояния сервиса (добавление/удаление)
export function toggleSelectedService(service) {
  if (selectedServices.includes(service)) {
    return removeSelectedService(service);
  } else {
    return addSelectedService(service);
  }
}

// Функция для получения текущих выбранных сервисов
export function getSelectedServices() {
  return selectedServices;
}

// Устаревшая функция для обратной совместимости
export function setSelectedService(service) {
  if (service === 'all') {
    selectedServices = [];
  } else {
    selectedServices = [service];
  }
  return selectedServices;
}

// Устаревшая функция для обратной совместимости
export function getSelectedService() {
  return selectedServices.length === 0 ? 'all' : selectedServices[0];
}

// Функция для генерации тестовых данных для дашборда
export function createDemoData() {
  // Генерируем тестовые данные для демонстрации
  const now = new Date();
  
  // Безопасное получение значения временного диапазона
  let timeRange = '1h'; // Значение по умолчанию
  const timeRangeElement = document.getElementById('time-range');
  if (timeRangeElement && timeRangeElement.value) {
    timeRange = timeRangeElement.value;
  }
  
  const numPoints = getNumPointsForTimeRange(timeRange);
  const interval = getIntervalForTimeRange(timeRange);
  
  // Генерируем общие данные для всех сервисов
  const allServicesData = generateDataForAllServices(numPoints, interval);
  
  // Если выбраны определенные сервисы, фильтруем данные
  if (selectedServices.length > 0) {
    return filterDataByServices(allServicesData, selectedServices);
  }
  
  return allServicesData;
}

// Функция для генерации данных по всем сервисам
function generateDataForAllServices(numPoints, interval) {
  // Список доступных сервисов
  const services = [
    'API Gateway', 
    'Auth Service', 
    'User Service', 
    'Payment Service', 
    'Notification Service', 
    'Analytics Service'
  ];
  
  // Генерируем данные для каждого сервиса
  const responseTimeDatasets = [];
  const throughputDatasets = [];
  const errorRateDatasets = [];
  const cpuDatasets = [];
  const memoryDatasets = [];
  
  // Для каждого сервиса генерируем свой набор данных
  services.forEach((service, index) => {
    // Добавляем небольшую вариацию данных для разных сервисов
    const responseTimeFactor = 0.8 + (index * 0.1);
    const throughputFactor = 1.0 - (index * 0.05);
    const errorRateFactor = 0.5 + (index * 0.3);
    const cpuFactor = 0.7 + (index * 0.1);
    const memoryFactor = 0.9 - (index * 0.05);
    
    // Добавляем сервис-специфичные датасеты (без дублирования метрик в названиях)
    const responseTimeData = generateTimeSeriesDataForService(
      numPoints, interval, 200 * responseTimeFactor, 800 * responseTimeFactor, 
      service, 'мс', false, service
    )[0];
    responseTimeDatasets.push(responseTimeData);
    
    const throughputData = generateTimeSeriesDataForService(
      numPoints, interval, 50 * throughputFactor, 150 * throughputFactor, 
      service, 'req/s', false, service
    )[0];
    throughputDatasets.push(throughputData);
    
    const errorRateData = generateTimeSeriesDataForService(
      numPoints, interval, 0, 0.05 * errorRateFactor, 
      service, '%', false, service
    )[0];
    errorRateDatasets.push(errorRateData);
    
    // Оставляем полные названия только для графиков ресурсов
    const cpuData = generateTimeSeriesDataForService(
      numPoints, interval, 10 * cpuFactor, 90 * cpuFactor, 
      `${service} - CPU`, '%', false, service
    )[0];
    cpuDatasets.push(cpuData);
    
    const memoryData = generateTimeSeriesDataForService(
      numPoints, interval, 20 * memoryFactor, 80 * memoryFactor, 
      `${service} - Память`, '%', false, service
    )[0];
    memoryDatasets.push(memoryData);
  });
  
  // Добавляем пороговые линии для графика ошибок
  const errorRateThreshold = generateTimeSeriesDataForService(
    numPoints, interval, 0.035, 0.035, 
    'Порог', '%', false, 'threshold'
  )[0];
  errorRateThreshold.borderColor = '#e74c3c';
  errorRateThreshold.backgroundColor = 'rgba(231, 76, 60, 0.1)';
  errorRateThreshold.borderDash = [5, 5];
  errorRateThreshold.tension = 0;
  errorRateDatasets.push(errorRateThreshold);
  
  // Комбинируем данные по CPU и памяти для общего графика использования ресурсов
  const resourceUsageData = [];
  services.forEach((service, index) => {
    resourceUsageData.push({
      label: `${service} - CPU`,
      data: cpuDatasets[index].data,
      borderColor: getColorForIndex(index),
      backgroundColor: 'rgba(52, 152, 219, 0.1)',
      tension: 0.3,
      service: service
    });
    
    resourceUsageData.push({
      label: `${service} - Память`,
      data: cpuDatasets[index].data.map((point, i) => {
        return {
          x: point.x, 
          y: memoryDatasets[index].data[i].y
        };
      }),
      borderColor: getColorForIndex(index + services.length),
      backgroundColor: 'rgba(231, 76, 60, 0.1)',
      tension: 0.3,
      borderDash: [5, 5],
      service: service
    });
  });
  
  const demoData = {
    response_time: responseTimeDatasets,
    throughput: throughputDatasets,
    error_rate: errorRateDatasets,
    service_health: generateServiceHealthData(),
    resource_usage: {
      overview: resourceUsageData,
      cpu: cpuDatasets,
      memory: memoryDatasets
    },
    // Добавляем список сервисов для селектора
    services: services
  };
  
  console.log('Сгенерированные демо-данные:', demoData);
  return demoData;
}

// Фильтрует данные по выбранным сервисам
export function filterDataByServices(data, services) {
  if (!services || services.length === 0) return data;
  
  console.log('Фильтрация данных для сервисов:', services);
  
  // Проверяем входные параметры
  if (!data || !Array.isArray(services)) {
    console.error('Некорректные параметры функции filterDataByServices:', data, services);
    return data;
  }
  
  // Функция для проверки, относится ли набор данных к выбранному сервису
  function belongsToSelectedService(dataset) {
    // Если элемент - служебный (например, порог), всегда включаем его
    if (dataset.service === 'threshold' || dataset.label === 'Порог') {
      return true;
    }
    
    // Проверяем, содержит ли метка сервиса один из выбранных сервисов
    return services.some(service => {
      return dataset.service === service || 
             (dataset.label && dataset.label.includes(service));
    });
  }
  
  const filteredData = {
    response_time: Array.isArray(data.response_time) ? data.response_time.filter(belongsToSelectedService) : data.response_time,
    throughput: Array.isArray(data.throughput) ? data.throughput.filter(belongsToSelectedService) : data.throughput,
    error_rate: Array.isArray(data.error_rate) ? data.error_rate.filter(dataset => {
      // Всегда включаем порог ошибок
      return belongsToSelectedService(dataset) || dataset.service === 'threshold' || dataset.borderDash;
    }) : data.error_rate,
    // Для таблицы состояния сервисов показываем все сервисы
    service_health: data.service_health,
    resource_usage: {
      overview: Array.isArray(data.resource_usage?.overview) ? data.resource_usage.overview.filter(belongsToSelectedService) : data.resource_usage?.overview,
      cpu: Array.isArray(data.resource_usage?.cpu) ? data.resource_usage.cpu.filter(belongsToSelectedService) : data.resource_usage?.cpu,
      memory: Array.isArray(data.resource_usage?.memory) ? data.resource_usage.memory.filter(belongsToSelectedService) : data.resource_usage?.memory
    },
    // Сохраняем полный список сервисов для селектора
    services: data.services
  };
  
  console.log('Отфильтрованные данные:', filteredData);
  return filteredData;
}

// Устаревшая функция для обратной совместимости
function filterDataByService(data, serviceName) {
  return filterDataByServices(data, [serviceName]);
}

// Цвета для сервисов 
function getColorForIndex(index) {
  const colors = [
    '#3498db', // голубой
    '#e74c3c', // красный
    '#2ecc71', // зеленый
    '#f39c12', // оранжевый
    '#9b59b6', // фиолетовый
    '#1abc9c', // бирюзовый
    '#34495e', // тёмно-серый
    '#7f8c8d'  // серый
  ];
  return colors[index % colors.length];
}

export function getNumPointsForTimeRange(timeRange) {
  switch(timeRange) {
    case '15m': return 15;
    case '1h': return 60;
    case '3h': return 36;
    case '6h': return 72;
    case '12h': return 72;
    case '24h': return 96;
    case '7d': return 168;
    default: return 60;
  }
}

export function getIntervalForTimeRange(timeRange) {
  switch(timeRange) {
    case '15m': return 60 * 1000; // 1 минута
    case '1h': return 60 * 1000; // 1 минута
    case '3h': return 5 * 60 * 1000; // 5 минут
    case '6h': return 5 * 60 * 1000; // 5 минут
    case '12h': return 10 * 60 * 1000; // 10 минут
    case '24h': return 15 * 60 * 1000; // 15 минут
    case '7d': return 60 * 60 * 1000; // 1 час
    default: return 60 * 1000; // 1 минута
  }
}

// Модифицированная функция для создания данных временных рядов для конкретного сервиса
function generateTimeSeriesDataForService(numPoints, interval, min, max, label, unit, includeThreshold = false, serviceName) {
  const now = new Date().getTime();
  const datasets = [];
  
  // Основная серия данных
  const mainSeries = {
    label: label,
    data: [],
    borderColor: getColorForServiceName(serviceName),
    backgroundColor: 'rgba(52, 152, 219, 0.2)',
    tension: 0.3,
    service: serviceName
  };
  
  // Генерируем случайные значения
  let prevValue = min + Math.random() * (max - min);
  
  for (let i = 0; i < numPoints; i++) {
    const timestamp = new Date(now - (numPoints - i - 1) * interval);
    
    // Небольшая случайность в значениях
    const change = Math.random() * 0.2 - 0.1;
    const randomJump = Math.random() > 0.95 ? (Math.random() * 0.3 - 0.15) : 0;
    
    let newValue = prevValue * (1 + change + randomJump);
    newValue = Math.max(min, Math.min(max, newValue));
    prevValue = newValue;
    
    mainSeries.data.push({
      x: timestamp,
      y: newValue
    });
  }
  
  datasets.push(mainSeries);
  
  // Добавляем порог, если необходимо
  if (includeThreshold) {
    const threshold = {
      label: 'Порог',
      data: [],
      borderColor: '#e74c3c',
      backgroundColor: 'rgba(231, 76, 60, 0.1)',
      borderDash: [5, 5],
      tension: 0,
      service: 'threshold' // Особое значение для порога
    };
    
    const thresholdValue = min + (max - min) * 0.7;
    
    for (let i = 0; i < numPoints; i++) {
      const timestamp = new Date(now - (numPoints - i - 1) * interval);
      threshold.data.push({
        x: timestamp,
        y: thresholdValue
      });
    }
    
    datasets.push(threshold);
  }
  
  return datasets;
}

// Возвращает цвет на основе имени сервиса
function getColorForServiceName(serviceName) {
  const colors = {
    'API Gateway': '#3498db',
    'Auth Service': '#e74c3c',
    'User Service': '#2ecc71',
    'Payment Service': '#f39c12',
    'Notification Service': '#9b59b6',
    'Analytics Service': '#1abc9c',
    'threshold': '#e74c3c'
  };
  
  return colors[serviceName] || '#7f8c8d'; // Серый цвет по умолчанию
}

export function generateTimeSeriesData(numPoints, interval, min, max, label, unit, includeThreshold = false) {
  return generateTimeSeriesDataForService(numPoints, interval, min, max, label, unit, includeThreshold, 'all');
}

export function generateServiceHealthData() {
  const services = [
    { name: 'API Gateway', status: 'up', uptime: '99.98%' },
    { name: 'Auth Service', status: 'up', uptime: '99.95%' },
    { name: 'User Service', status: 'up', uptime: '99.99%' },
    { name: 'Payment Service', status: Math.random() > 0.8 ? 'down' : 'up', uptime: '98.54%' },
    { name: 'Notification Service', status: 'up', uptime: '99.91%' },
    { name: 'Analytics Service', status: Math.random() > 0.9 ? 'down' : 'up', uptime: '99.78%' }
  ];
  
  return services;
}

// Функция для запроса реальных данных с сервера (если доступны)
// Возвращает данные в формате, понятном renderCharts; при ошибке или
// отсутствии данных в Prometheus возвращает демо-данные
export function fetchDataFromServer(timeRange) {
  return fetch(`/dashboard/metrics?time_range=${encodeURIComponent(timeRange)}`)
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then(serverData => {
      const transformed = transformServerData(serverData);
      if (transformed) {
        console.log('Используем данные Prometheus с сервера:', transformed);
        return transformed;
      }
      console.warn('Сервер не вернул данных метрик, используем демо-данные');
      return createDemoData();
    })
    .catch(error => {
      console.error('Ошибка при загрузке данных с сервера:', error);
      // В случае ошибки генерируем демо-данные
      return createDemoData();
    });
}

// Преобразует ответ /dashboard/metrics (серии Prometheus) в формат датасетов
// для renderCharts. Возвращает null, если данных нет.
export function transformServerData(serverData) {
  if (!serverData || typeof serverData !== 'object' || serverData.error) {
    return null;
  }

  // Одна серия Prometheus -> датасет Chart.js
  function seriesToDataset(series, index, labelSuffix = '', dashed = false) {
    const name = (series.metric && (series.metric.instance || series.metric.job)) || `series-${index + 1}`;
    return {
      label: labelSuffix ? `${name} - ${labelSuffix}` : name,
      data: (series.values || []).map(point => ({ x: point[0], y: point[1] })),
      borderColor: getColorForIndex(index),
      backgroundColor: 'transparent',
      tension: 0.3,
      borderDash: dashed ? [5, 5] : [],
      service: name
    };
  }

  function toDatasets(seriesList, labelSuffix = '', dashed = false) {
    if (!Array.isArray(seriesList)) return [];
    return seriesList.map((series, index) => seriesToDataset(series, index, labelSuffix, dashed));
  }

  const responseTime = toDatasets(serverData.response_time);
  const throughput = toDatasets(serverData.throughput);
  const errorRate = toDatasets(serverData.error_rate);
  const cpu = toDatasets(serverData.resource_usage && serverData.resource_usage.cpu, 'CPU');
  const memory = toDatasets(serverData.resource_usage && serverData.resource_usage.memory, 'Память', true);

  const hasData = [responseTime, throughput, errorRate, cpu, memory]
    .some(datasets => datasets.some(d => d.data.length > 0));
  if (!hasData) {
    return null;
  }

  // Статус сервисов: сервер отдаёт boolean, таблица ожидает 'up'/'down'
  const serviceHealth = (serverData.services_status || []).map(item => ({
    name: item.name,
    status: item.status ? 'up' : 'down',
    uptime: item.uptime || '—'
  }));

  return {
    response_time: responseTime,
    throughput: throughput,
    error_rate: errorRate,
    service_health: serviceHealth,
    resource_usage: {
      overview: cpu.concat(memory),
      cpu: cpu,
      memory: memory
    },
    services: serviceHealth.map(s => s.name)
  };
}

// Функция для обработки данных временных рядов из Prometheus
export function processPrometheusData(data) {
  if (!data || !data.data || !data.data.result) {
    return [];
  }
  
  return data.data.result.map(series => {
    return {
      metric: series.metric,
      values: series.values
    };
  });
}