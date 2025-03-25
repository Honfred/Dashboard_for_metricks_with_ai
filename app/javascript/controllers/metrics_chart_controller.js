import { Controller } from "@hotwired/stimulus";
import Chart from "chart.js/auto";

export default class extends Controller {
  static targets = ["chart"];
  
  connect() {
    this.metricId = this.element.dataset.metricId;
    this.metricName = this.element.dataset.metricName;
    this.timeRange = this.element.dataset.timeRange;
    this.chart = null;
    
    this.initChart();
    this.loadData();
    
    // Автоматическое обновление каждые 30 секунд
    this.refreshInterval = setInterval(() => {
      this.refreshData();
    }, 30000);
  }
  
  disconnect() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }
    
    if (this.chart) {
      this.chart.destroy();
    }
  }
  
  initChart() {
    // Используем контекст элемента (canvas), к которому привязан этот контроллер
    const ctx = this.element.getContext('2d');
    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: [],
        datasets: [{
          label: this.metricName,
          data: [],
          borderColor: 'rgb(75, 192, 192)',
          tension: 0.1,
          fill: false
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            title: {
              display: true,
              text: 'Время'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Значение'
            },
            beginAtZero: true
          }
        },
        plugins: {
          tooltip: {
            mode: 'index',
            intersect: false
          },
          legend: {
            position: 'top'
          },
          zoom: {
            zoom: {
              wheel: {
                enabled: true
              },
              pinch: {
                enabled: true
              },
              mode: 'x'
            }
          }
        }
      }
    });
  }
  
  async loadData() {
    try {
      console.log(`Загрузка данных для метрики ID: ${this.metricId}, диапазон: ${this.timeRange}`);
      const response = await fetch(`/metrics/${this.metricId}.json?time_range=${this.timeRange}`);
      
      if (!response.ok) {
        throw new Error(`Ошибка HTTP: ${response.status}`);
      }
      
      const data = await response.json();
      console.log("Получены данные:", data);
      
      this.updateChart(data);
      this.updateStatistics(data);
    } catch (error) {
      console.error("Ошибка при загрузке данных метрики:", error);
    }
  }
  
  refreshData() {
    this.loadData();
  }
  
  updateChart(data) {
    if (!this.chart) {
      console.error("Chart не инициализирован");
      return;
    }
    
    const chartData = {
      labels: [],
      values: []
    };
    
    console.log("Обновление графика с данными:", data);
    
    // Проверяем наличие данных
    if (!data || !data.data) {
      console.warn("Нет данных для отображения");
      this.chart.data.labels = [];
      this.chart.data.datasets[0].data = [];
      this.chart.update();
      return;
    }
    
    // Проверяем, что data.data - это массив
    if (!Array.isArray(data.data)) {
      console.warn("data.data не является массивом:", data.data);
      this.chart.data.labels = [];
      this.chart.data.datasets[0].data = [];
      this.chart.update();
      return;
    }
    
    // Дополнительная проверка на пустой массив
    if (data.data.length === 0) {
      console.warn("data.data - пустой массив");
      this.chart.data.labels = [];
      this.chart.data.datasets[0].data = [];
      this.chart.update();
      return;
    }
    
    // Для каждой метрики создаем отдельный набор данных
    let datasets = [];
    
    data.data.forEach((metricItem, index) => {
      if (!metricItem.values || metricItem.values.length === 0) {
        console.warn(`Нет values в элементе ${index}:`, metricItem);
        return;
      }
      
      // Подготавливаем данные для графика
      const dataPoints = [];
      const timeLabels = [];
      
      metricItem.values.forEach(point => {
        if (Array.isArray(point) && point.length >= 2) {
          const timestamp = new Date(point[0] * 1000);
          const timeStr = timestamp.toLocaleTimeString();
          const value = parseFloat(point[1]);
          
          // Пропускаем значения NaN
          if (!isNaN(value)) {
            timeLabels.push(timeStr);
            dataPoints.push(value);
          } else {
            // Для NaN добавляем null, чтобы сохранить позицию на графике
            timeLabels.push(timeStr);
            dataPoints.push(null);
          }
        } else {
          console.warn(`Некорректный формат точки данных:`, point);
        }
      });
      
      // Если нет данных после фильтрации, пропускаем эту метрику
      if (dataPoints.length === 0) {
        console.warn(`Нет числовых данных в метрике ${index}`);
        return;
      }
      
      // Определяем метку для набора данных
      let datasetLabel = this.metricName;
      if (metricItem.metric) {
        const labels = [];
        for (const key in metricItem.metric) {
          if (key !== "__name__" && metricItem.metric[key]) {
            labels.push(`${key}="${metricItem.metric[key]}"`);
          }
        }
        if (labels.length > 0) {
          datasetLabel += ` {${labels.join(", ")}}`;
        }
      }
      
      // Определяем цвет для этого набора данных
      const colors = [
        "rgb(75, 192, 192)",
        "rgb(255, 99, 132)",
        "rgb(54, 162, 235)",
        "rgb(255, 206, 86)",
        "rgb(153, 102, 255)",
        "rgb(255, 159, 64)"
      ];
      
      // Добавляем набор данных
      datasets.push({
        label: datasetLabel,
        data: dataPoints,
        borderColor: colors[index % colors.length],
        backgroundColor: colors[index % colors.length].replace("rgb", "rgba").replace(")", ", 0.1)"),
        tension: 0.1,
        fill: false,
        pointRadius: 2
      });
      
      // Сохраняем метки времени для оси X
      chartData.labels = timeLabels;
    });
    
    // Если после обработки всех метрик нет наборов данных, ничего не отображаем
    if (datasets.length === 0) {
      console.warn("Нет корректных наборов данных для отображения");
      this.chart.data.labels = [];
      this.chart.data.datasets = [{
        label: this.metricName,
        data: [],
        borderColor: "rgb(75, 192, 192)",
        tension: 0.1,
        fill: false
      }];
      this.chart.update();
      return;
    }
    
    // Обновляем график
    this.chart.data.labels = chartData.labels;
    this.chart.data.datasets = datasets;
    this.chart.update();
    
    console.log("График успешно обновлен с данными:", {
      labels: chartData.labels,
      datasetsCount: datasets.length
    });
  }
  
  updateStatistics(data) {
    if (!data || !data.data || data.data.length === 0) {
      console.warn("Нет данных для статистики");
      
      document.getElementById("metric-average").textContent = "Нет данных";
      document.getElementById("metric-maximum").textContent = "Нет данных";
      document.getElementById("metric-minimum").textContent = "Нет данных";
      document.getElementById("metric-p95").textContent = "Нет данных";
      
      return;
    }
    
    // Объединяем все значения со всех метрик
    let allValues = [];
    
    data.data.forEach(metricItem => {
      if (metricItem.values && metricItem.values.length > 0) {
        const values = metricItem.values
          .map(point => Array.isArray(point) && point.length >= 2 ? parseFloat(point[1]) : NaN)
          .filter(val => !isNaN(val));
        
        allValues = allValues.concat(values);
      }
    });
    
    if (allValues.length === 0) {
      console.warn("Нет числовых значений для статистики");
      
      document.getElementById("metric-average").textContent = "Нет данных";
      document.getElementById("metric-maximum").textContent = "Нет данных";
      document.getElementById("metric-minimum").textContent = "Нет данных";
      document.getElementById("metric-p95").textContent = "Нет данных";
      
      return;
    }
    
    const average = allValues.reduce((sum, val) => sum + val, 0) / allValues.length;
    const maximum = Math.max(...allValues);
    const minimum = Math.min(...allValues);
    const sorted = [...allValues].sort((a, b) => a - b);
    const p95Index = Math.floor(sorted.length * 0.95);
    const p95 = sorted[p95Index];
    
    document.getElementById("metric-average").textContent = average.toFixed(2);
    document.getElementById("metric-maximum").textContent = maximum.toFixed(2);
    document.getElementById("metric-minimum").textContent = minimum.toFixed(2);
    document.getElementById("metric-p95").textContent = p95.toFixed(2);
    
    console.log("Статистика обновлена:", { average, maximum, minimum, p95 });
  }
}
