// Основной файл дашборда
import * as Charts from 'dashboard/charts';
import * as Layout from 'dashboard/layout';
import * as Settings from 'dashboard/settings';
import * as Alerts from 'dashboard/alerts';
import * as Data from 'dashboard/data';

// Глобальные переменные
let refreshController = null;
let currentData = null;

// Загружает данные с сервера (с фолбэком на демо-данные внутри Data)
// и перерисовывает графики с учётом выбранных сервисов
function loadData() {
  const timeRange = document.getElementById('time-range')?.value || '1h';
  return Data.fetchDataFromServer(timeRange).then(data => {
    currentData = data;
    refreshChartsWithSelectedServices(window.dashboardSelectedServices || []);
    Alerts.checkAnomalies(data);
    return data;
  });
}

document.addEventListener('DOMContentLoaded', function() {
  // Инициализация дашборда
  initDashboard();
  
  // Настройка обновления данных
  setupAutoRefresh();
  
  // Настройка перетаскивания панелей (drag-and-drop)
  Layout.setupDragAndDrop();
  
  // Инициализация системы оповещений
  Alerts.initAlerts();
  
  // Проверка скрытых панелей при загрузке
  Layout.checkEmptyRows();
  Layout.checkAllPanelsDisabled();
  
  // Инициализируем массив для выбранных сервисов в глобальном контексте
  window.dashboardSelectedServices = [];
  
  // Обработчик для события выбора сервиса из таблицы service-health
  document.addEventListener('dashboard:toggle-service', function(event) {
    const serviceName = event.detail.service;
    const ctrlKey = event.detail.ctrlKey;
    
    if (serviceName) {
      toggleServiceSelection(serviceName, ctrlKey);
    }
  });
  
  // Обработчик для обновления всех графиков (используется при выходе из полноэкранного режима)
  document.addEventListener('dashboard:refresh-all-charts', function() {
    // Обновляем все графики с текущими данными (с учётом выбранных сервисов)
    refreshChartsWithSelectedServices(window.dashboardSelectedServices || []);
  });
  
  // Обработчики для элементов управления
  document.getElementById('time-range').addEventListener('change', updateTimeRange);
  document.getElementById('auto-refresh').addEventListener('change', updateRefreshInterval);
  document.getElementById('save-layout').addEventListener('click', saveCurrentSettings);
  document.getElementById('toggle-edit-mode').addEventListener('click', Layout.toggleEditMode);
  
  // Обработчики для переключателей видимости панелей
  document.querySelectorAll('.panel-toggle').forEach(function(checkbox) {
    checkbox.addEventListener('change', function() {
      Layout.togglePanelVisibility(this.dataset.panel, this.checked);
    });
  });
  
  // Обработчики для действий с панелями
  document.querySelectorAll('.panel-fullscreen').forEach(function(button) {
    button.addEventListener('click', Layout.toggleFullscreen);
  });
  
  // Обработчик для кнопки "Показать все панели"
  const showAllBtn = document.getElementById('show-all-panels');
  if (showAllBtn) {
    showAllBtn.addEventListener('click', Layout.showAllPanels);
  }
  
  // Обработчик событий для обновления графиков при изменении размера панелей
  document.addEventListener('dashboard:resize-chart', function(event) {
    handleChartResize(event.detail.panelType);
  });
  
  // Обработчик событий для сохранения макета
  document.addEventListener('dashboard:save-layout', function(event) {
    saveCurrentSettings();
  });
});

function initDashboard() {
  console.log('Инициализация дашборда начата...');

  try {
    // Сначала применяем сохранённые настройки (временной диапазон, панели, макет),
    // затем загружаем данные уже для актуального диапазона
    loadSettings()
      .then(() => loadData())
      .then(() => {
        console.log('Дашборд инициализирован успешно');
      })
      .catch(error => {
        console.error('Ошибка при инициализации дашборда:', error);
        // В случае ошибки показываем демо-данные, чтобы дашборд не оставался пустым
        currentData = Data.createDemoData();
        Charts.renderCharts(currentData);
      });
  } catch (e) {
    console.error('Ошибка при инициализации дашборда:', e);
    const initErrorMsg = window.dashboardTranslations?.messages?.initError || 'Ошибка при инициализации дашборда';
    Charts.showChartError(initErrorMsg + ': ' + e.message);

    // Попытка восстановления при ошибке - создаем данные заново
    try {
      currentData = Data.createDemoData();
      Charts.renderCharts(currentData);
    } catch (recoveryError) {
      console.error('Не удалось восстановиться после ошибки:', recoveryError);
    }
  }
}

// Переключение выбора сервиса (с учетом Ctrl для множественного выбора)
function toggleServiceSelection(serviceName, isMultiSelect) {
  console.log('Переключение выбора сервиса:', serviceName, 'множественный выбор:', isMultiSelect);
  
  // Получаем текущий список выбранных сервисов
  let selectedServices = window.dashboardSelectedServices || [];
  
  if (isMultiSelect) {
    // Режим множественного выбора - добавляем или удаляем сервис из списка
    const serviceIndex = selectedServices.indexOf(serviceName);
    if (serviceIndex !== -1) {
      // Если сервис уже выбран, удаляем его
      selectedServices.splice(serviceIndex, 1);
    } else {
      // Иначе добавляем его
      selectedServices.push(serviceName);
    }
  } else {
    // Режим одиночного выбора - либо выбираем только этот сервис, либо сбрасываем выбор
    if (selectedServices.length === 1 && selectedServices[0] === serviceName) {
      // Если был выбран только этот сервис, сбрасываем выбор
      selectedServices = [];
    } else {
      // Иначе выбираем только этот сервис
      selectedServices = [serviceName];
    }
  }
  
  console.log('Новый список выбранных сервисов:', selectedServices);
  
  // Обновляем глобальный список выбранных сервисов
  window.dashboardSelectedServices = selectedServices;
  
  // Обновляем выбор в модуле Data
  Data.setSelectedServices(selectedServices);
  
  // Обновляем интерфейс
  updateServiceSelection(selectedServices);
  
  // Обновляем графики
  refreshChartsWithSelectedServices(selectedServices);
}

// Выбор одного сервиса (сбрасывает все предыдущие выборы)
function selectOneService(serviceName) {
  window.dashboardSelectedServices = [serviceName];
  Data.setSelectedServices([serviceName]);
  updateServiceSelection([serviceName]);
  refreshChartsWithSelectedServices([serviceName]);
}

// Очистка выбора сервисов
function clearServiceSelection() {
  window.dashboardSelectedServices = [];
  Data.setSelectedServices([]);
  updateServiceSelection([]);
  refreshChartsWithSelectedServices([]);
}

// Обновление интерфейса в соответствии с выбранными сервисами
function updateServiceSelection(selectedServices) {
  // Обновляем выделение строк в таблице сервисов
  document.querySelectorAll('.service-row').forEach(row => {
    const serviceName = row.dataset.service;
    if (selectedServices.includes(serviceName)) {
      row.classList.add('selected');
    } else {
      row.classList.remove('selected');
    }
  });
  
  // Обновляем индикаторы на графиках
  updateSelectedServiceIndicators(selectedServices);
}

// Обновляет индикаторы выбранных сервисов на панелях
function updateSelectedServiceIndicators(services) {
  // Удаляем все существующие индикаторы
  document.querySelectorAll('.selected-service-indicator').forEach(el => el.remove());
  
  if (services.length === 0) return; // Не показываем индикаторы, если не выбраны сервисы
  
  // Добавляем индикаторы на все панели, кроме service-health
  document.querySelectorAll('.grid-panel:not(.service-health)').forEach(panel => {
    const indicator = document.createElement('div');
    indicator.className = 'selected-service-indicator';
    
    const serviceLabel = window.dashboardTranslations?.serviceLabel || 'Сервис';
    
    // Формируем текст индикатора в зависимости от количества выбранных сервисов
    if (services.length === 1) {
      indicator.textContent = `${serviceLabel}: ${services[0]}`;
    } else {
      indicator.textContent = `${serviceLabel}: ${services.length}`;
    }
    
    panel.appendChild(indicator);
    
    // Показываем индикатор
    indicator.style.display = 'block';
  });
}

// Обновление графиков с учетом выбранных сервисов
function refreshChartsWithSelectedServices(services) {
  if (currentData) {
    // Фильтруем данные для выбранных сервисов или показываем все
    const filteredData = services.length === 0 ? currentData :
                        Data.filterDataByServices(currentData, services);

    Charts.renderCharts(filteredData);
  } else {
    // Данных ещё нет — загружаем (после загрузки графики отрисуются)
    loadData();
  }
}

function loadSettings() {
  return Settings.loadSavedSettings()
    .then(settings => {
      if (settings) {
        // Применяем загруженные настройки
        Settings.applySettings(settings, {
          setupAutoRefresh: setupAutoRefresh,
          togglePanelVisibility: Layout.togglePanelVisibility,
          applyLayout: applyLayout
        });
      }
      return settings;
    })
    .catch(error => {
      console.error('Ошибка при загрузке настроек дашборда:', error);
      return null;
    });
}

function setupAutoRefresh() {
  // Останавливаем предыдущий контроллер обновления, если он существует
  if (refreshController && typeof refreshController.stop === 'function') {
    refreshController.stop();
  }
  
  // Создаем новый контроллер обновления
  refreshController = Settings.setupAutoRefresh(function() {
    // Функция для периодического обновления данных
    loadData();
  });
}

function updateTimeRange() {
  // Обновляем данные при изменении временного диапазона
  loadData();
}

function updateRefreshInterval() {
  setupAutoRefresh();
}

function applyLayout(layoutData) {
  // Проверяем, что данные макета корректны
  if (!layoutData || !layoutData.rows || !Array.isArray(layoutData.rows)) {
    console.error('Некорректные данные макета:', layoutData);
    return;
  }
  
  const gridContainer = document.getElementById('metrics-grid');
  if (!gridContainer) {
    console.error('Не найден контейнер с id "metrics-grid"');
    return;
  }
  
  // Сохраняем все оригинальные панели по их data-panel, а не по id
  const originalPanels = {};
  document.querySelectorAll('.grid-panel').forEach(panel => {
    const panelType = panel.dataset.panel;
    if (panelType) {
      originalPanels[panelType] = panel.cloneNode(true);
    }
  });
  
  // Очищаем текущий контейнер
  gridContainer.innerHTML = '';
  
  // Воссоздаем структуру строк и панелей на основе сохраненных данных
  layoutData.rows.forEach((rowData, rowIndex) => {
    // Создаем новую строку
    const rowEl = document.createElement('div');
    rowEl.className = 'grid-row';
    rowEl.id = `row-${rowIndex + 1}`;
    rowEl.dataset.row = rowIndex;
    
    // Добавляем панели в строку
    if (rowData.panels) {
      // Обрабатываем панели в разных форматах
      rowData.panels.forEach(panelData => {
        let panelType; // Тип панели (service-health, response-time и т.д.)
        let panelId; // ID панели для уникальной идентификации
        let isVisible = true; // Видимость панели

        // Определяем тип панели в зависимости от формата данных
        if (typeof panelData === 'string') {
          // Если панель - просто строка
          panelType = panelData;
          panelId = `panel-${panelType}`;
        } else if (panelData && typeof panelData === 'object') {
          // Если панель - это объект с полями
          if (panelData.dataPanel) {
            panelType = panelData.dataPanel;
          } else if (panelData.id && panelData.id.startsWith('panel-')) {
            // Извлекаем тип из ID, если возможно
            panelType = panelData.id.replace('panel-', '');
          }
          
          panelId = panelData.id || `panel-${panelType}`;
          
          // Проверяем видимость, если она указана
          if (panelData.hasOwnProperty('visible')) {
            isVisible = panelData.visible;
          }
        }
        
        if (!panelType) {
          console.warn(`Невозможно определить тип панели для данных:`, panelData);
          return; // Пропускаем эту панель
        }
        
        // Получаем существующую панель или создаем заглушку
        let panelEl;
        
        if (originalPanels[panelType]) {
          // Используем клон оригинальной панели
          panelEl = originalPanels[panelType].cloneNode(true);
          
          // Убеждаемся, что id соответствует панели
          panelEl.id = panelId;
          
          // Применяем видимость
          panelEl.style.display = isVisible ? 'block' : 'none';
        } else {
          // Создаем заглушку, если панель не найдена
          console.warn(`Панель с типом ${panelType} не найдена`);
          panelEl = Layout.createSamplePanel(panelType);
          
          // Применяем видимость
          if (!isVisible) {
            panelEl.style.display = 'none';
          }
        }
        
        // Добавляем панель в строку
        rowEl.appendChild(panelEl);
      });
    }
    
    // Добавляем строку в контейнер
    gridContainer.appendChild(rowEl);
  });
  
  // Повторно инициализируем drag-and-drop функциональность
  Layout.setupDragAndDrop();
  
  // Повторно подключаем обработчики событий для кнопок и функций
  Layout.setupPanelInteractions();
  
  // Проверяем пустые ряды и скрытые панели
  Layout.checkEmptyRows();
  Layout.checkAllPanelsDisabled();

  // Обновляем графики, если данные уже загружены
  // (при инициализации данные загрузятся позже и отрисуются сами)
  try {
    if (currentData) {
      refreshChartsWithSelectedServices(window.dashboardSelectedServices || []);
    }
  } catch (e) {
    console.error('Ошибка при рендеринге графиков после применения макета:', e);
  }
}

function handleChartResize(panelType) {
  // Обрабатываем изменение размера графика в полноэкранном режиме
  if (panelType === 'service-health') {
    // Для таблицы сервисов не нужно пересоздавать график
    const container = document.querySelector(`.grid-panel[data-panel="${panelType}"] .chart-container`);
    if (container && !container.querySelector('.status-table')) {
      const health = currentData?.service_health || Data.generateServiceHealthData();
      Charts.renderServiceHealthTable(container.id, health);
    }
  } else {
    // Обновляем соответствующий график по текущим данным
    if (!currentData) {
      loadData();
      return;
    }

    if (panelType === 'response-time' && currentData.response_time) {
      Charts.renderCharts({ response_time: currentData.response_time });
    } else if (panelType === 'throughput' && currentData.throughput) {
      Charts.renderCharts({ throughput: currentData.throughput });
    } else if (panelType === 'error-rate' && currentData.error_rate) {
      Charts.renderCharts({ error_rate: currentData.error_rate });
    } else if (panelType === 'resource-usage' && currentData.resource_usage) {
      Charts.renderCharts({ resource_usage: currentData.resource_usage });
    }
  }
}

function saveCurrentSettings() {
  // Собираем текущий макет
  const layoutData = Layout.getCurrentLayout();
  
  // Собираем и сохраняем все настройки
  const settings = Settings.saveCurrentSettings(layoutData);
  
  // Отправляем на сервер
  Settings.saveSettingsToServer(settings)
    .then(data => {
      const msg = window.dashboardTranslations?.messages?.settingsSaved || 'Настройки успешно сохранены';
      alert(msg);
    })
    .catch(error => {
      console.error('Ошибка при сохранении настроек:', error);
      const msg = window.dashboardTranslations?.messages?.settingsSavedLocally || 'Настройки сохранены локально, но не удалось сохранить на сервере';
      alert(msg + ': ' + error.message);
    });
}