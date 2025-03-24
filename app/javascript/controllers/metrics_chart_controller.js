import { Controller } from "stimulus";
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
    const ctx = document.getElementById("metrics-chart");
    
    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: [],
        datasets: [{
          label: this.metricName,
          data: [],
          borderColor: "rgb(75, 192, 192)",
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
              text: "Время"
            }
          },
          y: {
            title: {
              display: true,
              text: "Значение"
            },
            beginAtZero: true
          }
        },
        plugins: {
          tooltip: {
            mode: "index",
            intersect: false
          },
          legend: {
            position: "top"
          },
          zoom: {
            zoom: {
              wheel: {
                enabled: true
              },
              pinch: {
                enabled: true
              },
              mode: "x"
            }
          }
        }
      }
    });
  }
  
  async loadData() {
    try {
      const response = await fetch(`/metrics/${this.metricId}.json?time_range=${this.timeRange}`);
      const data = await response.json();
      
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
    if (!this.chart) return;
    
    const chartData = {
      labels: [],
      values: []
    };
    
    if (data.data && data.data.length > 0) {
      const metric = data.data[0];
      
      metric.values.forEach(point => {
        const timestamp = new Date(point[0] * 1000);
        chartData.labels.push(timestamp.toLocaleTimeString());
        chartData.values.push(parseFloat(point[1]));
      });
    }
    
    this.chart.data.labels = chartData.labels;
    this.chart.data.datasets[0].data = chartData.values;
    this.chart.update();
  }
  
  updateStatistics(data) {
    if (!data.data || data.data.length === 0) return;
    
    const values = data.data[0].values.map(point => parseFloat(point[1]));
    
    if (values.length === 0) return;
    
    const average = values.reduce((sum, val) => sum + val, 0) / values.length;
    const maximum = Math.max(...values);
    const minimum = Math.min(...values);
    const sorted = [...values].sort((a, b) => a - b);
    const p95Index = Math.floor(sorted.length * 0.95);
    const p95 = sorted[p95Index];
    
    document.getElementById("metric-average").textContent = average.toFixed(2);
    document.getElementById("metric-maximum").textContent = maximum.toFixed(2);
    document.getElementById("metric-minimum").textContent = minimum.toFixed(2);
    document.getElementById("metric-p95").textContent = p95.toFixed(2);
  }
}
