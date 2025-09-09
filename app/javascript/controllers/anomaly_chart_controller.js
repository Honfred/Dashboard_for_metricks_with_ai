import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Object }
  
  connect() {
    if (!this.dataValue) return
    
    const chartData = this.dataValue.chart_data
    if (!chartData || !chartData.timestamps || !chartData.values) return

    // Форматируем метки времени
    const labels = chartData.timestamps.map(ts => {
      const date = new Date(ts * 1000)
      return date.toLocaleString('ru', { hour: '2-digit', minute: '2-digit', day: '2-digit', month: '2-digit' })
    })
    
    // Получаем данные аномалий
    const anomaliesMap = {}
    if (chartData.anomalies) {
      chartData.anomalies.forEach(a => {
        anomaliesMap[a.timestamp] = a.value
      })
    }
    
    // Создаем массивы данных для графика
    const normalData = []
    const anomalyData = []
    
    chartData.timestamps.forEach((ts, index) => {
      if (anomaliesMap[ts]) {
        normalData.push(null)
        anomalyData.push(chartData.values[index])
      } else {
        normalData.push(chartData.values[index])
        anomalyData.push(null)
      }
    })
    
    // Создаем график
    const ctx = this.element.getContext('2d')
    
    new Chart(ctx, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [
          {
            label: 'Нормальные значения',
            data: normalData,
            borderColor: 'rgba(75, 192, 192, 1)',
            tension: 0.1,
            pointRadius: 3
          },
          {
            label: 'Аномалии',
            data: anomalyData,
            borderColor: 'rgba(255, 99, 132, 1)',
            backgroundColor: 'rgba(255, 99, 132, 0.2)',
            tension: 0,
            pointRadius: 6,
            pointStyle: 'triangle'
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            grid: {
              display: false
            }
          }
        },
        plugins: {
          tooltip: {
            mode: 'index',
            intersect: false
          },
          legend: {
            position: 'top',
          },
          title: {
            display: true,
            text: 'График значений метрики с аномалиями'
          }
        }
      }
    })
  }
}