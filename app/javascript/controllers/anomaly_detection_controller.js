import { Controller } from "stimulus";
import Chart from "chart.js/auto";

export default class extends Controller {
  connect() {
    const chartElement = document.getElementById("analysis-chart");
    
    if (!chartElement) return;
    
    this.metricId = chartElement.dataset.metricId;
    this.analysisId = chartElement.dataset.analysisId;
    this.analysisType = chartElement.dataset.analysisType;
    this.chart = null;
    
    this.initChart();
    this.loadData();
  }
  
  disconnect() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
  
  initChart() {
    const ctx = document.getElementById("analysis-chart");
    
    this.chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: [],
        datasets: [
          {
            label: "Фактические значения",
            data: [],
            borderColor: "rgb(75, 192, 192)",
            pointRadius: 2,
            fill: false
          },
          {
            label: "Предсказанные значения",
            data: [],
            borderColor: "rgb(255, 159, 64)",
            borderDash: [5, 5],
            pointRadius: 0,
            fill: false
          },
          {
            label: "Верхняя граница",
            data: [],
            borderColor: "rgba(255, 99, 132, 0.5)",
            pointRadius: 0,
            fill: false
          },
          {
            label: "Нижняя граница",
            data: [],
            borderColor: "rgba(255, 99, 132, 0.5)",
            pointRadius: 0,
            fill: {
              target: "+2",
              above: "rgba(255, 99, 132, 0.1)"
            }
          },
          {
            label: "Аномалии",
            data: [],
            backgroundColor: "rgb(255, 99, 132)",
            borderColor: "rgb(255, 99, 132)",
            pointRadius: 6,
            pointStyle: "circle",
            fill: false
          }
        ]
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
            }
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
          annotation: {
            annotations: {
              box1: {
                type: "box",
                xMin: 0,
                xMax: 0,
                yMin: 0,
                yMax: 0,
                backgroundColor: "rgba(255, 99, 132, 0.25)"
              }
            }
          }
        },
        interaction: {
          mode: "nearest",
          axis: "x",
          intersect: false
        }
      }
    });
  }
  
  async loadData() {
    try {
      const response = await fetch(`/metrics/${this.metricId}/ai_analyses/${this.analysisId}.json`);
      const data = await response.json();
      
      if (data.data && this.chart) {
        this.updateChart(data.data);
      }
    } catch (error) {
      console.error("Ошибка при загрузке данных анализа:", error);
    }
  }
  
  updateChart(data) {
    if (!this.chart) return;
    
    const times = [];
    const actualValues = [];
    const predictedValues = [];
    const upperBoundValues = [];
    const lowerBoundValues = [];
    const anomalies = [];
    
    // Обработка временных рядов
    if (data.timeseries) {
      data.timeseries.forEach(point => {
        const timestamp = new Date(point.timestamp * 1000);
        times.push(timestamp.toLocaleTimeString());
        actualValues.push(point.actual);
        
        if (point.predicted !== undefined) {
          predictedValues.push(point.predicted);
        } else {
          predictedValues.push(null);
        }
        
        if (point.upper_bound !== undefined) {
          upperBoundValues.push(point.upper_bound);
        } else {
          upperBoundValues.push(null);
        }
        
        if (point.lower_bound !== undefined) {
          lowerBoundValues.push(point.lower_bound);
        } else {
          lowerBoundValues.push(null);
        }
        
        if (point.is_anomaly) {
          anomalies.push(point.actual);
        } else {
          anomalies.push(null);
        }
      });
    }
    
    this.chart.data.labels = times;
    this.chart.data.datasets[0].data = actualValues;
    this.chart.data.datasets[1].data = predictedValues;
    this.chart.data.datasets[2].data = upperBoundValues;
    this.chart.data.datasets[3].data = lowerBoundValues;
    this.chart.data.datasets[4].data = anomalies;
    
    // Обновляем аннотации для подсветки аномалий
    const annotations = {};
    if (data.events) {
      data.events
        .filter(event => event.type === "anomaly")
        .forEach((anomaly, index) => {
          const startIndex = this.findClosestTimeIndex(times, anomaly.timestamp - 300);
          const endIndex = this.findClosestTimeIndex(times, anomaly.timestamp + 300);
          
          annotations[`anomaly${index}`] = {
            type: "box",
            xMin: times[startIndex],
            xMax: times[endIndex],
            borderColor: "rgba(255, 99, 132, 0.5)",
            backgroundColor: "rgba(255, 99, 132, 0.1)"
          };
        });
    }
    
    this.chart.options.plugins.annotation = { annotations };
    this.chart.update();
  }
  
  findClosestTimeIndex(times, timestamp) {
    const targetTime = new Date(timestamp * 1000).toLocaleTimeString();
    return times.findIndex(time => time >= targetTime) || 0;
  }
}
