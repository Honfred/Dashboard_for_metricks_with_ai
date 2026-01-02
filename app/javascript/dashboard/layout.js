// Функциональность для управления макетом дашборда

// Глобальные переменные для Sortable
let rowsSortable = null;
let panelSortables = [];

// Глобальная переменная режима редактирования
let isEditMode = false;

export function setupDragAndDrop() {
  // Проверяем, что Sortable существует в глобальном контексте
  if (typeof Sortable === 'undefined') {
    console.error('Библиотека Sortable не найдена! Плитки не будут перетаскиваться.');
    return;
  }
  
  // Очищаем предыдущие экземпляры Sortable, если таковые были
  if (rowsSortable) {
    try {
      rowsSortable.destroy();
    } catch (e) {
      console.warn('Ошибка при уничтожении предыдущего экземпляра Sortable:', e);
    }
  }
  
  if (panelSortables && panelSortables.length) {
    panelSortables.forEach(sortable => {
      try {
        if (sortable && typeof sortable.destroy === 'function') {
          sortable.destroy();
        }
      } catch (e) {
        console.warn('Ошибка при уничтожении экземпляра Sortable для панели:', e);
      }
    });
  }
  
  // Инициализируем массив для хранения экземпляров Sortable
  panelSortables = [];
  
  // Инициализация Sortable для строк
  const gridContainer = document.getElementById('metrics-grid');
  if (!gridContainer) {
    console.error('Контейнер с id "metrics-grid" не найден!');
    return;
  }
  
  try {
    rowsSortable = new Sortable(gridContainer, {
      group: 'rows',
      animation: 150,
      disabled: true, // Изначально отключено
      ghostClass: 'sortable-ghost',
      chosenClass: 'sortable-chosen',
      dragClass: 'sortable-drag',
      onStart: function(evt) {
        document.body.classList.add('dragging-active');
      },
      onEnd: function(evt) {
        document.body.classList.remove('dragging-active');
        saveLayout();
      }
    });
  } catch (e) {
    console.error('Ошибка при инициализации Sortable для строк:', e);
  }

  // Инициализация Sortable для панелей в каждой строке
  document.querySelectorAll('.grid-row').forEach(row => {
    try {
      const sortable = new Sortable(row, {
        group: 'panels',
        animation: 150,
        disabled: true, // Изначально отключено
        ghostClass: 'sortable-ghost',
        chosenClass: 'sortable-chosen',
        dragClass: 'sortable-drag',
        swapThreshold: 0.65,
        emptyInsertThreshold: 10,
        // Улучшенные настройки для более отзывчивого перетаскивания
        onStart: function(evt) {
          document.body.classList.add('dragging-active');
          evt.item.classList.add('being-dragged');
        },
        onEnd: function(evt) {
          document.body.classList.remove('dragging-active');
          evt.item.classList.remove('being-dragged');
          
          // Принудительное обновление для гарантии правильного отображения после перетаскивания
          setTimeout(function() {
            evt.item.style.transform = '';
            evt.item.style.opacity = '';
          }, 10);
          
          saveLayout();
        }
      });
      panelSortables.push(sortable);
    } catch (e) {
      console.error('Ошибка при инициализации Sortable для панелей в строке:', e);
    }
  });
  
  // Проверяем, не был ли включен режим редактирования ранее
  const container = document.querySelector('.dashboard-container');
  if (container && container.classList.contains('edit-mode')) {
    enableDragAndDrop();
  }
}

export function enableDragAndDrop() {
  // Включаем перетаскивание строк
  if (rowsSortable && typeof rowsSortable.option === 'function') {
    try {
      rowsSortable.option('disabled', false);
    } catch (e) {
      console.error('Ошибка при включении перетаскивания строк:', e);
    }
  } else {
    console.warn('rowsSortable не инициализирован или поврежден, переинициализируем...');
    setupDragAndDrop();
    return;
  }
  
  // Включаем перетаскивание панелей внутри строк
  if (panelSortables && panelSortables.length) {
    panelSortables.forEach((sortable, index) => {
      if (sortable && typeof sortable.option === 'function') {
        try {
          sortable.option('disabled', false);
        } catch (e) {
          console.error(`Ошибка при включении перетаскивания панелей (индекс ${index}):`, e);
        }
      } else {
        console.warn(`Экземпляр Sortable для панелей с индексом ${index} не инициализирован или поврежден`);
      }
    });
  } else {
    console.warn('panelSortables не инициализирован или пуст, переинициализируем...');
    setupDragAndDrop();
  }
}

export function disableDragAndDrop() {
  // Отключаем перетаскивание строк
  if (rowsSortable && typeof rowsSortable.option === 'function') {
    try {
      rowsSortable.option('disabled', true);
    } catch (e) {
      console.error('Ошибка при отключении перетаскивания строк:', e);
    }
  }
  
  // Отключаем перетаскивание панелей внутри строк
  if (panelSortables && panelSortables.length) {
    panelSortables.forEach((sortable, index) => {
      if (sortable && typeof sortable.option === 'function') {
        try {
          sortable.option('disabled', true);
        } catch (e) {
          console.error(`Ошибка при отключении перетаскивания панелей (индекс ${index}):`, e);
        }
      }
    });
  }
}

export function toggleEditMode() {
  const container = document.querySelector('.dashboard-container');
  const button = document.querySelector('#toggle-edit-mode');
  const t = window.dashboardTranslations?.editMode || {};
  
  if (container.classList.contains('edit-mode')) {
    // Выключаем режим редактирования
    container.classList.remove('edit-mode');
    const startText = t.start || 'Режим редактирования';
    button.innerHTML = `<i class="fa fa-edit"></i> ${startText}`;
    button.classList.remove('btn-danger');
    button.classList.add('btn-primary');
    
    // Отключаем перетаскивание
    disableDragAndDrop();
    
    // Сохраняем текущее расположение
    saveCurrentLayout();
    
    isEditMode = false;
  } else {
    // Включаем режим редактирования
    container.classList.add('edit-mode');
    const finishText = t.finish || 'Завершить редактирование';
    button.innerHTML = `<i class="fa fa-check"></i> ${finishText}`;
    button.classList.remove('btn-primary');
    button.classList.add('btn-danger');
    
    // Включаем перетаскивание
    enableDragAndDrop();
    
    isEditMode = true;
  }
}

export function togglePanelVisibility(panelId, isVisible) {
  document.querySelectorAll(`.grid-panel[data-panel="${panelId}"]`).forEach(panel => {
    if (isVisible) {
      panel.classList.remove('panel-hidden');
    } else {
      panel.classList.add('panel-hidden');
    }
  });
  
  // Проверяем, есть ли видимые панели в каждом ряду
  checkEmptyRows();
  
  // Проверяем, не отключены ли все панели
  checkAllPanelsDisabled();
}

export function checkEmptyRows() {
  document.querySelectorAll('.grid-row').forEach(row => {
    // Проверяем наличие видимых панелей в ряду
    const hasVisiblePanels = Array.from(row.querySelectorAll('.grid-panel')).some(panel => {
      // Проверяем отсутствие класса panel-hidden
      return !panel.classList.contains('panel-hidden') && !panel.classList.contains('d-none');
    });
    
    // Если нет видимых панелей, скрываем ряд
    row.style.display = hasVisiblePanels ? 'flex' : 'none';
  });
}

export function checkAllPanelsDisabled() {
  const allDisabled = !document.querySelectorAll('.panel-toggle:checked').length;
  const noDataEl = document.getElementById('no-panels-message');
  
  if (allDisabled) {
    if (!noDataEl) {
      const message = document.createElement('div');
      message.id = 'no-panels-message';
      message.className = 'no-panels-message';
      message.innerHTML = `
        <div class="alert alert-info">
          <i class="fa fa-info-circle"></i>
          <p>Все панели скрыты. Включите хотя бы одну панель для отображения метрик.</p>
          <button id="show-all-panels" class="btn btn-outline-primary">Показать все панели</button>
        </div>
      `;
      document.getElementById('metrics-grid').appendChild(message);
      
      document.getElementById('show-all-panels').addEventListener('click', showAllPanels);
    }
  } else if (noDataEl) {
    noDataEl.remove();
  }
}

export function showAllPanels() {
  document.querySelectorAll('.panel-toggle').forEach(checkbox => {
    checkbox.checked = true;
    const panel = checkbox.dataset.panel;
    document.querySelectorAll(`.grid-panel[data-panel="${panel}"]`).forEach(panelEl => {
      panelEl.classList.remove('panel-hidden');
    });
  });
  
  checkEmptyRows();
  checkAllPanelsDisabled();
}

export function toggleFullscreen(e) {
  // Предотвращаем всплытие события на родительские элементы
  e.preventDefault();
  e.stopPropagation();
  
  // Получаем панель, в которой находится кнопка
  const panel = this.closest('.grid-panel');
  const panelType = panel.dataset.panel; // Получаем тип панели по data-panel атрибуту
  
  // Определяем, был ли панель в полноэкранном режиме до переключения
  const wasFullscreen = panel.classList.contains('fullscreen');
  
  // Переключаем класс fullscreen
  panel.classList.toggle('fullscreen');
  
  // Обновляем иконку и подсказку
  if (panel.classList.contains('fullscreen')) {
    this.innerHTML = '<i class="fa fa-compress"></i>';
    this.title = 'Выйти из полноэкранного режима';
    document.body.style.overflow = 'hidden'; // Предотвращаем прокрутку страницы
  } else {
    this.innerHTML = '<i class="fa fa-expand"></i>';
    this.title = 'На весь экран';
    document.body.style.overflow = ''; // Восстанавливаем прокрутку страницы
  }
  
  // Пересоздаем график в полноэкранном режиме для корректного размера
  setTimeout(() => {
    // Если мы выходим из полноэкранного режима, обновляем все графики
    if (wasFullscreen) {
      document.dispatchEvent(new CustomEvent('dashboard:refresh-all-charts'));
    } else {
      // Если входим в полноэкранный режим, обновляем только текущий график
      document.dispatchEvent(new CustomEvent('dashboard:resize-chart', { 
        detail: { panelType: panelType } 
      }));
    }
  }, 300); // Небольшая задержка для завершения анимации
}

export function getCurrentLayout() {
  // Собираем текущее расположение панелей
  const rows = [];
  
  document.querySelectorAll('.grid-row').forEach(rowEl => {
    const panels = Array.from(rowEl.querySelectorAll('.grid-panel')).map(panelEl => {
      // Генерируем уникальный ID, если его нет
      const panelId = panelEl.id || `panel-${panelEl.dataset.panel}`;
      return {
        id: panelId,
        dataPanel: panelEl.dataset.panel,
        visible: !panelEl.classList.contains('panel-hidden')
      };
    });
    rows.push({ panels: panels });
  });
  
  return { rows: rows };
}

// Сохранение текущего состояния макета в localStorage
export function saveLayout() {
  // Получаем текущее состояние макета
  const layoutData = getCurrentLayout();
  
  // Сохраняем состояние в локальное хранилище
  localStorage.setItem('dashboardLayout', JSON.stringify(layoutData));
  
  console.log('Макет сохранен в localStorage:', layoutData);
}

// Функция создания панели по её типу
export function createSamplePanel(panelType) {
  const panelEl = document.createElement('div');
  panelEl.className = `grid-panel panel ${panelType}`;
  panelEl.dataset.panel = panelType;
  panelEl.id = `panel-${panelType}`;
  
  // Заголовок панели
  const panelName = {
    'service-health': 'Состояние сервисов',
    'response-time': 'Время отклика',
    'throughput': 'Пропускная способность',
    'error-rate': 'Уровень ошибок',
    'resource-usage': 'Использование ресурсов'
  }[panelType] || 'Неизвестная панель';
  
  // Создаем шаблон панели с пустым контейнером для графика
  panelEl.innerHTML = `
    <div class="panel-header">
      <h2>${panelName}</h2>
      <div class="panel-header-actions">
        <button class="panel-fullscreen" title="На весь экран"><i class="fa fa-expand"></i></button>
      </div>
    </div>
    
    ${panelType === 'resource-usage' ? `
      <div class="resource-usage-container">
        <div id="resource-usage-chart" class="chart-container">
          <canvas id="resource-usage-canvas" width="400" height="200"></canvas>
        </div>
        <div id="cpu-usage-chart" class="chart-container">
          <canvas id="cpu-usage-canvas" width="400" height="200"></canvas>
        </div>
        <div id="memory-usage-chart" class="chart-container">
          <canvas id="memory-usage-canvas" width="400" height="200"></canvas>
        </div>
      </div>
    ` : `
      <div id="${panelType}-chart" class="chart-container">
        <canvas id="${panelType}-canvas" width="400" height="200"></canvas>
      </div>
    `}
  `;
  
  // Добавляем обработчик для кнопки полноэкранного режима
  const fullscreenBtn = panelEl.querySelector('.panel-fullscreen');
  if (fullscreenBtn) {
    fullscreenBtn.addEventListener('click', toggleFullscreen);
  }
  
  return panelEl;
}

// Функция для получения текущего состояния макета для сохранения на сервере
export function saveCurrentLayout() {
  // Событие будет обработано в основном файле dashboard.js
  document.dispatchEvent(new CustomEvent('dashboard:save-layout', { 
    detail: { layout: getCurrentLayout() } 
  }));
}

// Функция для настройки интерактивности панелей после загрузки макета
export function setupPanelInteractions() {
  // Настраиваем кнопки полноэкранного режима
  document.querySelectorAll('.panel-fullscreen').forEach(button => {
    if (!button.hasEventListener) {
      button.addEventListener('click', toggleFullscreen);
      button.hasEventListener = true;
    }
  });
}