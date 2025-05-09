// Функциональность для работы с настройками дашборда

export function fetchSettingsFromServer() {
  console.log('Пытаемся загрузить настройки с сервера');
  
  return fetch('/dashboard/settings')
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ошибка: ${response.status}`);
      }
      return response.json();
    })
    .then(data => {
      if (data.success && data.settings) {
        console.log('Настройки успешно загружены с сервера:', data);
        
        // Сохраняем в localStorage для будущего использования
        localStorage.setItem('dashboardSettings', JSON.stringify(data.settings));
        
        return data.settings;
      } else {
        console.warn('Сервер вернул некорректные данные настроек:', data);
        throw new Error('Некорректные данные от сервера');
      }
    });
}

export function saveSettingsToServer(settings) {
  return fetch('/dashboard/save_settings', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
    },
    body: JSON.stringify({ settings: settings })
  })
  .then(response => {
    if (!response.ok) {
      throw new Error('Ошибка при сохранении настроек на сервере');
    }
    return response.json();
  })
  .then(data => {
    console.log('Настройки успешно сохранены на сервере:', data);
    return data;
  });
}

export function loadSettingsFromLocalStorage() {
  const savedSettings = localStorage.getItem('dashboardSettings');
  if (savedSettings) {
    try {
      return JSON.parse(savedSettings);
    } catch (e) {
      console.error('Ошибка при парсинге сохраненных настроек:', e);
      return null;
    }
  }
  return null;
}

export function saveSettingsToLocalStorage(settings) {
  try {
    localStorage.setItem('dashboardSettings', JSON.stringify(settings));
    return true;
  } catch (e) {
    console.error('Ошибка при сохранении настроек в localStorage:', e);
    return false;
  }
}

export function setupAutoRefresh(callback) {
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
    refreshInterval = setInterval(callback, timeInMs);
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
  
  // Возвращаем функцию для возможности остановки автообновления извне
  return {
    update: startRefresh,
    stop: () => clearInterval(refreshInterval)
  };
}

export function applySettings(settings, callbacks = {}) {
  if (!settings) return;
  
  // Применяем настройки интерфейса
  if (settings.time_range) {
    const timeRangeElement = document.getElementById('time-range');
    if (timeRangeElement) {
      timeRangeElement.value = settings.time_range;
    }
  }
  
  if (settings.refresh_interval) {
    const autoRefreshElement = document.getElementById('auto-refresh');
    if (autoRefreshElement) {
      autoRefreshElement.value = settings.refresh_interval;
      
      if (callbacks.setupAutoRefresh) {
        callbacks.setupAutoRefresh();
      }
    }
  }
  
  // Применяем видимость панелей
  if (settings.displayed_panels) {
    document.querySelectorAll('.panel-toggle').forEach(checkbox => {
      const panelId = checkbox.dataset.panel;
      const isVisible = settings.displayed_panels.includes(panelId);
      checkbox.checked = isVisible;
      
      if (callbacks.togglePanelVisibility) {
        callbacks.togglePanelVisibility(panelId, isVisible);
      }
    });
  }
  
  // Применяем макет, если он есть в настройках
  if (settings.layout && settings.layout.rows && callbacks.applyLayout) {
    callbacks.applyLayout(settings.layout);
  }
}

export function updateTimeRange(callback) {
  if (callback && typeof callback === 'function') {
    callback();
  }
}

export function updateRefreshInterval(callback) {
  if (callback && typeof callback === 'function') {
    callback();
  }
}

export function saveCurrentSettings(layout) {
  const settings = {
    time_range: document.getElementById('time-range')?.value || '1h',
    refresh_interval: document.getElementById('auto-refresh')?.value || '30s',
    displayed_panels: Array.from(document.querySelectorAll('.panel-toggle:checked')).map(el => el.dataset.panel),
    layout: layout
  };
  
  // Сохраняем в localStorage
  saveSettingsToLocalStorage(settings);
  console.log('Настройки сохранены в localStorage:', settings);
  
  // Возвращаем настройки для возможного сохранения на сервере
  return settings;
}

// Загружает настройки из разных источников
export function loadSavedSettings() {
  // Пробуем загрузить из localStorage
  const savedSettings = loadSettingsFromLocalStorage();
  const savedLayout = localStorage.getItem('dashboardLayout');

  try {
    // Если нашли настройки в localStorage, возвращаем их
    if (savedSettings) {
      console.log('Загружены сохраненные настройки из localStorage');
      return Promise.resolve(savedSettings);
    }

    // Если нашли только макет, но нет полных настроек
    if (savedLayout) {
      console.log('Загружен сохраненный макет из localStorage');
      const layoutData = JSON.parse(savedLayout);
      const settings = {
        time_range: '1h',
        refresh_interval: '30s',
        displayed_panels: ['service-health', 'response-time', 'throughput', 'error-rate', 'resource-usage'],
        layout: layoutData
      };
      return Promise.resolve(settings);
    }

    // Если ничего не нашли в localStorage, загружаем с сервера
    console.log('Пытаемся загрузить настройки с сервера');
    return fetchSettingsFromServer().catch(error => {
      console.error('Ошибка при загрузке настроек с сервера:', error);
      
      // В случае ошибки возвращаем настройки по умолчанию
      return {
        time_range: '1h',
        refresh_interval: '30s',
        displayed_panels: ['service-health', 'response-time', 'throughput', 'error-rate', 'resource-usage'],
        layout: {
          rows: [
            {
              panels: ['service-health', 'response-time']
            },
            {
              panels: ['throughput', 'error-rate']
            },
            {
              panels: ['resource-usage']
            }
          ]
        }
      };
    });
  } catch (e) {
    console.error('Ошибка при загрузке настроек:', e);
    
    // В случае любой ошибки возвращаем настройки по умолчанию
    return Promise.resolve({
      time_range: '1h',
      refresh_interval: '30s',
      displayed_panels: ['service-health', 'response-time', 'throughput', 'error-rate', 'resource-usage'],
      layout: null
    });
  }
}